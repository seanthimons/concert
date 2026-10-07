test_that("applied GUI cleaning choices are normalized and exclude unrelated switches", {
  df <- tibble::tibble(name = "  Registered combination  ", source_identifier = "DTXSID123")
  empty_reference <- tibble::tibble(term = character(), source = character(), active = logical())
  references <- stats::setNames(rep(list(empty_reference), 4L),
    c("functional_categories", "stop_words", "block_patterns", "strip_terms"))
  store <- shiny::reactiveValues(clean = df, column_tags = list(name = "Name", source_identifier = "DTXSID"),
    reference_lists = references, harmonize_run_nonce = 0L)
  shiny::testServer(mod_clean_data_server, args = list(data_store = store), {
    session$flushReact()
    session$setInputs(step_unicode = FALSE, step_whitespace = TRUE, step_cas = FALSE, step_names = FALSE,
      step_synonyms = FALSE, step_isotopes = FALSE, step_multi = FALSE, step_chiral = FALSE,
      step_units = FALSE, step_duration = FALSE, step_dates = FALSE, step_media = FALSE,
      run_checked = 1L)
    expected <- lapply(default_cleaning_step_mask(), function(x) FALSE)
    expected$whitespace <- TRUE
    expect_identical(store$cleaning_steps, expected)
    expect_identical(store$cleaned_data$name, "Registered combination")
    expect_identical(store$cleaned_data$source_identifier, df$source_identifier)
  })
})

test_that("cleaning masks survive a real workbook boundary and legacy workbooks have no mask", {
  mask <- lapply(default_cleaning_step_mask(), function(x) FALSE)
  df <- tibble::tibble(name = "Mock combination", source_identifier = "DTXSID123", original_row_id = 1L,
    consensus_dtxsid = NA_character_, consensus_status = "error")
  df <- init_resolution_state(df)
  sheets <- build_export_sheets(raw = df[c("name", "source_identifier")], resolution_state = df,
    consensus_summary = recalc_consensus_summary(df), cleaning_audit = NULL, reference_lists = list(),
    column_tags = list(name = "Name", source_identifier = "DTXSID"), detection = list(),
    file_info = list(name = "synthetic.csv", size = 100L), cleaning_steps = mask)
  path <- tempfile(fileext = ".xlsx")
  withr::defer(unlink(path))
  writexl::write_xlsx(sheets, path)
  restored <- restore_session_inputs(readxl::read_excel(path, sheet = "Session State"))
  expect_identical(restored$cleaning_steps, mask)
  legacy <- sheets[["Session State"]]
  legacy <- legacy[legacy$key != "cleaning_steps" | is.na(legacy$key), ]
  expect_null(restore_session_inputs(legacy)$cleaning_steps)
  expect_null(restore_session_inputs(NULL)$cleaning_steps)
})

test_that("malformed portable cleaning switches fail before replay", {
  masks <- list(list(names = NA), list(names = "FALSE"), list(names = c(TRUE, FALSE)),
    list(unrecognized = TRUE), list(TRUE), stats::setNames(list(TRUE, FALSE), c("names", "names")))
  for (mask in masks) {
    expect_error(serialize_session_inputs(list(cleaning_steps = mask)), "portable cleaning steps")
    # Bypass the serializer to verify the import boundary independently.
    sheet <- tibble::tibble(record_type = "portable_input_v1", row_index = 1L, key = "cleaning_steps",
      value = as.character(jsonlite::serializeJSON(mask)))
    expect_error(restore_session_inputs(sheet), "portable cleaning steps")
  }
})

test_that("skipping cleaning replays source evidence without adding chemical flags or candidates", {
  mask <- lapply(default_cleaning_step_mask(), function(x) FALSE)
  state <- list(clean_data = tibble::tibble(name = "Mock mixture (CAS 67-64-1)", source_identifier = "DTXSID123"),
    tag_map = list(name = "Name", source_identifier = "DTXSID"), reference_lists = list())
  replay <- stage_clean(state, cleaning_steps = mask)
  expect_identical(replay$cleaning_result$cleaned_data$name, state$clean_data$name)
  expect_identical(replay$cleaning_result$cleaned_data$source_identifier, state$clean_data$source_identifier)
  expect_identical(replay$merged_tags, state$tag_map)
  expect_false(any(grepl("^(cas_extract|isotope_|multi_analyte_|component_)", names(replay$cleaning_result$cleaned_data))))
  expect_equal(nrow(replay$cleaning_result$audit_trail), 0L)
  state$clean_data$original_row_id <- 27L
  retained <- stage_clean(state, cleaning_steps = mask)
  expect_identical(retained$cleaning_result$cleaned_data$original_row_id, 27L)
})

test_that("generated replay preserves a GUI decision made without Clean Data", {
  mask <- lapply(default_cleaning_step_mask(), function(x) FALSE)
  raw <- tibble::tibble(name = "Mock mixture (CAS 67-64-1)", source_identifier = "DTXSID123")
  tags <- list(name = "Name", source_identifier = "DTXSID")
  pipeline <- function(clean_data, ...) {
    # This mock models the actual curation input boundary, rather than replacing
    # the cleaned content with a fixed precomputed resolution state.
    expect_identical(clean_data$name, raw$name)
    expect_false(any(grepl("^(cas_extract|multi_analyte_|multi_cas)", names(clean_data))))
    df <- clean_data
    if (!"original_row_id" %in% names(df)) df$original_row_id <- seq_len(nrow(df))
    df$consensus_dtxsid <- NA_character_
    df$consensus_status <- "error"
    df$consensus_source <- NA_character_
    df$source_id_source_identifier_source_candidate_id <- "DTXSID123"
    df$source_id_source_identifier_validation_status <- "validated"
    df$source_id_source_identifier_identity_status <- "scope_review"
    df <- init_resolution_state(df)
    list(results = df, consensus_summary = recalc_consensus_summary(df))
  }
  local_mocked_bindings(run_curation_pipeline = pipeline,
    validate_manual_dtxsids = function(ids, ...) tibble::tibble(dtxsid = ids, is_valid = TRUE),
    postprocess_curation_candidates = function(resolution_state, ...) empty_postprocess_result(resolution_state, NULL, character()))
  df <- pipeline(raw)$results
  context <- gui_identity_context(df, 1L, tags)[[1]]
  saved <- gui_apply_identity_decision(df, NULL, NULL, df, context, "accept", "registered_mixture", "none",
    "DTXSID123", TRUE, "Source composition reviewed", "mock:registry-and-composition")
  dir <- withr::local_tempdir()
  input <- file.path(dir, "source.csv"); output <- file.path(dir, "curated.xlsx")
  readr::write_csv(raw, input)
  script <- generate_concert_script(input, output, tags, 1L, cleaning_steps = mask,
    identity_decisions = saved$identity_decisions, review_decision_evidence = saved$review_decision_evidence)
  path <- file.path(dir, "replay.R"); writeLines(script, path)
  result <- source(path, local = new.env(parent = globalenv()))$value
  expect_identical(result$data$name, raw$name)
  expect_true(identity_review_state(result$data)$identity_eligible[1])
  expect_true(identity_decision_current_rows(result$data)[1])
  expect_identical(hydrate_session_state(parse_concert_export(output))$state$identity_decisions, saved$identity_decisions)
  expect_identical(hydrate_session_state(parse_concert_export(output))$state$cleaning_steps, mask)
})
