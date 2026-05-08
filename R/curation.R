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
#' @param skip_flags Optional character vector of cleaning_flag values. Rows whose
#'   cleaning_flag contains any of these values are excluded from the search pool
#'   (their dedup_key_map entries are kept but marked as skipped).
#' @return List with unique_names, unique_cas, dedup_key_map, and skipped_rows (integer vector)
deduplicate_tagged_columns <- function(df, tag_map, skip_flags = NULL) {
  name_cols <- names(tag_map)[tag_map == "Name"]
  cas_cols <- names(tag_map)[tag_map == "CASRN"]
  other_cols <- names(tag_map)[tag_map == "Other"]

  # Identify rows to skip from API search (e.g. isotope_match)
  skipped_rows <- integer(0)
  if (!is.null(skip_flags) && "cleaning_flag" %in% names(df)) {
    skip_pattern <- paste0("\\b(", paste(skip_flags, collapse = "|"), ")\\b")
    skipped_rows <- which(!is.na(df$cleaning_flag) & grepl(skip_pattern, df$cleaning_flag))
    if (length(skipped_rows) > 0) {
      message(sprintf(
        "[dedup] Skipping %d rows from search pool (flags: %s)",
        length(skipped_rows),
        paste(skip_flags, collapse = ", ")
      ))
    }
  }

  # Build dedup key map using vectorized operations (O(n) instead of O(n²))
  n_rows <- nrow(df)
  col_names <- names(tag_map)
  n_cols <- length(col_names)

  # Pre-allocate vectors for the full result
  total_entries <- n_rows * n_cols
  all_row_idx <- integer(total_entries)
  all_col_names <- character(total_entries)
  all_tag_types <- character(total_entries)
  all_dedup_keys <- character(total_entries)

  idx <- 1L
  for (col_name in col_names) {
    end_idx <- idx + n_rows - 1L
    all_row_idx[idx:end_idx] <- seq_len(n_rows)
    all_col_names[idx:end_idx] <- col_name
    all_tag_types[idx:end_idx] <- tag_map[[col_name]]
    all_dedup_keys[idx:end_idx] <- as.character(df[[col_name]])
    idx <- end_idx + 1L
  }

  dedup_key_map <- tibble::tibble(
    row_idx = all_row_idx,
    column_name = all_col_names,
    tag_type = all_tag_types,
    dedup_key = all_dedup_keys
  )

  # Extract unique non-NA values by type, excluding skipped rows
  unique_names <- character(0)
  unique_cas <- character(0)

  searchable_cols <- c(name_cols, other_cols)
  if (length(searchable_cols) > 0) {
    search_df <- if (length(skipped_rows) > 0) df[-skipped_rows, , drop = FALSE] else df
    all_names <- unlist(lapply(searchable_cols, function(col) search_df[[col]]))
    unique_names <- unique(all_names[!is.na(all_names) & all_names != ""])
  }

  if (length(cas_cols) > 0) {
    search_df <- if (length(skipped_rows) > 0) df[-skipped_rows, , drop = FALSE] else df
    all_cas <- unlist(lapply(cas_cols, function(col) search_df[[col]]))
    unique_cas <- unique(all_cas[!is.na(all_cas) & all_cas != ""])
  }

  list(
    unique_names = unique_names,
    unique_cas = unique_cas,
    dedup_key_map = dedup_key_map,
    skipped_rows = skipped_rows
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
# search_starts_with (with session cache - Codex optimization)
# ============================================================================

# Session-level cache for starts-with results (survives across calls within session)
.starts_with_cache <- new.env(parent = emptyenv())

#' Clear the starts-with cache
#'
#' @export
clear_starts_with_cache <- function() {
  rm(list = ls(.starts_with_cache), envir = .starts_with_cache)
  invisible(NULL)
}

#' Starts-with fallback search for names that failed exact match
#'
#' Uses a session-level cache to avoid redundant API calls for repeated terms.
#' Cache keys are lowercased search terms; cache persists within R session.
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

  # Deduplicate input (same term may appear multiple times)
  unique_names <- unique(missed_names)

  # Check cache for already-fetched terms
  cache_keys <- tolower(unique_names)
  cached_mask <- vapply(cache_keys, exists, logical(1), envir = .starts_with_cache)

  uncached_names <- unique_names[!cached_mask]
  cached_names <- unique_names[cached_mask]

  # Retrieve cached results — rebuild searchValue from current query casing.
  # Cache stores payload-only (no searchValue) to avoid stale casing in setdiff().
  cached_results <- if (length(cached_names) > 0) {
    mapply(
      function(name, k) {
        cached_payload <- get(k, envir = .starts_with_cache)
        if (nrow(cached_payload) > 0) {
          cached_payload |> dplyr::mutate(searchValue = name, .before = 1)
        } else {
          # True miss — return empty with correct schema
          empty_result
        }
      },
      cached_names,
      tolower(cached_names),
      SIMPLIFY = FALSE,
      USE.NAMES = FALSE
    )
  } else {
    list()
  }

  # Fetch uncached names
  if (length(uncached_names) > 0) {
    message(sprintf(
      "Falling back on %d misses with starts-with search (%d cached)...",
      length(uncached_names),
      length(cached_names)
    ))

    for (name in uncached_names) {
      cache_key <- tolower(name)
      tryCatch(
        {
          raw <- ComptoxR::ct_chemical_search_start_with(name)
          if (!is.null(raw) && nrow(raw) > 0) {
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
            # Cache payload only (no searchValue) — avoids stale casing on retrieval
            payload <- result_chunk[, c("dtxsid", "preferredName", "searchName", "rank")]
            assign(cache_key, payload, envir = .starts_with_cache)
            cached_results[[length(cached_results) + 1]] <- result_chunk
          } else {
            # Confirmed empty response (true miss) — cache a zero-row payload tibble
            empty_payload <- tibble::tibble(
              dtxsid = character(0),
              preferredName = character(0),
              searchName = character(0),
              rank = integer(0)
            )
            assign(cache_key, empty_payload, envir = .starts_with_cache)
          }
        },
        error = function(e) {
          message(sprintf("  Warning: starts-with failed for '%s': %s", name, e$message))
          # Do NOT cache — allow retry on later runs
        }
      )
    }
  } else if (length(cached_names) > 0) {
    message(sprintf("All %d starts-with lookups served from cache", length(cached_names)))
  }

  if (length(cached_results) == 0) {
    return(empty_result)
  }

  dplyr::bind_rows(cached_results)
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
  valid_cas_values <- result$validated_cas[!is.na(result$validated_cas) & result$is_valid]

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
            cas_from_names$is_valid ~ "cas_no_match",
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
          cas_results$is_valid ~ "cas_no_match",
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
    n_exact,
    n_sw,
    n_cas,
    n_miss
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
#' @param pre_resolved Optional tibble with columns (row_idx, dtxsid, preferredName, source_tier)
#'   for rows that were resolved without API search (e.g. isotope_match). These are injected
#'   directly into the result vectors, overriding any API results for those row indices.
#' @return Original df with lookup columns joined back
map_results_to_rows <- function(df, dedup_key_map, lookup_results, pre_resolved = NULL) {
  input_rows <- nrow(df)

  # Build a fast lookup table: searchValue -> best result
  # Prefer resolved rows (non-NA dtxsid or preferredName) over unresolved, then lowest rank
  lookup_deduped <- lookup_results |>
    dplyr::arrange(
      is.na(dtxsid) & is.na(preferredName),
      rank
    ) |>
    dplyr::distinct(searchValue, .keep_all = TRUE)

  # Named list for O(1) lookup by searchValue
  lookup_idx <- stats::setNames(seq_len(nrow(lookup_deduped)), lookup_deduped$searchValue)

  message(sprintf(
    "[map_results_to_rows] Input: %d rows, %d lookup results (%d unique searchValues)",
    input_rows,
    nrow(lookup_results),
    nrow(lookup_deduped)
  ))

  # Filter out NA/empty dedup keys
  dedup_key_map <- dedup_key_map |>
    dplyr::filter(!is.na(dedup_key) & dedup_key != "")

  tag_cols <- unique(dedup_key_map$column_name)

  # For each tagged column, populate result vectors by direct indexing (no joins)
  for (col in tag_cols) {
    col_keys <- dedup_key_map |>
      dplyr::filter(column_name == col)

    # Pre-allocate result vectors matching df row count
    dtxsid_vec <- rep(NA_character_, input_rows)
    pref_vec <- rep(NA_character_, input_rows)
    search_vec <- rep(NA_character_, input_rows)
    rank_vec <- rep(NA_integer_, input_rows)
    tier_vec <- rep(NA_character_, input_rows)
    wqx_conf_vec <- rep(NA_real_, input_rows)

    # Fill in results by direct index lookup
    for (i in seq_len(nrow(col_keys))) {
      ridx <- col_keys$row_idx[i]
      key <- col_keys$dedup_key[i]
      match_pos <- lookup_idx[key]

      if (!is.na(match_pos)) {
        dtxsid_vec[ridx] <- lookup_deduped$dtxsid[match_pos]
        pref_vec[ridx] <- lookup_deduped$preferredName[match_pos]
        search_vec[ridx] <- lookup_deduped$searchName[match_pos]
        rank_vec[ridx] <- lookup_deduped$rank[match_pos]
        tier_vec[ridx] <- lookup_deduped$source_tier[match_pos]
        if ("wqx_confidence" %in% names(lookup_deduped)) {
          wqx_conf_vec[ridx] <- lookup_deduped$wqx_confidence[match_pos]
        }
      }
    }

    # Assign columns to df (no joins — row count cannot change)
    if (length(tag_cols) == 1) {
      df$dtxsid <- dtxsid_vec
      df$preferredName <- pref_vec
      df$searchName <- search_vec
      df$rank <- rank_vec
      df$source_tier <- tier_vec
      df$wqx_confidence <- wqx_conf_vec
    } else {
      suffix <- paste0("_", col)
      df[[paste0("dtxsid", suffix)]] <- dtxsid_vec
      df[[paste0("preferredName", suffix)]] <- pref_vec
      df[[paste0("searchName", suffix)]] <- search_vec
      df[[paste0("rank", suffix)]] <- rank_vec
      df[[paste0("source_tier", suffix)]] <- tier_vec
      df[[paste0("wqx_confidence", suffix)]] <- wqx_conf_vec
    }
  }

  # Inject pre-resolved rows (e.g. isotope_match) — override any API results

  if (!is.null(pre_resolved) && nrow(pre_resolved) > 0) {
    message(sprintf("[map_results_to_rows] Injecting %d pre-resolved rows (isotope_match)", nrow(pre_resolved)))

    for (i in seq_len(nrow(pre_resolved))) {
      ridx <- pre_resolved$row_idx[i]
      pr_dtxsid <- pre_resolved$dtxsid[i]
      pr_pref <- pre_resolved$preferredName[i]
      pr_tier <- pre_resolved$source_tier[i]

      if (length(tag_cols) == 1) {
        df$dtxsid[ridx] <- pr_dtxsid
        df$preferredName[ridx] <- pr_pref
        df$searchName[ridx] <- NA_character_
        df$rank[ridx] <- 0L
        df$source_tier[ridx] <- pr_tier
      } else {
        # Apply to all tagged columns for this row
        for (col in tag_cols) {
          suffix <- paste0("_", col)
          df[[paste0("dtxsid", suffix)]][ridx] <- pr_dtxsid
          df[[paste0("preferredName", suffix)]][ridx] <- pr_pref
          df[[paste0("searchName", suffix)]][ridx] <- NA_character_
          df[[paste0("rank", suffix)]][ridx] <- 0L
          df[[paste0("source_tier", suffix)]][ridx] <- pr_tier
        }
      }
    }
  }

  message(sprintf("[map_results_to_rows] Output: %d rows (no joins used)", nrow(df)))
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
#' @export
run_curation_pipeline <- function(
  clean_data,
  column_tags,
  progress_callback = NULL,
  dedup_only = FALSE,
  wqx_threshold = 0.85,
  starts_with = FALSE
) {
  # Build pre-resolved tibble for isotope-matched rows (skip API search)
  pre_resolved <- NULL
  if ("cleaning_flag" %in% names(clean_data) && "isotope_dtxsid" %in% names(clean_data)) {
    iso_rows <- which(
      !is.na(clean_data$cleaning_flag) &
        grepl("\\bisotope_match\\b", clean_data$cleaning_flag) &
        !is.na(clean_data$isotope_dtxsid)
    )
    if (length(iso_rows) > 0) {
      pre_resolved <- tibble::tibble(
        row_idx = iso_rows,
        dtxsid = clean_data$isotope_dtxsid[iso_rows],
        preferredName = NA_character_,
        source_tier = "isotope_match"
      )
      message(sprintf("[pipeline] %d isotope-matched rows with DTXSID will skip API search", length(iso_rows)))
    }
  }

  # Stage 1: Deduplication (skip isotope_match rows from search pool)
  dedup_result <- deduplicate_tagged_columns(clean_data, column_tags, skip_flags = "isotope_match")

  n_other <- sum(column_tags == "Other")
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
  n_wqx <- 0L

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
        sprintf(
          "Exact match: %d/%d found, %d falling back...",
          n_exact,
          length(dedup_result$unique_names),
          length(missed_names)
        )
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
            cas_from_names$is_valid ~ "cas_no_match",
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

      # Tier 3: WQX — no character minimum (local dictionary, no API cost)
      if (length(still_missed) > 0) {
        cache_dir <- system.file("extdata", "reference_cache", package = "chemreg")
        wqx_dict <- load_wqx_dictionary(cache_dir)
        wqx_raw <- match_wqx(still_missed, wqx_dict, threshold = wqx_threshold, verbose = FALSE)

        wqx_resolved <- wqx_raw[wqx_raw$match_tier != "none", ]
        n_wqx <- nrow(wqx_resolved)

        if (n_wqx > 0) {
          wqx_rows <- tibble::tibble(
            searchValue = wqx_resolved$input_name,
            dtxsid = NA_character_,
            preferredName = wqx_resolved$wqx_name,
            searchName = NA_character_,
            rank = NA_integer_,
            source_tier = paste0("wqx_", wqx_resolved$match_tier),
            wqx_confidence = ifelse(
              wqx_resolved$match_tier == "fuzzy",
              1 - wqx_resolved$match_distance,
              NA_real_
            )
          )
          all_results[[length(all_results) + 1]] <- wqx_rows
        }

        wqx_matched_names <- wqx_resolved$input_name
        final_missed <- setdiff(still_missed, wqx_matched_names)

        if (!is.null(progress_callback)) {
          progress_callback("wqx", sprintf("WQX match: %d more found...", n_wqx))
        }

        # Tier 4: Starts-with — only when enabled AND names remain
        if (starts_with && length(final_missed) > 0) {
          sw_candidates <- final_missed[nchar(final_missed) >= 3]
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
            final_missed <- setdiff(final_missed, sw_matched)
          }
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
          cas_results$is_valid ~ "cas_no_match",
          TRUE ~ "cas_invalid"
        )
      )
      all_results[[length(all_results) + 1]] <- cas_common
    }

    if (!is.null(progress_callback)) {
      progress_callback(
        "cas_columns",
        sprintf(
          "CAS columns: %d valid, %d invalid...",
          n_cas_from_columns,
          length(dedup_result$unique_cas) - n_cas_from_columns
        )
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
  message(sprintf(
    "[pipeline] clean_data: %d rows, combined_results: %d rows",
    nrow(clean_data),
    nrow(combined_results)
  ))
  mapped_df <- map_results_to_rows(
    clean_data,
    dedup_result$dedup_key_map,
    combined_results,
    pre_resolved = pre_resolved
  )

  # Assert row count preserved
  if (nrow(mapped_df) != nrow(clean_data)) {
    warning(sprintf(
      "[pipeline] CRITICAL: row count changed after mapping: %d -> %d. Truncating to original.",
      nrow(clean_data),
      nrow(mapped_df)
    ))
    mapped_df <- mapped_df[seq_len(nrow(clean_data)), , drop = FALSE]
  }

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
      n_wqx = n_wqx,
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
# enrich_candidates
# ============================================================================

#' Fetch CompTox chemical details for DTXSIDs and return structured cache
#'
#' Calls ct_details with a configurable projection to retrieve CASRN,
#' molecular formula, and molecular weight for each unique DTXSID.
#' Supports incremental caching: pass existing_cache to skip already-fetched DTXSIDs.
#'
#' @param dtxsids Character vector of DTXSIDs to enrich
#' @param existing_cache Optional tibble from a previous enrich_candidates() call.
#'   DTXSIDs already present in the cache will not be re-fetched.
#' @param projection Character: ct_details projection level.
#'   One of "all", "standard", "id", "structure", "nta", "compact".
#'   Default "standard".
#' @return Named list with:
#'   - cache: tibble(dtxsid, casrn, molecular_formula, molecular_weight)
#'   - failed_dtxsids: character vector of DTXSIDs that could not be fetched
#' @export
enrich_candidates <- function(dtxsids, existing_cache = NULL) {
  empty_cache <- tibble::tibble(
    dtxsid = character(0),
    casrn = character(0),
    molecular_formula = character(0),
    molecular_weight = numeric(0)
  )

  # Handle empty input
  if (length(dtxsids) == 0) {
    return(list(cache = existing_cache %||% empty_cache, failed_dtxsids = character(0)))
  }

  unique_dtxsids <- unique(dtxsids[!is.na(dtxsids) & dtxsids != ""])

  if (length(unique_dtxsids) == 0) {
    return(list(cache = existing_cache %||% empty_cache, failed_dtxsids = character(0)))
  }

  # Incremental caching: filter out already-cached DTXSIDs
  dtxsids_to_fetch <- unique_dtxsids
  if (!is.null(existing_cache) && nrow(existing_cache) > 0) {
    already_cached <- existing_cache$dtxsid
    dtxsids_to_fetch <- setdiff(unique_dtxsids, already_cached)
  }

  # If all DTXSIDs are already cached, return immediately

  if (length(dtxsids_to_fetch) == 0) {
    message("[enrich] All DTXSIDs already cached — skipping API call")
    return(list(cache = existing_cache, failed_dtxsids = character(0)))
  }

  message(sprintf("[enrich] Fetching details for %d unique DTXSIDs...", length(dtxsids_to_fetch)))

  api_error <- NULL
  raw <- tryCatch(
    suppressMessages(ComptoxR::ct_chemical_detail_search_bulk(dtxsids_to_fetch)),
    error = function(e) {
      message(sprintf("[enrich] API call failed: %s", conditionMessage(e)))
      api_error <<- conditionMessage(e)
      NULL
    }
  )

  # Handle API call failure (error thrown, not just empty result)
  if (!is.null(api_error)) {
    combined <- existing_cache %||% empty_cache
    return(list(cache = combined, failed_dtxsids = dtxsids_to_fetch))
  }

  if (is.null(raw) || (is.data.frame(raw) && nrow(raw) == 0)) {
    message("[enrich] API returned no results")
    # All queried DTXSIDs are effectively missing
    missing_rows <- tibble::tibble(
      dtxsid = dtxsids_to_fetch,
      casrn = NA_character_,
      molecular_formula = NA_character_,
      molecular_weight = NA_real_
    )
    combined <- dplyr::bind_rows(existing_cache, missing_rows)
    return(list(cache = combined, failed_dtxsids = character(0)))
  }

  message(sprintf("[enrich] Got %d rows, %d columns: %s", nrow(raw), ncol(raw), paste(names(raw), collapse = ", ")))

  # Extract and rename columns from API response (camelCase)
  dtxsid_col <- grep("^dtxsid$", names(raw), ignore.case = TRUE, value = TRUE)
  casrn_col <- grep("^casrn$", names(raw), ignore.case = TRUE, value = TRUE)
  formula_col <- grep("^mol.?formula$", names(raw), ignore.case = TRUE, value = TRUE)
  mw_col <- grep("^molecular.?weight$", names(raw), ignore.case = TRUE, value = TRUE)
  if (length(mw_col) == 0) {
    mw_col <- grep("^monoisotopic.?mass$", names(raw), ignore.case = TRUE, value = TRUE)
  }

  new_cache <- tibble::tibble(
    dtxsid = if (length(dtxsid_col) > 0) raw[[dtxsid_col[1]]] else NA_character_,
    casrn = if (length(casrn_col) > 0) raw[[casrn_col[1]]] else NA_character_,
    molecular_formula = if (length(formula_col) > 0) raw[[formula_col[1]]] else NA_character_,
    molecular_weight = if (length(mw_col) > 0) as.numeric(raw[[mw_col[1]]]) else NA_real_
  )

  # Handle partial response: add NA rows for DTXSIDs not in API result
  returned_dtxsids <- new_cache$dtxsid[!is.na(new_cache$dtxsid)]
  missing_dtxsids <- setdiff(dtxsids_to_fetch, returned_dtxsids)
  if (length(missing_dtxsids) > 0) {
    missing_rows <- tibble::tibble(
      dtxsid = missing_dtxsids,
      casrn = NA_character_,
      molecular_formula = NA_character_,
      molecular_weight = NA_real_
    )
    new_cache <- dplyr::bind_rows(new_cache, missing_rows)
  }

  # Combine with existing cache
  combined <- dplyr::bind_rows(existing_cache, new_cache)

  message(sprintf("[enrich] Cache now has %d entries", nrow(combined)))

  list(
    cache = combined,
    failed_dtxsids = character(0)
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
#' @export
get_dedup_preview <- function(clean_data, column_tags) {
  dedup_result <- deduplicate_tagged_columns(clean_data, column_tags, skip_flags = "isotope_match")

  list(
    n_names = length(dedup_result$unique_names),
    n_cas = length(dedup_result$unique_cas)
  )
}

# ============================================================================
# validate_manual_dtxsids
# ============================================================================

#' Validate manually-entered DTXSIDs via CompTox bulk API
#'
#' @param dtxsids Character vector of DTXSID strings (e.g., "DTXSID7020182")
#' @param batch_size Integer batch size for API calls (default 20)
#' @param delay_sec Numeric delay in seconds between batches (default 1)
#' @return Tibble with columns: searchValue, dtxsid, preferredName, rank, is_valid
#' @export
validate_manual_dtxsids <- function(dtxsids, batch_size = 20, delay_sec = 1) {
  empty_result <- tibble::tibble(
    searchValue = character(0),
    dtxsid = character(0),
    preferredName = character(0),
    rank = integer(0),
    is_valid = logical(0)
  )

  if (length(dtxsids) == 0) {
    return(empty_result)
  }

  # Deduplicate input
  unique_dtxsids <- unique(dtxsids[!is.na(dtxsids) & dtxsids != ""])

  if (length(unique_dtxsids) == 0) {
    return(empty_result)
  }

  message(sprintf("Validating %d unique DTXSIDs...", length(unique_dtxsids)))

  # Split into batches
  n_batches <- ceiling(length(unique_dtxsids) / batch_size)
  all_results <- list()

  for (batch_idx in seq_len(n_batches)) {
    start_idx <- (batch_idx - 1) * batch_size + 1
    end_idx <- min(batch_idx * batch_size, length(unique_dtxsids))
    batch <- unique_dtxsids[start_idx:end_idx]

    message(sprintf("  Batch %d/%d: %d DTXSIDs...", batch_idx, n_batches, length(batch)))

    # Use purrr::safely for error handling
    safe_lookup <- purrr::safely(ComptoxR::ct_chemical_search_equal_bulk)
    api_result <- safe_lookup(batch)

    if (!is.null(api_result$error)) {
      warning(sprintf("API call failed for batch %d: %s", batch_idx, api_result$error$message))
      # Mark all in this batch as invalid
      batch_result <- tibble::tibble(
        searchValue = batch,
        dtxsid = NA_character_,
        preferredName = NA_character_,
        rank = NA_integer_,
        is_valid = FALSE
      )
    } else {
      raw <- api_result$result

      if (is.null(raw) || nrow(raw) == 0) {
        # No results found - mark all as invalid
        batch_result <- tibble::tibble(
          searchValue = batch,
          dtxsid = NA_character_,
          preferredName = NA_character_,
          rank = NA_integer_,
          is_valid = FALSE
        )
      } else {
        # Standardize column names
        col_map <- list(
          searchValue = grep("^search.?value$", names(raw), ignore.case = TRUE, value = TRUE),
          dtxsid = grep("^dtxsid$", names(raw), ignore.case = TRUE, value = TRUE),
          preferredName = grep("^preferred.?name$", names(raw), ignore.case = TRUE, value = TRUE),
          rank = grep("^rank$", names(raw), ignore.case = TRUE, value = TRUE)
        )

        found_results <- tibble::tibble(
          searchValue = if (length(col_map$searchValue) > 0) raw[[col_map$searchValue[1]]] else NA_character_,
          dtxsid = if (length(col_map$dtxsid) > 0) raw[[col_map$dtxsid[1]]] else NA_character_,
          preferredName = if (length(col_map$preferredName) > 0) raw[[col_map$preferredName[1]]] else NA_character_,
          rank = if (length(col_map$rank) > 0) as.integer(raw[[col_map$rank[1]]]) else NA_integer_,
          is_valid = !is.na(if (length(col_map$dtxsid) > 0) raw[[col_map$dtxsid[1]]] else NA_character_)
        )

        # Take lowest rank per searchValue
        found_results <- found_results |>
          dplyr::group_by(searchValue) |>
          dplyr::slice_min(rank, n = 1, with_ties = FALSE) |>
          dplyr::ungroup()

        # Find DTXSIDs not in API response
        found_values <- found_results$searchValue[found_results$is_valid]
        missed_values <- setdiff(batch, found_values)

        if (length(missed_values) > 0) {
          missed_results <- tibble::tibble(
            searchValue = missed_values,
            dtxsid = NA_character_,
            preferredName = NA_character_,
            rank = NA_integer_,
            is_valid = FALSE
          )
          batch_result <- dplyr::bind_rows(found_results, missed_results)
        } else {
          batch_result <- found_results
        }
      }
    }

    all_results[[batch_idx]] <- batch_result

    # Delay between batches (except after last batch)
    if (batch_idx < n_batches && delay_sec > 0) {
      Sys.sleep(delay_sec)
    }
  }

  combined <- dplyr::bind_rows(all_results)

  n_valid <- sum(combined$is_valid, na.rm = TRUE)
  n_invalid <- sum(!combined$is_valid, na.rm = TRUE)
  message(sprintf("Validation complete: %d valid, %d invalid", n_valid, n_invalid))

  combined
}

# ============================================================================
# merge_retry_results
# ============================================================================

#' Merge retry curation results back into original resolution state
#'
#' @param original_state Original resolution_state data frame
#' @param retry_results Retry pipeline results data frame
#' @param selected_row_indices Integer vector of original row indices that were re-curated
#' @param tags_changed Logical indicating if column tags were changed (default FALSE)
#' @return Updated original_state data frame with retry results merged
#' @export
merge_retry_results <- function(original_state, retry_results, selected_row_indices, tags_changed = FALSE) {
  # Validate input
  if (nrow(retry_results) != length(selected_row_indices)) {
    stop(
      "Mismatch: retry_results has ",
      nrow(retry_results),
      " rows but selected_row_indices has ",
      length(selected_row_indices),
      " elements"
    )
  }

  # Initialize resolution state if needed
  original_state <- init_resolution_state(original_state)

  # Safety check: skip pinned rows
  pinned_mask <- original_state$.pinned[selected_row_indices]
  if (any(pinned_mask, na.rm = TRUE)) {
    pinned_indices <- selected_row_indices[pinned_mask]
    warning(sprintf(
      "Skipping %d pinned rows: %s",
      sum(pinned_mask, na.rm = TRUE),
      paste(pinned_indices, collapse = ", ")
    ))
    # Filter out pinned rows from both selected_row_indices and retry_results
    selected_row_indices <- selected_row_indices[!pinned_mask]
    retry_results <- retry_results[!pinned_mask, , drop = FALSE]
  }

  if (length(selected_row_indices) == 0) {
    message("No rows to merge after filtering pinned rows")
    return(original_state)
  }

  # If tags changed, add new columns from retry_results that don't exist in original_state
  if (tags_changed) {
    new_cols <- setdiff(names(retry_results), names(original_state))
    if (length(new_cols) > 0) {
      message(sprintf("Adding %d new columns from retry: %s", length(new_cols), paste(new_cols, collapse = ", ")))
      for (col in new_cols) {
        # Initialize with NA, matching the type from retry_results
        original_state[[col]] <- rep(NA, nrow(original_state))
        # Preserve column type
        if (is.numeric(retry_results[[col]])) {
          original_state[[col]] <- as.numeric(original_state[[col]])
        } else if (is.logical(retry_results[[col]])) {
          original_state[[col]] <- as.logical(original_state[[col]])
        } else {
          original_state[[col]] <- as.character(original_state[[col]])
        }
      }
    }
  }

  # Track original error status for unresolvable detection
  original_errors <- original_state$consensus_status[selected_row_indices] == "error"

  # Update consensus columns for selected rows
  consensus_cols <- c("consensus_dtxsid", "consensus_status", "consensus_source", "qc_tier")
  for (col in consensus_cols) {
    if (col %in% names(retry_results)) {
      original_state[[col]][selected_row_indices] <- retry_results[[col]]
    }
  }

  # Update per-column lookup columns (dtxsid_*, preferredName_*, rank_*, source_tier_*)
  lookup_col_patterns <- c("^dtxsid_", "^preferredName_", "^rank_", "^source_tier_")
  for (pattern in lookup_col_patterns) {
    retry_cols <- grep(pattern, names(retry_results), value = TRUE)
    for (col in retry_cols) {
      if (col %in% names(original_state)) {
        original_state[[col]][selected_row_indices] <- retry_results[[col]]
      } else if (tags_changed) {
        # New column was already added above
        original_state[[col]][selected_row_indices] <- retry_results[[col]]
      }
    }
  }

  # Mark unresolvable: rows that were error before AND are still error after retry
  retry_errors <- original_state$consensus_status[selected_row_indices] == "error"
  unresolvable_mask <- original_errors & retry_errors
  if (any(unresolvable_mask, na.rm = TRUE)) {
    unresolvable_indices <- selected_row_indices[unresolvable_mask]
    original_state$consensus_status[unresolvable_indices] <- "unresolvable"
    message(sprintf(
      "Marked %d rows as unresolvable (error before and after retry)",
      sum(unresolvable_mask, na.rm = TRUE)
    ))
  }

  message(sprintf("Merged retry results for %d rows", length(selected_row_indices)))
  original_state
}
