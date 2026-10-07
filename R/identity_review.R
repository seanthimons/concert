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
    identity_col(df, "identity_decision_current", FALSE) %in% TRUE
  list(
    scope = (multi | component | combined | scope %in% c("unknown", "aggregate", "class")) & !scope_resolved,
    conflict = !is.na(conflict) & nzchar(trimws(conflict)) & !conflict %in% "none",
    stale = identity_col(df, "identity_scope_reviewed", FALSE) %in% TRUE &
      !identity_col(df, "identity_decision_current", FALSE) %in% TRUE
  )
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
    stale_scope_decision = scope$stale
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
