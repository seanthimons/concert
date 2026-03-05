# cleaning_pipeline.R
# Pure R functions for text cleaning with audit trail tracking
#
# Core functions:
# - clean_unicode_field: Convert unicode to ASCII using stringi
# - clean_text_field: Strip leading/trailing whitespace and punctuation artifacts
# - build_audit_trail: Compare two dataframes and record changes
# - run_cleaning_pipeline: Orchestrate cleaning steps with audit trail

library(dplyr)
library(stringr)
library(stringi)
library(tibble)

#' Clean unicode characters to ASCII equivalents
#'
#' Uses stringi::stri_trans_general for transliteration (NOT iconv which drops chars).
#' Handles NA values by passing them through unchanged.
#' Works with both scalar and vector inputs.
#'
#' @param x Character vector
#' @return Character vector with unicode converted to ASCII
#'
#' @examples
#' clean_unicode_field("cafe\u0301")  # => "cafe"
#' clean_unicode_field("\u03B1-tocopherol")  # => "a-tocopherol"
#' clean_unicode_field(NA)  # => NA
clean_unicode_field <- function(x) {
  # Handle NA values
  result <- ifelse(is.na(x), NA_character_, stringi::stri_trans_general(x, "Any-Latin; Latin-ASCII"))
  return(result)
}

#' Clean text field by stripping whitespace and punctuation artifacts
#'
#' Chain: trim -> squish -> strip leading/trailing underscores and asterisks.
#' DOES NOT strip internal punctuation (preserves CAS numbers like "67-64-1"
#' and IUPAC names like "2,4-dichlorophenol").
#'
#' @param x Character vector
#' @return Character vector with whitespace and artifacts removed
#'
#' @examples
#' clean_text_field("  hello  ")  # => "hello"
#' clean_text_field("__name__")  # => "name"
#' clean_text_field("*starred*")  # => "starred"
#' clean_text_field("67-64-1")  # => "67-64-1" (preserved)
#' clean_text_field("2,4-dichlorophenol")  # => "2,4-dichlorophenol" (preserved)
clean_text_field <- function(x) {
  x %>%
    stringr::str_trim() %>%
    stringr::str_squish() %>%
    stringr::str_remove_all("^[_*]+|[_*]+$")
}

#' Build audit trail by comparing two dataframes
#'
#' Compares df_original to df_cleaned column-by-column, row-by-row.
#' Only records rows where original_value != new_value.
#'
#' @param df_original Original dataframe before cleaning step
#' @param df_cleaned Cleaned dataframe after cleaning step
#' @param step_name Name of the cleaning step (e.g., "unicode_to_ascii")
#' @param reason_fn Function that takes (field_name) and returns reason string
#' @return Tibble with columns: row_id, field, step, original_value, new_value, reason
build_audit_trail <- function(df_original, df_cleaned, step_name, reason_fn) {
  # Initialize empty audit trail
  audit_rows <- list()

  # Get character columns (only these are cleaned)
  char_cols <- names(df_original)[sapply(df_original, is.character)]

  # Compare each column
  for (col_name in char_cols) {
    original_vals <- as.character(df_original[[col_name]])
    cleaned_vals <- as.character(df_cleaned[[col_name]])

    # Find rows where values changed
    changed_idx <- which(original_vals != cleaned_vals)

    # Record changes
    for (idx in changed_idx) {
      audit_rows[[length(audit_rows) + 1]] <- tibble::tibble(
        row_id = as.integer(idx),
        field = col_name,
        step = step_name,
        original_value = original_vals[idx],
        new_value = cleaned_vals[idx],
        reason = reason_fn(col_name)
      )
    }
  }

  # Combine all rows into single tibble
  if (length(audit_rows) == 0) {
    # Return empty tibble with correct structure
    return(tibble::tibble(
      row_id = integer(),
      field = character(),
      step = character(),
      original_value = character(),
      new_value = character(),
      reason = character()
    ))
  }

  dplyr::bind_rows(audit_rows)
}

#' Run complete cleaning pipeline with audit trail tracking
#'
#' Orchestrates multiple cleaning steps:
#' 1. Unicode to ASCII conversion
#' 2. Whitespace and punctuation artifact stripping
#'
#' Each step generates an audit trail. Final audit trail combines all changes.
#'
#' @param df Dataframe to clean
#' @param reference_lists Optional list of reference data (unused in Phase 10, reserved for future)
#' @return List with cleaned_data (tibble) and audit_trail (tibble)
#'
#' @examples
#' df <- tibble::tibble(chemical_name = c("  acetone  ", "cafe\u0301"))
#' result <- run_cleaning_pipeline(df)
#' result$cleaned_data  # => tibble with cleaned values
#' result$audit_trail   # => tibble with change records
run_cleaning_pipeline <- function(df, reference_lists = NULL) {
  # Step 1: Unicode to ASCII
  df_after_unicode <- df %>%
    dplyr::mutate(dplyr::across(where(is.character), clean_unicode_field))

  audit_unicode <- build_audit_trail(
    df_original = df,
    df_cleaned = df_after_unicode,
    step_name = "unicode_to_ascii",
    reason_fn = function(field) paste0("Convert unicode characters to ASCII equivalents in ", field)
  )

  # Step 2: Whitespace and punctuation artifact stripping
  df_after_trim <- df_after_unicode %>%
    dplyr::mutate(dplyr::across(where(is.character), clean_text_field))

  audit_trim <- build_audit_trail(
    df_original = df_after_unicode,
    df_cleaned = df_after_trim,
    step_name = "trim_whitespace_punctuation",
    reason_fn = function(field) paste0("Strip leading/trailing whitespace and punctuation artifacts from ", field)
  )

  # Combine audit trails
  audit_combined <- dplyr::bind_rows(audit_unicode, audit_trim)

  # Return result
  list(
    cleaned_data = df_after_trim,
    audit_trail = audit_combined
  )
}
