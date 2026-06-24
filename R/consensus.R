# Consensus Logic: DTXSID comparison across tagged columns
#
# Row-level classification and QC tier scoring for chemical inventory data.
# Consumes output from prototype_pipeline.R (map_results_to_rows).

# ============================================================================
# find_dtxsid_cols
# ============================================================================

#' Auto-detect DTXSID columns by name pattern
#'
#' @param df Data frame with lookup results
#' @return Character vector of column names matching "dtxsid" or "dtxsid_*"
#' @export
find_dtxsid_cols <- function(df) {
  grep("^dtxsid$|^dtxsid_", names(df), value = TRUE)
}

source_column_name <- function(dtxsid_col) {
  if (identical(dtxsid_col, "dtxsid")) {
    return("Name")
  }
  sub("^dtxsid_", "", dtxsid_col)
}

source_field_column <- function(dtxsid_col, prefix) {
  if (identical(dtxsid_col, "dtxsid")) {
    return(prefix)
  }
  sub("^dtxsid_", paste0(prefix, "_"), dtxsid_col)
}

is_wqx_tier <- function(x) {
  !is.na(x) & grepl("^wqx_", x)
}

normalize_identity_evidence_name <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- NA_character_
  normalized <- tolower(gsub("[^a-z0-9]+", "", x))
  normalized[!nzchar(normalized)] <- NA_character_
  normalized
}

find_wqx_evidence_only_cols <- function(df, dtxsid_cols, row_idx) {
  cols <- character(0)
  for (col in dtxsid_cols) {
    tier_col <- source_field_column(col, "source_tier")
    pref_col <- source_field_column(col, "preferredName")
    if (!tier_col %in% names(df) || !pref_col %in% names(df)) {
      next
    }

    dtxsid_val <- df[[col]][row_idx]
    tier_val <- as.character(df[[tier_col]][row_idx])
    pref_val <- as.character(df[[pref_col]][row_idx])

    if (is.na(dtxsid_val) && is_wqx_tier(tier_val) && !is.na(pref_val) && nzchar(trimws(pref_val))) {
      cols <- c(cols, col)
    }
  }
  cols
}

has_wqx_evidence_conflict <- function(df, dtxsid_cols, row_idx) {
  wqx_cols <- find_wqx_evidence_only_cols(df, dtxsid_cols, row_idx)
  if (length(wqx_cols) == 0) {
    return(FALSE)
  }

  dtxsid_pref_keys <- character(0)
  for (col in dtxsid_cols) {
    dtxsid_val <- df[[col]][row_idx]
    if (is.na(dtxsid_val)) {
      next
    }
    pref_col <- source_field_column(col, "preferredName")
    if (pref_col %in% names(df)) {
      dtxsid_pref_keys <- c(dtxsid_pref_keys, normalize_identity_evidence_name(df[[pref_col]][row_idx]))
    }
  }
  dtxsid_pref_keys <- unique(dtxsid_pref_keys[!is.na(dtxsid_pref_keys)])
  if (length(dtxsid_pref_keys) == 0) {
    return(FALSE)
  }

  wqx_pref_keys <- vapply(
    wqx_cols,
    function(col) {
      pref_col <- source_field_column(col, "preferredName")
      normalize_identity_evidence_name(df[[pref_col]][row_idx])
    },
    character(1)
  )
  wqx_pref_keys <- wqx_pref_keys[!is.na(wqx_pref_keys)]

  any(!wqx_pref_keys %in% dtxsid_pref_keys)
}

# ============================================================================
# compute_qc_tier
# ============================================================================

#' Compute numeric QC tier for a consensus classification
#'
#' @param status Character: "agree", "agree_caveat", "disagree", "single", "error"
#' @param n_matched Integer: number of columns that matched (had same DTXSID)
#' @param n_total Integer: total number of tagged columns (K)
#' @return Integer QC tier (1 = best, K+1 = worst)
#' @export
compute_qc_tier <- function(status, n_matched, n_total) {
  tier <- switch(
    status,
    "agree" = 1L,
    "agree_caveat" = 1L + as.integer(n_total - n_matched),
    "single" = as.integer(n_total),
    "wqx" = as.integer(n_total),
    "disagree" = as.integer(n_total + 1L),
    "error" = as.integer(n_total + 2L),
    NA_integer_
  )
  tier
}

# ============================================================================
# classify_consensus
# ============================================================================

#' Classify consensus across tagged columns for each row
#'
#' NOTE: This function returns status values "agree", "agree_caveat", "single",
#' "wqx", "disagree", and "error". Downstream code (manual validation flow, retry merge)
#' may add additional status values: "manual" (manually-entered DTXSID) and
#' "unresolvable" (error persisting after retry).
#'
#' @param df Data frame with DTXSID columns from map_results_to_rows()
#' @param dtxsid_cols Character vector of DTXSID column names to compare
#' @return Original df with added columns: consensus_status, consensus_dtxsid,
#'         consensus_source, qc_tier
#' @export
classify_consensus <- function(df, dtxsid_cols) {
  k <- length(dtxsid_cols)

  # Compute per-row classification
  consensus_status <- character(nrow(df))
  consensus_dtxsid <- character(nrow(df))
  consensus_source <- character(nrow(df))
  qc_tier <- integer(nrow(df))

  # Pre-compute source_tier column names (avoids repeated sub() inside loop)
  tier_cols <- ifelse(dtxsid_cols == "dtxsid", "source_tier", sub("^dtxsid_", "source_tier_", dtxsid_cols))
  tier_cols_exist <- tier_cols %in% names(df)

  for (i in seq_len(nrow(df))) {
    # Extract DTXSIDs for this row across all tagged columns
    values <- vapply(
      dtxsid_cols,
      function(col) {
        val <- df[[col]][i]
        if (is.na(val)) NA_character_ else as.character(val)
      },
      character(1)
    )

    non_na <- values[!is.na(values)]
    n_present <- length(non_na)
    unique_vals <- unique(non_na)
    n_unique <- length(unique_vals)

    if (n_present > 0 && has_wqx_evidence_conflict(df, dtxsid_cols, i)) {
      # WQX can contribute name-only identity evidence. If it conflicts with a
      # DTXSID-backed source, treat the row like any other source disagreement
      # instead of letting the DTXSID-backed source appear as a clean single/agree.
      consensus_status[i] <- "disagree"
      consensus_dtxsid[i] <- NA_character_
      consensus_source[i] <- NA_character_
      qc_tier[i] <- compute_qc_tier("disagree", 0L, k)
      next
    }

    # WQX guard: rows with NA DTXSIDs but WQX source_tier get "wqx" status, not "error"
    if (n_present == 0) {
      row_tiers <- vapply(
        seq_along(tier_cols),
        function(j) {
          if (tier_cols_exist[j]) as.character(df[[tier_cols[j]]][i]) else NA_character_
        },
        character(1)
      )
      is_wqx_row <- any(!is.na(row_tiers) & grepl("^wqx_", row_tiers))

      if (is_wqx_row) {
        consensus_status[i] <- "wqx"
        consensus_dtxsid[i] <- NA_character_
        # Find which column had the WQX resolution for source attribution
        wqx_col_idx <- which(!is.na(row_tiers) & grepl("^wqx_", row_tiers))[1]
        consensus_source[i] <- if (tier_cols[wqx_col_idx] == "source_tier") "Name" else sub("^source_tier_", "", tier_cols[wqx_col_idx])
        qc_tier[i] <- compute_qc_tier("wqx", 0L, k)
        next
      }
    }

    if (n_present == 0) {
      # All NA -> error
      consensus_status[i] <- "error"
      consensus_dtxsid[i] <- NA_character_
      consensus_source[i] <- NA_character_
      qc_tier[i] <- compute_qc_tier("error", 0L, k)
    } else if (n_present == 1) {
      # Single source
      consensus_status[i] <- "single"
      consensus_dtxsid[i] <- non_na[1]
      # Find which column had the value
      src_col <- dtxsid_cols[!is.na(values)][1]
      consensus_source[i] <- if (src_col == "dtxsid") "Name" else sub("^dtxsid_", "", src_col)
      qc_tier[i] <- compute_qc_tier("single", 1L, k)
    } else if (n_unique == 1 && n_present == k) {
      # All columns agree
      consensus_status[i] <- "agree"
      consensus_dtxsid[i] <- unique_vals[1]
      consensus_source[i] <- "consensus"
      qc_tier[i] <- compute_qc_tier("agree", k, k)
    } else if (n_unique == 1 && n_present < k) {
      # Some agree, some missing
      consensus_status[i] <- "agree_caveat"
      consensus_dtxsid[i] <- unique_vals[1]
      consensus_source[i] <- "consensus"
      qc_tier[i] <- compute_qc_tier("agree_caveat", n_present, k)
    } else {
      # Multiple different DTXSIDs -> disagree
      consensus_status[i] <- "disagree"
      consensus_dtxsid[i] <- NA_character_
      consensus_source[i] <- NA_character_
      qc_tier[i] <- compute_qc_tier("disagree", 0L, k)
    }
  }

  df$consensus_status <- consensus_status
  df$consensus_dtxsid <- consensus_dtxsid
  df$consensus_source <- consensus_source
  df$qc_tier <- qc_tier

  df
}

# ============================================================================
# init_resolution_state
# ============================================================================

#' Initialize resolution state on a classified data frame
#'
#' Adds .pinned column (FALSE), .manual_entry column (FALSE), public
#' row_flag column (NA_character_), and row_flag_reason column
#' (NA_character_) if not already present. Also adds
#' .resolution_method and .resolution_reason columns (NA_character_) for tracking
#' how each row was resolved (per D-11).
#'
#' Valid .resolution_method values: "auto", "suggested-accept", "bulk-accept", "manual", NA.
#'
#' @param df Data frame (typically output of classify_consensus)
#' @return df with .pinned, .manual_entry, row_flag, row_flag_reason, .resolution_method, and .resolution_reason columns
#' @export
init_resolution_state <- function(df) {
  if (!".pinned" %in% names(df)) {
    df$.pinned <- FALSE
  }
  if (!".manual_entry" %in% names(df)) {
    df$.manual_entry <- FALSE
  }
  if (!"row_flag" %in% names(df)) {
    df$row_flag <- NA_character_
  }
  if (!"row_flag_reason" %in% names(df)) {
    df$row_flag_reason <- NA_character_
  }
  if (!".resolution_method" %in% names(df)) {
    df$.resolution_method <- NA_character_
  }
  if (!".resolution_reason" %in% names(df)) {
    df$.resolution_reason <- NA_character_
  }
  df
}

#' Valid row flag values
#'
#' @return Character vector of user-facing row flag values.
#' @export
valid_row_flags <- function() {
  c("BAD", "FOLLOW-UP", "VERIFIED")
}

#' Normalize a row flag value
#'
#' @param flag Character flag value, or NULL/NA/""/"CLEAR" to unset.
#' @return A valid uppercase flag, or NA_character_ when unset.
#' @export
normalize_row_flag <- function(flag) {
  if (is.null(flag) || length(flag) == 0 || is.na(flag[1])) {
    return(NA_character_)
  }

  normalized <- toupper(trimws(as.character(flag[1])))
  if (normalized %in% c("", "CLEAR")) {
    return(NA_character_)
  }

  valid_flags <- valid_row_flags()
  if (!normalized %in% valid_flags) {
    stop(
      "Invalid row_flag '", flag[1], "'. Valid flags are: ",
      paste(valid_flags, collapse = ", "),
      call. = FALSE
    )
  }

  normalized
}

normalize_row_flag_reason <- function(reason) {
  if (is.null(reason) || length(reason) == 0 || is.na(reason[1])) {
    return(NA_character_)
  }

  normalized <- trimws(as.character(reason[1]))
  if (!nzchar(normalized)) {
    return(NA_character_)
  }

  normalized
}

#' Set one row flag
#'
#' @param df Resolution state data frame.
#' @param row_idx Integer row index to update.
#' @param flag Flag value, or NULL/NA/""/"CLEAR" to unset.
#' @param reason Optional reviewer reason for BAD/FOLLOW-UP/follow-up flags.
#' @return Updated resolution state.
#' @export
set_row_flag <- function(df, row_idx, flag, reason = NULL) {
  set_row_flags(df, row_idx, flag, reason = reason)
}

#' Set row flags in bulk
#'
#' @param df Resolution state data frame.
#' @param row_indices Integer row indices to update.
#' @param flag Flag value, or NULL/NA/""/"CLEAR" to unset.
#' @param reason Optional reviewer reason to apply to all updated rows.
#' @return Updated resolution state.
#' @export
set_row_flags <- function(df, row_indices, flag, reason = NULL) {
  df <- init_resolution_state(df)

  if (is.null(row_indices) || length(row_indices) == 0) {
    return(df)
  }

  if (any(is.na(row_indices)) ||
    any(row_indices != as.integer(row_indices)) ||
    any(row_indices < 1L) ||
    any(row_indices > nrow(df))) {
    stop("row_indices must be valid 1-based row positions.", call. = FALSE)
  }

  row_indices <- as.integer(row_indices)
  normalized_flag <- normalize_row_flag(flag)
  normalized_reason <- normalize_row_flag_reason(reason)

  df$row_flag[row_indices] <- normalized_flag
  df$row_flag_reason[row_indices] <- if (is.na(normalized_flag)) {
    NA_character_
  } else {
    normalized_reason
  }
  df
}

# ============================================================================
# get_resolution_options
# ============================================================================

#' Get available resolution options for a disagree row
#'
#' Returns rich metadata for each option including DTXSID, preferredName, and rank.
#' Options are sorted by rank (best match first, lowest rank number).
#'
#' @param df Classified data frame
#' @param row_idx Integer row index
#' @param dtxsid_cols Character vector of DTXSID column names
#' @param enrichment_cache Optional enrichment cache with CASRN, molecular
#'   formula, and molecular weight columns for DTXSID options.
#' @return Named list of column_name = list(dtxsid, preferredName, rank) for columns with data.
#'         Sorted by rank (best first). Empty list if row is not "disagree".
#' @export
get_resolution_options <- function(df, row_idx, dtxsid_cols, enrichment_cache = NULL) {
  allowed_statuses <- c("disagree", "auto_resolved", "suggested")
  if (!df$consensus_status[row_idx] %in% allowed_statuses) {
    return(list())
  }

  # Source tier human-readable labels
  tier_labels <- c(
    "exact" = "Exact match",
    "cas" = "CAS lookup",
    "starts_with" = "Starts-with",
    "miss" = "No match",
    "cas_no_match" = "No match",
    "cas_invalid" = "No match",
    "wqx_exact" = "WQX Exact",
    "wqx_alias" = "WQX Alias",
    "wqx_fuzzy" = "WQX Fuzzy"
  )

  wqx_evidence_cols <- find_wqx_evidence_only_cols(df, dtxsid_cols, row_idx)

  options <- list()
  for (col in dtxsid_cols) {
    val <- df[[col]][row_idx]
    is_evidence_only <- is.na(val) && col %in% wqx_evidence_cols
    if (!is.na(val) || is_evidence_only) {
      # Get corresponding preferredName and rank
      pref_col <- source_field_column(col, "preferredName")
      rank_col <- source_field_column(col, "rank")
      tier_col <- source_field_column(col, "source_tier")
      pref_name <- if (pref_col %in% names(df)) df[[pref_col]][row_idx] else NA_character_
      rank_val <- if (rank_col %in% names(df)) df[[rank_col]][row_idx] else NA_real_

      # Source attribution
      source_column <- source_column_name(col)
      raw_tier <- if (tier_col %in% names(df)) as.character(df[[tier_col]][row_idx]) else NA_character_
      source_tier <- if (!is.na(raw_tier) && raw_tier %in% names(tier_labels)) {
        unname(tier_labels[raw_tier])
      } else {
        "Unknown"
      }

      # Enrichment metadata from cache
      enrich_casrn <- NA_character_
      enrich_formula <- NA_character_
      enrich_mw <- NA_real_
      if (!is.na(val) && !is.null(enrichment_cache) && nrow(enrichment_cache) > 0) {
        match_idx <- which(enrichment_cache$dtxsid == val)
        if (length(match_idx) > 0) {
          enrich_casrn <- enrichment_cache$casrn[match_idx[1]]
          enrich_formula <- enrichment_cache$molecular_formula[match_idx[1]]
          enrich_mw <- enrichment_cache$molecular_weight[match_idx[1]]
        }
      }

      options[[col]] <- list(
        dtxsid = val,
        preferredName = pref_name,
        rank = rank_val,
        source_column = source_column,
        source_tier = source_tier,
        casrn = enrich_casrn,
        molecular_formula = enrich_formula,
        molecular_weight = enrich_mw,
        evidence_only = is_evidence_only
      )
    }
  }

  # Sort by rank (lowest/best first), NAs last
  if (length(options) > 1) {
    ranks <- sapply(options, function(o) if (is.na(o$rank)) Inf else as.numeric(o$rank))
    options <- options[order(ranks)]
  }

  options
}

# ============================================================================
# score_one_candidate
# ============================================================================

#' Compute similarity score for a single candidate against an input name
#'
#' Score formula (per D-03): max(JW(input, preferredName, synonym_1, ..., synonym_N)).
#' If candidate rank <= 3, add +0.05 bonus. Clamp final score to `[0, 1]`.
#' All synonym tiers treated equally (per D-04).
#'
#' @param input_name Character scalar -- user's original chemical name (per D-07)
#' @param preferred_name Character scalar -- candidate's CompTox preferred name (NA allowed)
#' @param synonyms_str Character scalar -- pipe-joined synonyms from enrichment cache (NA allowed)
#' @param rank Numeric scalar -- candidate's rank value (NA allowed; bonus only if <= 3)
#' @return Numeric scalar in `[0, 1]`, or NA_real_ if no valid comparison possible
#' @export
score_one_candidate <- function(input_name, preferred_name, synonyms_str, rank) {
  if (is.na(input_name) || nchar(trimws(input_name)) == 0) {
    return(NA_real_)
  }

  syns <- if (!is.na(synonyms_str)) strsplit(synonyms_str, "|", fixed = TRUE)[[1]] else character(0)
  all_names <- c(preferred_name, syns)
  all_names <- all_names[!is.na(all_names) & nchar(trimws(all_names)) > 0]

  if (length(all_names) == 0) {
    return(NA_real_)
  }

  sims <- 1 - stringdist::stringdist(tolower(input_name), tolower(all_names), method = "jw")
  base_score <- max(sims, na.rm = TRUE)

  bonus <- if (!is.na(rank) && rank <= 3) 0.05 else 0.0
  min(1.0, base_score + bonus)
}

# ============================================================================
# compute_similarity_scores
# ============================================================================

#' Compute similarity scores for all disagree rows in resolution_state
#'
#' For each disagree row, scores each candidate DTXSID by comparing the user's
#' original Name-tagged column value against the candidate's preferredName and
#' all cached synonyms. Returns the best (max) candidate score per row.
#' Non-disagree rows get NA_real_.
#'
#' @param resolution_state Data frame with consensus_status, dtxsid_*, preferredName_*, rank_* columns
#' @param enrichment_cache Tibble with dtxsid and (optionally) synonyms columns
#' @param dtxsid_cols Character vector of dtxsid column names (e.g., c("dtxsid_Chemical", "dtxsid_CAS"))
#' @param column_tags Named list (col_name -> "Name"|"CASRN"|"Other") -- used to find input name column
#' @return resolution_state with similarity_score column added
#' @export
compute_similarity_scores <- function(resolution_state, enrichment_cache, dtxsid_cols, column_tags) {
  n <- nrow(resolution_state)
  scores <- rep(NA_real_, n)

  # Identify the Name-tagged column (per D-07: input is always user's original chemical name)
  name_cols <- names(column_tags)[column_tags == "Name"]
  if (length(name_cols) == 0) {
    message("[scoring] No Name-tagged column found -- skipping similarity scoring")
    resolution_state$similarity_score <- scores
    return(resolution_state)
  }
  name_col <- name_cols[1] # Use first Name-tagged column

  disagree_idx <- which(resolution_state$consensus_status == "disagree")

  if (length(disagree_idx) == 0) {
    resolution_state$similarity_score <- scores
    return(resolution_state)
  }

  has_synonyms <- !is.null(enrichment_cache) &&
    nrow(enrichment_cache) > 0 &&
    "synonyms" %in% names(enrichment_cache)

  # Pre-build dtxsid -> synonyms lookup for O(1) access
  syn_lookup <- if (has_synonyms) {
    stats::setNames(enrichment_cache$synonyms, enrichment_cache$dtxsid)
  } else {
    character(0)
  }

  for (i in disagree_idx) {
    input_name <- as.character(resolution_state[[name_col]][i])
    if (is.na(input_name) || nchar(trimws(input_name)) == 0) {
      next
    }

    candidate_scores <- numeric(0)

    for (col in dtxsid_cols) {
      dtxsid_val <- resolution_state[[col]][i]
      if (is.na(dtxsid_val)) {
        next
      }

      pref_col <- sub("^dtxsid_", "preferredName_", col)
      rank_col <- sub("^dtxsid_", "rank_", col)
      pref_name <- if (pref_col %in% names(resolution_state)) resolution_state[[pref_col]][i] else NA_character_
      rank_val <- if (rank_col %in% names(resolution_state)) resolution_state[[rank_col]][i] else NA_real_

      # Get synonyms from pre-built lookup
      synonyms_str <- if (length(syn_lookup) > 0 && dtxsid_val %in% names(syn_lookup)) {
        syn_lookup[[dtxsid_val]]
      } else {
        NA_character_
      }

      cs <- score_one_candidate(input_name, pref_name, synonyms_str, rank_val)
      if (!is.na(cs)) candidate_scores <- c(candidate_scores, cs)
    }

    if (length(candidate_scores) > 0) {
      scores[i] <- max(candidate_scores)
    }
  }

  resolution_state$similarity_score <- scores
  resolution_state
}

# ============================================================================
# resolve_row
# ============================================================================

#' Resolve a single disagreement row by choosing a preferred column
#'
#' @param df Classified data frame
#' @param row_idx Integer row index
#' @param chosen_column Character: name of the dtxsid column to use
#' @param dtxsid_cols Character vector of DTXSID column names
#' @return Modified df with consensus filled and row pinned
#' @export
resolve_row <- function(df, row_idx, chosen_column, dtxsid_cols) {
  # Validate row status allows resolution (disagree, auto_resolved, or suggested)
  allowed_statuses <- c("disagree", "auto_resolved", "suggested")
  if (!df$consensus_status[row_idx] %in% allowed_statuses) {
    stop("Row ", row_idx, " cannot be resolved (status: ", df$consensus_status[row_idx], ")")
  }

  # Validate chosen_column exists and has data
  if (!chosen_column %in% dtxsid_cols) {
    stop("Column '", chosen_column, "' is not in dtxsid_cols")
  }

  val <- df[[chosen_column]][row_idx]
  if (is.na(val)) {
    stop("Column '", chosen_column, "' has NA value for row ", row_idx)
  }

  # Initialize resolution state
  df <- init_resolution_state(df)

  # Set consensus
  df$consensus_dtxsid[row_idx] <- val
  df$consensus_source[row_idx] <- sub("^dtxsid_", "", chosen_column)
  df$.pinned[row_idx] <- TRUE
  df$.resolution_method[row_idx] <- "manual"

  df
}

# ============================================================================
# apply_priority_chain
# ============================================================================

#' Apply en masse column priority to resolve all non-pinned disagree rows
#'
#' @param df Classified data frame
#' @param priority_order Character vector of dtxsid column names ranked by preference
#' @param dtxsid_cols Character vector of all DTXSID column names
#' @return Modified df with consensus filled for resolved rows
#' @export
apply_priority_chain <- function(df, priority_order, dtxsid_cols) {
  df <- init_resolution_state(df)

  for (i in seq_len(nrow(df))) {
    # Only process disagree rows that are not pinned
    if (df$consensus_status[i] != "disagree") {
      next
    }
    if (isTRUE(df$.pinned[i])) {
      next
    }

    # Walk priority order, pick first with non-NA value
    for (col in priority_order) {
      val <- df[[col]][i]
      if (!is.na(val)) {
        df$consensus_dtxsid[i] <- val
        df$consensus_source[i] <- sub("^dtxsid_", "", col)
        break
      }
    }
  }

  df
}

# ============================================================================
# classify_auto_resolve
# ============================================================================

#' Classify disagree rows as auto-resolved, suggested, or leave as disagree
#'
#' Runs after compute_similarity_scores(). For each disagree row, collects
#' per-candidate scores and applies threshold logic (D-01/D-02/D-03):
#'   - Auto-resolve: best score >= 0.95 AND gap >= 0.15
#'   - Suggest: best score >= 0.70 (but not auto-resolve eligible)
#'   - Leave as disagree: best score < 0.70
#'
#' @param resolution_state Data frame with consensus_status, similarity_score, dtxsid_*,
#'   preferredName_*, rank_* columns
#' @param enrichment_cache Tibble with dtxsid and (optionally) synonyms columns
#' @param dtxsid_cols Character vector of dtxsid column names
#' @param column_tags Named list (col_name -> "Name"|"CASRN"|"Other")
#' @param auto_threshold Numeric, minimum score for auto-resolve (default 0.95, per D-01)
#' @param gap_threshold Numeric, minimum gap between best and second-best (default 0.15, per D-03)
#' @param suggest_threshold Numeric, minimum score for suggestion (default 0.70, per D-02)
#' @return resolution_state with updated consensus_status, .pinned, .resolution_method,
#'   .resolution_reason, and .suggested_column columns
#' @export
classify_auto_resolve <- function(
  resolution_state,
  enrichment_cache,
  dtxsid_cols,
  column_tags,
  auto_threshold = 0.95,
  gap_threshold = 0.15,
  suggest_threshold = 0.70
) {
  resolution_state <- init_resolution_state(resolution_state)

  # Add .suggested_column column if not present
  if (!".suggested_column" %in% names(resolution_state)) {
    resolution_state$.suggested_column <- NA_character_
  }

  # Identify the Name-tagged column (same pattern as compute_similarity_scores)
  name_cols <- names(column_tags)[column_tags == "Name"]
  if (length(name_cols) == 0) {
    message("[classify_auto_resolve] No Name-tagged column found -- skipping classification")
    return(resolution_state)
  }
  name_col <- name_cols[1]

  # Only process non-pinned disagree rows
  # Use vectorized !is.na() + logical comparison rather than isTRUE() (scalar-only)
  pinned_vec <- !is.na(resolution_state$.pinned) & resolution_state$.pinned
  disagree_idx <- which(
    resolution_state$consensus_status == "disagree" & !pinned_vec
  )

  if (length(disagree_idx) == 0) {
    return(resolution_state)
  }

  has_synonyms <- !is.null(enrichment_cache) &&
    nrow(enrichment_cache) > 0 &&
    "synonyms" %in% names(enrichment_cache)

  # Pre-build dtxsid -> synonyms lookup for O(1) access
  syn_lookup <- if (has_synonyms) {
    stats::setNames(enrichment_cache$synonyms, enrichment_cache$dtxsid)
  } else {
    character(0)
  }

  # Pre-build column name -> stripped source name map (avoids repeated sub() in loop)
  source_names <- stats::setNames(
    sub("^dtxsid_", "", dtxsid_cols),
    dtxsid_cols
  )

  for (i in disagree_idx) {
    input_name <- as.character(resolution_state[[name_col]][i])
    if (is.na(input_name) || nchar(trimws(input_name)) == 0) {
      next
    }

    # Collect per-candidate scores as a named numeric vector (name = column name)
    candidate_scores <- numeric(0)

    for (col in dtxsid_cols) {
      dtxsid_val <- resolution_state[[col]][i]
      if (is.na(dtxsid_val)) {
        next
      }

      pref_col <- sub("^dtxsid_", "preferredName_", col)
      rank_col <- sub("^dtxsid_", "rank_", col)
      pref_name <- if (pref_col %in% names(resolution_state)) {
        resolution_state[[pref_col]][i]
      } else {
        NA_character_
      }
      rank_val <- if (rank_col %in% names(resolution_state)) {
        resolution_state[[rank_col]][i]
      } else {
        NA_real_
      }

      synonyms_str <- if (length(syn_lookup) > 0 && dtxsid_val %in% names(syn_lookup)) {
        syn_lookup[[dtxsid_val]]
      } else {
        NA_character_
      }

      cs <- score_one_candidate(input_name, pref_name, synonyms_str, rank_val)
      if (!is.na(cs)) {
        candidate_scores[col] <- cs
      }
    }

    if (length(candidate_scores) == 0) {
      next
    }

    # Sort descending to get best and second-best
    candidate_scores <- sort(candidate_scores, decreasing = TRUE)
    best_score <- candidate_scores[1]
    best_col <- names(candidate_scores)[1]
    second_best <- if (length(candidate_scores) >= 2) candidate_scores[2] else 0.0
    gap <- best_score - second_best

    if (best_score >= auto_threshold && gap >= gap_threshold) {
      # Auto-resolve: clear winner with sufficient margin
      resolution_state$consensus_status[i] <- "auto_resolved"
      resolution_state$.pinned[i] <- TRUE
      resolution_state$.resolution_method[i] <- "auto"
      resolution_state$.resolution_reason[i] <- sprintf(
        "score=%.2f, gap=%.2f, threshold=%.2f",
        best_score,
        gap,
        auto_threshold
      )
      resolution_state$consensus_dtxsid[i] <- resolution_state[[best_col]][i]
      resolution_state$consensus_source[i] <- source_names[[best_col]]
      resolution_state$.suggested_column[i] <- best_col
    } else if (best_score >= suggest_threshold) {
      # Suggest: good score but not conclusive enough to auto-resolve
      resolution_state$consensus_status[i] <- "suggested"
      # .pinned stays FALSE -- user must act
      resolution_state$.resolution_method[i] <- NA_character_
      resolution_state$.resolution_reason[i] <- sprintf(
        "score=%.2f, gap=%.2f, suggest_threshold=%.2f",
        best_score,
        gap,
        suggest_threshold
      )
      resolution_state$.suggested_column[i] <- best_col
    }
    # else: leave as "disagree" -- best score below suggest_threshold
  }

  resolution_state
}

# ============================================================================
# accept_all_suggestions
# ============================================================================

#' Accept all suggested resolutions in bulk
#'
#' For each row with consensus_status == "suggested" that is not pinned,
#' resolves to the best-scoring candidate (stored in .suggested_column).
#' Sets .resolution_method to "bulk-accept" and .pinned to TRUE.
#'
#' @param df Data frame with consensus_status, .suggested_column, dtxsid_* columns
#' @param dtxsid_cols Character vector of DTXSID column names
#' @return Modified df with suggested rows resolved
#' @export
accept_all_suggestions <- function(df, dtxsid_cols) {
  df <- init_resolution_state(df)

  for (i in seq_len(nrow(df))) {
    if (df$consensus_status[i] != "suggested") {
      next
    }
    if (isTRUE(df$.pinned[i])) {
      next
    }

    best_col <- df$.suggested_column[i]
    if (is.na(best_col) || !best_col %in% dtxsid_cols) {
      next
    }

    val <- df[[best_col]][i]
    if (is.na(val)) {
      next
    }

    df$consensus_dtxsid[i] <- val
    df$consensus_source[i] <- sub("^dtxsid_", "", best_col)
    df$.pinned[i] <- TRUE
    df$.resolution_method[i] <- "bulk-accept"
    # Preserve existing .resolution_reason from classification
  }

  df
}
