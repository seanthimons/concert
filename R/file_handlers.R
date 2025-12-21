# File Handlers for Shiny Data Upload Application
# Functions for reading, validating, and processing uploaded files

#' Safely read a file with multiple fallback strategies
#'
#' @param filepath Character. Path to the file to read
#' @param file_ext Character. File extension (csv, xlsx, xls)
#' @return A tibble with the raw file contents (no header parsing)
#' @export
safely_read_file <- function(filepath, file_ext) {
  tryCatch({
    # Primary method: rio::import
    df <- rio::import(filepath, setclass = "tibble")

    # Validate result
    if (!is.data.frame(df)) {
      stop("File did not parse as a data frame")
    }

    if (nrow(df) == 0) {
      stop("File is empty (0 rows)")
    }

    if (ncol(df) == 0) {
      stop("File has no columns")
    }

    return(df)

  }, error = function(e_primary) {
    # Try fallback methods based on extension
    tryCatch({
      if (tolower(file_ext) %in% c("xlsx", "xls")) {
        # Excel fallback: readxl with no header parsing
        df <- readxl::read_excel(
          filepath,
          col_names = FALSE,
          .name_repair = "minimal",
          guess_max = Inf
        )

        # Ensure column names are character
        names(df) <- paste0("V", seq_len(ncol(df)))

      } else if (tolower(file_ext) == "csv") {
        # CSV fallback: Try UTF-8 first
        df <- tryCatch(
          {
            readr::read_csv(
              filepath,
              col_names = FALSE,
              show_col_types = FALSE,
              name_repair = "minimal"
            )
          },
          error = function(e_utf8) {
            # Try Latin-1 encoding
            readr::read_csv(
              filepath,
              col_names = FALSE,
              locale = readr::locale(encoding = "Latin1"),
              show_col_types = FALSE,
              name_repair = "minimal"
            )
          }
        )

        # Ensure column names are character
        names(df) <- paste0("V", seq_len(ncol(df)))

      } else {
        stop(paste("Unsupported file type:", file_ext))
      }

      # Validate fallback result
      if (nrow(df) == 0) {
        stop("File is empty (0 rows)")
      }

      # Convert to tibble
      df <- tibble::as_tibble(df)

      return(df)

    }, error = function(e_fallback) {
      # All methods failed
      stop(paste(
        "Failed to read file.",
        "Primary error:", e_primary$message,
        "Fallback error:", e_fallback$message
      ))
    })
  })
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
        "Allowed types:", paste(allowed_extensions, collapse = ", ")
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
        "Maximum size:", max_size_mb, "MB",
        "Your file:", round(file_input$size / 1024^2, 2), "MB"
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
