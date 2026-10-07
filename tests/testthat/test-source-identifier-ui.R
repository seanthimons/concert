test_that("source-ID role is suggested but applied only by explicit tag action", {
  expect_identical(suggest_column_tags(c("source_dtxsid", "dtxsid")), list(source_dtxsid = "DTXSID", dtxsid = "DTXSID"))
  store <- shiny::reactiveValues(clean = tibble::tibble(name = "Example", cas = "67-64-1",
    source_dtxsid = "DTXSID123", dtxsid_metadata = "DTXSID456"),
    selected_columns = c("name", "cas", "source_dtxsid"))
  notifications <- character()
  local_mocked_bindings(notify_user = function(message, ...) notifications <<- c(notifications, message))
  shiny::testServer(mod_tag_columns_server, args = list(data_store = store), {
    session$setInputs(suggest_tags = 1L)
    expect_null(store$column_tags)
    session$setInputs(tag_name = "Name", tag_cas = "CASRN", tag_source_dtxsid = "DTXSID", apply_tags = 1L)
    expect_identical(store$column_tags$source_dtxsid, "DTXSID")
    expect_identical(store$identifier_diagnostics$column, "dtxsid_metadata")
    session$setInputs(apply_tags = 2L)
    expect_equal(sum(grepl("Unused source identifier", notifications)), 1L)
    session$setInputs(ignored_identifier_cols = "dtxsid_metadata", apply_tags = 3L)
    expect_identical(store$ignored_identifier_cols, "dtxsid_metadata")
    expect_equal(nrow(store$identifier_diagnostics), 0L)
    session$setInputs(ignored_identifier_cols = "source_dtxsid", apply_tags = 4L)
    expect_match(tail(notifications, 1L), "cannot also be ignored")
    expect_identical(store$ignored_identifier_cols, "dtxsid_metadata")
  })
})

ui_review_fixture <- function() {
  automated <- init_resolution_state(tibble::tibble(name = c("Example", "Other"),
    source = c("DTXSID123", "DTXSID456"), original_row_id = 1:2,
    consensus_status = "error", consensus_dtxsid = NA_character_, consensus_source = NA_character_,
    source_id_source_source_candidate_id = c("DTXSID123", "DTXSID456"),
    source_id_source_validation_status = c("validated", "unavailable"),
    source_id_source_authority = "EPA CompTox", source_id_source_checked_at = "fixed"))
  automated
}

test_that("actual GUI flag evidence separates immutable automated and final state", {
  automated <- ui_review_fixture()
  final <- set_row_flags(automated, 1:2, "FOLLOW-UP", "Literal reviewer reason")
  evidence <- gui_flag_review_evidence(NULL, automated, final, 1:2,
    list(name = "Name", source = "DTXSID"), "deferred", "FOLLOW-UP", "Literal reviewer reason")
  expect_length(evidence$decisions, 2L)
  expect_false(identical(evidence$decisions[[1]]$scope_fingerprint, evidence$decisions[[2]]$scope_fingerprint))
  expect_identical(evidence$decisions[[1]]$flag, "FOLLOW-UP")
  expect_identical(evidence$decisions[[1]]$reason, "Literal reviewer reason")
  expect_identical(evidence$decisions[[1]]$current$validation$outcome, "valid")
  expect_identical(evidence$decisions[[2]]$current$validation$outcome, "unavailable")
  again <- gui_flag_review_evidence(evidence, automated, final, 1L,
    list(name = "Name", source = "DTXSID"), "other", "VERIFIED", "Still a provisional ID")
  expect_identical(again$decisions[[1]], evidence$decisions[[1]])
  expect_identical(again$decisions[[3]]$revision, 2L)
  expect_error(gui_flag_review_evidence(NULL, NULL, final, 1L,
    list(name = "Name"), "other", "BAD", "reason"), "baseline unavailable")
  duplicated <- automated[c(1L, 1L), ]
  expect_error(gui_flag_review_evidence(NULL, duplicated, duplicated, 1:2,
    list(name = "Name", source = "DTXSID"), "other", "BAD", "reason"), "ambiguous")
  expect_match(as.character(source_identifier_review_panel(automated, 2L, list(source = "DTXSID"))), "unavailable")
})

test_that("GUI curation keeps source validation as evidence without promotion", {
  withr::local_envvar(ctx_api_key = "mock-key")
  store <- shiny::reactiveValues(clean = tibble::tibble(source = "DTXSID123", original_row_id = 1L),
    column_tags = list(source = "DTXSID"), ignored_identifier_cols = character())
  calls <- 0L
  local_mocked_bindings(
    source_identifier_lookup = function(ids) {
      calls <<- calls + 1L
      expect_identical(ids, "DTXSID123")
      tibble::tibble(dtxsid = ids, preferredName = "Example", casrn = "67-64-1")
    },
    postprocess_curation_candidates = function(resolution_state, ...) {
      empty_postprocess_result(resolution_state, NULL, character())
    }
  )
  shiny::testServer(mod_run_curation_server, args = list(data_store = store), {
    session$setInputs(run_curation = 1L)
    expect_equal(calls, 1L)
    expect_identical(store$curation_status, "completed")
    expect_identical(store$source_identifier_evidence$validation_status, "validated")
    expect_true(is.na(store$resolution_state$consensus_dtxsid))
    expect_identical(store$script_baseline_state$source_id_source_validation_status, "validated")
  })
})

test_that("GUI flag action captures the explicit decision and preserves flags", {
  df <- ui_review_fixture()
  store <- shiny::reactiveValues(clean = df[c("name", "source")], column_tags = list(name = "Name", source = "DTXSID"),
    resolution_state = df, script_baseline_state = df, modal_row_idx = 1L,
    consensus_summary = recalc_consensus_summary(df), dtxsid_cols = character())
  shiny::testServer(mod_review_results_server, args = list(data_store = store), {
    session$flushReact()
    session$setInputs(modal_row_flag = "BAD", modal_row_flag_reason = "Explicit exclusion",
      modal_review_disposition = "deferred", modal_apply_row_flag = 1L)
    expect_identical(store$resolution_state$row_flag[1], "BAD")
    expect_identical(store$resolution_state$row_flag_reason[1], "Explicit exclusion")
    expect_length(store$review_decision_evidence$decisions, 1L)
    expect_identical(store$review_decision_evidence$decisions[[1]]$disposition, "deferred")
    expect_identical(store$review_row_flags$flag, "BAD")
    expect_identical(store$review_row_flags$decision_id, review_decision_key("Example"))
  })
})

test_that("GUI flag evidence reconciles unchanged through workbook and replay boundaries", {
  automated <- ui_review_fixture()
  tags <- list(name = "Name", source = "DTXSID")
  raw <- automated[c("name", "source")]
  final <- set_row_flags(automated, 1:2, "FOLLOW-UP", "Explicit review")
  evidence <- gui_flag_review_evidence(NULL, automated, final, 1:2, tags, "deferred", "FOLLOW-UP", "Explicit review", raw)
  flags <- gui_review_row_flags(final, tags)
  state <- list(resolution_state = automated, clean_data = raw, merged_chemical_tags = tags,
    merged_tags = tags, tag_map = tags, consensus_summary = recalc_consensus_summary(automated))
  replay <- stage_review(state, row_flags = flags, review_decision_evidence = evidence)
  expect_true(all(replay$review_reconciliation$baseline_status == "unchanged"))
  expect_identical(replay$resolution_state$row_flag, final$row_flag)
  sheets <- build_export_sheets(raw, final, recalc_consensus_summary(final), empty_cleaning_audit(), list(), tags,
    list(header_row = 1L), list(name = "fixture.csv"), review_decision_evidence = evidence)
  path <- tempfile(fileext = ".xlsx")
  withr::defer(unlink(path))
  writexl::write_xlsx(sheets, path)
  hydrated <- hydrate_session_state(parse_concert_export(path))$state
  expect_identical(hydrated$review_decision_evidence, evidence)
  script <- generate_concert_script("fixture.csv", "out.xlsx", tags, 1L,
    row_flags = flags, review_decision_evidence = evidence)
  expect_match(script, "review_decision_evidence = review_decision_evidence", fixed = TRUE)
})
