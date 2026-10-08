# Only pipeline-owned projections provide WQX review evidence. Raw input columns
# with matching names do not acquire an evidence role through their names.
wqx_review_columns <- function(df, fields = wqx_candidate_fields()) {
  cols <- unlist(lapply(find_dtxsid_cols(df), function(col) {
    vapply(fields, function(field) source_field_column(col, field), character(1))
  }), use.names = FALSE)
  intersect(unique(cols), names(df))
}

wqx_pending_field <- function(df, rows, field) {
  cols <- wqx_review_columns(df, field)
  vapply(rows, function(i) {
    values <- vapply(cols, function(col) as.character(df[[col]][i]), character(1))
    keep <- !is.na(values) & nzchar(trimws(values))
    if (!any(keep)) return(NA_character_)
    if (sum(keep) == 1L) return(unname(values[keep]))
    paste(paste0(cols[keep], "=", values[keep]), collapse = "; ")
  }, character(1))
}

# Registry membership of a vocabulary-derived candidate does not establish
# correspondence with the source. An explicit scoped decision can establish it.
wqx_correspondence_blockers <- function(df) {
  selected <- identity_col(df, "consensus_dtxsid")
  resolved <- identity_decision_current_rows(df)
  out <- rep(FALSE, nrow(df))
  for (i in which(!is.na(selected) & nzchar(trimws(selected)) & !resolved)) {
    wqx_cols <- find_wqx_evidence_only_cols(df, find_dtxsid_cols(df), i)
    if (!length(wqx_cols)) next
    lookup_cols <- setdiff(find_dtxsid_cols(df), wqx_cols)
    independent <- any(vapply(lookup_cols, function(col) {
      value <- df[[col]][i]
      tier <- identity_col(df, source_field_column(col, "source_tier"))[i]
      !is.na(value) && identical(as.character(value), as.character(selected[i])) &&
        !is.na(tier) && !tier %in% c("manual", "manual_entry", "source_metadata")
    }, logical(1)))
    out[i] <- !independent
  }
  out
}
