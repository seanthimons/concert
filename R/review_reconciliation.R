# Read-only selected-identity reconciliation consumer of the shared contract.
#' Construct a stable content-selector decision ID
#' @param name Reviewed source name.
#' @param casrn Optional reviewed CAS selector.
#' @return Stable decision identifier for capture_review_decision().
#' @export
review_decision_key <- function(name, casrn = NA_character_) {
  paste0("selector:", review_evidence_fingerprint(list(name = review_evidence_text(name),
    casrn = review_evidence_text(casrn))))
}

empty_review_reconciliation <- function() {
  data.frame(decision_id = character(), revision = integer(), row_index = integer(),
    name = character(), casrn = character(), flag = character(), reason = character(),
    disposition = character(), baseline_status = character(), change_category = character(),
    prior_selected_identity = character(), current_automated_identity = character(),
    current_final_identity = character(), prior_candidates = character(), current_candidates = character(),
    scope_fingerprint = character(), current_fingerprint = character(), acknowledged = logical(),
    actionable = logical(), recommended_action = character(), stringsAsFactors = FALSE)
}

review_snapshot_ids <- function(snapshot, field = "automated") {
  if (is.null(snapshot)) return(character())
  ids <- vapply(snapshot[[field]], function(row) {
    if (is.null(row$consensus_dtxsid)) NA_character_ else as.character(row$consensus_dtxsid)
  }, character(1))
  sort(unique(ids[!is.na(ids) & nzchar(ids)]))
}

review_snapshot_candidates <- function(snapshot) {
  if (is.null(snapshot) || !NROW(snapshot$candidates)) return(character())
  with(snapshot$candidates, sort(unique(paste(source, role, ifelse(is.na(cid), "", cid), dtxsid, sep = ":"))))
}

build_review_reconciliation <- function(automated, final = automated, row_flags = NULL,
                                        evidence = NULL, name_col, cas_col = NA_character_,
                                        scope_data = automated, scope_cols = c(name_col, cas_col),
                                        validation = NULL, source_id_cols = "source_dtxsid") {
  evidence <- validate_review_evidence(evidence)
  if (is.null(row_flags) || !NROW(row_flags)) return(empty_review_reconciliation())
  flags <- as.data.frame(row_flags, stringsAsFactors = FALSE)
  if (!all(c("name", "flag") %in% names(flags))) stop("row_flags requires name and flag.", call. = FALSE)
  if (!name_col %in% names(automated)) stop("Reconciliation requires the name column.", call. = FALSE)
  for (col in c("casrn", "reason", "decision_id")) if (!col %in% names(flags)) flags[[col]] <- NA_character_
  scope_cols <- scope_cols[!is.na(scope_cols) & nzchar(scope_cols)]
  rows <- vector("list", nrow(flags))
  scalar <- function(x) if (length(x)) paste(x, collapse = "; ") else NA_character_
  for (i in seq_len(nrow(flags))) {
    id <- review_evidence_text(flags$decision_id[i])
    if (is.na(id)) id <- review_decision_key(flags$name[i], flags$casrn[i])
    mask <- !is.na(automated[[name_col]]) & automated[[name_col]] == flags$name[i]
    cas <- review_evidence_text(flags$casrn[i])
    missing_cas_scope <- !is.na(cas) && (is.na(cas_col) || !cas_col %in% names(automated))
    if (!is.na(cas) && !missing_cas_scope) {
      mask <- mask & !is.na(automated[[cas_col]]) & automated[[cas_col]] == cas
    }
    idx <- which(mask)
    if (!length(idx) || missing_cas_scope) {
      row <- empty_review_reconciliation()[NA_integer_, , drop = FALSE]
      row$decision_id <- id
      row$name <- flags$name[i]
      row$casrn <- cas
      row$flag <- flags$flag[i]
      row$reason <- flags$reason[i]
      row$baseline_status <- if (missing_cas_scope) "scope_changed" else "target_missing"
      row$change_category <- row$baseline_status
      row$acknowledged <- FALSE
      row$actionable <- TRUE
      row$recommended_action <- "Review decision target and source/content scope"
      rows[[i]] <- row
      next
    }
    scope <- review_evidence_scope(scope_data, idx, scope_cols)
    current <- review_evidence_snapshot(automated, final, idx, validation, source_id_cols, scope_cols)
    comparison <- compare_review_decision(evidence, id, scope, current)
    prior <- comparison$decision
    old_ids <- review_snapshot_ids(if (is.null(prior)) NULL else prior$current)
    new_ids <- review_snapshot_ids(current)
    old_candidates <- review_snapshot_candidates(if (is.null(prior)) NULL else prior$current)
    new_candidates <- review_snapshot_candidates(current)
    category <- comparison$status
    if (category == "baseline_missing" && length(new_ids)) category <- "legacy_flag_with_selected_identity"
    if (category == "changed") {
      category <- if (!length(old_ids) && length(new_ids)) "no_identity_to_selected" else
        if (!identical(old_ids, new_ids)) "selected_identity_changed" else
        if (!identical(old_candidates, new_candidates)) "candidate_evidence_changed" else "validation_or_lookup_changed"
    }
    actionable <- comparison$status %in% c("changed", "scope_changed", "baseline_missing")
    ids <- if ("original_row_id" %in% names(final)) as.integer(final$original_row_id[idx]) else idx
    rows[[i]] <- data.frame(decision_id = id,
      revision = if (is.null(prior)) NA_integer_ else prior$revision, row_index = ids,
      name = as.character(automated[[name_col]][idx]), casrn = cas, flag = flags$flag[i], reason = flags$reason[i],
      disposition = if (is.null(prior)) NA_character_ else prior$disposition,
      baseline_status = comparison$status, change_category = category,
      prior_selected_identity = scalar(old_ids), current_automated_identity = scalar(new_ids),
      current_final_identity = scalar(review_snapshot_ids(current, "final")),
      prior_candidates = scalar(old_candidates), current_candidates = scalar(new_candidates),
      scope_fingerprint = review_evidence_fingerprint(scope), current_fingerprint = review_evidence_fingerprint(current),
      acknowledged = comparison$acknowledged, actionable = actionable,
      recommended_action = if (!actionable) "Retain recorded disposition" else if (comparison$status == "baseline_missing")
        "Review missing historical baseline; explicitly adopt present evidence or trusted history" else
        "Review changed evidence and source scope; explicitly revise or acknowledge", stringsAsFactors = FALSE)
  }
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  result
}
