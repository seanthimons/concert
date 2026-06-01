# Test each module server initializes without error

# Create mock data_store matching app.R's reactiveValues structure
create_test_store <- function() {
  shiny::reactiveValues(
    raw = NULL, clean = NULL, detection = NULL, file_info = NULL,
    selected_columns = NULL, column_tags = NULL,
    cleaning_audit = NULL, cleaned_data = NULL, reference_lists = NULL,
    curation_results = NULL, curation_report = NULL, curation_status = NULL,
    dedup_preview = NULL, consensus_data = NULL, consensus_summary = NULL,
    resolution_state = NULL, dtxsid_cols = NULL, priority_order = NULL,
    error_filter_active = FALSE, display_row_map = NULL,
    selected_error_rows = NULL, manual_queue = list(),
    qc_results = NULL,
    enrichment_cache = NULL,
    enrichment_failed = NULL,
    # Phase 33: Extended tag types
    numeric_tags = NULL,
    metadata_tags = NULL,
    harmonize_results = NULL,
    harmonize_audit = NULL,
    toxval_output = NULL,
    prev_chemical_tags = NULL,
    prev_numeric_tags = NULL,
    # Phase 34: Editor working copies
    unit_map_working = NULL,
    corrections_working = NULL
  )
}

test_that("mod_file_upload_server initializes without error", {
  shiny::testServer(mod_file_upload_server, args = list(
    data_store = create_test_store(),
    reset_all_downstream = function() {}
  ), {
    session$flushReact()
    expect_true(TRUE)  # Reaching here means no init error
  })
})

test_that("mod_data_preview_server initializes without error", {
  shiny::testServer(mod_data_preview_server, args = list(
    data_store = create_test_store(),
    preview_rows = shiny::reactive(10)
  ), {
    session$flushReact()
    expect_true(TRUE)
  })
})

test_that("mod_detection_info_server initializes without error", {
  shiny::testServer(mod_detection_info_server, args = list(
    data_store = create_test_store()
  ), {
    session$flushReact()
    expect_true(TRUE)
  })
})

test_that("mod_raw_data_server initializes without error", {
  shiny::testServer(mod_raw_data_server, args = list(
    data_store = create_test_store()
  ), {
    session$flushReact()
    expect_true(TRUE)
  })
})

test_that("mod_clean_data_server initializes without error", {
  shiny::testServer(mod_clean_data_server, args = list(
    data_store = create_test_store(),
    on_cleaning_complete = NULL
  ), {
    session$flushReact()
    expect_true(TRUE)
  })
})

test_that("mod_tag_columns_server initializes without error", {
  shiny::testServer(mod_tag_columns_server, args = list(
    data_store = create_test_store(),
    on_tags_applied = NULL
  ), {
    session$flushReact()
    expect_true(TRUE)
  })
})

test_that("mod_run_curation_server initializes without error", {
  shiny::testServer(mod_run_curation_server, args = list(
    data_store = create_test_store(),
    on_curation_complete = NULL
  ), {
    session$flushReact()
    expect_true(TRUE)
  })
})

test_that("mod_review_results_server initializes without error", {
  shiny::testServer(mod_review_results_server, args = list(
    data_store = create_test_store()
  ), {
    session$flushReact()
    expect_true(TRUE)
  })
})

test_that("mod_harmonize_server initializes without error", {
  shiny::testServer(mod_harmonize_server, args = list(
    data_store = create_test_store()
  ), {
    session$flushReact()
    expect_true(TRUE)  # Reaching here means no init error
  })
})

# Note: Return value tests skipped due to testServer() limitations
# Return values (preview_rows, tags_applied, curation_completed) are tested
# implicitly via integration testing and manual smoke tests

# Helper: find mod_review_results.R source from various test contexts
find_mod_review_results <- function() {
  candidates <- c(
    file.path(here::here(), "R", "mod_review_results.R"),
    file.path(getwd(), "R", "mod_review_results.R"),
    file.path(dirname(dirname(testthat::test_path())), "R", "mod_review_results.R")
  )
  for (p in candidates) {
    if (file.exists(p)) return(p)
  }
  NULL
}

find_mod_tag_columns <- function() {
  candidates <- c(
    file.path(here::here(), "R", "mod_tag_columns.R"),
    file.path(getwd(), "R", "mod_tag_columns.R"),
    file.path(dirname(dirname(testthat::test_path())), "R", "mod_tag_columns.R")
  )
  for (p in candidates) {
    if (file.exists(p)) return(p)
  }
  NULL
}

# UIPOL-01: Verify reactable call uses wrap = TRUE (not wrap = FALSE)
test_that("UIPOL-01: review results reactable uses wrap=TRUE", {
  src_path <- find_mod_review_results()
  skip_if(is.null(src_path), "R/mod_review_results.R not found from test context")
  src <- readLines(src_path)
  wrap_true_lines <- grep("wrap\\s*=\\s*TRUE", src)
  expect_true(length(wrap_true_lines) > 0, info = "wrap = TRUE must be present in mod_review_results.R")
  wrap_false_lines <- grep("wrap\\s*=\\s*FALSE", src)
  expect_equal(length(wrap_false_lines), 0, info = "wrap = FALSE must not appear in mod_review_results.R")
})

# UIPOL-02: Verify elementId is not present in the reactable call
test_that("UIPOL-02: review results reactable does not use elementId", {
  src_path <- find_mod_review_results()
  skip_if(is.null(src_path), "R/mod_review_results.R not found from test context")
  src <- readLines(src_path)
  element_id_lines <- grep("elementId", src)
  expect_equal(length(element_id_lines), 0, info = "elementId must not appear in mod_review_results.R")
})

# UIPOL-03: Verify unname() wraps unlist(queue) to prevent jsonlite named vector warning
test_that("UIPOL-03: unlist(queue) is wrapped with unname() to prevent jsonlite warning", {
  src_path <- find_mod_review_results()
  skip_if(is.null(src_path), "R/mod_review_results.R not found from test context")
  src <- readLines(src_path)
  # The fix must be present
  unname_unlist_lines <- grep("unname\\(unlist\\(", src)
  expect_true(length(unname_unlist_lines) > 0, info = "unname(unlist(...)) must be present in mod_review_results.R")
  # The unfixed pattern must NOT be present (bare unlist(queue) without unname)
  bare_unlist_lines <- grep("^\\s*all_dtxsids\\s*<-\\s*unlist\\(queue\\)", src)
  expect_equal(length(bare_unlist_lines), 0, info = "bare unlist(queue) without unname() must not be present at the all_dtxsids assignment")
})

test_that("UIPOL-04: re-tag modal uses named list choices to avoid jsonlite warning", {
  src_path <- find_mod_review_results()
  skip_if(is.null(src_path), "R/mod_review_results.R not found from test context")
  src <- readLines(src_path)

  named_list_lines <- grep(
    "choices = list\\(\"\\(none\\)\" = \"\", \"Name\" = \"Name\", \"CASRN\" = \"CASRN\", \"Other\" = \"Other\"\\)",
    src
  )
  expect_true(length(named_list_lines) > 0, info = "re-tag modal choices must use list(...)")

  named_vector_lines <- grep(
    "choices = c\\(\"\\(none\\)\" = \"\", \"Name\" = \"Name\", \"CASRN\" = \"CASRN\", \"Other\" = \"Other\"\\)",
    src
  )
  expect_equal(length(named_vector_lines), 0, info = "re-tag modal choices must not use c(...)")
})

test_that("Tag Columns table puts Type before Column Name", {
  src_path <- find_mod_tag_columns()
  skip_if(is.null(src_path), "R/mod_tag_columns.R not found from test context")
  src <- paste(readLines(src_path), collapse = "\n")

  type_pos <- regexpr('tags\\$th\\("Type"', src)[[1]]
  name_pos <- regexpr('tags\\$th\\("Column Name"', src)[[1]]

  expect_true(type_pos > 0)
  expect_true(name_pos > 0)
  expect_lt(type_pos, name_pos)
})

test_that("Tag Columns rows have selected-state styling hook", {
  src_path <- find_mod_tag_columns()
  skip_if(is.null(src_path), "R/mod_tag_columns.R not found from test context")
  src <- paste(readLines(src_path), collapse = "\n")

  expect_match(src, "tag-column-row")
  expect_match(src, "tag-column-selected")
  expect_match(src, "shiny:inputchanged")
})
