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
