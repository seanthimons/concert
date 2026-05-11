# Data Detection Algorithms for Frontmatter Identification
# Functions for detecting where actual data begins in messy files

#' Detect data start using heuristic fill ratio method
#'
#' @param df Data frame to analyze
#' @param min_filled_ratio Minimum proportion of filled cells (default: 0.7)
#' @param min_cols Minimum number of filled cells required (default: 3)
#' @return List with header_row, data_start_row, metadata_rows, method, confidence
#' @export
detect_data_start_heuristic <- function(df, min_filled_ratio = 0.7, min_cols = 3) {
  if (nrow(df) == 0) {
    return(list(
      header_row = 1,
      data_start_row = 1,
      metadata_rows = integer(0),
      method = "heuristic",
      confidence = 0.1
    ))
  }

  # Calculate fill ratio for each row
  row_stats <- purrr::map_dfr(seq_len(min(nrow(df), 50)), function(i) {
    row_values <- df[i, ]

    # Count non-NA and non-empty cells
    filled_cells <- sum(!is.na(row_values) & row_values != "", na.rm = TRUE)
    total_cells <- ncol(df)
    fill_ratio <- filled_cells / total_cells

    # Calculate uniqueness ratio
    unique_vals <- dplyr::n_distinct(as.character(unlist(row_values)), na.rm = TRUE)
    unique_ratio <- unique_vals / max(filled_cells, 1)

    tibble::tibble(
      row_num = i,
      filled_cells = filled_cells,
      total_cells = total_cells,
      fill_ratio = fill_ratio,
      unique_ratio = unique_ratio
    )
  })

  # Find first row that meets criteria
  candidate_rows <- row_stats %>%
    dplyr::filter(
      filled_cells >= min_cols,
      fill_ratio >= min_filled_ratio,
      unique_ratio > 0.3 # Avoid rows with all same values
    )

  if (nrow(candidate_rows) == 0) {
    # Fallback: find row with highest fill ratio
    best_row <- row_stats %>%
      dplyr::slice_max(fill_ratio, n = 1) %>%
      dplyr::pull(row_num)

    if (length(best_row) == 0) {
      best_row <- 1
    }

    return(list(
      header_row = best_row,
      data_start_row = best_row,
      metadata_rows = if (best_row > 1) seq_len(best_row - 1) else integer(0),
      method = "heuristic",
      confidence = 0.4
    ))
  }

  # Get first qualifying row
  data_start <- candidate_rows$row_num[1]

  # Assume header is row before data_start (if exists and has reasonable fill ratio)
  header_row <- if (data_start > 1) {
    prev_row_fill <- row_stats %>%
      dplyr::filter(row_num == data_start - 1) %>%
      dplyr::pull(fill_ratio)

    if (length(prev_row_fill) > 0 && prev_row_fill > 0.5) {
      data_start - 1
    } else {
      data_start
    }
  } else {
    data_start
  }

  # Calculate confidence based on fill ratio consistency
  subsequent_rows <- row_stats %>%
    dplyr::filter(row_num >= data_start, row_num <= min(data_start + 10, nrow(df)))

  if (nrow(subsequent_rows) > 0) {
    avg_fill <- mean(subsequent_rows$fill_ratio, na.rm = TRUE)
    fill_sd <- sd(subsequent_rows$fill_ratio, na.rm = TRUE)
    confidence <- min(1.0, avg_fill * (1 - min(fill_sd, 0.3)))
  } else {
    confidence <- 0.6
  }

  return(list(
    header_row = header_row,
    data_start_row = header_row + 1L,
    metadata_rows = if (header_row > 1) seq_len(header_row - 1) else integer(0),
    method = "heuristic",
    confidence = confidence
  ))
}


#' Detect data start using pattern matching for common header keywords
#'
#' @param df Data frame to analyze
#' @return List with header_row, data_start_row, method, confidence
#' @export
detect_pattern_based <- function(df) {
  if (nrow(df) == 0) {
    return(list(
      header_row = 1,
      data_start_row = 1,
      method = "pattern",
      confidence = 0.1
    ))
  }

  # Common header keywords (case-insensitive) - Chemistry focused
  header_indicators <- c(
    # General
    "name",
    "id",
    "date",
    "type",
    "value",
    "code",
    "description",
    "amount",
    "status",
    "category",
    "number",
    # Chemistry specific
    "chemical",
    "cas",
    "formula",
    "molecular",
    "structure",
    "compound",
    "substance",
    "reagent",
    "solvent",
    "hazard",
    "safety",
    "ghs",
    "sds",
    "msds",
    "quantity",
    "qty",
    "mass",
    "volume",
    "concentration",
    "purity",
    "grade",
    "supplier",
    "manufacturer",
    "storage",
    "location",
    "expiry",
    "batch",
    "lot"
  )

  # Score each row based on keyword matches
  row_scores <- purrr::map_dbl(seq_len(min(nrow(df), 20)), function(i) {
    row_text <- tolower(paste(as.character(df[i, ]), collapse = " "))

    # Count keyword matches
    keyword_matches <- sum(stringr::str_detect(row_text, header_indicators))

    # Bonus for having multiple short text values (typical of headers)
    row_values <- as.character(df[i, ])
    short_text_count <- sum(nchar(row_values) > 2 & nchar(row_values) < 30, na.rm = TRUE)

    # Combined score
    keyword_matches + (short_text_count * 0.1)
  })

  # Find row with highest score
  if (all(row_scores == 0)) {
    # No pattern matches found
    return(list(
      header_row = 1,
      data_start_row = 2,
      method = "pattern",
      confidence = 0.2
    ))
  }

  header_row <- which.max(row_scores)
  max_score <- max(row_scores)

  # Calculate confidence based on score
  confidence <- min(1.0, max_score / length(header_indicators))

  return(list(
    header_row = header_row,
    data_start_row = header_row + 1,
    method = "pattern",
    confidence = confidence
  ))
}


#' Detect data start by checking column type consistency
#'
#' @param df Data frame to analyze
#' @param scan_rows Number of rows to scan after each candidate (default: 50)
#' @return List with header_row, data_start_row, method, confidence
#' @export
detect_by_type_consistency <- function(df, scan_rows = 50) {
  if (nrow(df) < 3) {
    return(list(
      header_row = 1,
      data_start_row = 2,
      method = "type_consistency",
      confidence = 0.3
    ))
  }

  # Test candidate header positions
  candidates <- seq_len(min(20, nrow(df) - 2))

  scores <- purrr::map_dbl(candidates, function(header_candidate) {
    # Extract sample data after potential header
    start_row <- header_candidate + 1
    end_row <- min(nrow(df), start_row + scan_rows - 1)

    if (start_row > nrow(df)) {
      return(0)
    }

    sample_data <- df[start_row:end_row, , drop = FALSE]

    if (nrow(sample_data) < 2) {
      return(0)
    }

    # Check type consistency for each column
    type_stability <- purrr::map_dbl(seq_len(ncol(sample_data)), function(col_idx) {
      col_data <- sample_data[[col_idx]]

      # Remove NAs for type checking
      col_data_clean <- col_data[!is.na(col_data)]

      if (length(col_data_clean) < 2) {
        return(0.5) # Neutral score for columns with too few values
      }

      # Check if column appears to be numeric
      numeric_ratio <- sum(suppressWarnings(!is.na(as.numeric(as.character(col_data_clean))))) / length(col_data_clean)

      # Check if column has consistent type
      is_consistent <- if (numeric_ratio > 0.8) {
        # Mostly numeric
        1.0
      } else if (numeric_ratio < 0.2) {
        # Mostly text
        0.9
      } else {
        # Mixed types
        0.3
      }

      is_consistent
    })

    # Average type stability across columns
    mean(type_stability, na.rm = TRUE)
  })

  # Find best candidate
  best_idx <- which.max(scores)
  best_score <- scores[best_idx]

  if (length(best_idx) == 0 || best_score < 0.3) {
    return(list(
      header_row = 1,
      data_start_row = 2,
      method = "type_consistency",
      confidence = 0.3
    ))
  }

  return(list(
    header_row = candidates[best_idx],
    data_start_row = candidates[best_idx] + 1,
    method = "type_consistency",
    confidence = best_score
  ))
}


#' Main ensemble detection function combining all methods
#'
#' @param df Data frame to analyze
#' @param mode Detection mode: "auto" or "manual"
#' @param manual_row Manual header row number (used if mode = "manual")
#' @return List with detection results including all_results for debugging
#' @export
detect_data_start <- function(df, mode = "auto", manual_row = NULL) {
  # Manual override
  if (mode == "manual" && !is.null(manual_row)) {
    return(list(
      header_row = manual_row,
      data_start_row = manual_row + 1,
      metadata_rows = if (manual_row > 1) seq_len(manual_row - 1) else integer(0),
      method = "manual",
      confidence = 1.0,
      all_results = list()
    ))
  }

  # Run all detection methods with error handling
  methods <- list(
    heuristic = purrr::safely(detect_data_start_heuristic)(df),
    pattern = purrr::safely(detect_pattern_based)(df),
    type_consistency = purrr::safely(detect_by_type_consistency)(df)
  )

  # Extract successful results
  results <- methods %>%
    purrr::map("result") %>%
    purrr::compact()

  # If all methods failed, use fallback
  if (length(results) == 0) {
    return(list(
      header_row = 1,
      data_start_row = 2,
      metadata_rows = integer(0),
      method = "fallback",
      confidence = 0.3,
      all_results = list(),
      errors = purrr::map(methods, "error") %>% purrr::compact()
    ))
  }

  # Select method with highest confidence
  confidences <- purrr::map_dbl(results, ~ .$confidence)
  best_idx <- which.max(confidences)
  best_result <- results[[best_idx]]

  # Add metadata_rows if not present
  if (is.null(best_result$metadata_rows)) {
    best_result$metadata_rows <- if (best_result$header_row > 1) {
      seq_len(best_result$header_row - 1)
    } else {
      integer(0)
    }
  }

  # Store all results for debugging
  best_result$all_results <- results

  return(best_result)
}


#' Extract clean data based on detection results
#'
#' @param raw_df Raw data frame
#' @param detection Detection results from detect_data_start()
#' @return Cleaned data frame with proper headers
#' @export
extract_clean_data <- function(raw_df, detection) {
  header_row <- detection$header_row
  data_start_row <- detection$data_start_row

  # Extract column names from header row
  if (header_row <= nrow(raw_df)) {
    col_names <- as.character(raw_df[header_row, ])

    # Handle empty or NA column names
    col_names <- ifelse(is.na(col_names) | col_names == "", paste0("Column_", seq_along(col_names)), col_names)
  } else {
    col_names <- names(raw_df)
  }

  # Extract data rows
  if (data_start_row <= nrow(raw_df)) {
    clean_data <- raw_df[data_start_row:nrow(raw_df), , drop = FALSE]
    names(clean_data) <- col_names
  } else {
    # No data rows, return empty tibble with column names
    clean_data <- tibble::tibble()
    for (col in col_names) {
      clean_data[[col]] <- character(0)
    }
  }

  # Convert to tibble
  clean_data <- tibble::as_tibble(clean_data)

  return(clean_data)
}


#' Handle merged cells by filling down first column
#'
#' @param df Data frame to process
#' @return Data frame with filled merged cells
#' @export
handle_merged_cells <- function(df) {
  if (ncol(df) == 0 || nrow(df) == 0) {
    return(df)
  }

  # Check first column for merged cell pattern
  first_col <- df[[1]]
  first_col_non_na <- first_col[!is.na(first_col) & first_col != ""]

  # If first column has many NAs and some repeated values, likely merged
  na_ratio <- sum(is.na(first_col) | first_col == "") / length(first_col)

  if (na_ratio > 0.3 && length(first_col_non_na) > 0) {
    # Fill down first column
    df <- df %>%
      tidyr::fill(1, .direction = "down")
  }

  return(df)
}
