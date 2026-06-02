# Shared post-curation enrichment, scoring, and auto-resolution helpers.

collect_candidate_dtxsids <- function(resolution_state, dtxsid_cols = NULL) {
  if (is.null(resolution_state) || nrow(resolution_state) == 0) {
    return(character(0))
  }

  dtxsid_cols <- dtxsid_cols %||% find_dtxsid_cols(resolution_state)
  all_unique_dtxsids <- character(0)

  disagree_idx <- which(resolution_state$consensus_status == "disagree")
  if (length(disagree_idx) > 0 && length(dtxsid_cols) > 0) {
    for (dc in dtxsid_cols) {
      vals <- resolution_state[[dc]][disagree_idx]
      all_unique_dtxsids <- c(all_unique_dtxsids, vals[!is.na(vals)])
    }
  }

  resolved_idx <- which(
    resolution_state$consensus_status %in%
      c("agree", "agree_caveat", "single", "manual", "auto_resolved", "suggested")
  )
  if (length(resolved_idx) > 0 && "consensus_dtxsid" %in% names(resolution_state)) {
    consensus_vals <- resolution_state$consensus_dtxsid[resolved_idx]
    all_unique_dtxsids <- c(all_unique_dtxsids, consensus_vals[!is.na(consensus_vals)])
  }

  keep <- !is.na(all_unique_dtxsids) & nzchar(all_unique_dtxsids)
  unique(all_unique_dtxsids[keep])
}

empty_postprocess_result <- function(resolution_state, enrichment_cache, enrichment_failed) {
  list(
    resolution_state = resolution_state,
    enrichment_cache = enrichment_cache,
    enrichment_failed = enrichment_failed %||% character(0),
    consensus_summary = recalc_consensus_summary(resolution_state),
    n_dtxsids = 0L,
    n_enriched = 0L,
    n_total = if (!is.null(enrichment_cache)) nrow(enrichment_cache) else 0L,
    n_failed = length(enrichment_failed %||% character(0)),
    n_auto = sum(resolution_state$consensus_status == "auto_resolved", na.rm = TRUE),
    n_suggested = sum(resolution_state$consensus_status == "suggested", na.rm = TRUE)
  )
}

postprocess_curation_candidates <- function(
  resolution_state,
  column_tags,
  dtxsid_cols = NULL,
  enrichment_cache = NULL
) {
  resolution_state <- init_resolution_state(resolution_state)
  dtxsid_cols <- dtxsid_cols %||% find_dtxsid_cols(resolution_state)
  enrichment_failed <- character(0)

  all_unique_dtxsids <- collect_candidate_dtxsids(resolution_state, dtxsid_cols)
  if (length(all_unique_dtxsids) == 0) {
    return(empty_postprocess_result(resolution_state, enrichment_cache, enrichment_failed))
  }

  enrich_result <- enrich_candidates(
    dtxsids = all_unique_dtxsids,
    existing_cache = enrichment_cache
  )
  enrichment_cache <- enrich_result$cache
  enrichment_failed <- enrich_result$failed_dtxsids

  synonym_result <- enrich_synonyms(
    dtxsids = all_unique_dtxsids,
    existing_cache = enrichment_cache
  )
  enrichment_cache <- synonym_result$cache

  if (
    !is.null(resolution_state) &&
      length(dtxsid_cols) > 0 &&
      !is.null(column_tags) &&
      length(column_tags) > 0
  ) {
    resolution_state <- compute_similarity_scores(
      resolution_state = resolution_state,
      enrichment_cache = enrichment_cache,
      dtxsid_cols = dtxsid_cols,
      column_tags = column_tags
    )

    resolution_state <- classify_auto_resolve(
      resolution_state = resolution_state,
      enrichment_cache = enrichment_cache,
      dtxsid_cols = dtxsid_cols,
      column_tags = column_tags
    )
  }

  list(
    resolution_state = resolution_state,
    enrichment_cache = enrichment_cache,
    enrichment_failed = enrichment_failed,
    consensus_summary = recalc_consensus_summary(resolution_state),
    n_dtxsids = length(all_unique_dtxsids),
    n_enriched = if (!is.null(enrichment_cache) && "casrn" %in% names(enrichment_cache)) {
      sum(!is.na(enrichment_cache$casrn))
    } else {
      0L
    },
    n_total = if (!is.null(enrichment_cache)) nrow(enrichment_cache) else 0L,
    n_failed = length(enrichment_failed),
    n_auto = sum(resolution_state$consensus_status == "auto_resolved", na.rm = TRUE),
    n_suggested = sum(resolution_state$consensus_status == "suggested", na.rm = TRUE)
  )
}
