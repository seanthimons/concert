# Scoped GUI decisions use the existing backend and portable evidence contract.
gui_identity_selector <- function(df, row, column_tags) {
  chemical <- names(column_tags)[unlist(column_tags) %in% c("Name", "CASRN", "DTXSID")]
  cols <- unique(c("original_row_id", chemical, "multi_analyte_part_index", "multi_analyte_source_name", "multi_analyte_source_cas"))
  cols <- intersect(cols, names(df))
  cols <- cols[!grepl("^(identity_|consensus_|dtxsid|row_flag|\\.)", cols)]
  if (!"original_row_id" %in% cols || length(cols) < 2L || is.na(df$original_row_id[row])) {
    stop("Source lineage and content are required. Re-curate this source before recording correspondence.", call. = FALSE)
  }
  as.list(df[row, cols, drop = FALSE])
}

gui_identity_context <- function(df, rows, column_tags) {
  stats::setNames(lapply(rows, function(row) list(
    selector = gui_identity_selector(df, row, column_tags),
    fingerprint = identity_evidence_fingerprint(df, row), snapshot = df[row, , drop = FALSE]
  )), as.character(rows))
}

identity_scope_review_controls <- function(session, context) {
  choices <- vapply(context, function(x) paste("Source row", x$selector$original_row_id,
    if ("source_file" %in% names(x$snapshot)) paste0("[", x$snapshot$source_file[1], "]") else "",
    paste(unlist(x$selector[setdiff(names(x$selector), "original_row_id")]), collapse = " / ")), character(1))
  choices <- stats::setNames(names(context), choices)
  if (length(context) > 1L) choices <- c("Choose one source row" = "", choices)
  div(class = "border rounded p-3 mt-3", tags$h6("Source identity correspondence"),
    p("Record what this source represents and whether the selected registry identity represents it. Flags remain separate."),
    selectInput(session$ns("identity_scope_target"), "Source row", choices = choices,
      selected = if (length(context) == 1L) names(context)[1] else ""),
    uiOutput(session$ns("identity_scope_evidence")),
    radioButtons(session$ns("identity_scope_action"), "Decision",
      choices = c("Keep unresolved" = "retain_unresolved", "Record correspondence" = "accept"), selected = "retain_unresolved"),
    selectInput(session$ns("identity_scope_kind"), "Source represents",
      c("Unknown" = "unknown", "One substance" = "substance", "Registered mixture" = "registered_mixture",
        "Aggregate" = "aggregate", "Chemical class" = "class"), selected = "unknown"),
    selectInput(session$ns("identity_scope_conflict"), "Remaining conflict",
      c("Scope unresolved" = "scope", "Source name / CAS" = "source_name_cas",
        "Source identifier" = "source_identifier", "None \u2014 resolved" = "none"), selected = "scope"),
    textInput(session$ns("identity_scope_id"), "Selected DTXSID", value = ""),
    checkboxInput(session$ns("identity_scope_correspondence"), "I reviewed evidence that this ID represents this source", FALSE),
    textAreaInput(session$ns("identity_scope_reason"), "Decision reason", rows = 2),
    textAreaInput(session$ns("identity_scope_reference"), "Supporting evidence (record, URL, document or composition)", rows = 2),
    actionButton(session$ns("identity_scope_save"), "Save source decision", class = "btn-primary"),
    uiOutput(session$ns("identity_scope_result")))
}

gui_identity_row <- function(df, selector) {
  match <- rep(TRUE, nrow(df))
  for (col in names(selector)) {
    if (!col %in% names(df)) stop("Source scope changed; reopen the row review.", call. = FALSE)
    value <- selector[[col]]
    match <- match & if (is.na(value)) is.na(df[[col]]) else !is.na(df[[col]]) & df[[col]] == value
  }
  rows <- which(match)
  if (length(rows) != 1L) stop("Select one unambiguous source row; this decision cannot span a chemical group.", call. = FALSE)
  rows
}

gui_apply_identity_decision <- function(df, decisions, evidence, automated, context, action, scope,
                                        conflict, selected_id, correspondence, reason, reference) {
  row <- gui_identity_row(df, context$selector)
  if (!identical(identity_evidence_fingerprint(df, row), context$fingerprint)) {
    stop("Evidence changed while this dialog was open. Reopen and review the current evidence.", call. = FALSE)
  }
  if (is.null(automated)) stop("Automated baseline unavailable; re-curate before recording a decision.", call. = FALSE)
  lineage <- intersect(c("original_row_id", "multi_analyte_part_index"), names(context$selector))
  baseline_row <- gui_identity_row(automated, context$selector[lineage])
  decision <- list(selector = context$selector, action = action, scope = scope, conflict = conflict,
    selected_dtxsid = trimws(selected_id %||% ""), correspondence = isTRUE(correspondence),
    reason = trimws(reason %||% ""), evidence_reference = trimws(reference %||% ""),
    evidence_fingerprint = context$fingerprint)
  # Preserve the inspected pre-decision values for ordinary replay overrides.
  # The scoped decision itself owns the changes it makes to these fields.
  owned <- c("consensus_status", "consensus_dtxsid", "consensus_source", ".resolution_method", ".pinned")
  decision$gui_review_input <- as.list(df[row, intersect(owned, names(df)), drop = FALSE])
  decisions <- decisions %||% list()
  same <- vapply(decisions, function(x) identical(x$selector, decision$selector), logical(1))
  prior <- decisions[same]
  decision$gui_replay_input <- if (length(prior)) {
    prior[[length(prior)]]$gui_replay_input %||% prior[[length(prior)]]$gui_review_input %||% decision$gui_review_input
  } else decision$gui_review_input
  updated <- apply_identity_decisions(list(resolution_state = df), list(decision))$resolution_state
  columns <- names(context$selector)
  captured_scope <- review_evidence_scope(df, row, columns)
  snapshot <- review_evidence_snapshot(automated[baseline_row, , drop = FALSE], updated[row, , drop = FALSE],
    scope_cols = columns)
  id <- paste0("identity:", review_evidence_fingerprint(context$selector))
  evidence <- capture_review_decision(evidence, id, captured_scope, snapshot,
    if (action == "accept") "accepted" else "scope_conflict",
    flag = identity_col(df, "row_flag")[row], reason = decision$reason)
  decisions <- c(decisions[!same], list(decision))
  list(resolution_state = updated, identity_decisions = decisions, review_decision_evidence = evidence, row = row)
}

# Do not export scoped ID changes as compound-wide ordinary overrides.
gui_identity_replay_state <- function(df, decisions) {
  result <- df
  for (decision in decisions %||% list()) {
    if (is.null(decision$gui_review_input)) next
    row <- gui_identity_row(df, decision$selector)
    if (!identical(as.character(identity_col(df, "identity_decision_fingerprint")[row]),
                   identity_evidence_fingerprint(df, row))) {
      stop("A source decision is stale. Review it before generating replay.", call. = FALSE)
    }
    input <- decision$gui_replay_input %||% decision$gui_review_input
    for (col in names(input)) result[[col]][row] <- input[[col]]
  }
  result
}
