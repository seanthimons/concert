# File Handlers for Shiny Data Upload Application
# Functions for reading, validating, and processing uploaded files

#' Safely read a file with multiple fallback strategies
#'
#' @param filepath Character. Path to the file to read
#' @param file_ext Character. File extension (csv, xlsx, xls)
#' @return A tibble with the raw file contents (no header parsing)
#' @export
safely_read_file <- function(filepath, file_ext) {
  # For CSV files, skip rio::import and use more robust reading
  if (tolower(file_ext) == "csv") {
    return(read_csv_robust(filepath))
  }

  # For Excel files, use specialized reading
  if (tolower(file_ext) %in% c("xlsx", "xls")) {
    return(read_excel_robust(filepath))
  }

  # Fallback to rio for other formats
  tryCatch(
    {
      df <- rio::import(filepath, setclass = "tibble")

      if (!is.data.frame(df) || nrow(df) == 0 || ncol(df) == 0) {
        stop("Invalid data frame from rio::import")
      }

      return(df)
    },
    error = function(e) {
      stop(paste("Unsupported file type or corrupt file:", file_ext))
    }
  )
}

#' Robust delimited-text reading
#'
#' Decides encoding and delimiter up front rather than on read errors, because
#' readr warns instead of failing on wrong encodings and delimiters:
#' - binary content (NUL bytes) is rejected
#' - invalid UTF-8 is read as Windows-1252 (a superset of Latin-1)
#' - the delimiter (`,`, `;`, tab, `|`) is the one giving the most fields on
#'   the typical line; `;` files use decimal commas
#' - if readr returns fewer columns or rows than the file has (a short title
#'   line above the header, a truncated last row), the file is re-read with
#'   base R padded to the widest line
#' @keywords internal
read_csv_robust <- function(filepath) {
  head_bytes <- readBin(filepath, "raw", n = 8192)
  if (length(head_bytes) == 0) {
    stop("CSV file is empty or could not be read")
  }
  if (any(head_bytes == as.raw(0))) {
    stop("File does not look like text (it contains binary data). Upload a CSV or Excel file.")
  }

  lines <- readLines(filepath, warn = FALSE)
  encoding <- if (all(validUTF8(lines))) "UTF-8" else "windows-1252"

  count_fields <- function(con, sep) {
    suppressWarnings(utils::count.fields(con, sep = sep, quote = "\"", comment.char = "", blank.lines.skip = TRUE))
  }
  delims <- c(",", ";", "\t", "|")
  sample_lines <- iconv(utils::head(lines, 1000), from = encoding, to = "UTF-8", sub = "?")
  sample_lines <- sample_lines[nzchar(trimws(sample_lines))]
  typical <- vapply(delims, function(d) {
    n <- count_fields(textConnection(sample_lines), d)
    n <- n[!is.na(n)]
    if (length(n) == 0) 1L else as.integer(names(which.max(table(n))))
  }, integer(1))
  delim <- delims[which.max(typical)]

  locale <- if (delim == ";") {
    readr::locale(encoding = encoding, decimal_mark = ",", grouping_mark = ".")
  } else {
    readr::locale(encoding = encoding)
  }
  df <- tryCatch(
    readr::read_delim(
      filepath,
      delim = delim,
      col_names = FALSE,
      show_col_types = FALSE,
      name_repair = "minimal",
      guess_max = 10000,
      trim_ws = TRUE,
      locale = locale
    ),
    error = function(e) NULL
  )

  # readr sizes columns from line 1 and drops a short unterminated last line,
  # so a title row above the header or a truncated file loses data silently.
  # count.fields is ~5% of a readr read.
  n <- count_fields(filepath, delim)
  n_fields <- suppressWarnings(max(n, na.rm = TRUE))
  n_records <- sum(!is.na(n))
  if (is.finite(n_fields) && (is.null(df) || ncol(df) < n_fields || nrow(df) < n_records)) {
    df <- tibble::as_tibble(utils::read.table(
      filepath,
      sep = delim,
      quote = "\"",
      header = FALSE,
      col.names = paste0("V", seq_len(n_fields)),
      fill = TRUE,
      colClasses = "character",
      na.strings = c("", "NA"),
      comment.char = "",
      strip.white = TRUE,
      fileEncoding = if (encoding == "UTF-8") "UTF-8-BOM" else encoding
    ))
  }

  # Validate result
  if (!is.data.frame(df) || nrow(df) == 0 || ncol(df) == 0) {
    stop("CSV file is empty or could not be read")
  }

  # Ensure column names are standardized
  names(df) <- paste0("V", seq_len(ncol(df)))

  return(df)
}

#' Robust Excel reading
#' @keywords internal
read_excel_robust <- function(filepath) {
  tryCatch(
    {
      df <- readxl::read_excel(
        filepath,
        col_names = FALSE,
        .name_repair = "minimal",
        guess_max = 10000
      )

      # Date cells in text columns come back as serial strings ("24478"); a
      # CAS-RN typed into Excel without Text formatting ends up this way.
      # Render them as ISO dates so repair_cas_date_coercion() can see them.
      # Only serial-looking cells can be dates, so the per-cell re-read is
      # skipped entirely for workbooks without any.
      serials <- lapply(df, function(v) if (is.character(v)) which(grepl("^\\d{1,6}(\\.\\d+)?$", v)) else integer())
      if (any(lengths(serials) > 0)) {
        # ponytail: second readxl pass over the candidate columns only
        cand_cols <- which(lengths(serials) > 0)
        col_types <- rep("skip", ncol(df))
        col_types[cand_cols] <- "list"
        cells <- readxl::read_excel(filepath, col_names = FALSE, col_types = col_types, .name_repair = "minimal")
        for (k in seq_along(cand_cols)) {
          j <- cand_cols[k]
          idx <- serials[[j]]
          is_date <- vapply(cells[[k]][idx], inherits, logical(1), what = "POSIXct")
          if (any(is_date)) {
            df[[j]][idx[is_date]] <- vapply(cells[[k]][idx[is_date]], format, character(1), format = "%Y-%m-%d")
          }
        }
      }

      # Validate result
      if (!is.data.frame(df) || nrow(df) == 0 || ncol(df) == 0) {
        stop("Excel file is empty or could not be read")
      }

      # Ensure column names are character
      names(df) <- paste0("V", seq_len(ncol(df)))

      # Convert to tibble
      tibble::as_tibble(df)
    },
    error = function(e) {
      stop(paste("Failed to read Excel file:", e$message))
    }
  )
}


#' Calculate smart preview row count based on file size
#'
#' @param df Data frame to analyze
#' @return Integer. Number of rows to preview
#' @export
calculate_smart_preview_rows <- function(df) {
  n <- nrow(df)

  if (n <= 100) {
    return(50)
  } else if (n <= 1000) {
    return(25)
  } else {
    return(10)
  }
}


#' Validate uploaded file before processing
#'
#' @param file_input File input object from Shiny fileInput
#' @param max_size_mb Maximum file size in MB (default: 50)
#' @return List with success (TRUE/FALSE) and message
#' @export
validate_file <- function(file_input, max_size_mb = 50) {
  # Check if file exists
  if (is.null(file_input)) {
    return(list(
      success = FALSE,
      message = "No file selected"
    ))
  }

  # Extract file extension
  file_ext <- tolower(tools::file_ext(file_input$name))

  # Check file extension
  allowed_extensions <- c("csv", "xlsx", "xls")
  if (!file_ext %in% allowed_extensions) {
    return(list(
      success = FALSE,
      message = paste(
        "Invalid file type.",
        "Allowed types:",
        paste(allowed_extensions, collapse = ", ")
      )
    ))
  }

  # Check file size
  max_size_bytes <- max_size_mb * 1024^2
  if (file_input$size > max_size_bytes) {
    return(list(
      success = FALSE,
      message = paste(
        "File too large.",
        "Maximum size:",
        max_size_mb,
        "MB",
        "Your file:",
        round(file_input$size / 1024^2, 2),
        "MB"
      )
    ))
  }

  # All checks passed
  return(list(
    success = TRUE,
    message = "File validation successful"
  ))
}


#' Format file size for display
#'
#' @param size_bytes Numeric. File size in bytes
#' @return Character. Formatted file size
#' @export
format_file_size <- function(size_bytes) {
  if (size_bytes < 1024) {
    return(paste(size_bytes, "B"))
  } else if (size_bytes < 1024^2) {
    return(paste(round(size_bytes / 1024, 2), "KB"))
  } else if (size_bytes < 1024^3) {
    return(paste(round(size_bytes / 1024^2, 2), "MB"))
  } else {
    return(paste(round(size_bytes / 1024^3, 2), "GB"))
  }
}
