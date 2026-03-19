# cleaning_pipeline.R
# Pure R functions for text cleaning with audit trail tracking
#
# Core functions:
# - Unicode cleaning: Uses ComptoxR::clean_unicode for chemistry-specific mappings
# - clean_text_field: Strip leading/trailing whitespace and punctuation artifacts
# - build_audit_trail: Compare two dataframes and record changes
# - run_cleaning_pipeline: Orchestrate cleaning steps with audit trail

library(dplyr)
library(stringr)
library(stringi)
library(tibble)


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

#' Strip terminal enclosures (parentheticals and brackets) from name fields
#'
#' Removes terminal (...) and [...] from Name-tagged columns, with protection
#' for chemical names containing "yl" (except exception words).
#' Preserves stripped content in formula_extract_{source} columns.
#'
#' @param df Dataframe with name columns
#' @param name_cols Character vector of Name-tagged column names
#' @return List with cleaned_data, audit_trail, and new_tags (empty list)
#'
#' @examples
#' df <- tibble::tibble(chemical_name = c("Acetone (ACS reagent)", "ethanol (ethyl alcohol)"))
#' strip_terminal_enclosures(df, "chemical_name")
strip_terminal_enclosures <- function(df, name_cols) {
  # Initialize result
  df_result <- df
  audit_rows <- list()

  # Process each name column
  for (col_name in name_cols) {
    # Create formula_extract column name (if it doesn't exist)
    extract_col_name <- paste0("formula_extract_", col_name)
    if (!extract_col_name %in% names(df_result)) {
      df_result[[extract_col_name]] <- NA_character_
    }

    # Process each row
    for (idx in seq_len(nrow(df))) {
      original_value <- df[[col_name]][idx]

      # Skip NA
      if (is.na(original_value)) {
        next
      }

      stripped_value <- original_value
      extracted_content <- NA_character_

      # Try to strip terminal parenthetical (...) - check for empty content first
      parenth_match <- stringr::str_match(stripped_value, "^(.*)\\(([^)]*)\\)\\s*$")
      if (!is.na(parenth_match[1, 1])) {
        content <- parenth_match[1, 3]
        base <- parenth_match[1, 2]

        # Skip empty parentheticals
        content_trimmed <- stringr::str_trim(content)
        if (content_trimmed == "") {
          # Remove empty parenthetical without audit
          stripped_value <- stringr::str_trim(base)
        } else {
          # Check if we should keep it (contains "yl" but not exception words, OR contains %)
          exception_words <- c("density", "probably", "average", "combination")
          has_yl <- stringr::str_detect(content, "yl")
          has_exception <- any(sapply(exception_words, function(w) stringr::str_detect(stringr::str_to_lower(content), w)))
          has_percentage <- stringr::str_detect(content, "%")

          # Strip if: (no yl OR has exception) AND no percentage
          should_strip <- (!has_yl || has_exception) && !has_percentage

          if (should_strip) {
            # Strip it
            stripped_value <- stringr::str_trim(base)
            extracted_content <- content
          }
        }
      }

      # Try to strip terminal bracket [...] - check for empty content first
      bracket_match <- stringr::str_match(stripped_value, "^(.*)\\[([^]]*)\\]\\s*$")
      if (!is.na(bracket_match[1, 1])) {
        content <- bracket_match[1, 3]
        base <- bracket_match[1, 2]

        # Skip empty brackets
        content_trimmed <- stringr::str_trim(content)
        if (content_trimmed == "") {
          # Remove empty bracket without audit
          stripped_value <- stringr::str_trim(base)
        } else {
          # Same logic for brackets
          exception_words <- c("density", "probably", "average", "combination")
          has_yl <- stringr::str_detect(content, "yl")
          has_exception <- any(sapply(exception_words, function(w) stringr::str_detect(stringr::str_to_lower(content), w)))
          has_percentage <- stringr::str_detect(content, "%")

          # Strip if: (no yl OR has exception) AND no percentage
          should_strip <- (!has_yl || has_exception) && !has_percentage

          if (should_strip) {
            # Strip it
            stripped_value <- stringr::str_trim(base)
            # If we already extracted from parenthetical, combine
            if (!is.na(extracted_content)) {
              extracted_content <- paste(extracted_content, content, sep = "; ")
            } else {
              extracted_content <- content
            }
          }
        }
      }

      # Update result
      if (stripped_value != original_value) {
        df_result[[col_name]][idx] <- stripped_value
        # Only update extract column if we extracted something new (don't overwrite existing)
        if (!is.na(extracted_content)) {
          # If there's already content, append
          if (!is.na(df_result[[extract_col_name]][idx]) && df_result[[extract_col_name]][idx] != "") {
            df_result[[extract_col_name]][idx] <- paste(df_result[[extract_col_name]][idx], extracted_content, sep = "; ")
          } else {
            df_result[[extract_col_name]][idx] <- extracted_content
          }
        }

        # Add audit entry
        audit_rows[[length(audit_rows) + 1]] <- tibble::tibble(
          row_id = as.integer(idx),
          field = col_name,
          step = "strip_terminal_enclosures",
          original_value = original_value,
          new_value = stripped_value,
          reason = paste0("Strip terminal enclosure from ", col_name, "; content saved to ", extract_col_name)
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
    cleaned_data = df_result,
    audit_trail = audit_trail,
    new_tags = list()  # formula_extract columns are informational, not auto-tagged
  )
}

#' Strip quality adjectives from name fields
#'
#' Removes quality words like "pure", "purified", "technical", "grade", "chemical"
#' from Name-tagged columns. Uses word boundaries for clean removal.
#'
#' @param df Dataframe with name columns
#' @param name_cols Character vector of Name-tagged column names
#' @return List with cleaned_data and audit_trail
#'
#' @examples
#' df <- tibble::tibble(chemical_name = c("technical grade ethanol", "purified water"))
#' strip_quality_adjectives(df, "chemical_name")
strip_quality_adjectives <- function(df, name_cols) {
  # Save before state
  df_before <- df

  # Quality word pattern
  pattern <- "\\b(pure|purif\\w*|tech\\w*|grade|chemical)\\b"

  # Apply to each name column
  df_after <- df
  for (col_name in name_cols) {
    df_after[[col_name]] <- df[[col_name]] %>%
      stringr::str_remove_all(stringr::regex(pattern, ignore_case = TRUE)) %>%
      stringr::str_squish()
  }

  # Build audit trail manually
  audit_rows <- list()

  for (col_name in name_cols) {
    original_vals <- as.character(df_before[[col_name]])
    cleaned_vals <- as.character(df_after[[col_name]])

    # Find changes
    for (idx in seq_along(original_vals)) {
      orig <- original_vals[idx]
      new <- cleaned_vals[idx]

      if (!is.na(orig) && !is.na(new) && orig != new) {
        audit_rows[[length(audit_rows) + 1]] <- tibble::tibble(
          row_id = as.integer(idx),
          field = col_name,
          step = "strip_quality_adjectives",
          original_value = orig,
          new_value = new,
          reason = paste0("Remove quality adjectives from ", col_name)
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

#' Strip salt references from name fields
#'
#' Removes "and its [adjective] salts" patterns from Name-tagged columns.
#'
#' @param df Dataframe with name columns
#' @param name_cols Character vector of Name-tagged column names
#' @return List with cleaned_data and audit_trail
#'
#' @examples
#' df <- tibble::tibble(chemical_name = c("lead and its salts", "mercury and its inorganic salts"))
#' strip_salt_references(df, "chemical_name")
strip_salt_references <- function(df, name_cols) {
  # Save before state
  df_before <- df

  # Salt pattern
  pattern <- "and its (\\w+ )?salts"

  # Apply to each name column
  df_after <- df
  for (col_name in name_cols) {
    df_after[[col_name]] <- df[[col_name]] %>%
      stringr::str_remove_all(stringr::regex(pattern, ignore_case = TRUE)) %>%
      stringr::str_trim()
  }

  # Build audit trail manually
  audit_rows <- list()

  for (col_name in name_cols) {
    original_vals <- as.character(df_before[[col_name]])
    cleaned_vals <- as.character(df_after[[col_name]])

    # Find changes
    for (idx in seq_along(original_vals)) {
      orig <- original_vals[idx]
      new <- cleaned_vals[idx]

      if (!is.na(orig) && !is.na(new) && orig != new) {
        audit_rows[[length(audit_rows) + 1]] <- tibble::tibble(
          row_id = as.integer(idx),
          field = col_name,
          step = "strip_salt_references",
          original_value = orig,
          new_value = new,
          reason = paste0("Remove ambiguous salt reference from ", col_name)
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

#' Strip terminal "unspecified" suffixes from name fields
#'
#' Removes terminal "[,;-]? unspecified" patterns from Name-tagged columns.
#'
#' @param df Dataframe with name columns
#' @param name_cols Character vector of Name-tagged column names
#' @return List with cleaned_data and audit_trail
#'
#' @examples
#' df <- tibble::tibble(chemical_name = c("compound, unspecified", "chemical - unspecified"))
#' strip_terminal_unspecified(df, "chemical_name")
strip_terminal_unspecified <- function(df, name_cols) {
  # Save before state
  df_before <- df

  # Terminal unspecified pattern
  pattern <- "[,;-]?\\s*unspecified\\s*$"

  # Apply to each name column
  df_after <- df
  for (col_name in name_cols) {
    df_after[[col_name]] <- df[[col_name]] %>%
      stringr::str_remove_all(stringr::regex(pattern, ignore_case = TRUE)) %>%
      stringr::str_trim()
  }

  # Build audit trail manually
  audit_rows <- list()

  for (col_name in name_cols) {
    original_vals <- as.character(df_before[[col_name]])
    cleaned_vals <- as.character(df_after[[col_name]])

    # Find changes
    for (idx in seq_along(original_vals)) {
      orig <- original_vals[idx]
      new <- cleaned_vals[idx]

      if (!is.na(orig) && !is.na(new) && orig != new) {
        audit_rows[[length(audit_rows) + 1]] <- tibble::tibble(
          row_id = as.integer(idx),
          field = col_name,
          step = "strip_terminal_unspecified",
          original_value = orig,
          new_value = new,
          reason = paste0("Remove terminal 'unspecified' suffix from ", col_name)
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

#' Strip user-defined reference terms from name fields
#'
#' Removes terms from the strip_terms reference list from Name-tagged columns.
#' Terms containing regex metacharacters (\w, +, *, ^, $) are applied as-is.
#' Plain terms are wrapped in word boundaries for clean removal.
#'
#' @param df Dataframe with name columns
#' @param name_cols Character vector of Name-tagged column names
#' @param strip_terms_tbl Tibble with columns: term, source, active
#' @return List with cleaned_data and audit_trail
#'
#' @examples
#' df <- tibble::tibble(chemical_name = c("pure acetone", "technical ethanol"))
#' terms <- tibble::tibble(term = c("pure", "technical"), source = "user", active = TRUE)
#' strip_reference_terms(df, "chemical_name", terms)
strip_reference_terms <- function(df, name_cols, strip_terms_tbl) {
  # Save before state
  df_before <- df

  # Filter to active terms
 active_terms <- strip_terms_tbl %>%
    dplyr::filter(active == TRUE)

  # Skip if no active terms
  if (nrow(active_terms) == 0) {
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

  # Regex metacharacters that indicate a term is already a regex pattern
  regex_meta <- c("\\\\w", "\\+", "\\*", "\\^", "\\$")

  # Apply each term to each name column
  df_after <- df
  for (col_name in name_cols) {
    for (i in seq_len(nrow(active_terms))) {
      term <- active_terms$term[i]

      # Check if term contains regex metacharacters
      is_regex <- any(sapply(regex_meta, function(m) grepl(m, term, fixed = FALSE)))

      if (is_regex) {
        # Apply as-is (it's already a regex pattern)
        df_after[[col_name]] <- df_after[[col_name]] %>%
          stringr::str_remove_all(stringr::regex(term, ignore_case = TRUE)) %>%
          stringr::str_squish()
      } else {
        # Wrap in word boundaries for clean removal
        pattern <- paste0("\\b", stringr::str_replace_all(term, "([/.])", "\\\\\\1"), "\\b")
        df_after[[col_name]] <- df_after[[col_name]] %>%
          stringr::str_remove_all(stringr::regex(pattern, ignore_case = TRUE)) %>%
          stringr::str_squish()
      }
    }
  }

  # Build audit trail
  audit_rows <- list()

  for (col_name in name_cols) {
    original_vals <- as.character(df_before[[col_name]])
    cleaned_vals <- as.character(df_after[[col_name]])

    for (idx in seq_along(original_vals)) {
      orig <- original_vals[idx]
      new <- cleaned_vals[idx]

      if (!is.na(orig) && !is.na(new) && orig != new) {
        audit_rows[[length(audit_rows) + 1]] <- tibble::tibble(
          row_id = as.integer(idx),
          field = col_name,
          step = "strip_reference_terms",
          original_value = orig,
          new_value = new,
          reason = paste0("Remove user-defined strip terms from ", col_name)
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

#' Split synonyms in name fields with IUPAC comma protection
#'
#' Splits comma/semicolon-separated synonyms into separate rows.
#' Protects digit-comma-digit patterns (IUPAC inverted names like "butane, 2,2-dimethyl").
#' Primary name keeps original row; synonyms get new rows with CAS columns set to NA.
#'
#' @param df Dataframe with name columns
#' @param name_cols Character vector of Name-tagged column names
#' @param tag_map Named list mapping column names to types
#' @return List with cleaned_data and audit_trail
#'
#' @examples
#' df <- tibble::tibble(
#'   original_row_id = 1L,
#'   cas_number = "67-64-1",
#'   chemical_name = "xylene, dimethylbenzene, xylol"
#' )
#' tag_map <- list(cas_number = "CASRN", chemical_name = "Name")
#' split_synonyms(df, "chemical_name", tag_map)
split_synonyms <- function(df, name_cols, tag_map) {
  # Get CASRN columns
  cas_cols <- names(tag_map)[tag_map == "CASRN"]

  # Initialize result
  df_result <- df
  audit_rows <- list()

  # Process each name column
  for (col_name in name_cols) {
    # Build expanded dataframe
    expanded_rows <- list()

    for (idx in seq_len(nrow(df_result))) {
      row_data <- df_result[idx, ]
      original_name <- row_data[[col_name]]

      # Skip NA
      if (is.na(original_name)) {
        expanded_rows[[length(expanded_rows) + 1]] <- row_data %>%
          dplyr::mutate(
            synonym_count = 1L,
            synonym_index = 1L
          )
        next
      }

      # Step 0+1: Protect IUPAC comma patterns with repeat-until-stable loop
      # Single pass of (\d+),(\d+) only catches one pair per adjacency:
      # "2,4,6" -> "2@@@4,6" (misses second comma). Loop until no changes.
      protected_name <- original_name
      for (iter in seq_len(10)) {
        prev <- protected_name
        # Protect letter-comma-letter (N,N- O,O- S,S- etc.)
        protected_name <- stringr::str_replace_all(protected_name, "([A-Za-z]),([A-Za-z])", "\\1@@@\\2")
        # Protect digit-comma-digit (IUPAC locants like 2,4- or 1,3-)
        protected_name <- stringr::str_replace_all(protected_name, "(\\d+),(\\d+)", "\\1@@@\\2")
        if (identical(prev, protected_name)) break
      }

      # Step 2: Protect IUPAC inverted names (e.g., "butane, 2,2-dimethyl")
      # Pattern: comma followed by space and digit indicates inverted IUPAC name
      # Replace that comma with a different placeholder
      protected_name <- stringr::str_replace_all(protected_name, ",\\s+(\\d)", "%%%\\1")

      # Step 3: Split on semicolons first, then commas
      parts <- protected_name %>%
        stringr::str_split(";") %>%
        unlist() %>%
        stringr::str_split(",") %>%
        unlist() %>%
        stringr::str_trim() %>%
        stringr::str_replace_all("@@@", ",") %>%   # Restore digit-comma-digit
        stringr::str_replace_all("%%%", ", ")      # Restore inverted name comma

      # Remove empty strings
      parts <- parts[parts != "" & !is.na(parts)]

      # If no split occurred (single name), keep as-is
      if (length(parts) <= 1) {
        expanded_rows[[length(expanded_rows) + 1]] <- row_data %>%
          dplyr::mutate(
            synonym_count = 1L,
            synonym_index = 1L
          )
        next
      }

      # Multiple synonyms found - expand rows
      synonym_count <- length(parts)

      # Add audit entry for original row
      audit_rows[[length(audit_rows) + 1]] <- tibble::tibble(
        row_id = as.integer(row_data$original_row_id),
        field = col_name,
        step = "split_synonyms",
        original_value = original_name,
        new_value = paste0("Split into ", synonym_count, " synonyms: ", paste(parts, collapse = "; ")),
        reason = paste0("Split comma/semicolon-separated synonyms in ", col_name)
      )

      # Create rows for each synonym
      for (syn_idx in seq_along(parts)) {
        new_row <- row_data
        new_row[[col_name]] <- parts[syn_idx]
        new_row$synonym_count <- as.integer(synonym_count)
        new_row$synonym_index <- as.integer(syn_idx)

        # Set CAS columns to NA for synonym rows (index > 1)
        if (syn_idx > 1) {
          for (cas_col in cas_cols) {
            if (cas_col %in% names(new_row)) {
              new_row[[cas_col]] <- NA_character_
            }
          }

          # Add audit entry for synonym row
          audit_rows[[length(audit_rows) + 1]] <- tibble::tibble(
            row_id = as.integer(row_data$original_row_id),
            field = col_name,
            step = "split_synonyms",
            original_value = original_name,
            new_value = paste0("Synonym row ", syn_idx, ": ", parts[syn_idx]),
            reason = paste0("Synonym from row ", row_data$original_row_id)
          )
        }

        expanded_rows[[length(expanded_rows) + 1]] <- new_row
      }
    }

    # Combine all expanded rows
    df_result <- dplyr::bind_rows(expanded_rows)
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
    audit_trail = audit_trail
  )
}

#' Detect bare molecular formulas
#'
#' Uses ComptoxR's validator regex to identify bare molecular formulas (H2O, NaCl, CuSO4).
#' Bare formulas are blocked because they lack chemical context needed for curation.
#' Detected formulas are moved to formula_blocked_{col} columns and name set to NA.
#'
#' @param df Dataframe with name columns
#' @param name_cols Character vector of Name-tagged column names
#' @return List with cleaned_data and audit_trail
#'
#' @examples
#' df <- tibble::tibble(chemical_name = c("H2O", "acetone", "NaCl"))
#' detect_bare_formulas(df, c("chemical_name"))
detect_bare_formulas <- function(df, name_cols) {
  # Check if ComptoxR is available
  if (!requireNamespace("ComptoxR", quietly = TRUE)) {
    warning("ComptoxR not available - skipping bare formula detection")
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

  # Extract validator regex from ComptoxR
  validator_obj <- ComptoxR:::create_formula_extractor_final()
  validator_env <- environment(validator_obj)
  validator_regex <- validator_env$validator_regex

  # Initialize result
  df_result <- df
  audit_rows <- list()

  # Add cleaning_flag column if it doesn't exist
  if (!"cleaning_flag" %in% names(df_result)) {
    df_result$cleaning_flag <- NA_character_
  }

  # Process each name column
  for (col_name in name_cols) {
    # Create formula_blocked column if it doesn't exist
    blocked_col_name <- paste0("formula_blocked_", col_name)
    if (!blocked_col_name %in% names(df_result)) {
      df_result[[blocked_col_name]] <- NA_character_
    }

    # Process each row
    for (idx in seq_len(nrow(df))) {
      original_value <- df[[col_name]][idx]

      # Skip NA
      if (is.na(original_value)) {
        next
      }

      # Clean the value same way ComptoxR does: remove spaces and dots
      cleaned_for_test <- original_value %>%
        stringr::str_remove_all("\\s+") %>%
        stringr::str_remove_all("\\.")

      # Heuristic pre-check: real formulas never contain 2+ consecutive lowercase letters
      # "NaCl" has only single lowercase chars; "Naphthalene" has "aphthalene"
      # This prevents false positives from chemical names that look like element sequences
      has_word_pattern <- stringr::str_detect(original_value, "[a-z]{2}")

      # Additional heuristic: pure uppercase with no digits is almost always an abbreviation, not a formula
      # Real formulas have numbers (C10H22, CaCl2) or mixed case (NaCl, CuSO4)
      # Abbreviations are all uppercase letters (DEHP, PFOA, PCB, DDT)
      is_all_uppercase_no_digits <- stringr::str_detect(original_value, "^[A-Z]+$")

      # Test if the ENTIRE cleaned string matches the validator regex
      # Skip the regex check if:
      # 1. It looks like a word (has 2+ consecutive lowercase letters), OR
      # 2. It's all uppercase with no digits (abbreviation)
      is_bare_formula <- if (has_word_pattern || is_all_uppercase_no_digits) {
        FALSE
      } else {
        stringr::str_detect(cleaned_for_test, paste0("^", validator_regex, "$"))
      }

      if (is_bare_formula) {
        # Block this row
        df_result$cleaning_flag[idx] <- "BLOCK: bare formula"
        df_result[[blocked_col_name]][idx] <- original_value
        df_result[[col_name]][idx] <- NA_character_

        # Add audit entry
        audit_rows[[length(audit_rows) + 1]] <- tibble::tibble(
          row_id = as.integer(idx),
          field = col_name,
          step = "detect_bare_formula",
          original_value = original_value,
          new_value = "[NA]",
          reason = paste0("Bare molecular formula detected in ", col_name, "; preserved in ", blocked_col_name)
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
    cleaned_data = df_result,
    audit_trail = audit_trail
  )
}

#' Flag rows matching reference list entries
#'
#' Two-pass matching: exact match first (tolower comparison), then substring match.
#' Only active=TRUE reference entries are matched against.
#' Match type and source are recorded in audit trail.
#'
#' @param df Dataframe with name columns
#' @param name_cols Character vector of Name-tagged column names
#' @param reference_list Tibble with columns: term, source, active
#' @param flag_type Either "warning" or "blocking"
#' @param flag_label Human-readable label for the flag (e.g., "functional category")
#' @return List with cleaned_data and audit_trail
#'
#' @examples
#' df <- tibble::tibble(chemical_name = c("plasticizer", "dibutyl phthalate plasticizer"))
#' ref <- tibble::tibble(term = "plasticizer", source = "app_default", active = TRUE)
#' flag_reference_matches(df, c("chemical_name"), ref, "warning", "functional category")
flag_reference_matches <- function(df, name_cols, reference_list, flag_type, flag_label) {
  # Initialize result
  df_result <- df
  audit_rows <- list()

  # Add cleaning_flag column if it doesn't exist
  if (!"cleaning_flag" %in% names(df_result)) {
    df_result$cleaning_flag <- NA_character_
  }

  # Filter to active entries only
  active_refs <- reference_list %>%
    dplyr::filter(active == TRUE)

  # Skip if no active references
  if (nrow(active_refs) == 0) {
    return(list(
      cleaned_data = df_result,
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

  # Determine flag prefix
  flag_prefix <- if (flag_type == "blocking") "BLOCK" else "WARN"

  # Process each name column
  for (col_name in name_cols) {
    # Process each row
    for (idx in seq_len(nrow(df))) {
      # Skip if already flagged (first flag wins - bare formula has priority)
      if (!is.na(df_result$cleaning_flag[idx]) && df_result$cleaning_flag[idx] != "") {
        next
      }

      original_value <- df[[col_name]][idx]

      # Skip NA
      if (is.na(original_value)) {
        next
      }

      # Two-pass matching
      matched <- FALSE
      match_type <- NA_character_
      matched_term <- NA_character_
      matched_source <- NA_character_

      # Pass 1: Exact match (case-insensitive)
      for (ref_idx in seq_len(nrow(active_refs))) {
        ref_term <- active_refs$term[ref_idx]
        if (tolower(original_value) == tolower(ref_term)) {
          matched <- TRUE
          match_type <- "exact"
          matched_term <- ref_term
          matched_source <- active_refs$source[ref_idx]
          break
        }
      }

      # Pass 2: Substring match with word boundaries (only if no exact match)
      if (!matched) {
        for (ref_idx in seq_len(nrow(active_refs))) {
          ref_term <- active_refs$term[ref_idx]
          # Use word boundaries to prevent substring false positives
          # e.g., stop word "na" should NOT match inside "Naphthalene"
          # Escape special regex characters in ref_term, then wrap in \b boundaries
          escaped_term <- stringr::str_replace_all(ref_term, "([/.])", "\\\\\\1")
          bounded_pattern <- paste0("\\b", escaped_term, "\\b")
          if (stringr::str_detect(original_value, stringr::regex(bounded_pattern, ignore_case = TRUE))) {
            matched <- TRUE
            match_type <- "substring"
            matched_term <- ref_term
            matched_source <- active_refs$source[ref_idx]
            break
          }
        }
      }

      # If matched, set flag
      if (matched) {
        df_result$cleaning_flag[idx] <- paste0(flag_prefix, ": ", flag_label, " [", match_type, "]")

        # Add audit entry
        audit_rows[[length(audit_rows) + 1]] <- tibble::tibble(
          row_id = as.integer(idx),
          field = col_name,
          step = paste0("flag_", flag_type),
          original_value = original_value,
          new_value = df_result$cleaning_flag[idx],
          reason = paste0(
            "Matched '", matched_term, "' (source: ", matched_source, ", match type: ", match_type, ") in ", col_name
          )
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
    cleaned_data = df_result,
    audit_trail = audit_trail
  )
}

#' Detect non-ASCII characters in a character vector
#'
#' Helper function that scans a character vector for non-ASCII characters.
#' Returns a list of unique non-ASCII characters with their Unicode codepoints
#' and occurrence counts.
#'
#' @param x Character vector to scan
#' @return Named list keyed by "U+XXXX" with elements: char, codepoint, count
detect_non_ascii_chars <- function(x) {
  # Handle NA and empty vectors
  if (length(x) == 0 || all(is.na(x))) {
    return(list())
  }

  # Remove NAs for processing
  x_clean <- x[!is.na(x)]

  # Find all non-ASCII characters
  non_ascii_list <- list()

  for (val in x_clean) {
    # Check if value contains non-ASCII
    if (grepl("[^\x01-\x7F]", val)) {
      # Extract individual characters
      chars <- strsplit(val, "")[[1]]

      for (char in chars) {
        # Check if this character is non-ASCII
        if (grepl("[^\x01-\x7F]", char)) {
          # Get codepoint
          codepoint_int <- utf8ToInt(char)
          codepoint_str <- sprintf("U+%04X", codepoint_int)

          # Add or increment count
          if (codepoint_str %in% names(non_ascii_list)) {
            non_ascii_list[[codepoint_str]]$count <- non_ascii_list[[codepoint_str]]$count + 1
          } else {
            non_ascii_list[[codepoint_str]] <- list(
              char = char,
              codepoint = codepoint_str,
              count = 1
            )
          }
        }
      }
    }
  }

  return(non_ascii_list)
}

#' Perform post-curation Unicode QC (read-only detection)
#'
#' Scans a dataframe for non-ASCII characters without modifying the data.
#' This is a QC function for post-curation detection of Unicode that may
#' not have been handled by ComptoxR::clean_unicode.
#'
#' Returns a report of:
#' - How many rows contain non-ASCII characters
#' - Which row indices have non-ASCII
#' - What specific Unicode characters were found (with codepoints and counts)
#'
#' @param df Dataframe to scan (typically post-curation resolution_state)
#' @return List with: rows_with_non_ascii (integer), row_indices (integer vector),
#'   unhandled_chars (named list keyed by "U+XXXX")
#'
#' @examples
#' df <- tibble::tibble(name = c("acetone", "\u03B1-tocopherol"))
#' result <- perform_unicode_qc(df)
#' result$rows_with_non_ascii  # => 1
#' result$row_indices  # => c(2)
#' result$unhandled_chars[["U+03B1"]]$count  # => 1
perform_unicode_qc <- function(df) {
  # Handle empty dataframe
  if (nrow(df) == 0 || ncol(df) == 0) {
    return(list(
      rows_with_non_ascii = 0,
      row_indices = integer(),
      unhandled_chars = list()
    ))
  }

  # Get character columns
  char_cols <- names(df)[sapply(df, is.character)]

  # Handle no character columns
  if (length(char_cols) == 0) {
    return(list(
      rows_with_non_ascii = 0,
      row_indices = integer(),
      unhandled_chars = list()
    ))
  }

  # Track rows with non-ASCII
  rows_with_issues <- integer()
  all_non_ascii_chars <- list()

  # Scan each character column
  for (col_name in char_cols) {
    col_data <- df[[col_name]]

    # Find rows with non-ASCII in this column
    for (row_idx in seq_along(col_data)) {
      val <- col_data[row_idx]

      # Skip NA
      if (is.na(val)) {
        next
      }

      # Check for non-ASCII
      if (grepl("[^\x01-\x7F]", val)) {
        # Record row index (if not already recorded)
        if (!(row_idx %in% rows_with_issues)) {
          rows_with_issues <- c(rows_with_issues, row_idx)
        }

        # Extract non-ASCII characters from this value
        non_ascii_found <- detect_non_ascii_chars(val)

        # Merge into all_non_ascii_chars (accumulating counts)
        for (codepoint in names(non_ascii_found)) {
          if (codepoint %in% names(all_non_ascii_chars)) {
            all_non_ascii_chars[[codepoint]]$count <- all_non_ascii_chars[[codepoint]]$count + non_ascii_found[[codepoint]]$count
          } else {
            all_non_ascii_chars[[codepoint]] <- non_ascii_found[[codepoint]]
          }
        }
      }
    }
  }

  # Return result
  list(
    rows_with_non_ascii = length(rows_with_issues),
    row_indices = sort(rows_with_issues),
    unhandled_chars = all_non_ascii_chars
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

  # Step 1: Unicode to ASCII (using ComptoxR for chemistry-specific mappings)
  df_after_unicode <- df_after_lineage %>%
    dplyr::mutate(dplyr::across(where(is.character), ComptoxR::clean_unicode))

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

  # If tag_map provided, run CAS and name steps
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
    df_after_multi_cas <- detect_multi_cas(df_after_rescue, tag_map_updated)

    # Step 6: Name cleaning (if Name columns present)
    name_cols <- names(tag_map)[tag_map == "Name"]

    if (length(name_cols) > 0) {
      # Step 6a: Strip terminal enclosures
      enclosure_result <- strip_terminal_enclosures(df_after_multi_cas, name_cols)
      df_after_enclosures <- enclosure_result$cleaned_data
      audit_combined <- dplyr::bind_rows(audit_combined, enclosure_result$audit_trail)
      # Merge new_tags from formula_extract columns (though currently empty)
      new_tags <- c(new_tags, enclosure_result$new_tags)

      # Update tag_map with formula_extract columns if needed
      tag_map_updated <- c(tag_map_updated, enclosure_result$new_tags)

      # Step 6b: Strip quality adjectives
      quality_result <- strip_quality_adjectives(df_after_enclosures, name_cols)
      df_after_quality <- quality_result$cleaned_data
      audit_combined <- dplyr::bind_rows(audit_combined, quality_result$audit_trail)

      # Step 6c: Strip salt references
      salt_result <- strip_salt_references(df_after_quality, name_cols)
      df_after_salts <- salt_result$cleaned_data
      audit_combined <- dplyr::bind_rows(audit_combined, salt_result$audit_trail)

      # Step 6d: Strip terminal unspecified
      unspec_result <- strip_terminal_unspecified(df_after_salts, name_cols)
      df_after_unspec <- unspec_result$cleaned_data
      audit_combined <- dplyr::bind_rows(audit_combined, unspec_result$audit_trail)

      # Step 6d1: Strip user-defined reference terms
      if (!is.null(reference_lists$strip_terms)) {
        strip_ref_result <- strip_reference_terms(df_after_unspec, name_cols, reference_lists$strip_terms)
        df_after_unspec <- strip_ref_result$cleaned_data
        audit_combined <- dplyr::bind_rows(audit_combined, strip_ref_result$audit_trail)
      }

      # Step 6d2: Final cleanup BEFORE second stripping - str_squish and remove trailing punctuation
      df_before_second_strip <- df_after_unspec %>%
        dplyr::mutate(dplyr::across(dplyr::all_of(name_cols), ~ {
          .x %>%
            stringr::str_squish() %>%
            stringr::str_remove("\\(\\s*\\)\\s*$") %>%  # Remove empty parentheticals
            stringr::str_trim() %>%
            stringr::str_remove("[,;-]+$") %>%  # Remove trailing punctuation
            stringr::str_trim()
        }))

      # Step 6d3: Strip terminal enclosures AGAIN (after text cleaning exposes new terminal enclosures)
      enclosure_result2 <- strip_terminal_enclosures(df_before_second_strip, name_cols)
      df_after_enclosures2 <- enclosure_result2$cleaned_data
      audit_combined <- dplyr::bind_rows(audit_combined, enclosure_result2$audit_trail)

      # Step 6e: Split synonyms (MUST be LAST)
      synonym_result <- split_synonyms(df_after_enclosures2, name_cols, tag_map_updated)
      df_after_synonyms <- synonym_result$cleaned_data
      audit_combined <- dplyr::bind_rows(audit_combined, synonym_result$audit_trail)

      # Step 6f: Final cleanup after synonym split - str_squish and remove empty parentheticals
      df_after_synonyms <- df_after_synonyms %>%
        dplyr::mutate(dplyr::across(dplyr::all_of(name_cols), ~ {
          .x %>%
            stringr::str_squish() %>%
            stringr::str_remove_all("\\(\\s*\\)") %>%  # Remove empty parentheticals
            stringr::str_trim()
        }))

      # Remove rows where all name columns are empty or NA
      name_check <- df_after_synonyms[, name_cols, drop = FALSE]
      all_empty <- apply(name_check, 1, function(row) {
        all(is.na(row) | row == "")
      })
      df_final <- df_after_synonyms[!all_empty, ]
    } else {
      # No name columns - skip name cleaning
      df_final <- df_after_multi_cas
    }
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
