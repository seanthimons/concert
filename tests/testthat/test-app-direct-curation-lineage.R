test_that("full app direct curation retains source lineage through scoped review and rerun", {
  withr::local_envvar(ctx_api_key = "synthetic-service-key")
  local_mocked_bindings(
    search_exact = function(names, ...) tibble::tibble(searchValue = names, dtxsid = "DTXSID789",
      preferredName = "Synthetic candidate", searchName = "EXACT", rank = 1L),
    source_identifier_lookup = function(ids) tibble::tibble(dtxsid = ids[ids == "DTXSID123"],
      preferredName = "Synthetic registered mixture", casrn = NA_character_),
    validate_manual_dtxsids = function(ids, ...) tibble::tibble(dtxsid = ids, is_valid = TRUE),
    postprocess_curation_candidates = function(resolution_state, ...) {
      empty_postprocess_result(resolution_state, NULL, character())
    },
    find_related_parent_candidates = function(...) tibble::tibble()
  )
  upload <- tempfile(fileext = ".csv")
  withr::defer(unlink(upload))
  source_rows <- tibble::tibble(name = c("Mock mixture", "Mock mixture", "Mock rejected"),
    source_dtxsid = c("DTXSID123", "DTXSID123", "DTXSID456"), source_file = c("A", "B", "C"))
  readr::write_csv(source_rows, upload)
  app <- new.env(parent = globalenv())
  sys.source(test_path("../../inst/app/app.R"), envir = app)
  shiny::testServer(app$server, {
    session$flushReact()
    session$setInputs(`upload-detection_mode` = "manual", `upload-manual_header_row` = 1L)
    session$setInputs(`upload-file_upload` = data.frame(name = "synthetic.csv", size = file.info(upload)$size,
      type = "text/csv", datapath = upload))
    expect_equal(nrow(data_store$clean), 3L)
    expect_false("original_row_id" %in% names(data_store$clean))
    data_store$selected_columns <- names(data_store$clean)
    session$setInputs(`tags-tag_name` = "Name", `tags-tag_source_dtxsid` = "DTXSID",
      `tags-tag_source_file` = "", `tags-apply_tags` = 1L)
    session$setInputs(`curation-run_curation` = 1L)
    expect_identical(data_store$curation_status, "completed")
    expect_identical(data_store$resolution_state$original_row_id, 1:3)
    expect_identical(data_store$resolution_state$source_file, source_rows$source_file)
    expect_identical(data_store$resolution_state$name, source_rows$name)

    session$setInputs(`results-expert_override_click` = list(row = 1L))
    expect_length(data_store$identity_modal_context, 2L)
    expect_identical(data_store$identity_modal_context[["1"]]$selector$original_row_id, 1L)
    session$setInputs(`results-identity_scope_target` = "1", `results-identity_scope_action` = "accept",
      `results-identity_scope_kind` = "registered_mixture", `results-identity_scope_conflict` = "none",
      `results-identity_scope_id` = "DTXSID123", `results-identity_scope_correspondence` = TRUE,
      `results-identity_scope_reason` = "Synthetic source correspondence", `results-identity_scope_reference` = "mock:registry",
      `results-identity_scope_save` = 1L)
    expect_identical(identity_review_state(data_store$resolution_state)$identity_eligible, c(TRUE, FALSE, FALSE))
    expect_identical(data_store$resolution_state$consensus_dtxsid, c("DTXSID123", "DTXSID789", "DTXSID789"))
    history <- data_store$review_decision_evidence
    session$setInputs(`curation-run_curation` = 2L)
    expect_identical(data_store$curation_status, "completed")
    expect_identical(data_store$resolution_state$original_row_id, 1:3)
    expect_identical(identity_review_state(data_store$resolution_state)$identity_eligible, c(TRUE, FALSE, FALSE))
    expect_identical(data_store$review_decision_evidence, history)
    expect_identical(data_store$resolution_state$source_file, source_rows$source_file)
    expect_false("original_row_id" %in% names(data_store$clean))

    # Imported source IDs are retained verbatim, rather than renumbered to the
    # upload's current positions or matched to an earlier scoped decision.
    data_store$clean$original_row_id <- c(11L, 22L, 33L)
    session$setInputs(`curation-run_curation` = 3L)
    expect_identical(data_store$resolution_state$original_row_id, c(11L, 22L, 33L))
    expect_identical(data_store$clean$original_row_id, c(11L, 22L, 33L))
    expect_false(any(identity_review_state(data_store$resolution_state)$identity_eligible))
  })
})
