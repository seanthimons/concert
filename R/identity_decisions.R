#' Capture current row evidence for a scoped identity decision
#'
#' This fingerprint binds an explicit decision to source content, lineage,
#' candidates and lookup outcomes. Flags and derived acceptance fields are not
#' evidence. Capture it after inspecting the row; a changed fingerprint requires
#' another explicit review. Version 2 records retain the source columns actually
#' reviewed and detect new chemical evidence. Unrelated new nonchemical columns
#' and enumerated harmonization outputs do not invalidate that decision.
#' @param df Current resolution data.
#' @param row Integer row position.
#' @return A versioned evidence fingerprint.
#' @export
identity_evidence_fingerprint <- function(df, row) {
  stopifnot(length(row) == 1L, row >= 1L, row <= nrow(df))
  record <- tryCatch(jsonlite::fromJSON(identity_col(df, "identity_decision_record")[row]),
                     error = function(e) NULL)
  columns <- if (!is.null(record) && identical(record$version, "2") &&
                 is.character(record$evidence_columns)) record$evidence_columns else NULL
  identity_fingerprint_v2(df, row, columns)
}

identity_evidence_columns <- function(df) {
  excluded <- c("row_flag", "row_flag_reason", "review_note", "needs_review", "identity_scope", "identity_conflict",
    "identity_scope_reviewed", "identity_decision_current", "identity_decision_fingerprint",
    "identity_decision_record", "identity_status", "identity_blockers", "identity_eligible", "accepted_dtxsid",
    "consensus_casrn", "consensus_formula", "consensus_mw")
  # These are established harmonization outputs, not changed chemical identity
  # evidence. Preserve original source names/CAS/IDs, lineage and all captured
  # source context outside this explicitly enumerated nonchemical boundary.
  harmonized <- c("media", "media_original", "media_category", "media_envo_id", "media_flag",
    paste0("media_", media_identity_fields()), "media_routing_status",
    "study_duration_value", "study_duration_units", "year", DETECTION_GENERATED_COLUMNS)
  cols <- setdiff(names(df)[!grepl("^\\.", names(df))], c(excluded, harmonized))
  sort(cols[!grepl("^source_id_.*_checked_at$", cols)])
}

identity_new_chemical_columns <- function(df) {
  names(df)[grepl(paste0("^(consensus_|dtxsid($|_)|preferredName($|_)|source_tier($|_)|",
    "match_tier($|_)|tied_dtxsids($|_)|lookup_evidence_columns$|source_id_|",
    "resolver_|pubchem_|parent_|multi_analyte_|component_|isotope_|wqx_)|",
    "(^|_)(name|cas|casrn|dtxsid|smiles|inchi|inchikey|formula|chemical|compound|substance)(_|$)"), names(df))]
}

identity_fingerprint_values <- function(df, row, cols, version) {
  paste0("identity-v", version, ":", digest::digest(identity_evidence_values(df, row, cols), algo = "sha256"))
}

# The evidence a fingerprint hashes: trimmed text per column, blanks dropped.
identity_evidence_values <- function(df, row, cols) {
  cols <- sort(intersect(cols, names(df)))
  values <- lapply(as.list(df[row, cols, drop = FALSE]), function(x) {
    x <- trimws(as.character(x)); x[is.na(x) | !nzchar(x)] <- NA_character_; x
  })
  # The qualifier warning restates the name, which is already evidence; keep it
  # out so adding the step does not stale existing decisions (#129).
  if (!is.null(values$cleaning_flag)) {
    flag <- gsub(paste0("(^|;\\s*)", measurement_qualifier_warning_label(), " \\[[^]]*\\]"), "", values$cleaning_flag)
    flag <- sub("^;\\s*", "", flag)
    values$cleaning_flag <- ifelse(is.na(flag) | !nzchar(flag), NA_character_, flag)
  }
  values[!vapply(values, function(x) all(is.na(x)), logical(1))]
}

identity_v2_columns <- function(df, columns = NULL) {
  eligible <- identity_evidence_columns(df)
  if (is.null(columns)) columns <- eligible
  # Keep the source columns actually reviewed, and detect new semantic chemical
  # evidence. New arbitrary nonchemical output columns cannot stale a decision.
  intersect(unique(c(columns, identity_new_chemical_columns(df))), eligible)
}

identity_fingerprint_v2 <- function(df, row, columns = NULL) {
  identity_fingerprint_values(df, row, identity_v2_columns(df, columns), "2")
}

# Readable form of what identity_evidence_fingerprint() hashes for a row with no applied decision.
identity_evidence_snapshot <- function(df, row) identity_evidence_values(df, row, identity_v2_columns(df))

identity_fingerprint_v1 <- function(df, row) {
  excluded <- c("row_flag", "row_flag_reason", "review_note", "needs_review", "identity_scope", "identity_conflict",
    "identity_scope_reviewed", "identity_decision_current", "identity_decision_fingerprint",
    "identity_decision_record", "identity_status", "identity_blockers", "identity_eligible", "accepted_dtxsid",
    "consensus_casrn", "consensus_formula", "consensus_mw")
  cols <- setdiff(names(df)[!grepl("^\\.", names(df))], excluded)
  cols <- cols[!grepl("^source_id_.*_checked_at$", cols)]
  identity_fingerprint_values(df, row, cols, "1")
}

identity_decision_current_rows <- function(df) {
  signature <- identity_col(df, "identity_decision_fingerprint")
  recorded <- identity_col(df, "identity_decision_record")
  out <- rep(FALSE, nrow(df))
  for (i in which(!is.na(signature) & !is.na(recorded))) {
    record <- tryCatch(jsonlite::fromJSON(recorded[i]), error = function(e) NULL)
    out[i] <- !is.null(record) && length(record$version) == 1L && !is.na(record$version) &&
      record$version %in% c("1", "2") &&
      (identical(record$version, "1") || is.character(record$evidence_columns)) &&
      identical(record$action, "accept") && identical(record$membership, "valid") &&
      isTRUE(record$correspondence) && identical(record$applied_fingerprint, signature[i]) &&
      identical(record$selected_dtxsid, as.character(identity_col(df, "consensus_dtxsid")[i])) &&
      identical(record$scope, as.character(identity_col(df, "identity_scope")[i])) &&
      identical(record$conflict, as.character(identity_col(df, "identity_conflict")[i])) &&
      identical(signature[i], if (identical(record$version, "1")) identity_fingerprint_v1(df, i) else
        identity_fingerprint_v2(df, i, record$evidence_columns))
  }
  out
}

#' Apply explicit row-scoped identity decisions
#'
#' Each list record needs a selector containing original_row_id and source
#' content column values, action (accept or retain_unresolved), scope, conflict,
#' reason, evidence_reference and evidence_fingerprint. Acceptance also needs
#' selected_dtxsid and correspondence=TRUE. Authoritative registry membership
#' is validated separately; unavailable validation cannot grant acceptance.
#' Ambiguous selectors fail without applying decisions. So does changed
#' evidence, unless `on_drift = "report"`.
#' @param state Curation state containing resolution_state.
#' @param identity_decisions List of explicit decision records.
#' @return State with preserved source evidence and recorded decisions.
#' @examples
#' \dontrun{
#' decision <- list(
#'   selector = list(original_row_id = 27L, chemical_name = "Registered combination"),
#'   action = "accept", scope = "registered_mixture", conflict = "none",
#'   selected_dtxsid = "DTXSID123", correspondence = TRUE,
#'   reason = "Source composition matches the registered combined entity",
#'   evidence_reference = "Reviewed source composition and authoritative registry record",
#'   evidence_fingerprint = identity_evidence_fingerprint(state$resolution_state, 27L)
#' )
#' state <- apply_identity_decisions(state, list(decision))
#' }
#'
#' @details
#' A combined source may be accepted as a registered mixture without splitting.
#' Keeping an aggregate unresolved records its scope but does not accept a
#' representative component. A repeated source CAS on split children remains
#' candidate evidence until component correspondence is explicitly reviewed.
#' Flags, manual picks and bulk suggestion acceptance cannot resolve these
#' scope conflicts. Selecting a configured source DTXSID also requires its exact
#' source membership evidence to be validated; lookup agreement and a separate
#' successful ID lookup cannot promote unavailable or rejected source evidence.
#' A different validated identity can explicitly resolve conflicting source
#' metadata while retaining its original validation outcomes and provenance.
#' Existing flags and reasons are preserved by this function.
#' The fingerprint row argument is the current row position, while the selector
#' uses source lineage and content; these may differ after reordering.
#' @param on_drift What to do when a decision's `evidence_fingerprint` no
#'   longer matches the row. `"stop"` (default) fails. `"report"` skips that
#'   decision, applies the rest, and lists the skipped ones in
#'   `state$identity_drift` with the recorded and current fingerprints, and
#'   the evidence columns that changed when the decision carries a snapshot.
#'   Malformed decisions and ambiguous selectors fail in both modes.
#' @export
apply_identity_decisions <- function(state, identity_decisions, on_drift = c("stop", "report")) {
  on_drift <- match.arg(on_drift)
  if (!length(identity_decisions)) return(state)
  df <- init_resolution_state(state$resolution_state)
  drift <- list()
  for (decision in identity_decisions) {
    prev <- df
    selector <- decision$selector
    if (!is.list(selector) || is.null(names(selector)) || !"original_row_id" %in% names(selector) ||
        length(selector) < 2L || any(!names(selector) %in% names(df)) ||
        any(grepl("^(identity_|consensus_|dtxsid|row_flag|\\.)", names(selector)))) {
      stop("Identity selector requires original_row_id and source content columns.", call. = FALSE)
    }
    matches <- rep(TRUE, nrow(df))
    for (col in names(selector)) {
      value <- selector[[col]]
      if (length(value) != 1L) stop("Identity selector values must be scalar.", call. = FALSE)
      matches <- matches & if (is.na(value)) is.na(df[[col]]) else !is.na(df[[col]]) & df[[col]] == value
    }
    rows <- which(matches)
    if (length(rows) != 1L) stop("Identity selector must match exactly one source row.", call. = FALSE)
    i <- rows[1]
    required <- c("action", "scope", "conflict", "reason", "evidence_reference", "evidence_fingerprint")
    if (any(vapply(required, function(key) length(decision[[key]]) != 1L ||
                   is.na(decision[[key]]) || !nzchar(trimws(decision[[key]])), logical(1)))) {
      stop("Identity decisions require action, scope, conflict, reason and evidence reference/fingerprint.", call. = FALSE)
    }
    if (!decision$action %in% c("accept", "retain_unresolved") ||
        !decision$scope %in% c("substance", "registered_mixture", "aggregate", "class", "unknown") ||
        !decision$conflict %in% c("none", "scope", "source_name_cas", "source_identifier")) {
      stop("Invalid identity decision action, scope or conflict.", call. = FALSE)
    }
    # Shape errors fail before the drift check: a malformed decision is never reported as drift.
    if (decision$action == "accept") {
      id <- decision$selected_dtxsid
      if (!decision$scope %in% c("substance", "registered_mixture") || decision$conflict != "none" ||
          !isTRUE(decision$correspondence) || length(id) != 1L || is.na(id) || !grepl("^DTXSID[0-9]+$", id)) {
        stop("Acceptance requires resolved scope/conflict, an ID and explicit source correspondence.", call. = FALSE)
      }
    }
    # GUI replay reconstructs only the inspected lookup projection for this
    # exact source row. Source content, candidates and validation cannot change.
    if (!is.null(decision$gui_review_input)) {
      input <- decision$gui_review_input
      allowed <- c("consensus_status", "consensus_dtxsid", "consensus_source", ".resolution_method", ".pinned")
      if (!is.list(input) || is.null(names(input)) || anyDuplicated(names(input)) ||
          any(!names(input) %in% allowed) || any(lengths(input) != 1L) ||
          any(!vapply(names(input), function(col) if (col == ".pinned") is.logical(input[[col]]) else
            is.character(input[[col]]), logical(1)))) {
        stop("Invalid GUI decision lookup projection.", call. = FALSE)
      }
      for (col in names(input)) {
        if (!col %in% names(df)) df[[col]] <- if (col == ".pinned") rep(FALSE, nrow(df)) else rep(NA_character_, nrow(df))
        df[[col]][i] <- input[[col]]
      }
    }
    before <- identity_evidence_fingerprint(df, i)
    legacy_match <- startsWith(decision$evidence_fingerprint, "identity-v1:") &&
      identical(identity_fingerprint_v1(df, i), decision$evidence_fingerprint)
    if (!identical(before, decision$evidence_fingerprint) && !legacy_match) {
      if (on_drift == "stop") stop("Identity decision evidence changed.", call. = FALSE)
      current <- identity_evidence_snapshot(df, i)
      changed <- if (is.list(decision$evidence)) {
        keys <- union(names(decision$evidence), names(current))
        keys[!vapply(keys, function(k) identical(as.character(decision$evidence[[k]]), as.character(current[[k]])),
          logical(1))]
      }
      drift[[length(drift) + 1L]] <- tibble::tibble(
        original_row_id = as.integer(df$original_row_id[i]),
        multi_analyte_part_index = as.integer(identity_col(df, "multi_analyte_part_index")[i]),
        action = decision$action, scope = decision$scope,
        selected_dtxsid = as.character(decision$selected_dtxsid %||% NA_character_),
        reason = decision$reason, evidence_reference = decision$evidence_reference,
        recorded_fingerprint = decision$evidence_fingerprint, current_fingerprint = before,
        changed_columns = if (!length(changed)) NA_character_ else paste(changed, collapse = "; "),
        decision = list(decision), current_evidence = list(current)
      )
      df <- prev
      next
    }
    membership <- "not_requested"
    if (decision$action == "accept") {
      id <- decision$selected_dtxsid
      source_candidates <- grep("^source_id_.*_source_candidate_id$", names(df), value = TRUE)
      for (col in source_candidates) {
        candidate <- normalize_source_dtxsid(df[[col]][i])
        if (!is.na(candidate) && identical(candidate, id)) {
          validation_col <- sub("_source_candidate_id$", "_validation_status", col)
          if (!identical(as.character(identity_col(df, validation_col)[i]), "validated")) {
            stop("Source-ID promotion requires validated exact source membership and explicit correspondence.", call. = FALSE)
          }
        }
      }
      validation <- validate_manual_dtxsids(id)
      if (nrow(validation) != 1L || !isTRUE(validation$is_valid[1]) ||
          !identical(as.character(validation$dtxsid[1]), id)) {
        stop("Authoritative membership invalid or unavailable; identity remains provisional.", call. = FALSE)
      }
      membership <- "valid"
      df$consensus_dtxsid[i] <- id
      df$consensus_status[i] <- "manual"
      df$consensus_source[i] <- "identity_decision"
      df$.resolution_method[i] <- "manual"
      df$.pinned[i] <- TRUE
    }
    for (col in c("identity_scope", "identity_conflict", "identity_decision_fingerprint", "identity_decision_record")) {
      if (!col %in% names(df)) df[[col]] <- NA_character_
    }
    if (!"identity_scope_reviewed" %in% names(df)) df$identity_scope_reviewed <- FALSE
    df$identity_scope[i] <- decision$scope
    df$identity_conflict[i] <- decision$conflict
    df$identity_scope_reviewed[i] <- TRUE
    evidence_columns <- identity_evidence_columns(df)
    applied <- identity_fingerprint_v2(df, i, evidence_columns)
    record <- c(strip_ledger_fields(list(decision))[[1]], list(version = "2", evidence_columns = evidence_columns,
                              membership = membership, applied_fingerprint = applied))
    df$identity_decision_fingerprint[i] <- applied
    df$identity_decision_record[i] <- as.character(jsonlite::toJSON(record, auto_unbox = TRUE, null = "null"))
  }
  df$identity_decision_current <- identity_decision_current_rows(df)
  state$resolution_state <- df
  state$identity_decisions <- strip_ledger_fields(identity_decisions)
  if (on_drift == "report") state$identity_drift <- dplyr::bind_rows(drift)
  state
}
