library(testthat)
library(shiny)
library(DT)
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
