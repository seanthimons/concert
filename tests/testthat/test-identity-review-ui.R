identity_gui_fixture <- function() {
  init_resolution_state(tibble::tibble(original_row_id = 1:2, name = "Registered combination", cas = "1-23-4",
    consensus_dtxsid = "DTXSID123", consensus_status = "single", consensus_source = "cas",
    dtxsid_cas = "DTXSID123", multi_analyte_resolution = "keep_combined",
    identity_conflict = "scope", source_file = c("A", "B")))
}
identity_gui_save <- function(df, decisions = NULL, evidence = NULL, baseline = identity_gui_fixture(), context = NULL,
                              action = "accept", scope = "registered_mixture", conflict = "none", id = "DTXSID123") {
  if (is.null(context)) context <- gui_identity_context(df, 1L, list(name = "Name", cas = "CASRN"))[[1]]
  gui_apply_identity_decision(df, decisions, evidence, baseline, context, action, scope, conflict, id,
    TRUE, "Reviewed composition", "mock:source-and-registry")
}

test_that("scoped GUI actions preserve flags, lineage and immutable decision revisions", {
  local_mocked_bindings(validate_manual_dtxsids = function(ids, ...) tibble::tibble(dtxsid = ids, is_valid = TRUE))
  df <- identity_gui_fixture()
  df$row_flag <- c("FOLLOW-UP", "BAD")
  df$row_flag_reason <- c("Keep follow-up", "Excluded")
  out <- identity_gui_save(df)
  expect_identical(out$resolution_state$row_flag, df$row_flag)
  expect_identical(out$resolution_state$row_flag_reason, df$row_flag_reason)
  expect_identical(out$resolution_state$source_file, df$source_file)
  expect_identical(identity_review_state(out$resolution_state)$identity_eligible, c(FALSE, FALSE))
  expect_true(identity_decision_current_rows(out$resolution_state)[1])
  expect_length(out$review_decision_evidence$decisions, 1L)
  again <- identity_gui_save(out$resolution_state, out$identity_decisions, out$review_decision_evidence)
  expect_identical(again$review_decision_evidence$decisions[[1]], out$review_decision_evidence$decisions[[1]])
  expect_equal(again$review_decision_evidence$decisions[[2]]$revision, 2L)
  expect_length(again$identity_decisions, 1L)
})

test_that("GUI acceptance fails transactionally for ambiguous, stale, unavailable or invalid input", {
  calls <- 0L
  local_mocked_bindings(validate_manual_dtxsids = function(ids, ...) {
    calls <<- calls + 1L; tibble::tibble(dtxsid = ids, is_valid = FALSE)
  })
  df <- identity_gui_fixture()
  context <- gui_identity_context(df, 1L, list(name = "Name", cas = "CASRN"))[[1]]
  changed <- df; changed$cas[1] <- "new"
  expect_error(identity_gui_save(changed, context = context), "unambiguous|scope")
  changed <- df; changed$dtxsid_cas[1] <- "DTXSID456"
  expect_error(identity_gui_save(changed, context = context), "Evidence changed")
  duplicate <- df; duplicate$original_row_id[2] <- 1L
  expect_error(identity_gui_save(duplicate, context = context), "unambiguous")
  expect_equal(calls, 0L)
  expect_error(identity_gui_save(df, id = "DTXSID456"), "invalid or unavailable")
  expect_error(identity_gui_save(df, scope = "aggregate"), "Acceptance requires")
  expect_error(identity_gui_save(df, conflict = "scope"), "Acceptance requires")
  expect_error(identity_gui_save(df, baseline = NULL), "baseline unavailable")
  unresolved <- identity_gui_save(df, action = "retain_unresolved", scope = "aggregate", conflict = "scope")
  expect_identical(unresolved$resolution_state$consensus_dtxsid, df$consensus_dtxsid)
  expect_false(any(identity_review_state(unresolved$resolution_state)$identity_eligible))
})

test_that("actual modal observer connects explicit source selection to backend", {
  local_mocked_bindings(validate_manual_dtxsids = function(ids, ...) tibble::tibble(dtxsid = ids, is_valid = TRUE))
  df <- identity_gui_fixture()
  notices <- character()
  local_mocked_bindings(notify_user = function(message, ...) notices <<- c(notices, message))
  store <- shiny::reactiveValues(clean = df[c("name", "cas")], column_tags = list(name = "Name", cas = "CASRN"),
    resolution_state = df, script_baseline_state = df, consensus_summary = recalc_consensus_summary(df),
    dtxsid_cols = "dtxsid_cas", dedup_group_map = list())
  shiny::testServer(mod_review_results_server, args = list(data_store = store), {
    session$flushReact()
    session$setInputs(expert_override_click = list(row = 1L))
    expect_length(store$identity_modal_context, 2L)
    session$setInputs(identity_scope_target = "", identity_scope_save = 1L)
    expect_match(tail(notices, 1), "Choose one source row")
    expect_identical(store$resolution_state, df)
    session$setInputs(identity_scope_target = "1", identity_scope_action = "accept",
      identity_scope_kind = "registered_mixture", identity_scope_conflict = "none", identity_scope_id = "DTXSID123",
      identity_scope_correspondence = FALSE, identity_scope_reason = "Reviewed composition",
      identity_scope_reference = "mock:registry", identity_scope_save = 2L)
    expect_identical(store$resolution_state, df)
    expect_match(tail(notices, 1), "explicit source correspondence")
    session$setInputs(identity_scope_correspondence = TRUE, identity_scope_save = 3L)
    expect_identical(identity_review_state(store$resolution_state)$identity_eligible, c(TRUE, FALSE))
    expect_length(store$identity_decisions, 1L)
    expect_length(store$review_decision_evidence$decisions, 1L)
    expect_null(store$identity_modal_context)
  })
})

test_that("GUI decisions replay by source rather than ordinary compound-wide ID overrides", {
  local_mocked_bindings(validate_manual_dtxsids = function(ids, ...) {
    tibble::tibble(searchValue = ids, dtxsid = ids, is_valid = TRUE, preferredName = "fixture")
  })
  df <- identity_gui_fixture(); tags <- list(name = "Name", cas = "CASRN")
  out <- identity_gui_save(df, id = "DTXSID456")
  projected <- gui_identity_replay_state(out$resolution_state, out$identity_decisions)
  expect_identical(projected$consensus_dtxsid, df$consensus_dtxsid)
  overrides <- build_review_overrides(df, projected, tags)
  state <- list(resolution_state = df, consensus_summary = recalc_consensus_summary(df),
    merged_chemical_tags = tags, merged_tags = tags, clean_data = df[c("name", "cas")])
  replay <- stage_review(state, review_overrides = overrides, identity_decisions = out$identity_decisions,
    review_decision_evidence = out$review_decision_evidence)
  expect_identical(replay$resolution_state$consensus_dtxsid, c("DTXSID456", "DTXSID123"))
  expect_identical(identity_review_state(replay$resolution_state)$identity_eligible, c(TRUE, FALSE))
  again <- identity_gui_save(out$resolution_state, out$identity_decisions, out$review_decision_evidence, id = "DTXSID789")
  projected <- gui_identity_replay_state(again$resolution_state, again$identity_decisions)
  replay <- stage_review(state, review_overrides = build_review_overrides(df, projected, tags),
    identity_decisions = again$identity_decisions)
  expect_identical(replay$resolution_state$consensus_dtxsid, c("DTXSID789", "DTXSID123"))
  altered <- out$resolution_state; altered$dtxsid_cas[1] <- "DTXSID789"
  expect_error(gui_identity_replay_state(altered, out$identity_decisions), "stale")
  bad <- out$identity_decisions; bad[[1]]$gui_review_input$cas <- "forged"
  expect_error(apply_identity_decisions(state, bad), "Invalid GUI")
  reversed <- df[2:1, ]; reversed_state <- state; reversed_state$resolution_state <- reversed
  replay <- stage_review(reversed_state, identity_decisions = out$identity_decisions)
  expect_identical(replay$resolution_state$consensus_dtxsid, c("DTXSID123", "DTXSID456"))
  sheets <- build_export_sheets(df, out$resolution_state, list(), empty_cleaning_audit(), list(), tags,
    list(header_row = 1L), list(name = "fixture.csv"), identity_decisions = out$identity_decisions,
    review_decision_evidence = out$review_decision_evidence)
  path <- tempfile(fileext = ".xlsx"); withr::defer(unlink(path))
  writexl::write_xlsx(sheets, path)
  hydrated <- hydrate_session_state(parse_concert_export(path))$state
  expect_identical(hydrated$identity_decisions, out$identity_decisions)
  expect_identical(hydrated$review_decision_evidence, out$review_decision_evidence)
  expect_identical(identity_review_state(hydrated$resolution_state)$identity_eligible, c(TRUE, FALSE))
})

test_that("source membership outages cannot be promoted by the GUI action", {
  calls <- 0L
  local_mocked_bindings(validate_manual_dtxsids = function(ids, ...) {
    calls <<- calls + 1L; tibble::tibble(dtxsid = ids, is_valid = TRUE)
  })
  df <- identity_gui_fixture()
  df$source_id_source_source_candidate_id <- "DTXSID123"
  df$source_id_source_validation_status <- "unavailable"
  expect_error(identity_gui_save(df), "validated exact source membership")
  expect_equal(calls, 0L)
  context <- gui_identity_context(df, 1L, list(name = "Name", cas = "CASRN"))[[1]]
  expect_error(gui_apply_identity_decision(df, NULL, NULL, df, context, "accept", "substance", "none",
    "DTXSID123", TRUE, "", ""), "require action")
  expect_equal(calls, 0L)
})

test_that("generated standalone GUI replay executes under deterministic services", {
  df <- identity_gui_fixture(); tags <- list(name = "Name", cas = "CASRN")
  local_mocked_bindings(validate_manual_dtxsids = function(ids, ...) {
    tibble::tibble(searchValue = ids, dtxsid = ids, is_valid = TRUE, preferredName = "fixture")
  }, run_curation_pipeline = function(...) list(results = df, consensus_summary = recalc_consensus_summary(df)),
  postprocess_curation_candidates = function(resolution_state, ...) empty_postprocess_result(resolution_state, NULL, character()))
  out <- identity_gui_save(df, id = "DTXSID456")
  dir <- withr::local_tempdir()
  input <- file.path(dir, "source.csv"); output <- file.path(dir, "curated.xlsx")
  readr::write_csv(df[c("name", "cas", "source_file")], input)
  script <- generate_concert_script(input, output, tags, 1L,
    review_overrides = build_review_overrides(df, gui_identity_replay_state(out$resolution_state, out$identity_decisions), tags),
    identity_decisions = out$identity_decisions, review_decision_evidence = out$review_decision_evidence)
  path <- file.path(dir, "replay.R"); writeLines(script, path)
  result <- source(path, local = new.env(parent = globalenv()))$value
  expect_identical(result$data$consensus_dtxsid, c("DTXSID456", "DTXSID123"))
  expect_identical(identity_review_state(result$data)$identity_eligible, c(TRUE, FALSE))
  restored <- hydrate_session_state(parse_concert_export(output))$state
  expect_identical(restored$identity_decisions, out$identity_decisions)
  expect_identical(restored$review_decision_evidence, out$review_decision_evidence)
})
