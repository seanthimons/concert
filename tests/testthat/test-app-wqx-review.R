test_that("actual app preserves WQX candidates through scoped GUI review and rerun", {
  fixtures <- new.env(parent = globalenv())
  sys.source(test_path("../../inst/examples/wqx-review-app.R"), envir = fixtures)
  fixtures$with_wqx_review_fixture_services({
    app <- new.env(parent = globalenv())
    sys.source(test_path("../../inst/app/app.R"), envir = app)
    upload <- normalizePath(test_path("../../inst/examples/wqx-review-upload.csv"))
    shiny::testServer(app$server, {
      session$flushReact()
      session$setInputs(`upload-detection_mode` = "manual", `upload-manual_header_row` = 1L)
      session$setInputs(`upload-file_upload` = data.frame(name = "wqx-review-upload.csv",
        size = file.info(upload)$size, type = "text/csv", datapath = upload))
      expect_equal(nrow(data_store$clean), 3L)
      data_store$selected_columns <- names(data_store$clean)
      session$setInputs(`tags-tag_name` = "Name", `tags-tag_source_file` = "", `tags-apply_tags` = 1L)
      session$setInputs(`curation-run_curation` = 1L)
      expect_identical(data_store$curation_status, "completed")
      baseline <- data_store$resolution_state
      expect_identical(baseline$original_row_id, 1:3)
      expect_identical(baseline$name, c("Arsenick", "DO", "TETRACYCLINES"))
      expect_identical(baseline$wqx_name, c("Arsenic", "Dissolved oxygen", "Tetracycline"))
      expect_identical(baseline$wqx_match_tier, c("fuzzy", "alias", "fuzzy"))
      expect_identical(baseline$wqx_cas_dtxsid_candidates, c("DTXSID999000001", NA_character_, "DTXSID999000003"))
      expect_identical(baseline$wqx_cas_lookup_status, c("candidate", "missing", "candidate"))
      expect_true(all(is.na(baseline$consensus_dtxsid)))
      expect_false(any(identity_review_state(baseline)$identity_eligible))
      expect_identical(baseline$resolver_query,
        c("Arsenick; Arsenic", "DO; Dissolved oxygen", "TETRACYCLINES; Tetracycline"))
      expect_equal(nrow(pending_rows(list(resolution_state = baseline, merged_chemical_tags = data_store$column_tags))), 3L)

      session$setInputs(`results-expert_override_click` = list(row = 1L))
      expect_length(data_store$identity_modal_context, 1L)
      session$setInputs(`results-identity_scope_target` = "1")
      evidence <- output$`results-identity_scope_evidence`
      expect_match(paste(evidence$html, collapse = ""), "7440-38-2", fixed = TRUE)
      expect_match(paste(evidence$html, collapse = ""), "Arsenick", fixed = TRUE)
      session$setInputs(`results-identity_scope_target` = "1", `results-identity_scope_action` = "accept",
        `results-identity_scope_kind` = "substance", `results-identity_scope_conflict` = "none",
        `results-identity_scope_id` = "DTXSID999000001", `results-identity_scope_correspondence` = TRUE,
        `results-identity_scope_reason` = "Synthetic source scope checked", `results-identity_scope_reference` = "mock:scope-A",
        `results-identity_scope_save` = 1L)
      expect_identical(identity_review_state(data_store$resolution_state)$identity_eligible, c(TRUE, FALSE, FALSE))
      expect_identical(data_store$resolution_state$consensus_dtxsid, c("DTXSID999000001", NA_character_, NA_character_))

      session$setInputs(`results-expert_override_click` = list(row = 2L))
      session$setInputs(`results-modal_row_flag` = "VERIFIED", `results-modal_row_flag_reason` = "Retain reviewed WQX name only",
        `results-modal_review_disposition` = "other", `results-modal_apply_row_flag` = 1L)
      expect_identical(data_store$resolution_state$row_flag, c(NA_character_, "VERIFIED", NA_character_))
      expect_true(is.na(data_store$resolution_state$consensus_dtxsid[2L]))
      expect_identical(pending_rows(list(resolution_state = data_store$resolution_state,
        merged_chemical_tags = data_store$column_tags))$row_index, 3L)
      history <- data_store$review_decision_evidence
      session$setInputs(`curation-run_curation` = 2L)
      expect_identical(data_store$curation_status, "completed")
      expect_identical(identity_review_state(data_store$resolution_state)$identity_eligible, c(TRUE, FALSE, FALSE))
      expect_identical(data_store$resolution_state$wqx_cas_dtxsid_candidates, baseline$wqx_cas_dtxsid_candidates)
      expect_identical(data_store$resolution_state$wqx_name, baseline$wqx_name)
      expect_identical(data_store$resolution_state$row_flag, c(NA_character_, "VERIFIED", NA_character_))
      expect_identical(data_store$review_decision_evidence, history)
      expect_identical(data_store$resolution_state$source_file, baseline$source_file)
      expect_identical(data_store$clean$name, baseline$name)
    })
  })
})
