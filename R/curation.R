# Curation Pipeline: Deduplication + Tiered CompTox Search + Consensus Classification
#
# Self-contained module migrated from R/prototype_pipeline.R.
# R/prototype_pipeline.R is kept as historical reference only — not sourced at runtime.
# This file depends on R/consensus.R being sourced first (for classify_consensus, find_dtxsid_cols, init_resolution_state).

# ============================================================================
# deduplicate_tagged_columns
# ============================================================================

#' Deduplicate tagged column values before API calls
#'
#' @param df Data frame with chemical data
#' @param tag_map Named list mapping column names to tag types ("Name", "CASRN", or "Other")
#' @return List with unique_names, unique_cas, and dedup_key_map
deduplicate_tagged_columns <- function(df, tag_map) {
  name_cols <- names(tag_map)[tag_map == "Name"]
  cas_cols <- names(tag_map)[tag_map == "CASRN"]
  other_cols <- names(tag_map)[tag_map == "Other"]

  # Build dedup key map: one row per original row+column combination
  key_rows <- list()

  for (col_name in names(tag_map)) {
    tag_type <- tag_map[[col_name]]
    values <- df[[col_name]]

    for (i in seq_along(values)) {
      key_rows[[length(key_rows) + 1]] <- tibble::tibble(
        row_idx = i,
        column_name = col_name,
        tag_type = tag_type,
        dedup_key = as.character(values[i])
      )
    }
  }

  dedup_key_map <- dplyr::bind_rows(key_rows)

  # Extract unique non-NA values by type
  unique_names <- character(0)
  unique_cas <- character(0)

  searchable_cols <- c(name_cols, other_cols)
  if (length(searchable_cols) > 0) {
    all_names <- unlist(lapply(searchable_cols, function(col) df[[col]]))
    unique_names <- unique(all_names[!is.na(all_names) & all_names != ""])
  }

  if (length(cas_cols) > 0) {
    all_cas <- unlist(lapply(cas_cols, function(col) df[[col]]))
    unique_cas <- unique(all_cas[!is.na(all_cas) & all_cas != ""])
  }

  list(
    unique_names = unique_names,
    unique_cas = unique_cas,
    dedup_key_map = dedup_key_map
  )
}

# ============================================================================
# search_exact
# ============================================================================

#' Exact match search via CompToxR bulk API
#'
#' @param unique_names Character vector of unique chemical names
#' @return Tibble with searchValue, dtxsid, preferredName, searchName, rank
search_exact <- function(unique_names) {
  empty_result <- tibble::tibble(
    searchValue = character(0),
    dtxsid = character(0),
    preferredName = character(0),
    searchName = character(0),
    rank = integer(0)
  )

  if (length(unique_names) == 0) {
    return(empty_result)
  }

  message(sprintf("Exact search: %d unique names...", length(unique_names)))

  raw <- ComptoxR::ct_chemical_search_equal_bulk(unique_names)

  if (is.null(raw) || nrow(raw) == 0) {
    return(empty_result)
  }

  # Standardize column names — ComptoxR may use different casing
  col_map <- list(
    searchValue = grep("^search.?value$", names(raw), ignore.case = TRUE, value = TRUE),
    dtxsid = grep("^dtxsid$", names(raw), ignore.case = TRUE, value = TRUE),
    preferredName = grep("^preferred.?name$", names(raw), ignore.case = TRUE, value = TRUE),
    searchName = grep("^search.?name$", names(raw), ignore.case = TRUE, value = TRUE),
    rank = grep("^rank$", names(raw), ignore.case = TRUE, value = TRUE)
  )

  result <- tibble::tibble(
    searchValue = if (length(col_map$searchValue) > 0) raw[[col_map$searchValue[1]]] else NA_character_,
    dtxsid = if (length(col_map$dtxsid) > 0) raw[[col_map$dtxsid[1]]] else NA_character_,
    preferredName = if (length(col_map$preferredName) > 0) raw[[col_map$preferredName[1]]] else NA_character_,
    searchName = if (length(col_map$searchName) > 0) raw[[col_map$searchName[1]]] else NA_character_,
    rank = if (length(col_map$rank) > 0) as.integer(raw[[col_map$rank[1]]]) else NA_integer_
  )

  # #NOTE: Takes lowest rank (top result) per searchValue — tweakable
  result <- result |>
    dplyr::group_by(searchValue) |>
    dplyr::slice_min(rank, n = 1, with_ties = FALSE) |>
    dplyr::ungroup()

  result
}

# ============================================================================
# search_starts_with
# ============================================================================

#' Starts-with fallback search for names that failed exact match
#'
#' @param missed_names Character vector of names that failed exact match
#' @return Tibble with same columns as search_exact, may have multiple rows per input
search_starts_with <- function(missed_names) {
  empty_result <- tibble::tibble(
    searchValue = character(0),
    dtxsid = character(0),
    preferredName = character(0),
    searchName = character(0),
    rank = integer(0)
  )

  if (length(missed_names) == 0) {
    return(empty_result)
  }

  message(sprintf("Falling back on %d misses with starts-with search...", length(missed_names)))

  results_list <- list()
  for (name in missed_names) {
    tryCatch(
      {
        raw <- ComptoxR::ct_chemical_search_start_with(name)
        if (!is.null(raw) && nrow(raw) > 0) {
          # Standardize columns
          col_map <- list(
            dtxsid = grep("^dtxsid$", names(raw), ignore.case = TRUE, value = TRUE),
            preferredName = grep("^preferred.?name$", names(raw), ignore.case = TRUE, value = TRUE),
            searchName = grep("^search.?name$", names(raw), ignore.case = TRUE, value = TRUE),
            rank = grep("^rank$", names(raw), ignore.case = TRUE, value = TRUE)
          )

          result_chunk <- tibble::tibble(
            searchValue = name,
            dtxsid = if (length(col_map$dtxsid) > 0) raw[[col_map$dtxsid[1]]] else NA_character_,
            preferredName = if (length(col_map$preferredName) > 0) raw[[col_map$preferredName[1]]] else NA_character_,
            searchName = if (length(col_map$searchName) > 0) raw[[col_map$searchName[1]]] else NA_character_,
            rank = if (length(col_map$rank) > 0) as.integer(raw[[col_map$rank[1]]]) else NA_integer_
          )
          results_list[[length(results_list) + 1]] <- result_chunk
        }
      },
      error = function(e) {
        message(sprintf("  Warning: starts-with failed for '%s': %s", name, e$message))
      }
    )
  }

  if (length(results_list) == 0) {
    return(empty_result)
  }

  dplyr::bind_rows(results_list)
}

# ============================================================================
# validate_and_lookup_cas
# ============================================================================

#' Validate CAS numbers and lookup DTXSID for valid ones
#'
#' @param unique_cas Character vector of CAS-like strings
#' @return Tibble with original_cas, validated_cas, is_valid, dtxsid, preferredName
validate_and_lookup_cas <- function(unique_cas) {
  empty_result <- tibble::tibble(
    original_cas = character(0),
    validated_cas = character(0),
    is_valid = logical(0),
    dtxsid = character(0),
    preferredName = character(0),
    rank = integer(0)
  )

  if (length(unique_cas) == 0) {
    return(empty_result)
  }

  message(sprintf("Validating %d unique CAS numbers...", length(unique_cas)))

  # Normalize with ComptoxR::as_cas
  validated <- ComptoxR::as_cas(unique_cas)
  valid_flags <- ComptoxR::is_cas(validated)

  # Handle NA input: as_cas(NA) returns NA, is_cas(NA) should return NA
  # For our purposes, NA input means not valid
  valid_flags[is.na(unique_cas)] <- NA

  result <- tibble::tibble(
    original_cas = unique_cas,
    validated_cas = validated,
    is_valid = valid_flags,
    dtxsid = NA_character_,
    preferredName = NA_character_,
    rank = NA_integer_
  )

  # Lookup DTXSID for valid CAS numbers
  valid_cas_values <- result$validated_cas[!is.na(result$validated_cas) & result$is_valid == TRUE]

  if (length(valid_cas_values) > 0) {
    tryCatch(
      {
        message(sprintf("Looking up DTXSID for %d valid CAS numbers...", length(valid_cas_values)))
        cas_lookup <- ComptoxR::ct_chemical_search_equal_bulk(valid_cas_values)

        if (!is.null(cas_lookup) && nrow(cas_lookup) > 0) {
          # Extract relevant columns
          sv_col <- grep("^search.?value$", names(cas_lookup), ignore.case = TRUE, value = TRUE)
          dtx_col <- grep("^dtxsid$", names(cas_lookup), ignore.case = TRUE, value = TRUE)
          pn_col <- grep("^preferred.?name$", names(cas_lookup), ignore.case = TRUE, value = TRUE)

          if (length(sv_col) > 0 && length(dtx_col) > 0) {
            rk_col <- grep("^rank$", names(cas_lookup), ignore.case = TRUE, value = TRUE)

            lookup_map <- tibble::tibble(
              validated_cas = cas_lookup[[sv_col[1]]],
              looked_up_dtxsid = cas_lookup[[dtx_col[1]]],
              looked_up_name = if (length(pn_col) > 0) cas_lookup[[pn_col[1]]] else NA_character_,
              looked_up_rank = if (length(rk_col) > 0) as.integer(cas_lookup[[rk_col[1]]]) else NA_integer_
            )

            # Keep lowest rank (top result) per CAS
            lookup_map <- lookup_map |>
              dplyr::arrange(looked_up_rank) |>
              dplyr::distinct(validated_cas, .keep_all = TRUE)

            result <- result |>
              dplyr::left_join(lookup_map, by = "validated_cas") |>
              dplyr::mutate(
                dtxsid = dplyr::coalesce(looked_up_dtxsid, dtxsid),
                preferredName = dplyr::coalesce(looked_up_name, preferredName),
                rank = looked_up_rank
              ) |>
              dplyr::select(-looked_up_dtxsid, -looked_up_name, -looked_up_rank)
          }
        }
      },
      error = function(e) {
        message(sprintf("  Warning: CAS DTXSID lookup failed: %s", e$message))
      }
    )
  }

  result
}

# ============================================================================
# run_tiered_search
# ============================================================================

#' Run tiered search: exact → CAS → starts-with (3-char min)
#'
#' @param dedup_result Output of deduplicate_tagged_columns
#' @return Tibble of all lookup results with source_tier column
run_tiered_search <- function(dedup_result) {
  all_results <- list()

  # Tier 1: Exact match on names
  if (length(dedup_result$unique_names) > 0) {
    exact_results <- search_exact(dedup_result$unique_names)

    if (nrow(exact_results) > 0) {
      exact_results$source_tier <- "exact"
      all_results[[length(all_results) + 1]] <- exact_results
    }

    # Identify misses
    matched_names <- exact_results$searchValue[!is.na(exact_results$dtxsid)]
    missed_names <- setdiff(dedup_result$unique_names, matched_names)

    # Tier 2: CAS validation on exact misses
    if (length(missed_names) > 0) {
      cas_from_names <- validate_and_lookup_cas(missed_names)

      if (nrow(cas_from_names) > 0) {
        cas_name_common <- tibble::tibble(
          searchValue = cas_from_names$original_cas,
          dtxsid = cas_from_names$dtxsid,
          preferredName = cas_from_names$preferredName,
          searchName = dplyr::if_else(!is.na(cas_from_names$dtxsid), "CAS-RN", NA_character_),
          rank = cas_from_names$rank,
          source_tier = dplyr::case_when(
            !is.na(cas_from_names$dtxsid) ~ "cas",
            cas_from_names$is_valid == TRUE ~ "cas_no_match",
            TRUE ~ "cas_invalid"
          )
        )
        all_results[[length(all_results) + 1]] <- cas_name_common
      }

      cas_matched <- cas_from_names$original_cas[!is.na(cas_from_names$dtxsid)]
      still_missed <- setdiff(missed_names, cas_matched)

      # Tier 3: Starts-with on remaining misses (3-char minimum)
      if (length(still_missed) > 0) {
        sw_candidates <- still_missed[nchar(still_missed) >= 3]

        if (length(sw_candidates) > 0) {
          sw_results <- search_starts_with(sw_candidates)
          if (nrow(sw_results) > 0) {
            sw_results$source_tier <- "starts_with"
            all_results[[length(all_results) + 1]] <- sw_results
          }

          # Find remaining misses after starts-with
          sw_matched <- sw_results$searchValue[!is.na(sw_results$dtxsid)]
          final_missed <- setdiff(still_missed, sw_matched)
        } else {
          final_missed <- still_missed
        }

        # Add all-tier misses for names
        if (length(final_missed) > 0) {
          miss_rows <- tibble::tibble(
            searchValue = final_missed,
            dtxsid = NA_character_,
            preferredName = NA_character_,
            searchName = NA_character_,
            rank = NA_integer_,
            source_tier = "miss"
          )
          all_results[[length(all_results) + 1]] <- miss_rows
        }
      }
    }
  }

  # Tier 4: CAS validation for CASRN-tagged columns (separate path)
  if (length(dedup_result$unique_cas) > 0) {
    cas_results <- validate_and_lookup_cas(dedup_result$unique_cas)

    if (nrow(cas_results) > 0) {
      # Convert CAS results to common format
      cas_common <- tibble::tibble(
        searchValue = cas_results$original_cas,
        dtxsid = cas_results$dtxsid,
        preferredName = cas_results$preferredName,
        searchName = dplyr::if_else(!is.na(cas_results$dtxsid), "CAS-RN", NA_character_),
        rank = cas_results$rank,
        source_tier = dplyr::case_when(
          !is.na(cas_results$dtxsid) ~ "cas",
          cas_results$is_valid == TRUE ~ "cas_no_match",
          TRUE ~ "cas_invalid"
        )
      )
      all_results[[length(all_results) + 1]] <- cas_common
    }
  }

  if (length(all_results) == 0) {
    return(tibble::tibble(
      searchValue = character(0),
      dtxsid = character(0),
      preferredName = character(0),
      searchName = character(0),
      rank = integer(0),
      source_tier = character(0)
    ))
  }

  combined <- dplyr::bind_rows(all_results)

  # Summary message
  n_exact <- sum(combined$source_tier == "exact", na.rm = TRUE)
  n_sw <- sum(combined$source_tier == "starts_with", na.rm = TRUE)
  n_cas <- sum(combined$source_tier == "cas", na.rm = TRUE)
  n_miss <- sum(combined$source_tier == "miss", na.rm = TRUE)
  message(sprintf(
    "Results: %d exact, %d starts-with, %d CAS, %d misses",
    n_exact, n_sw, n_cas, n_miss
  ))

  combined
}

# ============================================================================
# map_results_to_rows
# ============================================================================

#' Map lookup results back to all original rows
#'
#' @param df Original data frame
#' @param dedup_key_map Dedup key map from deduplicate_tagged_columns
#' @param lookup_results Lookup results from run_tiered_search
#' @return Original df with lookup columns joined back
map_results_to_rows <- function(df, dedup_key_map, lookup_results) {
  # Add row index to original df if not present
  df$.row_idx <- seq_len(nrow(df))

  # Join dedup_key_map to lookup_results on dedup_key = searchValue
  enriched_keys <- dedup_key_map |>
    dplyr::left_join(
      lookup_results,
      by = c("dedup_key" = "searchValue"),
      relationship = "many-to-many"
    )

  # For each tagged column, create a set of lookup columns
  tag_cols <- unique(enriched_keys$column_name)

  for (col in tag_cols) {
    col_data <- enriched_keys |>
      dplyr::filter(column_name == col) |>
      dplyr::select(row_idx, dtxsid, preferredName, searchName, rank, source_tier)

    # If only one tagged column, use simple names; otherwise suffix
    if (length(tag_cols) == 1) {
      names(col_data)[names(col_data) != "row_idx"] <- c(
        "dtxsid", "preferredName", "searchName", "rank", "source_tier"
      )
    } else {
      suffix <- paste0("_", col)
      names(col_data)[names(col_data) != "row_idx"] <- paste0(
        c("dtxsid", "preferredName", "searchName", "rank", "source_tier"),
        suffix
      )
    }

    df <- df |>
      dplyr::left_join(col_data, by = c(".row_idx" = "row_idx"))
  }

  df$.row_idx <- NULL
  df
}

# ============================================================================
# run_curation_pipeline
# ============================================================================

#' Orchestrate the full curation pipeline: dedup → search → map → consensus → resolution
#'
#' @param clean_data The cleaned data frame (data_store$clean)
#' @param column_tags Named list (col_name -> "Name"|"CASRN"|"Other")
#' @param progress_callback Optional function(stage, message) for reporting progress to Shiny
#' @param dedup_only If TRUE, return after dedup stage with just counts (for preview)
#' @return List with results, dedup_summary, search_summary, consensus_summary
run_curation_pipeline <- function(clean_data, column_tags, progress_callback = NULL, dedup_only = FALSE) {
  # Stage 1: Deduplication
  dedup_result <- deduplicate_tagged_columns(clean_data, column_tags)

  n_other <- sum(tag_map == "Other")
  dedup_msg <- sprintf(
    "Deduplicated: %d unique names (including %d Other columns), %d unique CAS",
    length(dedup_result$unique_names),
    n_other,
    length(dedup_result$unique_cas)
  )

  if (!is.null(progress_callback)) {
    progress_callback("dedup", dedup_msg)
  }

  # Return early if dedup_only
  if (dedup_only) {
    return(list(
      dedup_summary = list(
        n_names = length(dedup_result$unique_names),
        n_cas = length(dedup_result$unique_cas)
      )
    ))
  }

  # Stage 2: Tiered search (inline orchestration for progress callbacks)
  all_results <- list()
  n_exact <- 0
  n_starts_with <- 0
  n_cas_from_names <- 0
  n_cas_from_columns <- 0
  n_miss <- 0

  # Tier 1: Exact match on names
  if (length(dedup_result$unique_names) > 0) {
    exact_results <- search_exact(dedup_result$unique_names)

    if (nrow(exact_results) > 0) {
      exact_results$source_tier <- "exact"
      all_results[[length(all_results) + 1]] <- exact_results
      n_exact <- sum(!is.na(exact_results$dtxsid))
    }

    matched_names <- exact_results$searchValue[!is.na(exact_results$dtxsid)]
    missed_names <- setdiff(dedup_result$unique_names, matched_names)

    if (!is.null(progress_callback)) {
      progress_callback(
        "exact",
        sprintf("Exact match: %d/%d found, %d falling back...", n_exact, length(dedup_result$unique_names), length(missed_names))
      )
    }

    # Tier 2: CAS validation on exact misses (NEW POSITION)
    if (length(missed_names) > 0) {
      cas_from_names <- validate_and_lookup_cas(missed_names)

      if (nrow(cas_from_names) > 0) {
        n_cas_from_names <- sum(!is.na(cas_from_names$dtxsid))

        cas_name_common <- tibble::tibble(
          searchValue = cas_from_names$original_cas,
          dtxsid = cas_from_names$dtxsid,
          preferredName = cas_from_names$preferredName,
          searchName = dplyr::if_else(!is.na(cas_from_names$dtxsid), "CAS-RN", NA_character_),
          rank = cas_from_names$rank,
          source_tier = dplyr::case_when(
            !is.na(cas_from_names$dtxsid) ~ "cas",
            cas_from_names$is_valid == TRUE ~ "cas_no_match",
            TRUE ~ "cas_invalid"
          )
        )
        all_results[[length(all_results) + 1]] <- cas_name_common
      }

      cas_matched <- cas_from_names$original_cas[!is.na(cas_from_names$dtxsid)]
      still_missed <- setdiff(missed_names, cas_matched)

      if (!is.null(progress_callback)) {
        progress_callback("cas_names", sprintf("CAS fallback on names: %d resolved...", length(cas_matched)))
      }

      # Tier 3: Starts-with on remaining misses (MOVED TO LAST, with 3-char minimum)
      if (length(still_missed) > 0) {
        sw_candidates <- still_missed[nchar(still_missed) >= 3]

        if (length(sw_candidates) > 0) {
          sw_results <- search_starts_with(sw_candidates)
          if (nrow(sw_results) > 0) {
            sw_results$source_tier <- "starts_with"
            all_results[[length(all_results) + 1]] <- sw_results
            n_starts_with <- sum(!is.na(sw_results$dtxsid))
          }

          if (!is.null(progress_callback)) {
            progress_callback("starts_with", sprintf("Starts-with: %d more found...", n_starts_with))
          }

          sw_matched <- sw_results$searchValue[!is.na(sw_results$dtxsid)]
          final_missed <- setdiff(still_missed, sw_matched)
        } else {
          final_missed <- still_missed
        }

        n_miss <- length(final_missed)

        if (length(final_missed) > 0) {
          miss_rows <- tibble::tibble(
            searchValue = final_missed,
            dtxsid = NA_character_,
            preferredName = NA_character_,
            searchName = NA_character_,
            rank = NA_integer_,
            source_tier = "miss"
          )
          all_results[[length(all_results) + 1]] <- miss_rows
        }
      }
    }
  }

  # Tier 4: CAS validation for CASRN-tagged columns (separate path)
  if (length(dedup_result$unique_cas) > 0) {
    cas_results <- validate_and_lookup_cas(dedup_result$unique_cas)

    if (nrow(cas_results) > 0) {
      n_cas_from_columns <- sum(!is.na(cas_results$dtxsid))

      # Convert to common format
      cas_common <- tibble::tibble(
        searchValue = cas_results$original_cas,
        dtxsid = cas_results$dtxsid,
        preferredName = cas_results$preferredName,
        searchName = dplyr::if_else(!is.na(cas_results$dtxsid), "CAS-RN", NA_character_),
        rank = cas_results$rank,
        source_tier = dplyr::case_when(
          !is.na(cas_results$dtxsid) ~ "cas",
          cas_results$is_valid == TRUE ~ "cas_no_match",
          TRUE ~ "cas_invalid"
        )
      )
      all_results[[length(all_results) + 1]] <- cas_common
    }

    if (!is.null(progress_callback)) {
      progress_callback(
        "cas_columns",
        sprintf("CAS columns: %d valid, %d invalid...", n_cas_from_columns, length(dedup_result$unique_cas) - n_cas_from_columns)
      )
    }
  }

  # Combine all search results
  if (length(all_results) == 0) {
    combined_results <- tibble::tibble(
      searchValue = character(0),
      dtxsid = character(0),
      preferredName = character(0),
      searchName = character(0),
      rank = integer(0),
      source_tier = character(0)
    )
  } else {
    combined_results <- dplyr::bind_rows(all_results)
  }

  # Stage 3: Map results to rows
  mapped_df <- map_results_to_rows(clean_data, dedup_result$dedup_key_map, combined_results)

  # Stage 4: Consensus classification
  dtxsid_cols <- find_dtxsid_cols(mapped_df)
  classified_df <- classify_consensus(mapped_df, dtxsid_cols)

  # Compute consensus summary
  n_agree <- sum(classified_df$consensus_status == "agree", na.rm = TRUE)
  n_disagree <- sum(classified_df$consensus_status == "disagree", na.rm = TRUE)
  n_agree_caveat <- sum(classified_df$consensus_status == "agree_caveat", na.rm = TRUE)
  n_single <- sum(classified_df$consensus_status == "single", na.rm = TRUE)
  n_error <- sum(classified_df$consensus_status == "error", na.rm = TRUE)

  if (!is.null(progress_callback)) {
    progress_callback(
      "consensus",
      sprintf(
        "Consensus: %d agree, %d disagree, %d partial...",
        n_agree,
        n_disagree,
        n_agree_caveat
      )
    )
  }

  # Stage 5: Initialize resolution state
  resolved_df <- init_resolution_state(classified_df)

  # Return full pipeline result
  list(
    results = resolved_df,
    dedup_summary = list(
      n_names = length(dedup_result$unique_names),
      n_cas = length(dedup_result$unique_cas)
    ),
    search_summary = list(
      n_exact = n_exact,
      n_starts_with = n_starts_with,
      n_cas_valid = n_cas_from_columns + n_cas_from_names,
      n_miss = n_miss
    ),
    consensus_summary = list(
      n_agree = n_agree,
      n_disagree = n_disagree,
      n_agree_caveat = n_agree_caveat,
      n_single = n_single,
      n_error = n_error
    )
  )
}

# ============================================================================
# get_dedup_preview
# ============================================================================

#' Get deduplication preview counts before running full pipeline
#'
#' @param clean_data The cleaned data frame
#' @param column_tags Named list (col_name -> "Name"|"CASRN"|"Other")
#' @return List with n_names and n_cas
get_dedup_preview <- function(clean_data, column_tags) {
  dedup_result <- deduplicate_tagged_columns(clean_data, column_tags)

  list(
    n_names = length(dedup_result$unique_names),
    n_cas = length(dedup_result$unique_cas)
  )
}
