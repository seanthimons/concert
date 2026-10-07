curation_scope_rerun_fixture <- function() {
  init_resolution_state(tibble::tibble(original_row_id = 1:2, name = "Registered combination", cas = "1-23-4",
    consensus_dtxsid = "DTXSID123", consensus_status = "single", consensus_source = "cas",
    dtxsid_cas = "DTXSID123", multi_analyte_resolution = "keep_combined", identity_conflict = "scope",
    source_file = c("A", "B"), source_id_input_checked_at = "first fetch"))
}

curation_scope_rerun_save <- function(df) {
  gui_apply_identity_decision(df, NULL, NULL, df,
    gui_identity_context(df, 1L, list(name = "Name", cas = "CASRN"))[[1]],
    "accept", "registered_mixture", "none", "DTXSID456", TRUE, "Reviewed composition", "mock:registry")
}

test_that("curation observer preserves source-scoped decisions without compound-wide promotion", {
  withr::local_envvar(ctx_api_key = "mock-test-key")
  notices <- character()
  fresh <- curation_scope_rerun_fixture()
  service <- new.env(parent = emptyenv())
  service$results <- fresh
  local_mocked_bindings(
    validate_manual_dtxsids = function(ids, ...) tibble::tibble(dtxsid = ids, is_valid = TRUE),
    notify_user = function(message, ...) notices <<- c(notices, message),
    run_curation_pipeline = function(...) list(results = service$results,
      search_summary = list(n_cas_valid = 1L, n_exact = 0L, n_starts_with = 0L, n_wqx = 0L, n_miss = 0L),
      dedup_summary = list(n_cas = 1L)),
    postprocess_curation_candidates = function(resolution_state, ...) empty_postprocess_result(resolution_state, NULL, character())
  )
  baseline <- fresh
  saved <- curation_scope_rerun_save(baseline)
  saved$resolution_state$row_flag <- c("VERIFIED", "FOLLOW-UP")
  saved$resolution_state$row_flag_reason <- c("Reviewed", "Still pending")
  store <- shiny::reactiveValues(clean = baseline[c("name", "cas")], column_tags = list(name = "Name", cas = "CASRN"),
    resolution_state = saved$resolution_state, script_baseline_state = baseline,
    identity_decisions = saved$identity_decisions, review_decision_evidence = saved$review_decision_evidence)
  # The validated source fetch timestamp does not change identity evidence.
  fresh$source_id_input_checked_at <- "second fetch"
  service$results <- fresh
  shiny::testServer(mod_run_curation_server, args = list(data_store = store), {
    session$flushReact()
    session$setInputs(run_curation = 1L)
    expect_identical(store$curation_status, "completed")
    expect_identical(store$resolution_state$consensus_dtxsid, c("DTXSID456", "DTXSID123"))
    expect_identical(identity_review_state(store$resolution_state)$identity_eligible, c(TRUE, FALSE))
    expect_identical(store$resolution_state$row_flag, c("VERIFIED", "FOLLOW-UP"))
    expect_identical(store$resolution_state$row_flag_reason, c("Reviewed", "Still pending"))
    expect_identical(store$resolution_state$source_file, baseline$source_file)
    expect_identical(store$script_baseline_state, fresh)
    expect_identical(store$identity_decisions, saved$identity_decisions)
    expect_identical(store$review_decision_evidence, saved$review_decision_evidence)
    expect_false(any(grepl("not re-applied", notices)))

    service$results$consensus_dtxsid[1] <- "DTXSID789"
    service$results$dtxsid_cas[1] <- "DTXSID789"
    session$setInputs(run_curation = 2L)
    expect_identical(store$curation_status, "completed")
    expect_identical(store$resolution_state$consensus_dtxsid, c("DTXSID789", "DTXSID123"))
    expect_identical(store$resolution_state$dtxsid_cas, service$results$dtxsid_cas)
    expect_false(any(identity_review_state(store$resolution_state)$identity_eligible))
    expect_match(identity_review_state(store$resolution_state)$identity_blockers[1], "stale_scope_decision")
    expect_true(any(grepl("evidence changed", notices)))
    expect_identical(store$resolution_state$row_flag, c("VERIFIED", "FOLLOW-UP"))
    expect_identical(store$identity_decisions, saved$identity_decisions)
    expect_identical(store$review_decision_evidence, saved$review_decision_evidence)
    expect_identical(store$script_baseline_state, service$results)
  })
})

test_that("changed automated consensus cannot be concealed by GUI replay projection", {
  local_mocked_bindings(validate_manual_dtxsids = function(ids, ...) tibble::tibble(dtxsid = ids, is_valid = TRUE))
  baseline <- curation_scope_rerun_fixture()
  saved <- curation_scope_rerun_save(baseline)
  fresh <- baseline
  fresh$consensus_dtxsid[1] <- "DTXSID789"
  fresh$dtxsid_cas[1] <- "DTXSID789"
  out <- reapply_curation_identity_decisions(fresh, baseline, fresh, saved$resolution_state, saved$identity_decisions)
  expect_identical(out$resolution_state$consensus_dtxsid, fresh$consensus_dtxsid)
  expect_identical(out$resolution_state$dtxsid_cas, fresh$dtxsid_cas)
  expect_match(out$messages, "evidence changed")
  expect_false(any(identity_review_state(out$resolution_state)$identity_eligible))
  expect_match(identity_review_state(out$resolution_state)$identity_blockers[1], "stale_scope_decision")
  expect_identical(out$resolution_state$identity_decision_record[1], saved$resolution_state$identity_decision_record[1])
})

test_that("membership becoming unavailable fails closed on unchanged baseline", {
  local_mocked_bindings(validate_manual_dtxsids = function(ids, ...) tibble::tibble(dtxsid = ids, is_valid = TRUE))
  baseline <- curation_scope_rerun_fixture()
  saved <- curation_scope_rerun_save(baseline)
  local_mocked_bindings(validate_manual_dtxsids = function(ids, ...) tibble::tibble(dtxsid = ids, is_valid = NA))
  out <- reapply_curation_identity_decisions(baseline, baseline, baseline, saved$resolution_state, saved$identity_decisions)
  expect_false(any(identity_review_state(out$resolution_state)$identity_eligible))
  expect_identical(out$resolution_state$consensus_dtxsid, baseline$consensus_dtxsid)
  expect_match(out$messages, "invalid or unavailable")
})

test_that("repeated reruns cannot revive a stale decision by replacing its baseline", {
  local_mocked_bindings(validate_manual_dtxsids = function(ids, ...) tibble::tibble(dtxsid = ids, is_valid = TRUE))
  baseline <- curation_scope_rerun_fixture()
  saved <- curation_scope_rerun_save(baseline)
  fresh <- baseline
  # Only the consensus changed, so reconstructing gui_review_input would hide
  # this change if the prior stale decision were allowed through a later rerun.
  fresh$consensus_dtxsid[1] <- "DTXSID789"
  out <- reapply_curation_identity_decisions(fresh, baseline, fresh, saved$resolution_state, saved$identity_decisions)
  repeated <- reapply_curation_identity_decisions(fresh, fresh, fresh, out$resolution_state, saved$identity_decisions)
  expect_identical(repeated$resolution_state$consensus_dtxsid, fresh$consensus_dtxsid)
  expect_false(any(identity_review_state(repeated$resolution_state)$identity_eligible))
  expect_match(repeated$messages, "earlier source decision is stale")
})
