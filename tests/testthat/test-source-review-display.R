test_that("scoped selection labels use the selected source ID rather than lookup names", {
  df <- init_resolution_state(tibble::tibble(
    consensus_status = "manual", consensus_dtxsid = c("DTXSID123", "DTXSID456"),
    consensus_source = "identity_decision", preferredName = "Unrelated lookup name",
    source_id_source_source_candidate_id = "DTXSID123",
    source_id_source_validation_status = c("validated", "unavailable"),
    source_id_source_preferred_name = "Selected source name"))
  html <- derive_resolution_html(df, 1:2)
  expect_match(html[1], "Selected source name")
  expect_false(any(grepl("Unrelated lookup name", html)))
  expect_false(grepl("Selected source name", html[2]))
  expect_match(html[2], "DTXSID456")
})

test_that("review table hides serialized decision internals and source choices show provenance", {
  hidden <- review_internal_hidden_cols(c("name", "identity_decision_record", "identity_decision_fingerprint"))
  expect_true(all(c("identity_decision_record", "identity_decision_fingerprint") %in% hidden))
  df <- init_resolution_state(tibble::tibble(original_row_id = 1:2, name = "Same chemical",
    source_file = c("inventory A", "inventory B")))
  context <- gui_identity_context(df, 1:2, list(name = "Name"))
  controls <- as.character(identity_scope_review_controls(list(ns = identity), context))
  expect_match(controls, "inventory A")
  expect_match(controls, "inventory B")
})

test_that("the review module exports applied cleaning choices rather than draft defaults", {
  captured <- NULL
  local_mocked_bindings(generate_concert_script = function(...) {
    captured <<- list(...)
    "# synthetic replay"
  })
  df <- init_resolution_state(tibble::tibble(original_row_id = 1L, name = "Synthetic source",
    consensus_dtxsid = NA_character_, consensus_status = "error"))
  store <- shiny::reactiveValues(resolution_state = df, script_baseline_state = df,
    clean = df[c("name")], column_tags = list(name = "Name"), file_info = list(name = "synthetic.csv"))
  shiny::testServer(mod_review_results_server, args = list(data_store = store), {
    replay_script_text()
    expect_identical(captured$cleaning_steps, lapply(default_cleaning_step_mask(), function(x) FALSE))
    store$cleaned_data <- df
    store$cleaning_steps <- list(whitespace = TRUE, names = FALSE)
    replay_script_text()
    expect_identical(captured$cleaning_steps, store$cleaning_steps)
  })
})
