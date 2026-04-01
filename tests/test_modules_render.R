library(testthat)
library(shiny)
library(reactable)
library(reactable.extras)
library(bslib)
library(htmltools)

# Source all R files (modules + utilities)
for (f in list.files(here::here("R"), recursive = TRUE, pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}

# Create mock data_store matching app.R's reactiveValues structure
create_test_store <- function() {
  reactiveValues(
    raw = NULL, clean = NULL, detection = NULL, file_info = NULL,
    selected_columns = NULL, column_tags = NULL,
    cleaning_audit = NULL, cleaned_data = NULL, reference_lists = NULL,
    curation_results = NULL, curation_report = NULL, curation_status = NULL,
    dedup_preview = NULL, consensus_data = NULL, consensus_summary = NULL,
    resolution_state = NULL, dtxsid_cols = NULL, priority_order = NULL,
    error_filter_active = FALSE, display_row_map = NULL,
    selected_error_rows = NULL, manual_queue = list()
  )
}

# Test each module server initializes without error
test_that("mod_file_upload_server initializes without error", {
  testServer(mod_file_upload_server, args = list(
    data_store = create_test_store(),
    reset_all_downstream = function() {}
  ), {
    session$flushReact()
    expect_true(TRUE)  # Reaching here means no init error
  })
})

test_that("mod_data_preview_server initializes without error", {
  testServer(mod_data_preview_server, args = list(
    data_store = create_test_store(),
    preview_rows = reactive(10)
  ), {
    session$flushReact()
    expect_true(TRUE)
  })
})

test_that("mod_detection_info_server initializes without error", {
  testServer(mod_detection_info_server, args = list(
    data_store = create_test_store()
  ), {
    session$flushReact()
    expect_true(TRUE)
  })
})

test_that("mod_raw_data_server initializes without error", {
  testServer(mod_raw_data_server, args = list(
    data_store = create_test_store()
  ), {
    session$flushReact()
    expect_true(TRUE)
  })
})

test_that("mod_clean_data_server initializes without error", {
  testServer(mod_clean_data_server, args = list(
    data_store = create_test_store(),
    on_cleaning_complete = NULL
  ), {
    session$flushReact()
    expect_true(TRUE)
  })
})

test_that("mod_tag_columns_server initializes without error", {
  testServer(mod_tag_columns_server, args = list(
    data_store = create_test_store(),
    on_tags_applied = NULL
  ), {
    session$flushReact()
    expect_true(TRUE)
  })
})

test_that("mod_run_curation_server initializes without error", {
  testServer(mod_run_curation_server, args = list(
    data_store = create_test_store(),
    on_curation_complete = NULL
  ), {
    session$flushReact()
    expect_true(TRUE)
  })
})

test_that("mod_review_results_server initializes without error", {
  testServer(mod_review_results_server, args = list(
    data_store = create_test_store()
  ), {
    session$flushReact()
    expect_true(TRUE)
  })
})

# Note: Return value tests skipped due to testServer() limitations
# Return values (preview_rows, tags_applied, curation_completed) are tested
# implicitly via integration testing and manual smoke tests

# UIPOL-01: Verify reactable call uses wrap = TRUE (not wrap = FALSE)
test_that("UIPOL-01: review results reactable uses wrap=TRUE", {
  src <- readLines(here::here("R/modules/mod_review_results.R"))
  wrap_true_lines <- grep("wrap\\s*=\\s*TRUE", src)
  expect_true(length(wrap_true_lines) > 0, info = "wrap = TRUE must be present in mod_review_results.R")
  wrap_false_lines <- grep("wrap\\s*=\\s*FALSE", src)
  expect_equal(length(wrap_false_lines), 0, info = "wrap = FALSE must not appear in mod_review_results.R")
})

# UIPOL-02: Verify elementId is not present in the reactable call
test_that("UIPOL-02: review results reactable does not use elementId", {
  src <- readLines(here::here("R/modules/mod_review_results.R"))
  element_id_lines <- grep("elementId", src)
  expect_equal(length(element_id_lines), 0, info = "elementId must not appear in mod_review_results.R")
})

# UIPOL-03: Verify unname() wraps unlist(queue) to prevent jsonlite named vector warning
test_that("UIPOL-03: unlist(queue) is wrapped with unname() to prevent jsonlite warning", {
  src <- readLines(here::here("R/modules/mod_review_results.R"))
  # The fix must be present
  unname_unlist_lines <- grep("unname\\(unlist\\(", src)
  expect_true(length(unname_unlist_lines) > 0, info = "unname(unlist(...)) must be present in mod_review_results.R")
  # The unfixed pattern must NOT be present (bare unlist(queue) without unname)
  bare_unlist_lines <- grep("^\\s*all_dtxsids\\s*<-\\s*unlist\\(queue\\)", src)
  expect_equal(length(bare_unlist_lines), 0, info = "bare unlist(queue) without unname() must not be present at the all_dtxsids assignment")
})
