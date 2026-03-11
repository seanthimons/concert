# Consensus Logic: DTXSID comparison across tagged columns
#
# Row-level classification and QC tier scoring for chemical inventory data.
# Consumes output from prototype_pipeline.R (map_results_to_rows).

library(dplyr)
library(tibble)

# ============================================================================
# find_dtxsid_cols
# ============================================================================

#' Auto-detect DTXSID columns by name pattern
#'
#' @param df Data frame with lookup results
#' @return Character vector of column names matching "dtxsid_*"
find_dtxsid_cols <- function(df) {
  grep("^dtxsid_", names(df), value = TRUE)
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
compute_qc_tier <- function(status, n_matched, n_total) {
  tier <- switch(status,
    "agree" = 1L,
    "agree_caveat" = 1L + as.integer(n_total - n_matched),
    "single" = as.integer(n_total),
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
#' "disagree", and "error". Downstream code (manual validation flow, retry merge)
#' may add additional status values: "manual" (manually-entered DTXSID) and
#' "unresolvable" (error persisting after retry).
#'
#' @param df Data frame with DTXSID columns from map_results_to_rows()
#' @param dtxsid_cols Character vector of DTXSID column names to compare
#' @return Original df with added columns: consensus_status, consensus_dtxsid,
#'         consensus_source, qc_tier
classify_consensus <- function(df, dtxsid_cols) {
  k <- length(dtxsid_cols)

  # Compute per-row classification
  consensus_status <- character(nrow(df))
  consensus_dtxsid <- character(nrow(df))
  consensus_source <- character(nrow(df))
  qc_tier <- integer(nrow(df))

  for (i in seq_len(nrow(df))) {
    # Extract DTXSIDs for this row across all tagged columns
    values <- vapply(dtxsid_cols, function(col) {
      val <- df[[col]][i]
      if (is.na(val)) NA_character_ else as.character(val)
    }, character(1))

    non_na <- values[!is.na(values)]
    n_present <- length(non_na)
    unique_vals <- unique(non_na)
    n_unique <- length(unique_vals)

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
      consensus_source[i] <- sub("^dtxsid_", "", src_col)
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
#' Adds .pinned column (FALSE) and .manual_entry column (FALSE) if not already present.
#'
#' @param df Data frame (typically output of classify_consensus)
#' @return df with .pinned and .manual_entry columns
init_resolution_state <- function(df) {
  if (!".pinned" %in% names(df)) {
    df$.pinned <- FALSE
  }
  if (!".manual_entry" %in% names(df)) {
    df$.manual_entry <- FALSE
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
#' @return Named list of column_name = list(dtxsid, preferredName, rank) for columns with data.
#'         Sorted by rank (best first). Empty list if row is not "disagree".
get_resolution_options <- function(df, row_idx, dtxsid_cols, enrichment_cache = NULL) {
  if (df$consensus_status[row_idx] != "disagree") {
    return(list())
  }

  # Source tier human-readable labels
  tier_labels <- c(
    "exact" = "Exact match",
    "cas" = "CAS lookup",
    "starts_with" = "Starts-with",
    "miss" = "No match",
    "cas_no_match" = "No match",
    "cas_invalid" = "No match"
  )

  options <- list()
  for (col in dtxsid_cols) {
    val <- df[[col]][row_idx]
    if (!is.na(val)) {
      # Get corresponding preferredName and rank
      pref_col <- sub("^dtxsid_", "preferredName_", col)
      rank_col <- sub("^dtxsid_", "rank_", col)
      tier_col <- sub("^dtxsid_", "source_tier_", col)
      pref_name <- if (pref_col %in% names(df)) df[[pref_col]][row_idx] else NA_character_
      rank_val <- if (rank_col %in% names(df)) df[[rank_col]][row_idx] else NA_real_

      # Source attribution
      source_column <- sub("^dtxsid_", "", col)
      raw_tier <- if (tier_col %in% names(df)) df[[tier_col]][row_idx] else NA_character_
      source_tier <- if (!is.na(raw_tier) && raw_tier %in% names(tier_labels)) {
        unname(tier_labels[raw_tier])
      } else {
        "Unknown"
      }

      # Enrichment metadata from cache
      enrich_casrn <- NA_character_
      enrich_formula <- NA_character_
      enrich_mw <- NA_real_
      if (!is.null(enrichment_cache) && nrow(enrichment_cache) > 0) {
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
        molecular_weight = enrich_mw
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
# resolve_row
# ============================================================================

#' Resolve a single disagreement row by choosing a preferred column
#'
#' @param df Classified data frame
#' @param row_idx Integer row index
#' @param chosen_column Character: name of the dtxsid column to use
#' @param dtxsid_cols Character vector of DTXSID column names
#' @return Modified df with consensus filled and row pinned
resolve_row <- function(df, row_idx, chosen_column, dtxsid_cols) {
  # Validate row is disagree

  if (df$consensus_status[row_idx] != "disagree") {
    stop("Row ", row_idx, " is not a disagree row (status: ", df$consensus_status[row_idx], ")")
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
apply_priority_chain <- function(df, priority_order, dtxsid_cols) {
  df <- init_resolution_state(df)

  for (i in seq_len(nrow(df))) {
    # Only process disagree rows that are not pinned
    if (df$consensus_status[i] != "disagree") next
    if (isTRUE(df$.pinned[i])) next

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
