# Accepted identity policy is separate from lookup consensus.
identity_policy_version <- function() "1"

identity_col <- function(df, name, default = NA_character_) {
  df[[name]] %||% rep(default, nrow(df))
}

identity_scope_blockers <- function(df) {
  n <- nrow(df)
  scope <- identity_col(df, "identity_scope")
  conflict <- identity_col(df, "identity_conflict")
  multi <- is_multi_analyte_review_row(df)
  component <- identity_col(df, "component_cas_unresolved", FALSE) %in% TRUE
  combined <- identity_col(df, "multi_analyte_resolution") %in% "keep_combined"
  scope_resolved <- identity_col(df, "identity_scope_reviewed", FALSE) %in% TRUE &
    scope %in% c("substance", "registered_mixture") &
    identity_decision_current_rows(df)
  list(
    scope = (multi | component | combined | scope %in% c("unknown", "aggregate", "class", "registered_mixture")) & !scope_resolved,
    conflict = !is.na(conflict) & nzchar(trimws(conflict)) & !conflict %in% "none",
    stale = identity_col(df, "identity_scope_reviewed", FALSE) %in% TRUE &
      !identity_decision_current_rows(df)
  )
}

# Explicit source-ID roles retain validation and correspondence separately.
# Missing source IDs do not invalidate otherwise legitimate Name/CAS lookups.
source_identity_blockers <- function(df) {
  n <- nrow(df)
  out <- list(invalid = rep(FALSE, n), unavailable = rep(FALSE, n),
              ambiguous = rep(FALSE, n), conflict = rep(FALSE, n), scope = rep(FALSE, n),
              correspondence = rep(FALSE, n))
  resolved <- identity_decision_current_rows(df)
  selected <- identity_col(df, "consensus_dtxsid")
  manual <- identity_col(df, ".manual_entry", FALSE) %in% TRUE |
    identity_col(df, "consensus_status") %in% "manual" |
    identity_col(df, "consensus_source") %in% c("manual_entry", "source_dtxsid") |
    identity_col(df, ".resolution_method") %in% c("manual", "user-pick", "bulk-accept")
  # A generic manual entry is not a source-correspondence decision. Only lookup
  # columns owned by the pipeline can establish independent supporting evidence;
  # generic dtxsid_* detection would let raw metadata bypass this gate.
  supported <- rep(FALSE, n)
  if ("lookup_evidence_columns" %in% names(df)) {
    for (i in which(manual & !is.na(selected))) {
      cols <- find_dtxsid_cols(df[i, , drop = FALSE])
      cols <- setdiff(cols, find_wqx_evidence_only_cols(df, cols, i))
      for (col in cols) {
        tier <- identity_col(df, source_field_column(col, "source_tier"))[i]
        if (!is.na(tier) && tier %in% c("manual", "manual_entry", "source_metadata")) next
        value <- df[[col]][i]
        if (!is.na(value) && identical(as.character(value), as.character(selected[i]))) supported[i] <- TRUE
      }
    }
  }
  stems <- unique(sub("_(validation_status|identity_status)$", "",
    grep("^source_id_.*_(validation_status|identity_status)$", names(df), value = TRUE)))
  for (stem in stems) {
    status <- identity_col(df, paste0(stem, "_validation_status"))
    identity <- identity_col(df, paste0(stem, "_identity_status"))
    raw <- identity_col(df, paste0(stem, "_source_raw_id"))
    candidate <- identity_col(df, paste0(stem, "_source_candidate_id"))
    present <- (!is.na(raw) & nzchar(trimws(raw))) | (!is.na(candidate) & nzchar(trimws(candidate)))
    active <- present & !resolved
    out$invalid <- out$invalid | (active & status %in% c("invalid_format", "not_found", "returned_id_mismatch"))
    out$ambiguous <- out$ambiguous | (active & status %in% "ambiguous")
    out$unavailable <- out$unavailable | (active & (is.na(status) |
      !status %in% c("validated", "invalid_format", "not_found", "returned_id_mismatch", "ambiguous")))
    out$conflict <- out$conflict | (!resolved & identity %in% "identity_conflict")
    out$scope <- out$scope | (!resolved & identity %in% "scope_review")
    matching_source <- !is.na(candidate) & !is.na(selected) &
      normalize_source_dtxsid(candidate) == as.character(selected)
    out$correspondence <- out$correspondence | (active & matching_source & manual & !supported)
  }
  out
}

#' Derive accepted identity eligibility from current evidence
#'
#' Lookup consensus remains provisional when review, scope or source conflicts
#' are unresolved. Derived fields are recomputed and must not be used as replay
#' authority. Registry existence and source correspondence are separate checks.
#' @param df Curated row data with consensus and optional review fields.
#' @return A tibble with identity_status, identity_blockers, identity_eligible,
#'   and accepted_dtxsid, aligned to the input rows.
#' @export
identity_review_state <- function(df) {
  n <- nrow(df)
  id <- as.character(identity_col(df, "consensus_dtxsid"))
  status <- identity_col(df, "consensus_status")
  flag <- identity_col(df, "row_flag")
  scope <- identity_scope_blockers(df)
  source <- source_identity_blockers(df)
  accepted_suggestion <- status %in% "suggested" &
    identity_col(df, ".pinned", FALSE) %in% TRUE &
    identity_col(df, ".resolution_method") %in% c("bulk-accept", "manual", "user-pick")
  blockers <- list(
    missing_identity = is.na(id) | !grepl("^DTXSID[0-9]+$", id),
    unresolved_lookup = !status %in% c("agree", "agree_caveat", "single", "manual", "auto_resolved") &
      !accepted_suggestion,
    follow_up = flag %in% "FOLLOW-UP",
    excluded = flag %in% "BAD",
    incoming_review = identity_col(df, "needs_review", FALSE) %in% TRUE,
    unresolved_scope = scope$scope,
    source_conflict = scope$conflict,
    stale_scope_decision = scope$stale,
    source_identifier_invalid = source$invalid,
    source_identifier_unavailable = source$unavailable,
    source_identifier_ambiguous = source$ambiguous,
    source_identity_conflict = source$conflict,
    source_identity_scope = source$scope,
    source_correspondence_unconfirmed = source$correspondence
  )
  text <- rep("", n)
  for (key in names(blockers)) {
    hit <- blockers[[key]] %in% TRUE
    text[hit] <- ifelse(nzchar(text[hit]), paste(text[hit], key, sep = "; "), key)
  }
  eligible <- !nzchar(text)
  tibble::tibble(
    identity_status = ifelse(eligible, "accepted", "provisional"),
    identity_blockers = text,
    identity_eligible = eligible,
    accepted_dtxsid = ifelse(eligible, id, NA_character_)
  )
}

#' Return accepted identities with source lineage
#' @param df Curated row data.
#' @return Eligible rows with recomputed acceptance fields; all source columns
#'   and measurements are retained.
#' @export
accepted_identity_view <- function(df) {
  state <- identity_review_state(df)
  df[names(state)] <- state
  df[state$identity_eligible, , drop = FALSE]
}
