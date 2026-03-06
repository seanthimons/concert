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

#' Inject row lineage tracking
#'
#' Adds original_row_id column as first column to track row identity through transformations.
#'
#' @param df Dataframe to add lineage to
#' @return Dataframe with original_row_id as first column
#'
#' @examples
#' df <- tibble::tibble(a = 1:3, b = c("x", "y", "z"))
#' inject_row_lineage(df)  # => tibble with original_row_id = 1:3 as first column
inject_row_lineage <- function(df) {
  df %>%
    dplyr::mutate(original_row_id = 1:nrow(df), .before = 1)
}

#' Normalize CAS fields using ComptoxR
#'
#' Applies ComptoxR::as_cas() to all CASRN-tagged columns:
#' - Converts unformatted CAS (e.g., "67641") to standard format ("67-64-1")
#' - Converts placeholder text ("no cas", "n/a", "proprietary", "-") to NA
#' - Validates checksums and sets invalid CAS to NA
#'
#' @param df Dataframe with CAS columns
#' @param tag_map Named list mapping column names to types ("CASRN", "Name", "Other")
#' @return List with cleaned_data (tibble) and audit_trail (tibble)
#'
#' @examples
#' df <- tibble::tibble(cas = c("67641", "no cas", "67-64-2"))
#' tag_map <- list(cas = "CASRN")
#' normalize_cas_fields(df, tag_map)
normalize_cas_fields <- function(df, tag_map) {
  # Get CASRN columns
  cas_cols <- names(tag_map)[tag_map == "CASRN"]

  # Skip if no CASRN columns
  if (length(cas_cols) == 0) {
    return(list(
      cleaned_data = df,
      audit_trail = tibble::tibble(
        row_id = integer(),
        field = character(),
        step = character(),
        original_value = character(),
        new_value = character(),
        reason = character()
      )
    ))
  }

  # Save before state
  df_before <- df

  # Apply as_cas to each CASRN column
  df_after <- df %>%
    dplyr::mutate(dplyr::across(dplyr::all_of(cas_cols), ~ ComptoxR::as_cas(.x)))

  # Build audit trail manually to handle NA transitions
  audit_rows <- list()

  for (col_name in cas_cols) {
    original_vals <- as.character(df_before[[col_name]])
    cleaned_vals <- as.character(df_after[[col_name]])

    # Find changes: either different values OR non-NA became NA
    for (idx in seq_along(original_vals)) {
      orig <- original_vals[idx]
      new <- cleaned_vals[idx]

      # Record if values differ (including NA transitions)
      if (!identical(orig, new)) {
        audit_rows[[length(audit_rows) + 1]] <- tibble::tibble(
          row_id = as.integer(idx),
          field = col_name,
          step = "normalize_cas",
          original_value = ifelse(is.na(orig), "[NA]", orig),
          new_value = ifelse(is.na(new), "[NA]", new),
          reason = paste0("Normalize CAS-RN in ", col_name, " using ComptoxR::as_cas()")
        )
      }
    }
  }

  # Combine audit rows
  audit_trail <- if (length(audit_rows) == 0) {
    tibble::tibble(
      row_id = integer(),
      field = character(),
      step = character(),
      original_value = character(),
      new_value = character(),
      reason = character()
    )
  } else {
    dplyr::bind_rows(audit_rows)
  }

  list(
    cleaned_data = df_after,
    audit_trail = audit_trail
  )
}

#' Rescue CAS-RNs from non-CASRN text columns
#'
#' Uses ComptoxR::extract_cas() to find CAS-RNs embedded in Name/Other columns.
#' Extracted CAS values are placed in new cas_extract_{source} columns.
#' Source text is stripped of the CAS pattern.
#'
#' @param df Dataframe with tagged columns
#' @param tag_map Named list mapping column names to types ("CASRN", "Name", "Other")
#' @return List with cleaned_data, audit_trail, and new_tags (mapping cas_extract columns to "CASRN")
#'
#' @examples
#' df <- tibble::tibble(name = c("acetone (67-64-1)", "water"))
#' tag_map <- list(name = "Name")
#' rescue_cas_from_text(df, tag_map)
rescue_cas_from_text <- function(df, tag_map) {
  # Get non-CASRN columns
  non_cas_cols <- names(tag_map)[tag_map != "CASRN"]

  # Skip if no non-CASRN columns
  if (length(non_cas_cols) == 0) {
    return(list(
      cleaned_data = df,
      audit_trail = tibble::tibble(
        row_id = integer(),
        field = character(),
        step = character(),
        original_value = character(),
        new_value = character(),
        reason = character()
      ),
      new_tags = list()
    ))
  }

  # Initialize result
  df_result <- df
  audit_rows <- list()
  new_tags <- list()

  # Process each non-CASRN column
  for (col_name in non_cas_cols) {
    # Extract CAS from this column
    extracted_cas <- ComptoxR::extract_cas(df[[col_name]])

    # ComptoxR::extract_cas returns a list column - need to unlist
    # Convert list to character vector
    if (is.list(extracted_cas)) {
      extracted_cas <- sapply(extracted_cas, function(x) {
        if (length(x) == 0 || is.na(x[1])) {
          return(NA_character_)
        } else {
          return(x[1])  # Take first CAS if multiple found
        }
      })
    }

    # Check if any non-NA values were extracted
    if (any(!is.na(extracted_cas))) {
      # Create new column name
      new_col_name <- paste0("cas_extract_", col_name)

      # Add extracted CAS column
      df_result[[new_col_name]] <- extracted_cas

      # Tag this new column as CASRN
      new_tags[[new_col_name]] <- "CASRN"

      # Strip CAS pattern from source text
      df_result[[col_name]] <- df[[col_name]] %>%
        stringr::str_remove_all("\\s*[\\(\\[]?\\d{1,7}-\\d{2}-\\d[\\)\\]]?\\s*") %>%
        stringr::str_squish()

      # Build audit trail for extractions
      for (idx in seq_along(extracted_cas)) {
        if (!is.na(extracted_cas[idx])) {
          audit_rows[[length(audit_rows) + 1]] <- tibble::tibble(
            row_id = as.integer(idx),
            field = col_name,
            step = "rescue_cas",
            original_value = as.character(df[[col_name]][idx]),
            new_value = paste0("Extracted ", extracted_cas[idx], " to ", new_col_name),
            reason = paste0("Extract CAS-RN from ", col_name, " using ComptoxR::extract_cas()")
          )
        }
      }
    }
  }

  # Combine audit rows
  audit_trail <- if (length(audit_rows) == 0) {
    tibble::tibble(
      row_id = integer(),
      field = character(),
      step = character(),
      original_value = character(),
      new_value = character(),
      reason = character()
    )
  } else {
    dplyr::bind_rows(audit_rows)
  }

  list(
    cleaned_data = df_result,
    audit_trail = audit_trail,
    new_tags = new_tags
  )
}

#' Detect rows with multiple CAS-RNs
#'
#' Flags rows containing more than one non-NA CAS value across all CASRN-tagged columns.
#' Adds multi_cas (logical) and multi_cas_count (integer) columns.
#'
#' @param df Dataframe with CASRN columns
#' @param tag_map Named list mapping column names to types ("CASRN", "Name", "Other")
#' @return Dataframe with multi_cas and multi_cas_count columns added
#'
#' @examples
#' df <- tibble::tibble(cas1 = c("67-64-1", NA), cas2 = c("108-88-3", NA))
#' tag_map <- list(cas1 = "CASRN", cas2 = "CASRN")
#' detect_multi_cas(df, tag_map)
detect_multi_cas <- function(df, tag_map) {
  # Get all CASRN columns (including any cas_extract_* columns)
  cas_cols <- names(tag_map)[tag_map == "CASRN"]

  # Count non-NA CAS values per row
  cas_count <- rowSums(!is.na(df[, cas_cols, drop = FALSE]))

  # Add flags
  df %>%
    dplyr::mutate(
      multi_cas = cas_count > 1,
      multi_cas_count = as.integer(cas_count)
    )
}

#' Run complete cleaning pipeline with audit trail tracking
#'
#' Orchestrates multiple cleaning steps:
#' 0. Row lineage injection (always)
#' 1. Unicode to ASCII conversion
#' 2. Whitespace and punctuation artifact stripping
#' 3. CAS normalization (if tag_map provided)
#' 4. CAS rescue from text (if tag_map provided)
#' 5. Multi-CAS detection (if tag_map provided)
#'
#' Each step generates an audit trail. Final audit trail combines all changes.
#'
#' @param df Dataframe to clean
#' @param tag_map Optional named list mapping column names to types ("CASRN", "Name", "Other")
#' @param reference_lists Optional list of reference data (unused in Phase 11, reserved for future)
#' @return List with cleaned_data (tibble), audit_trail (tibble), and new_tags (list)
#'
#' @examples
#' df <- tibble::tibble(chemical_name = c("  acetone  ", "cafe\u0301"))
#' result <- run_cleaning_pipeline(df)
#' result$cleaned_data  # => tibble with cleaned values
#' result$audit_trail   # => tibble with change records
#'
#' # With CAS processing
#' df <- tibble::tibble(cas = c("67641", "no cas"), name = c("acetone", "ethanol 64-17-5"))
#' tag_map <- list(cas = "CASRN", name = "Name")
#' result <- run_cleaning_pipeline(df, tag_map)
#' result$new_tags  # => list(cas_extract_name = "CASRN")
run_cleaning_pipeline <- function(df, tag_map = NULL, reference_lists = NULL) {
  # Step 0: Inject row lineage
  df_after_lineage <- inject_row_lineage(df)

  # Step 1: Unicode to ASCII
  df_after_unicode <- df_after_lineage %>%
    dplyr::mutate(dplyr::across(where(is.character), clean_unicode_field))

  audit_unicode <- build_audit_trail(
    df_original = df_after_lineage,
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

  # Combine basic audit trails
  audit_combined <- dplyr::bind_rows(audit_unicode, audit_trim)

  # Initialize new_tags
  new_tags <- list()

  # If tag_map provided, run CAS steps
  if (!is.null(tag_map)) {
    # Step 3: Normalize CAS fields
    cas_result <- normalize_cas_fields(df_after_trim, tag_map)
    df_after_cas <- cas_result$cleaned_data
    audit_combined <- dplyr::bind_rows(audit_combined, cas_result$audit_trail)

    # Step 4: Rescue CAS from text columns
    rescue_result <- rescue_cas_from_text(df_after_cas, tag_map)
    df_after_rescue <- rescue_result$cleaned_data
    audit_combined <- dplyr::bind_rows(audit_combined, rescue_result$audit_trail)
    new_tags <- rescue_result$new_tags

    # Update tag_map with rescued columns for multi-CAS detection
    tag_map_updated <- c(tag_map, new_tags)

    # Step 5: Detect multi-CAS
    df_final <- detect_multi_cas(df_after_rescue, tag_map_updated)
  } else {
    # No CAS processing - just basic cleaning
    df_final <- df_after_trim
  }

  # Return result
  list(
    cleaned_data = df_final,
    audit_trail = audit_combined,
    new_tags = new_tags
  )
}
