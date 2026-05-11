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

#' Robust CSV reading with multiple fallback strategies
#' @keywords internal
read_csv_robust <- function(filepath) {
  # Strategy 1: Try readr with auto-detection (most common)
  df <- tryCatch(
    {
      readr::read_csv(
        filepath,
        col_names = FALSE,
        show_col_types = FALSE,
        name_repair = "minimal",
        guess_max = 10000,
        locale = readr::locale(encoding = "UTF-8")
      )
    },
    error = function(e1) {
      # Strategy 2: Try with Latin-1 encoding
      tryCatch(
        {
          readr::read_csv(
            filepath,
            col_names = FALSE,
            show_col_types = FALSE,
            name_repair = "minimal",
            guess_max = 10000,
            locale = readr::locale(encoding = "Latin1")
          )
        },
        error = function(e2) {
          # Strategy 3: Try with semicolon delimiter (European format)
          tryCatch(
            {
              readr::read_delim(
                filepath,
                delim = ";",
                col_names = FALSE,
                show_col_types = FALSE,
                name_repair = "minimal",
                guess_max = 10000
              )
            },
            error = function(e3) {
              # Strategy 4: Try with tab delimiter
              tryCatch(
                {
                  readr::read_delim(
                    filepath,
                    delim = "\t",
                    col_names = FALSE,
                    show_col_types = FALSE,
                    name_repair = "minimal",
                    guess_max = 10000
                  )
                },
                error = function(e4) {
                  # Strategy 5: Last resort - base R read.csv
                  df_base <- read.csv(
                    filepath,
                    header = FALSE,
                    stringsAsFactors = FALSE,
                    check.names = FALSE
                  )
                  tibble::as_tibble(df_base)
                }
              )
            }
          )
        }
      )
    }
  )

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

      # Ensure column names are character
      names(df) <- paste0("V", seq_len(ncol(df)))

      # Validate result
      if (!is.data.frame(df) || nrow(df) == 0 || ncol(df) == 0) {
        stop("Excel file is empty or could not be read")
      }

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
