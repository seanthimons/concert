# cleaning_pipeline.R
# Pure R functions for text cleaning with audit trail tracking
#
# Core functions:
# - Unicode cleaning: Uses ComptoxR::clean_unicode for chemistry-specific mappings
# - clean_text_field: Strip leading/trailing whitespace and punctuation artifacts
# - build_audit_trail: Compare two dataframes and record changes
# - run_cleaning_pipeline: Orchestrate cleaning steps with audit trail

# Roman numeral pattern for oxidation states (I through XII, case-insensitive)
# Matches: pure roman numeral like "III", or element symbol + roman numeral like "Cr III"
ROMAN_NUMERAL_PATTERN <- "(?i)^\\s*([A-Z][a-z]?\\s+)?(I{1,3}|IV|V|VI{0,3}|IX|X|XI{0,2})\\s*$"


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
#' @importFrom magrittr %>%
#' @export
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
#' @export
build_audit_trail <- function(df_original, df_cleaned, step_name, reason_fn) {
  # Get character columns (only these are cleaned)
  char_cols <- names(df_original)[sapply(df_original, is.character)]

  # Pre-allocate vectors for all audit entries (avoids O(n^2) growing-list pattern)
  all_row_ids <- integer()
  all_fields <- character()
  all_originals <- character()
  all_news <- character()

  # Compare each column and collect changes vectorized

  for (col_name in char_cols) {
    original_vals <- as.character(df_original[[col_name]])
    cleaned_vals <- as.character(df_cleaned[[col_name]])

    # Find rows where values changed (vectorized comparison)
    changed_idx <- which(original_vals != cleaned_vals)

    if (length(changed_idx) > 0) {
      # Vectorized append
      all_row_ids <- c(all_row_ids, as.integer(changed_idx))
      all_fields <- c(all_fields, rep(col_name, length(changed_idx)))
      all_originals <- c(all_originals, original_vals[changed_idx])
      all_news <- c(all_news, cleaned_vals[changed_idx])
    }
  }

  # Build single tibble from vectors (O(1) vs O(n) bind_rows)
  if (length(all_row_ids) == 0) {
    return(tibble::tibble(
      row_id = integer(),
      field = character(),
      step = character(),
      original_value = character(),
      new_value = character(),
      reason = character()
    ))
  }

  tibble::tibble(
    row_id = all_row_ids,
    field = all_fields,
    step = rep(step_name, length(all_row_ids)),
    original_value = all_originals,
    new_value = all_news,
    reason = vapply(all_fields, reason_fn, character(1))
  )
}

#' Remap audit trail row IDs from unique-string slice to parent dataset
#'
#' When a step function runs on a deduplicated slice of a dataframe, its audit
#' trail contains row IDs 1..n_unique. This function expands those IDs back to
#' the full set of matching parent rows, producing an audit trail with correct
#' row IDs relative to the original (parent) dataframe.
#'
#' @param audit_slice 6-column audit tibble from the deduped unique-string slice.
#'   Row IDs are positions 1..n_unique within the unique slice.
#' @param parent_map Named list where names are character representations of
#'   positions in the unique slice ("1", "2", ...) and values are integer vectors
#'   of ALL parent row indices that mapped to that unique value.
#' @return 6-column audit tibble with row_id values expanded to parent row indices.
#'   Preserves all other columns (field, step, original_value, new_value, reason).
#' @export
remap_audit_to_parent <- function(audit_slice, parent_map) {
  # Fast path: no audit entries to expand
  if (nrow(audit_slice) == 0) {
    return(audit_slice)
  }

  # Pre-allocate vectors (avoids O(n^2) growing-list pattern per CLAUDE.md guardrail)
  all_row_ids <- integer()
  all_fields <- character()
  all_steps <- character()
  all_originals <- character()
  all_news <- character()
  all_reasons <- character()

  for (i in seq_len(nrow(audit_slice))) {
    slice_pos <- as.character(audit_slice$row_id[i])
    parent_indices <- parent_map[[slice_pos]]

    if (is.null(parent_indices) || length(parent_indices) == 0) {
      next
    }

    n_expand <- length(parent_indices)

    all_row_ids <- c(all_row_ids, parent_indices)
    all_fields <- c(all_fields, rep(audit_slice$field[i], n_expand))
    all_steps <- c(all_steps, rep(audit_slice$step[i], n_expand))
    all_originals <- c(all_originals, rep(audit_slice$original_value[i], n_expand))
    all_news <- c(all_news, rep(audit_slice$new_value[i], n_expand))
    all_reasons <- c(all_reasons, rep(audit_slice$reason[i], n_expand))
  }

  result <- tibble::tibble(
    row_id = all_row_ids,
    field = all_fields,
    step = all_steps,
    original_value = all_originals,
    new_value = all_news,
    reason = all_reasons
  )

  # Type safety assertion (PERF-02 companion: row_id must be integer)
  stopifnot(is.integer(result$row_id))

  result
}

#' Deduplication wrapper for cleaning step functions
#'
#' Runs a cleaning step function on only the distinct values of the target
#' columns, then remaps the results back to the full parent dataframe. This
#' provides a significant speedup when the dataset has many repeated values
#' (e.g., the same chemical name appearing in thousands of rows).
#'
#' If the uniqueness ratio (n_distinct / n_total) exceeds \code{uniqueness_threshold},
#' deduplication is bypassed and the step function is called directly on the full
#' dataframe (D-03). This avoids overhead in datasets that are already highly unique.
#'
#' @param step_fn Step function to call. Must return \code{list(cleaned_data, audit_trail)}.
#' @param df Full parent dataframe to process.
#' @param ... Additional arguments passed to \code{step_fn} (e.g., \code{tag_map}).
#' @param dedup_cols Character vector of column names to dedup on. The composite
#'   key is constructed by pasting these column values together.
#' @param uniqueness_threshold Numeric in [0,1]. If n_distinct/n_total exceeds
#'   this value, skip dedup and call the step directly. Default: 0.5.
#' @return List with \code{cleaned_data} (same row count as \code{df}) and
#'   \code{audit_trail} (row IDs valid for \code{df}). Identical shape to calling
#'   \code{step_fn(df, ...)} directly.
#' @export
dedup_step <- function(step_fn, df, ..., dedup_cols, uniqueness_threshold = 0.5) {
  # Build composite dedup key: NA values become "__NA__" sentinel (T-37-02)
  key_parts <- lapply(dedup_cols, function(col) {
    vals <- df[[col]]
    ifelse(is.na(vals), "__NA__", as.character(vals))
  })
  key_vec <- do.call(paste0, key_parts)

  n_total <- length(key_vec)
  unique_keys <- unique(key_vec)
  n_distinct <- length(unique_keys)

  # Uniqueness bypass (D-03): high-cardinality data gets direct processing
  if (n_total == 0 || n_distinct / n_total > uniqueness_threshold) {
    return(step_fn(df, ...))
  }

  # Build dedup map
  # first_occurrence[i] = index of the first occurrence of unique_keys[i] in key_vec
  first_occurrence <- match(unique_keys, key_vec)
  df_unique <- df[first_occurrence, , drop = FALSE]

  # parent_map: named list, names = position in unique slice (as character),
  # values = integer vectors of ALL parent row indices mapping to that unique value.
  # Use split() + match() to build in O(n) rather than O(n*m) with which() per key.
  key_to_unique_pos <- match(key_vec, unique_keys) # integer position in unique_keys for each parent row
  groups <- split(seq_along(key_vec), key_to_unique_pos) # O(n): group parent indices by unique position
  parent_map <- stats::setNames(
    lapply(as.character(seq_along(unique_keys)), function(pos) {
      idx <- groups[[pos]]
      if (is.null(idx)) integer(0L) else as.integer(idx)
    }),
    as.character(seq_along(unique_keys))
  )

  # Run step on unique slice only
  result <- step_fn(df_unique, ...)

  # Remap cleaned_data: for each parent row, copy the cleaned values from its
  # corresponding unique-slice position (vectorized via match)
  key_to_unique_idx <- match(key_vec, unique_keys)
  df_remapped <- result$cleaned_data[key_to_unique_idx, , drop = FALSE]
  rownames(df_remapped) <- NULL

  # Remap audit trail: expand slice row IDs to all matching parent rows
  remapped_audit <- remap_audit_to_parent(result$audit_trail, parent_map)

  # PERF-02 assertion: remapped audit row_ids must not exceed parent row count (T-37-04)
  if (nrow(remapped_audit) > 0) {
    stopifnot(max(remapped_audit$row_id) <= nrow(df))
  }

  # Build return list preserving step contract
  return_list <- list(cleaned_data = df_remapped, audit_trail = remapped_audit)

  # Preserve new_tags if step returned them (e.g., normalize_cas_fields variants)
  if (!is.null(result$new_tags)) {
    return_list$new_tags <- result$new_tags
  }

  return_list
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
#' @export
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
#' @export
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

  # Build audit trail vectorized (avoids O(n^2) growing-list pattern)
  all_row_ids <- integer()
  all_fields <- character()
  all_originals <- character()
  all_news <- character()

  for (col_name in cas_cols) {
    original_vals <- as.character(df_before[[col_name]])
    cleaned_vals <- as.character(df_after[[col_name]])

    # Vectorized comparison: find rows where values differ (including NA transitions)
    # Use mapply for pairwise identical check
    differs <- !mapply(identical, original_vals, cleaned_vals, USE.NAMES = FALSE)
    changed_idx <- which(differs)

    if (length(changed_idx) > 0) {
      all_row_ids <- c(all_row_ids, as.integer(changed_idx))
      all_fields <- c(all_fields, rep(col_name, length(changed_idx)))
      all_originals <- c(all_originals, ifelse(is.na(original_vals[changed_idx]), "[NA]", original_vals[changed_idx]))
      all_news <- c(all_news, ifelse(is.na(cleaned_vals[changed_idx]), "[NA]", cleaned_vals[changed_idx]))
    }
  }

  # Build single tibble from vectors
  audit_trail <- if (length(all_row_ids) == 0) {
    tibble::tibble(
      row_id = integer(),
      field = character(),
      step = character(),
      original_value = character(),
      new_value = character(),
      reason = character()
    )
  } else {
    tibble::tibble(
      row_id = all_row_ids,
      field = all_fields,
      step = rep("normalize_cas", length(all_row_ids)),
      original_value = all_originals,
      new_value = all_news,
      reason = paste0("Normalize CAS-RN in ", all_fields, " using ComptoxR::as_cas()")
    )
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
#' @export
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
          return(x[1]) # Take first CAS if multiple found
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

      # Build audit trail for extractions (vectorized)
      extracted_idx <- which(!is.na(extracted_cas))
      if (length(extracted_idx) > 0) {
        audit_rows[[length(audit_rows) + 1]] <- tibble::tibble(
          row_id = as.integer(extracted_idx),
          field = rep(col_name, length(extracted_idx)),
          step = rep("rescue_cas", length(extracted_idx)),
          original_value = as.character(df[[col_name]][extracted_idx]),
          new_value = paste0("Extracted ", extracted_cas[extracted_idx], " to ", new_col_name),
          reason = rep(
            paste0("Extract CAS-RN from ", col_name, " using ComptoxR::extract_cas()"),
            length(extracted_idx)
          )
        )
      }
    }
  }

  # Combine audit rows (now a list of tibbles, not a list of single-row tibbles)
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
#' @export
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
#' @export
strip_terminal_enclosures <- function(df, name_cols) {
  # Initialize result
  df_result <- df

  # Pre-allocate audit vectors (avoid list-growth O(n²))
  audit_row_ids <- integer()
  audit_fields <- character()
  audit_originals <- character()
  audit_news <- character()
  audit_reasons <- character()

  # Exception words for vectorized detection
  exception_words <- c("density", "probably", "average", "combination")

  # Process each name column (vectorized per column, not per row)
  for (col_name in name_cols) {
    extract_col_name <- paste0("formula_extract_", col_name)
    if (!extract_col_name %in% names(df_result)) {
      df_result[[extract_col_name]] <- NA_character_
    }

    original_vals <- df[[col_name]]
    n <- length(original_vals)
    stripped_vals <- original_vals
    extracted_vals <- rep(NA_character_, n)

    # ---- Pass 1: Strip terminal parentheticals (vectorized) ----
    parenth_match <- stringr::str_match(stripped_vals, "^(.*)\\(([^)]*)\\)\\s*$")
    has_parenth <- !is.na(parenth_match[, 1])

    if (any(has_parenth)) {
      parenth_base <- parenth_match[has_parenth, 2]
      parenth_content <- parenth_match[has_parenth, 3]
      parenth_trimmed <- stringr::str_trim(parenth_content)

      # Vectorized empty check
      is_empty <- parenth_trimmed == ""

      # Empty parentheticals: strip without audit
      empty_idx <- which(has_parenth)[is_empty]
      if (length(empty_idx) > 0) {
        stripped_vals[empty_idx] <- stringr::str_trim(parenth_base[is_empty])
      }

      # Non-empty: check strip conditions vectorized
      non_empty_idx <- which(has_parenth)[!is_empty]
      if (length(non_empty_idx) > 0) {
        content_ne <- parenth_content[!is_empty]
        content_lower <- stringr::str_to_lower(content_ne)
        trimmed_ne <- parenth_trimmed[!is_empty]

        has_yl <- stringr::str_detect(content_ne, "yl")
        has_pct <- stringr::str_detect(content_ne, "%")
        has_roman <- stringr::str_detect(trimmed_ne, ROMAN_NUMERAL_PATTERN)

        # Vectorized exception check
        has_exception <- Reduce(
          `|`,
          lapply(exception_words, function(w) {
            stringr::str_detect(content_lower, w)
          })
        )

        should_strip <- (!has_yl | has_exception) & !has_pct & !has_roman
        strip_idx <- non_empty_idx[should_strip]

        if (length(strip_idx) > 0) {
          stripped_vals[strip_idx] <- stringr::str_trim(parenth_base[!is_empty][should_strip])
          extracted_vals[strip_idx] <- content_ne[should_strip]
        }
      }
    }

    # ---- Pass 2: Strip terminal brackets (vectorized) ----
    bracket_match <- stringr::str_match(stripped_vals, "^(.*)\\[([^]]*)\\]\\s*$")
    has_bracket <- !is.na(bracket_match[, 1])

    if (any(has_bracket)) {
      bracket_base <- bracket_match[has_bracket, 2]
      bracket_content <- bracket_match[has_bracket, 3]
      bracket_trimmed <- stringr::str_trim(bracket_content)

      is_empty <- bracket_trimmed == ""

      # Empty brackets: strip without audit
      empty_idx <- which(has_bracket)[is_empty]
      if (length(empty_idx) > 0) {
        stripped_vals[empty_idx] <- stringr::str_trim(bracket_base[is_empty])
      }

      # Non-empty: check strip conditions
      non_empty_idx <- which(has_bracket)[!is_empty]
      if (length(non_empty_idx) > 0) {
        content_ne <- bracket_content[!is_empty]
        content_lower <- stringr::str_to_lower(content_ne)
        trimmed_ne <- bracket_trimmed[!is_empty]

        has_yl <- stringr::str_detect(content_ne, "yl")
        has_pct <- stringr::str_detect(content_ne, "%")
        has_roman <- stringr::str_detect(trimmed_ne, ROMAN_NUMERAL_PATTERN)

        has_exception <- Reduce(
          `|`,
          lapply(exception_words, function(w) {
            stringr::str_detect(content_lower, w)
          })
        )

        should_strip <- (!has_yl | has_exception) & !has_pct & !has_roman
        strip_idx <- non_empty_idx[should_strip]

        if (length(strip_idx) > 0) {
          stripped_vals[strip_idx] <- stringr::str_trim(bracket_base[!is_empty][should_strip])
          # Combine with existing extracted content
          new_content <- content_ne[should_strip]
          existing <- extracted_vals[strip_idx]
          extracted_vals[strip_idx] <- ifelse(
            is.na(existing),
            new_content,
            paste(existing, new_content, sep = "; ")
          )
        }
      }
    }

    # ---- Batch update and audit ----
    changed_mask <- !is.na(original_vals) & (stripped_vals != original_vals)
    if (any(changed_mask)) {
      changed_idx <- which(changed_mask)
      df_result[[col_name]] <- stripped_vals

      # Update extract column (merge with existing)
      existing_extract <- df_result[[extract_col_name]][changed_idx]
      new_extract <- extracted_vals[changed_idx]
      df_result[[extract_col_name]][changed_idx] <- ifelse(
        is.na(existing_extract) | existing_extract == "",
        new_extract,
        ifelse(is.na(new_extract), existing_extract, paste(existing_extract, new_extract, sep = "; "))
      )

      # Batch append to audit vectors
      audit_row_ids <- c(audit_row_ids, as.integer(changed_idx))
      audit_fields <- c(audit_fields, rep(col_name, length(changed_idx)))
      audit_originals <- c(audit_originals, original_vals[changed_idx])
      audit_news <- c(audit_news, stripped_vals[changed_idx])
      audit_reasons <- c(
        audit_reasons,
        rep(
          paste0("Strip terminal enclosure from ", col_name, "; content saved to ", extract_col_name),
          length(changed_idx)
        )
      )
    }
  }

  # Build audit trail from vectors (single tibble construction)
  audit_trail <- if (length(audit_row_ids) == 0) {
    tibble::tibble(
      row_id = integer(),
      field = character(),
      step = character(),
      original_value = character(),
      new_value = character(),
      reason = character()
    )
  } else {
    tibble::tibble(
      row_id = audit_row_ids,
      field = audit_fields,
      step = rep("strip_terminal_enclosures", length(audit_row_ids)),
      original_value = audit_originals,
      new_value = audit_news,
      reason = audit_reasons
    )
  }

  list(
    cleaned_data = df_result,
    audit_trail = audit_trail,
    new_tags = list()
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
#' @export
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

  # Build audit trail vectorized
  all_row_ids <- integer()
  all_fields <- character()
  all_originals <- character()
  all_news <- character()

  for (col_name in name_cols) {
    original_vals <- as.character(df_before[[col_name]])
    cleaned_vals <- as.character(df_after[[col_name]])

    # Vectorized: find rows where non-NA values changed
    changed_idx <- which(!is.na(original_vals) & !is.na(cleaned_vals) & original_vals != cleaned_vals)

    if (length(changed_idx) > 0) {
      all_row_ids <- c(all_row_ids, as.integer(changed_idx))
      all_fields <- c(all_fields, rep(col_name, length(changed_idx)))
      all_originals <- c(all_originals, original_vals[changed_idx])
      all_news <- c(all_news, cleaned_vals[changed_idx])
    }
  }

  # Build single tibble from vectors
  audit_trail <- if (length(all_row_ids) == 0) {
    tibble::tibble(
      row_id = integer(),
      field = character(),
      step = character(),
      original_value = character(),
      new_value = character(),
      reason = character()
    )
  } else {
    tibble::tibble(
      row_id = all_row_ids,
      field = all_fields,
      step = rep("strip_quality_adjectives", length(all_row_ids)),
      original_value = all_originals,
      new_value = all_news,
      reason = paste0("Remove quality adjectives from ", all_fields)
    )
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
#' @export
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

  # Build audit trail vectorized
  all_row_ids <- integer()
  all_fields <- character()
  all_originals <- character()
  all_news <- character()

  for (col_name in name_cols) {
    original_vals <- as.character(df_before[[col_name]])
    cleaned_vals <- as.character(df_after[[col_name]])

    # Vectorized: find rows where non-NA values changed
    changed_idx <- which(!is.na(original_vals) & !is.na(cleaned_vals) & original_vals != cleaned_vals)

    if (length(changed_idx) > 0) {
      all_row_ids <- c(all_row_ids, as.integer(changed_idx))
      all_fields <- c(all_fields, rep(col_name, length(changed_idx)))
      all_originals <- c(all_originals, original_vals[changed_idx])
      all_news <- c(all_news, cleaned_vals[changed_idx])
    }
  }

  # Build single tibble from vectors
  audit_trail <- if (length(all_row_ids) == 0) {
    tibble::tibble(
      row_id = integer(),
      field = character(),
      step = character(),
      original_value = character(),
      new_value = character(),
      reason = character()
    )
  } else {
    tibble::tibble(
      row_id = all_row_ids,
      field = all_fields,
      step = rep("strip_salt_references", length(all_row_ids)),
      original_value = all_originals,
      new_value = all_news,
      reason = paste0("Remove ambiguous salt reference from ", all_fields)
    )
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
#' @export
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

  # Build audit trail vectorized
  all_row_ids <- integer()
  all_fields <- character()
  all_originals <- character()
  all_news <- character()

  for (col_name in name_cols) {
    original_vals <- as.character(df_before[[col_name]])
    cleaned_vals <- as.character(df_after[[col_name]])

    # Vectorized: find rows where non-NA values changed
    changed_idx <- which(!is.na(original_vals) & !is.na(cleaned_vals) & original_vals != cleaned_vals)

    if (length(changed_idx) > 0) {
      all_row_ids <- c(all_row_ids, as.integer(changed_idx))
      all_fields <- c(all_fields, rep(col_name, length(changed_idx)))
      all_originals <- c(all_originals, original_vals[changed_idx])
      all_news <- c(all_news, cleaned_vals[changed_idx])
    }
  }

  # Build single tibble from vectors
  audit_trail <- if (length(all_row_ids) == 0) {
    tibble::tibble(
      row_id = integer(),
      field = character(),
      step = character(),
      original_value = character(),
      new_value = character(),
      reason = character()
    )
  } else {
    tibble::tibble(
      row_id = all_row_ids,
      field = all_fields,
      step = rep("strip_terminal_unspecified", length(all_row_ids)),
      original_value = all_originals,
      new_value = all_news,
      reason = paste0("Remove terminal 'unspecified' suffix from ", all_fields)
    )
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
#' @export
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
  regex_meta <- c("\\\\w", "\\+", "\\*", "\\^", "\\$", "\\?", "\\(", "\\)", "\\[", "\\]", "\\{", "\\}", "\\|")

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
        # Escape all regex metacharacters, then wrap in word boundaries
        escaped_term <- stringr::str_replace_all(term, "([\\\\/.\\[\\](){}|?+*^$])", "\\\\\\1")
        pattern <- paste0("\\b", escaped_term, "\\b")
        df_after[[col_name]] <- df_after[[col_name]] %>%
          stringr::str_remove_all(stringr::regex(pattern, ignore_case = TRUE)) %>%
          stringr::str_squish()
      }
    }
  }

  # Build audit trail vectorized
  all_row_ids <- integer()
  all_fields <- character()
  all_originals <- character()
  all_news <- character()

  for (col_name in name_cols) {
    original_vals <- as.character(df_before[[col_name]])
    cleaned_vals <- as.character(df_after[[col_name]])

    # Vectorized: find rows where non-NA values changed
    changed_idx <- which(!is.na(original_vals) & !is.na(cleaned_vals) & original_vals != cleaned_vals)

    if (length(changed_idx) > 0) {
      all_row_ids <- c(all_row_ids, as.integer(changed_idx))
      all_fields <- c(all_fields, rep(col_name, length(changed_idx)))
      all_originals <- c(all_originals, original_vals[changed_idx])
      all_news <- c(all_news, cleaned_vals[changed_idx])
    }
  }

  # Build single tibble from vectors
  audit_trail <- if (length(all_row_ids) == 0) {
    tibble::tibble(
      row_id = integer(),
      field = character(),
      step = character(),
      original_value = character(),
      new_value = character(),
      reason = character()
    )
  } else {
    tibble::tibble(
      row_id = all_row_ids,
      field = all_fields,
      step = rep("strip_reference_terms", length(all_row_ids)),
      original_value = all_originals,
      new_value = all_news,
      reason = paste0("Remove user-defined strip terms from ", all_fields)
    )
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
#' @export
split_synonyms <- function(df, name_cols, tag_map) {
  # Get CASRN columns
  cas_cols <- names(tag_map)[tag_map == "CASRN"]

  # Helper: protect IUPAC patterns and split a single string
  split_one_name <- function(name) {
    if (is.na(name)) {
      return(NA_character_)
    }

    # Protect IUPAC comma patterns (repeat until stable)
    protected <- name
    for (iter in seq_len(10)) {
      prev <- protected
      protected <- stringr::str_replace_all(protected, "([A-Za-z]),([A-Za-z])", "\\1@@@\\2")
      protected <- stringr::str_replace_all(protected, "([A-Za-z]),(\\d)", "\\1@@@\\2")
      protected <- stringr::str_replace_all(protected, "(\\d+),(\\d+)", "\\1@@@\\2")
      if (identical(prev, protected)) break
    }

    # Protect IUPAC inverted names
    protected <- stringr::str_replace_all(protected, ",\\s+(\\d)", "%%%\\1")

    # Split and restore
    parts <- protected %>%
      stringr::str_split(";") %>%
      unlist() %>%
      stringr::str_split(",") %>%
      unlist() %>%
      stringr::str_trim() %>%
      stringr::str_replace_all("@@@", ",") %>%
      stringr::str_replace_all("%%%", ", ")

    parts[parts != "" & !is.na(parts)]
  }

  df_result <- df

  # Pre-allocate audit vectors
  audit_row_ids <- integer()
  audit_fields <- character()
  audit_originals <- character()
  audit_news <- character()
  audit_reasons <- character()

  for (col_name in name_cols) {
    col_values <- df_result[[col_name]]
    n_rows <- nrow(df_result)

    # Vectorized: quick check for potential splits (contains ; or ,)
    # This lets us skip the expensive split_one_name for most rows
    might_split <- !is.na(col_values) & stringr::str_detect(col_values, "[;,]")
    might_split[is.na(might_split)] <- FALSE

    # If nothing might split, just add synonym columns and continue
    if (!any(might_split)) {
      df_result$synonym_count <- rep(1L, n_rows)
      df_result$synonym_index <- rep(1L, n_rows)
      next
    }

    # Pre-compute splits only for rows that might split
    split_indices <- which(might_split)
    split_results <- lapply(col_values[split_indices], split_one_name)
    split_counts <- vapply(split_results, length, integer(1))

    # Identify which rows actually split (>1 part)
    actually_splits <- split_counts > 1
    expand_indices <- split_indices[actually_splits]
    expand_results <- split_results[actually_splits]
    expand_counts <- split_counts[actually_splits]

    # If nothing actually splits, just add synonym columns
    if (length(expand_indices) == 0) {
      df_result$synonym_count <- rep(1L, n_rows)
      df_result$synonym_index <- rep(1L, n_rows)
      next
    }

    # Build expanded dataframe efficiently
    # 1. Keep non-expanding rows as-is
    # 2. Expand only the rows that split

    non_expand_mask <- rep(TRUE, n_rows)
    non_expand_mask[expand_indices] <- FALSE

    # Non-expanding rows: keep with synonym metadata
    non_expand_df <- df_result[non_expand_mask, , drop = FALSE]
    if (nrow(non_expand_df) > 0) {
      non_expand_df$synonym_count <- 1L
      non_expand_df$synonym_index <- 1L
    }

    # Expanding rows: create multiple rows per original
    expand_dfs <- vector("list", length(expand_indices))

    for (i in seq_along(expand_indices)) {
      idx <- expand_indices[i]
      parts <- expand_results[[i]]
      synonym_count <- expand_counts[i]
      original_name <- col_values[idx]
      original_row_id <- df_result$original_row_id[idx]

      # Create expanded rows by replicating the original row
      expanded <- df_result[rep(idx, synonym_count), , drop = FALSE]
      expanded[[col_name]] <- parts
      expanded$synonym_count <- synonym_count
      expanded$synonym_index <- seq_len(synonym_count)

      # Set CAS columns to NA for synonym rows (index > 1)
      if (synonym_count > 1 && length(cas_cols) > 0) {
        for (cas_col in cas_cols) {
          if (cas_col %in% names(expanded)) {
            expanded[[cas_col]][2:synonym_count] <- NA_character_
          }
        }
      }

      expand_dfs[[i]] <- expanded

      # Collect audit entries for this expansion
      audit_row_ids <- c(audit_row_ids, as.integer(original_row_id))
      audit_fields <- c(audit_fields, col_name)
      audit_originals <- c(audit_originals, original_name)
      audit_news <- c(audit_news, paste0("Split into ", synonym_count, " synonyms: ", paste(parts, collapse = "; ")))
      audit_reasons <- c(audit_reasons, paste0("Split comma/semicolon-separated synonyms in ", col_name))

      # Audit entries for synonym rows (index > 1)
      if (synonym_count > 1) {
        for (syn_idx in 2:synonym_count) {
          audit_row_ids <- c(audit_row_ids, as.integer(original_row_id))
          audit_fields <- c(audit_fields, col_name)
          audit_originals <- c(audit_originals, original_name)
          audit_news <- c(audit_news, paste0("Synonym row ", syn_idx, ": ", parts[syn_idx]))
          audit_reasons <- c(audit_reasons, paste0("Synonym from row ", original_row_id))
        }
      }
    }

    # Combine: non-expanding rows + all expanded rows
    df_result <- dplyr::bind_rows(c(list(non_expand_df), expand_dfs))
  }

  # Build audit trail from vectors
  audit_trail <- if (length(audit_row_ids) == 0) {
    tibble::tibble(
      row_id = integer(),
      field = character(),
      step = character(),
      original_value = character(),
      new_value = character(),
      reason = character()
    )
  } else {
    tibble::tibble(
      row_id = audit_row_ids,
      field = audit_fields,
      step = rep("split_synonyms", length(audit_row_ids)),
      original_value = audit_originals,
      new_value = audit_news,
      reason = audit_reasons
    )
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
#' @export
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

  # Pre-allocate audit vectors
  audit_row_ids <- integer()
  audit_fields <- character()
  audit_originals <- character()
  audit_blocked_cols <- character()

  # Get row IDs (use original_row_id if available)
  row_ids <- if ("original_row_id" %in% names(df_result)) {
    df_result$original_row_id
  } else {
    seq_len(nrow(df_result))
  }

  # Pre-compile the full formula regex once
  full_formula_regex <- paste0("^", validator_regex, "$")

  # Process each name column (vectorized per column)
  for (col_name in name_cols) {
    # Create formula_blocked column if it doesn't exist
    blocked_col_name <- paste0("formula_blocked_", col_name)
    if (!blocked_col_name %in% names(df_result)) {
      df_result[[blocked_col_name]] <- NA_character_
    }

    col_values <- df[[col_name]]

    # Skip entirely NA columns
    if (all(is.na(col_values))) {
      next
    }

    # Vectorized cleaning: remove spaces and dots
    cleaned_for_test <- col_values %>%
      stringr::str_remove_all("\\s+") %>%
      stringr::str_remove_all("\\.")

    # Vectorized heuristic checks
    has_word_pattern <- stringr::str_detect(col_values, "[a-z]{2}")
    has_word_pattern[is.na(has_word_pattern)] <- FALSE

    is_all_uppercase_no_digits <- stringr::str_detect(col_values, "^[A-Z]+$")
    is_all_uppercase_no_digits[is.na(is_all_uppercase_no_digits)] <- FALSE

    # Vectorized formula detection (only on candidates that pass heuristics)
    candidates <- which(!is.na(col_values) & !has_word_pattern & !is_all_uppercase_no_digits)

    is_bare_formula <- rep(FALSE, length(col_values))
    if (length(candidates) > 0) {
      is_bare_formula[candidates] <- stringr::str_detect(
        cleaned_for_test[candidates],
        full_formula_regex
      )
      is_bare_formula[is.na(is_bare_formula)] <- FALSE
    }

    # Get indices of bare formulas
    bare_formula_idx <- which(is_bare_formula)

    if (length(bare_formula_idx) > 0) {
      # Vectorized assignment
      df_result$cleaning_flag[bare_formula_idx] <- "BLOCK: bare formula"
      df_result[[blocked_col_name]][bare_formula_idx] <- col_values[bare_formula_idx]
      df_result[[col_name]][bare_formula_idx] <- NA_character_

      # Collect audit entries
      audit_row_ids <- c(audit_row_ids, as.integer(row_ids[bare_formula_idx]))
      audit_fields <- c(audit_fields, rep(col_name, length(bare_formula_idx)))
      audit_originals <- c(audit_originals, col_values[bare_formula_idx])
      audit_blocked_cols <- c(audit_blocked_cols, rep(blocked_col_name, length(bare_formula_idx)))
    }
  }

  # Build single audit tibble from vectors
  audit_trail <- if (length(audit_row_ids) == 0) {
    tibble::tibble(
      row_id = integer(),
      field = character(),
      step = character(),
      original_value = character(),
      new_value = character(),
      reason = character()
    )
  } else {
    tibble::tibble(
      row_id = audit_row_ids,
      field = audit_fields,
      step = rep("detect_bare_formula", length(audit_row_ids)),
      original_value = audit_originals,
      new_value = rep("[NA]", length(audit_row_ids)),
      reason = paste0("Bare molecular formula detected in ", audit_fields, "; preserved in ", audit_blocked_cols)
    )
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
#' @export
flag_reference_matches <- function(df, name_cols, reference_list, flag_type, flag_label) {
  # Initialize result
  df_result <- df

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

  # Pre-compile all regex patterns ONCE (outside all loops) - fixes O(rows*terms) compilation

  ref_terms_lower <- tolower(active_refs$term)
  compiled_patterns <- lapply(active_refs$term, function(term) {
    escaped_term <- stringr::str_replace_all(term, "([/.])", "\\\\\\1")
    stringr::regex(paste0("\\b", escaped_term, "\\b"), ignore_case = TRUE)
  })

  # Pre-allocate audit trail vectors (avoids O(n^2) growing-list pattern)
  audit_row_ids <- integer()
  audit_fields <- character()
  audit_steps <- character()
  audit_originals <- character()
  audit_news <- character()
  audit_reasons <- character()

  # Track which rows already have a flag (for "first flag wins")
  already_flagged <- !is.na(df_result$cleaning_flag) & df_result$cleaning_flag != ""

  # Process each name column
  for (col_name in name_cols) {
    col_values <- df_result[[col_name]]
    col_values_lower <- tolower(col_values)

    # Get row IDs (use original_row_id if available)
    row_ids <- if ("original_row_id" %in% names(df_result)) {
      df_result$original_row_id
    } else {
      seq_len(nrow(df_result))
    }

    # === PASS 1: Exact match (vectorized via match()) ===
    exact_match_idx <- match(col_values_lower, ref_terms_lower)
    has_exact_match <- !is.na(exact_match_idx) & !already_flagged & !is.na(col_values)

    if (any(has_exact_match)) {
      matched_indices <- which(has_exact_match)
      ref_indices <- exact_match_idx[matched_indices]

      # Set flags (vectorized assignment)
      df_result$cleaning_flag[matched_indices] <- paste0(flag_prefix, ": ", flag_label, " [exact]")
      already_flagged[matched_indices] <- TRUE

      # Build audit entries (vectorized append)
      audit_row_ids <- c(audit_row_ids, as.integer(row_ids[matched_indices]))
      audit_fields <- c(audit_fields, rep(col_name, length(matched_indices)))
      audit_steps <- c(audit_steps, rep(paste0("flag_", flag_type), length(matched_indices)))
      audit_originals <- c(audit_originals, col_values[matched_indices])
      audit_news <- c(audit_news, df_result$cleaning_flag[matched_indices])
      audit_reasons <- c(
        audit_reasons,
        paste0(
          "Matched '",
          active_refs$term[ref_indices],
          "' (source: ",
          active_refs$source[ref_indices],
          ", match type: exact) in ",
          col_name
        )
      )
    }

    # === PASS 2: Substring match (loop over terms, vectorized str_detect per term) ===
    # Only check rows that aren't already flagged and have non-NA values
    candidates <- which(!already_flagged & !is.na(col_values))

    if (length(candidates) > 0) {
      for (ref_idx in seq_along(compiled_patterns)) {
        # Skip if no candidates left
        if (length(candidates) == 0) {
          break
        }

        # Vectorized str_detect over candidate rows (no per-row regex compilation)
        candidate_values <- col_values[candidates]
        matches <- stringr::str_detect(candidate_values, compiled_patterns[[ref_idx]])
        matches[is.na(matches)] <- FALSE

        if (any(matches)) {
          matched_positions <- candidates[matches]

          # Set flags
          df_result$cleaning_flag[matched_positions] <- paste0(flag_prefix, ": ", flag_label, " [substring]")
          already_flagged[matched_positions] <- TRUE

          # Build audit entries
          audit_row_ids <- c(audit_row_ids, as.integer(row_ids[matched_positions]))
          audit_fields <- c(audit_fields, rep(col_name, length(matched_positions)))
          audit_steps <- c(audit_steps, rep(paste0("flag_", flag_type), length(matched_positions)))
          audit_originals <- c(audit_originals, col_values[matched_positions])
          audit_news <- c(audit_news, df_result$cleaning_flag[matched_positions])
          audit_reasons <- c(
            audit_reasons,
            paste0(
              "Matched '",
              active_refs$term[ref_idx],
              "' (source: ",
              active_refs$source[ref_idx],
              ", match type: substring) in ",
              col_name
            )
          )

          # Remove matched rows from candidates (shrinks search space)
          candidates <- candidates[!matches]
        }
      }
    }
  }

  # Build audit trail from vectors (single tibble construction - O(1) vs O(n) bind_rows)
  audit_trail <- if (length(audit_row_ids) == 0) {
    tibble::tibble(
      row_id = integer(),
      field = character(),
      step = character(),
      original_value = character(),
      new_value = character(),
      reason = character()
    )
  } else {
    tibble::tibble(
      row_id = audit_row_ids,
      field = audit_fields,
      step = audit_steps,
      original_value = audit_originals,
      new_value = audit_news,
      reason = audit_reasons
    )
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
#' @export
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
#' @export
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
            all_non_ascii_chars[[codepoint]]$count <- all_non_ascii_chars[[codepoint]]$count +
              non_ascii_found[[codepoint]]$count
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
#' @param use_dedup Logical. When TRUE (default), uses dedup_step() wrappers
#'   and pre-check predicates for performance optimization. Set to FALSE for
#'   benchmark comparison against the non-dedup baseline path.
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
#' @export
run_cleaning_pipeline <- function(df, tag_map = NULL, reference_lists = NULL, use_dedup = TRUE) {
  # Step 0: Inject row lineage
  df_after_lineage <- inject_row_lineage(df)

  # Step 1: Unicode to ASCII (using ComptoxR for chemistry-specific mappings)
  df_after_unicode <- df_after_lineage %>%
    dplyr::mutate(dplyr::across(tidyselect::where(is.character), ComptoxR::clean_unicode))

  audit_unicode <- build_audit_trail(
    df_original = df_after_lineage,
    df_cleaned = df_after_unicode,
    step_name = "unicode_to_ascii",
    reason_fn = function(field) paste0("Convert unicode characters to ASCII equivalents in ", field)
  )

  # Step 2: Whitespace and punctuation artifact stripping
  df_after_trim <- df_after_unicode %>%
    dplyr::mutate(dplyr::across(tidyselect::where(is.character), clean_text_field))

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
      # Step 6-pre: Protect chiral designations (before enclosure stripping)
      chiral_result <- protect_chiral_designations(df_after_multi_cas, name_cols)
      df_after_chiral <- chiral_result$cleaned_data
      audit_combined <- dplyr::bind_rows(audit_combined, chiral_result$audit_trail)

      # Step 6a: Strip terminal enclosures
      enclosure_result <- strip_terminal_enclosures(df_after_chiral, name_cols)
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
        dplyr::mutate(dplyr::across(
          dplyr::all_of(name_cols),
          ~ {
            .x %>%
              stringr::str_squish() %>%
              stringr::str_remove("\\(\\s*\\)\\s*$") %>% # Remove empty parentheticals
              stringr::str_trim() %>%
              stringr::str_remove("[,;-]+$") %>% # Remove trailing punctuation
              stringr::str_trim()
          }
        ))

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
        dplyr::mutate(dplyr::across(
          dplyr::all_of(name_cols),
          ~ {
            .x %>%
              stringr::str_squish() %>%
              stringr::str_remove_all("\\(\\s*\\)") %>% # Remove empty parentheticals
              stringr::str_trim()
          }
        ))

      # Remove rows where all name columns are empty or NA
      name_check <- df_after_synonyms[, name_cols, drop = FALSE]
      all_empty <- apply(name_check, 1, function(row) {
        all(is.na(row) | row == "")
      })
      df_final <- df_after_synonyms[!all_empty, ]

      # Step 7: Expand isotope shortcodes (before bare formula detection)
      isotope_result <- expand_isotope_shortcodes(df_final, name_cols, reference_lists$isotope_lookup)
      df_final <- isotope_result$cleaned_data
      audit_combined <- dplyr::bind_rows(audit_combined, isotope_result$audit_trail)

      # Step 8: Flag multi-analyte expressions
      multi_result <- flag_multi_analyte(df_final, name_cols)
      df_final <- multi_result$cleaned_data
      audit_combined <- dplyr::bind_rows(audit_combined, multi_result$audit_trail)

      # Step 9: Restore chiral designation placeholders (must run before curation/lookup)
      chiral_restore_result <- restore_chiral_designations(df_final, name_cols)
      df_final <- chiral_restore_result$cleaned_data
      audit_combined <- dplyr::bind_rows(audit_combined, chiral_restore_result$audit_trail)
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

# ==============================================================================
# Phase 23: Isotope Cleaning — Three New Cleaning Functions
# ==============================================================================

#' Prefix for chiral designation placeholders
#'
#' Used by protect_chiral_designations() to replace chiral markers before
#' downstream enclosure stripping (Step 6a) removes them.
CHIRAL_PLACEHOLDER_PREFIX <- "###CHIRAL_"

#' Protect chiral designations from downstream stripping
#'
#' Replaces chiral markers — (+), (-), (R), (S), (R,S), (dl), etc. — with
#' numbered placeholders (###CHIRAL_n###) and sets a WARNING flag.
#' Must run BEFORE strip_terminal_enclosures() (Step 6a).
#'
#' @param df Dataframe with name columns
#' @param name_cols Character vector of Name-tagged column names
#' @return List with cleaned_data (tibble) and audit_trail (tibble)
#'
#' @examples
#' df <- tibble::tibble(chemical_name = c("(+)-catechin", "acetone"))
#' protect_chiral_designations(df, c("chemical_name"))
#' @export
protect_chiral_designations <- function(df, name_cols) {
  # Regex pattern for chiral markers in parentheses (per D-09)
  # Matches: (+), (-), (+-), (+/-), (R), (S), (R,S), (S,R), (d), (l), (dl), (D), (L), (DL)
  CHIRAL_REGEX <- "\\((\\+|-|\\+-|\\+/-|R,S|S,R|R|S|[dD][lL]|[dD]|[lL])\\)"

  df_result <- df

  # Add cleaning_flag column if missing
  if (!"cleaning_flag" %in% names(df_result)) {
    df_result$cleaning_flag <- NA_character_
  }

  # Pre-allocate audit vectors
  audit_row_ids <- integer()
  audit_fields <- character()
  audit_originals <- character()
  audit_news <- character()

  # Process each name column
  for (col_name in name_cols) {
    if (!col_name %in% names(df_result)) {
      next
    }

    col_values <- df_result[[col_name]]

    # Vectorized detection: find rows with chiral markers
    has_chiral <- grepl(CHIRAL_REGEX, col_values, perl = TRUE)
    has_chiral[is.na(has_chiral)] <- FALSE
    chiral_idx <- which(has_chiral)

    if (length(chiral_idx) == 0) {
      next
    }

    # Process only rows with chiral markers
    original_values <- col_values[chiral_idx]
    protected_values <- character(length(chiral_idx))

    for (i in seq_along(chiral_idx)) {
      original_value <- original_values[i]

      # Find chiral markers
      matches <- gregexpr(CHIRAL_REGEX, original_value, perl = TRUE)
      match_positions <- regmatches(original_value, matches)[[1]]

      # Replace each chiral marker with a content-encoded placeholder
      protected_value <- original_value
      for (marker in match_positions) {
        inner <- sub("^\\((.+)\\)$", "\\1", marker)
        token <- inner |>
          stringr::str_replace_all("\\+", "PLUS") |>
          stringr::str_replace_all("/", "SLASH") |>
          stringr::str_replace_all("-", "MINUS") |>
          stringr::str_replace_all(",", "_COMMA_")
        placeholder <- paste0(CHIRAL_PLACEHOLDER_PREFIX, token, "###")
        protected_value <- sub(CHIRAL_REGEX, placeholder, protected_value, perl = TRUE)
      }

      protected_values[i] <- protected_value
    }

    # Vectorized updates
    df_result[[col_name]][chiral_idx] <- protected_values

    # Vectorized flag update
    existing_flags <- df_result$cleaning_flag[chiral_idx]
    new_flag <- "WARNING: chiral designation"
    df_result$cleaning_flag[chiral_idx] <- ifelse(
      is.na(existing_flags),
      new_flag,
      paste0(existing_flags, "; ", new_flag)
    )

    # Collect audit entries
    audit_row_ids <- c(audit_row_ids, as.integer(chiral_idx))
    audit_fields <- c(audit_fields, rep(col_name, length(chiral_idx)))
    audit_originals <- c(audit_originals, original_values)
    audit_news <- c(audit_news, protected_values)
  }

  # Build audit trail from vectors
  audit_trail <- if (length(audit_row_ids) == 0) {
    tibble::tibble(
      row_id = integer(),
      field = character(),
      step = character(),
      original_value = character(),
      new_value = character(),
      reason = character()
    )
  } else {
    tibble::tibble(
      row_id = audit_row_ids,
      field = audit_fields,
      step = rep("protect_chiral_designations", length(audit_row_ids)),
      original_value = audit_originals,
      new_value = audit_news,
      reason = paste0("Chiral designation detected in ", audit_fields, "; protected with placeholder")
    )
  }

  list(
    cleaned_data = df_result,
    audit_trail = audit_trail
  )
}

#' Restore chiral designation placeholders to original markers
#'
#' Reverses protect_chiral_designations() by replacing ###CHIRAL_{TOKEN}### back
#' to the original chiral marker (e.g., ###CHIRAL_PLUS### -> (+)).
#' Must run AFTER all name cleaning steps and BEFORE ComptoxR lookup.
#'
#' @param df Dataframe with name columns that may contain chiral placeholders
#' @param name_cols Character vector of Name-tagged column names
#' @return List with cleaned_data (tibble) and audit_trail (tibble)
#' @export
restore_chiral_designations <- function(df, name_cols) {
  CHIRAL_RESTORE_REGEX <- "###CHIRAL_([A-Za-z_]+)###"

  decode_chiral_token <- function(token) {
    token |>
      stringr::str_replace_all("PLUS", "+") |>
      stringr::str_replace_all("SLASH", "/") |>
      stringr::str_replace_all("MINUS", "-") |>
      stringr::str_replace_all("_COMMA_", ",")
  }

  df_result <- df

  # Pre-allocate audit vectors
  audit_row_ids <- integer()
  audit_fields <- character()
  audit_originals <- character()
  audit_news <- character()

  for (col_name in name_cols) {
    if (!col_name %in% names(df_result)) {
      next
    }

    col_values <- df_result[[col_name]]

    # Vectorized detection: find rows with chiral placeholders
    has_placeholder <- grepl(CHIRAL_RESTORE_REGEX, col_values, perl = TRUE)
    has_placeholder[is.na(has_placeholder)] <- FALSE
    restore_idx <- which(has_placeholder)

    if (length(restore_idx) == 0) {
      next
    }

    # Process only rows with placeholders
    original_values <- col_values[restore_idx]
    restored_values <- character(length(restore_idx))

    for (i in seq_along(restore_idx)) {
      original_value <- original_values[i]
      restored_value <- original_value
      placeholders <- regmatches(restored_value, gregexpr(CHIRAL_RESTORE_REGEX, restored_value, perl = TRUE))[[1]]

      for (ph in placeholders) {
        token <- sub("^###CHIRAL_(.+)###$", "\\1", ph)
        original_marker <- paste0("(", decode_chiral_token(token), ")")
        restored_value <- sub(ph, original_marker, restored_value, fixed = TRUE)
      }

      restored_values[i] <- restored_value
    }

    # Vectorized update
    df_result[[col_name]][restore_idx] <- restored_values

    # Collect audit entries
    audit_row_ids <- c(audit_row_ids, as.integer(restore_idx))
    audit_fields <- c(audit_fields, rep(col_name, length(restore_idx)))
    audit_originals <- c(audit_originals, original_values)
    audit_news <- c(audit_news, restored_values)
  }

  # Build audit trail from vectors
  audit_trail <- if (length(audit_row_ids) == 0) {
    tibble::tibble(
      row_id = integer(),
      field = character(),
      step = character(),
      original_value = character(),
      new_value = character(),
      reason = character()
    )
  } else {
    tibble::tibble(
      row_id = audit_row_ids,
      field = audit_fields,
      step = rep("restore_chiral_designations", length(audit_row_ids)),
      original_value = audit_originals,
      new_value = audit_news,
      reason = rep("Restored chiral designation placeholder(s) after cleaning", length(audit_row_ids))
    )
  }

  list(
    cleaned_data = df_result,
    audit_trail = audit_trail
  )
}

#' Expand isotope shortcodes to canonical Name-Mass format (vectorized)
#'
#' Two-pass approach applied column-at-a-time:
#' 1. Naked shortcode expansion: u234 -> Uranium-234 (using cached isotope lookup)
#' 2. Spelled-out normalization: radium 226 -> Radium-226
#' Plus special case: unat -> WARNING flag (unresolvable natural uranium mixture)
#'
#' Exclusions per ISOT-03:
#' - Carbon backbone patterns (C12H22O11) — NOT expanded
#' - Deuterium d-prefix patterns (d-glucose) — NOT expanded
#' - Isotope prefixes in compound names (14C-glucose) — NOT expanded
#'
#' @param df Dataframe with name columns
#' @param name_cols Character vector of Name-tagged column names
#' @param isotope_lookup Optional pre-built lookup from load_isotope_lookup().
#'   If NULL, falls back to building from ComptoxR::pt$isotope directly.
#' @return List with cleaned_data (tibble) and audit_trail (tibble)
#'
#' @examples
#' df <- tibble::tibble(chemical_name = c("u234", "radium 226", "C12H22O11"))
#' expand_isotope_shortcodes(df, c("chemical_name"))
#' @export
expand_isotope_shortcodes <- function(df, name_cols, isotope_lookup = NULL) {
  empty_audit <- tibble::tibble(
    row_id = integer(),
    field = character(),
    step = character(),
    original_value = character(),
    new_value = character(),
    reason = character()
  )

  if (nrow(df) == 0) {
    return(list(cleaned_data = df, audit_trail = empty_audit))
  }

  # Resolve lookup: use cached, or build from ComptoxR, or bail

  if (!is.null(isotope_lookup)) {
    lookup <- isotope_lookup$lookup
    ELEMENT_ALT_NAMES <- isotope_lookup$elem_alt_names
  } else if (requireNamespace("ComptoxR", quietly = TRUE)) {
    isotopes <- ComptoxR::pt$isotope
    lookup <- tibble::tibble(
      symbol = isotopes$element,
      mass = isotopes$Z,
      element_name = isotopes$Name,
      shortcode = tolower(paste0(isotopes$element, isotopes$Z)),
      canonical = paste0(isotopes$Name, "-", isotopes$Z),
      dtxsid = if ("DTXSID" %in% names(isotopes)) isotopes$DTXSID else NA_character_
    )
    lookup <- lookup[!duplicated(lookup$shortcode), ]
    lookup <- lookup[order(-nchar(lookup$symbol)), ]
    ELEMENT_ALT_NAMES <- c("cesium" = "Caesium", "aluminum" = "Aluminium", "sulfur" = "Sulphur")
  } else {
    warning("ComptoxR not available - skipping isotope shortcode expansion")
    return(list(cleaned_data = df, audit_trail = empty_audit))
  }

  df_result <- df
  audit_rows <- list()

  if (!"cleaning_flag" %in% names(df_result)) {
    df_result$cleaning_flag <- NA_character_
  }

  for (col_name in name_cols) {
    if (!col_name %in% names(df_result)) {
      next
    }

    vals <- df_result[[col_name]]
    original_vals <- vals

    # ---- Vectorized exclusion masks ----
    is_na <- is.na(vals)
    is_unat <- !is_na & grepl("^unat$", vals, ignore.case = TRUE)
    is_d_prefix <- !is_na & !is_unat & grepl("^[dD]-[a-z]", vals)
    is_compound_prefix <- !is_na & !is_unat & !is_d_prefix & grepl("^\\d+[A-Z][a-z]?-", vals)

    # Rows eligible for expansion
    eligible <- !is_na & !is_unat & !is_d_prefix & !is_compound_prefix

    # ---- Special case: unat -> WARNING flag ----
    if (any(is_unat)) {
      unat_idx <- which(is_unat)
      existing <- df_result$cleaning_flag[unat_idx]
      new_flag <- "WARNING: unresolvable isotope (unat)"
      df_result$cleaning_flag[unat_idx] <- ifelse(
        is.na(existing),
        new_flag,
        paste0(existing, "; ", new_flag)
      )
    }

    if (!any(eligible)) {
      next
    }

    # Work only on eligible values
    work_vals <- vals[eligible]

    # ---- Codex optimization: Prefilter lookup to symbols actually present ----
    # Instead of O(rows × lookup_size), filter lookup first then O(rows × matches)
    collapsed_text <- paste(tolower(work_vals), collapse = " ")

    # Pass 1 filter: keep only isotopes whose symbol appears in the text
    symbols_present <- vapply(
      lookup$symbol,
      function(sym) {
        grepl(tolower(sym), collapsed_text, fixed = TRUE)
      },
      logical(1)
    )
    filtered_lookup <- lookup[symbols_present, , drop = FALSE]

    # ---- Pass 1: Naked shortcode expansion (filtered subset only) ----
    if (nrow(filtered_lookup) > 0) {
      for (i in seq_len(nrow(filtered_lookup))) {
        sym <- filtered_lookup$symbol[i]
        mass_num <- filtered_lookup$mass[i]
        canonical <- filtered_lookup$canonical[i]

        pattern <- paste0(
          "(?<![0-9])\\b(?i:",
          stringr::str_escape(sym),
          ")(",
          stringr::str_escape(mass_num),
          ")\\b(?![A-Z])"
        )
        work_vals <- gsub(pattern, canonical, work_vals, perl = TRUE)
      }
    }

    # ---- Pass 2: Spelled-out normalization (prefiltered) ----
    # Deduplicate to unique (element_name, mass, canonical) combos
    spelled_lookup <- unique(lookup[, c("element_name", "mass", "canonical")])

    # Filter to element names actually present in text
    elem_names_present <- vapply(
      spelled_lookup$element_name,
      function(nm) {
        grepl(tolower(nm), collapsed_text, fixed = TRUE)
      },
      logical(1)
    )

    # Also check alt names
    alt_names_present <- vapply(
      spelled_lookup$element_name,
      function(nm) {
        alts <- names(ELEMENT_ALT_NAMES)[ELEMENT_ALT_NAMES == nm]
        any(vapply(alts, function(a) grepl(tolower(a), collapsed_text, fixed = TRUE), logical(1)))
      },
      logical(1)
    )

    filtered_spelled <- spelled_lookup[elem_names_present | alt_names_present, , drop = FALSE]

    if (nrow(filtered_spelled) > 0) {
      for (i in seq_len(nrow(filtered_spelled))) {
        elem_name <- filtered_spelled$element_name[i]
        mass_num <- filtered_spelled$mass[i]
        canonical <- filtered_spelled$canonical[i]

        names_to_match <- elem_name
        alt_matches <- names(ELEMENT_ALT_NAMES)[ELEMENT_ALT_NAMES == elem_name]
        if (length(alt_matches) > 0) {
          names_to_match <- c(names_to_match, alt_matches)
        }

        for (match_name in names_to_match) {
          spelled_pattern <- paste0(
            "(?i)\\b",
            stringr::str_escape(match_name),
            "(?:\\s+|-)",
            stringr::str_escape(mass_num),
            "\\b"
          )
          work_vals <- gsub(spelled_pattern, canonical, work_vals, perl = TRUE)
        }
      }
    }

    # ---- Write back and build audit trail ----
    vals[eligible] <- work_vals
    df_result[[col_name]] <- vals

    changed_mask <- eligible & (vals != original_vals)
    if (any(changed_mask)) {
      changed_idx <- which(changed_mask)
      # Determine reason per row (shortcode vs normalization)
      reasons <- ifelse(
        original_vals[changed_idx] != vals[changed_idx] &
          grepl("[a-z]\\d", original_vals[changed_idx], ignore.case = TRUE),
        paste0("Isotope shortcode expanded in ", col_name),
        paste0("Isotope form normalized in ", col_name)
      )

      # Use original_row_id if available (post-synonym-split dataframes have expanded rows)
      rids <- if ("original_row_id" %in% names(df_result)) df_result$original_row_id[changed_idx] else changed_idx
      audit_rows[[length(audit_rows) + 1]] <- tibble::tibble(
        row_id = as.integer(rids),
        field = col_name,
        step = "expand_isotope_shortcodes",
        original_value = original_vals[changed_idx],
        new_value = vals[changed_idx],
        reason = reasons
      )
    }
  }

  audit_trail <- if (length(audit_rows) == 0) empty_audit else dplyr::bind_rows(audit_rows)

  # ---- Flag isotope-matched rows and populate isotope_dtxsid ----
  if (nrow(audit_trail) > 0) {
    # Rows that were changed by isotope expansion (any column)
    changed_rows <- unique(audit_trail$row_id)

    # Build canonical->dtxsid map from the lookup (only entries with non-NA DTXSID)
    if ("dtxsid" %in% names(lookup)) {
      dtxsid_map <- stats::setNames(lookup$dtxsid, lookup$canonical)
      dtxsid_map <- dtxsid_map[!is.na(dtxsid_map)]
    } else {
      dtxsid_map <- character(0)
    }

    # Initialize isotope_dtxsid column if needed
    if (!"isotope_dtxsid" %in% names(df_result)) {
      df_result$isotope_dtxsid <- NA_character_
    }

    for (ridx in changed_rows) {
      # Set cleaning_flag
      existing_flag <- df_result$cleaning_flag[ridx]
      df_result$cleaning_flag[ridx] <- if (is.na(existing_flag)) {
        "isotope_match"
      } else {
        paste0(existing_flag, "; isotope_match")
      }

      # Try to resolve DTXSID from expanded canonical name
      if (length(dtxsid_map) > 0) {
        for (col_name in name_cols) {
          if (!col_name %in% names(df_result)) {
            next
          }
          val <- df_result[[col_name]][ridx]
          if (!is.na(val) && val %in% names(dtxsid_map)) {
            df_result$isotope_dtxsid[ridx] <- dtxsid_map[[val]]
            break
          }
        }
      }
    }
  }

  list(cleaned_data = df_result, audit_trail = audit_trail)
}

#' Flag rows containing naked multi-analyte expressions
#'
#' Flags rows where name columns contain naked " + " or " and " between tokens
#' as "WARNING: potential multi-analyte". Does NOT modify cell values (flag only per D-11).
#'
#' A naked " + " means a plus sign surrounded by whitespace and NOT inside parentheses.
#' "(+)-catechin" is NOT flagged — the + is inside parentheses.
#'
#' @param df Dataframe with name columns
#' @param name_cols Character vector of Name-tagged column names
#' @return List with cleaned_data (tibble) and audit_trail (tibble)
#'
#' @examples
#' df <- tibble::tibble(chemical_name = c("nitrate + nitrite", "(+)-catechin", "acetone"))
#' flag_multi_analyte(df, c("chemical_name"))
#' @export
flag_multi_analyte <- function(df, name_cols) {
  df_result <- df

  # Add cleaning_flag column if missing
  if (!"cleaning_flag" %in% names(df_result)) {
    df_result$cleaning_flag <- NA_character_
  }

  # Pattern for naked " + ": whitespace + plus + whitespace
  # NOT inside parentheses — we check this by requiring the + is not immediately
  # preceded by "(" or followed by ")"
  NAKED_PLUS_PATTERN <- "(?<!\\()\\s\\+\\s(?!\\))"

  # Pattern for naked " and ": word boundary " and " word boundary (case-insensitive)
  NAKED_AND_PATTERN <- "(?i)\\s+and\\s+"

  # Pre-allocate audit vectors
  audit_row_ids <- integer()
  audit_fields <- character()
  audit_originals <- character()

  # Get row IDs (use original_row_id if available)
  row_ids <- if ("original_row_id" %in% names(df_result)) {
    df_result$original_row_id
  } else {
    seq_len(nrow(df_result))
  }

  for (col_name in name_cols) {
    if (!col_name %in% names(df_result)) {
      next
    }

    col_values <- df_result[[col_name]]

    # Vectorized pattern detection
    has_naked_plus <- grepl(NAKED_PLUS_PATTERN, col_values, perl = TRUE)
    has_naked_plus[is.na(has_naked_plus)] <- FALSE

    has_naked_and <- grepl(NAKED_AND_PATTERN, col_values, perl = TRUE)
    has_naked_and[is.na(has_naked_and)] <- FALSE

    # Find rows to flag (non-NA values that match either pattern)
    to_flag <- which(!is.na(col_values) & (has_naked_plus | has_naked_and))

    if (length(to_flag) > 0) {
      # Vectorized flag update
      new_flag <- "WARNING: potential multi-analyte"
      existing_flags <- df_result$cleaning_flag[to_flag]

      df_result$cleaning_flag[to_flag] <- ifelse(
        is.na(existing_flags),
        new_flag,
        paste0(existing_flags, "; ", new_flag)
      )

      # Collect audit entries
      audit_row_ids <- c(audit_row_ids, as.integer(row_ids[to_flag]))
      audit_fields <- c(audit_fields, rep(col_name, length(to_flag)))
      audit_originals <- c(audit_originals, col_values[to_flag])
    }
  }

  # Build audit trail from vectors
  audit_trail <- if (length(audit_row_ids) == 0) {
    tibble::tibble(
      row_id = integer(),
      field = character(),
      step = character(),
      original_value = character(),
      new_value = character(),
      reason = character()
    )
  } else {
    tibble::tibble(
      row_id = audit_row_ids,
      field = audit_fields,
      step = rep("flag_multi_analyte", length(audit_row_ids)),
      original_value = audit_originals,
      new_value = audit_originals,
      reason = paste0("Potential multi-analyte expression detected in ", audit_fields)
    )
  }

  list(
    cleaned_data = df_result,
    audit_trail = audit_trail
  )
}
