test_that("curate_headless can run harmonized output fully in memory", {
  skip_if_not_installed("withr")

  input_path <- tempfile(fileext = ".csv")
  output_path <- tempfile(fileext = ".xlsx")
  readr::write_csv(
    tibble::tibble(
      chemical = "pH",
      result = "7.1",
      unit = "standard units"
    ),
    input_path
  )
  withr::defer(unlink(input_path))
  withr::defer(unlink(output_path))

  local_mocked_bindings(
    run_curation_pipeline = function(cleaned_data, merged_tags, ...) {
      cleaned_data$consensus_status <- "wqx"
      cleaned_data$consensus_dtxsid <- NA_character_
      list(
        results = cleaned_data,
        consensus_summary = tibble::tibble(status = "wqx", n = 1)
      )
    }
  )

  result <- curate_headless(
    input_path = input_path,
    output_path = NULL,
    tag_map = list(chemical = "Name", result = "Result", unit = "Unit"),
    harmonize = TRUE,
    write_files = FALSE,
    source_name = "EPA SSWQS",
    verbose = FALSE
  )

  expect_named(result, c("data", "audit_trail", "harmonize_audit"))
  expect_s3_class(result$data, "tbl_df")
  expect_equal(result$data$source, "EPA SSWQS")
  expect_false(file.exists(output_path))
})

test_that("curate_headless requires output_path only when writing files", {
  input_path <- tempfile(fileext = ".csv")
  readr::write_csv(tibble::tibble(chemical = "pH"), input_path)
  withr::defer(unlink(input_path))

  expect_error(
    curate_headless(
      input_path = input_path,
      output_path = NULL,
      tag_map = list(chemical = "Name"),
      write_files = TRUE,
      verbose = FALSE
    ),
    "output_path is required"
  )
})

test_that("curate_headless returns Numeric measurement audit without mapping it to toxval_numeric", {
  skip_if_not_installed("withr")

  input_path <- tempfile(fileext = ".csv")
  readr::write_csv(
    tibble::tibble(
      chemical = "Benzene",
      reporting_limit = "5-10",
      unit = "ug/L"
    ),
    input_path
  )
  withr::defer(unlink(input_path))

  unit_map <- tibble::tibble(
    from_unit = "ug/L",
    to_unit = "mg/L",
    multiplier = 0.001,
    category = "mass_concentration"
  )

  local_mocked_bindings(
    run_curation_pipeline = function(cleaned_data, merged_tags, ...) {
      cleaned_data$consensus_status <- "agree"
      cleaned_data$consensus_dtxsid <- "DTXSID7020182"
      list(
        results = cleaned_data,
        consensus_summary = list(
          n_agree = 1,
          n_disagree = 0,
          n_agree_caveat = 0,
          n_single = 0,
          n_manual = 0,
          n_error = 0,
          n_unresolvable = 0
        )
      )
    }
  )

  result <- curate_headless(
    input_path = input_path,
    output_path = NULL,
    tag_map = list(chemical = "Name", reporting_limit = "Numeric", unit = "Unit"),
    harmonize = TRUE,
    unit_map = unit_map,
    corrections = tibble::tibble(pattern = character(), replacement = character()),
    write_files = FALSE,
    verbose = FALSE
  )

  expect_equal(nrow(result$data), 1)
  expect_true(is.na(result$data$toxval_numeric))
  expect_equal(nrow(result$harmonize_audit), 3)
  expect_equal(unique(result$harmonize_audit$measurement_column), "reporting_limit")
  expect_equal(result$harmonize_audit$range_bin, c("low", "mid", "high"))
  expect_equal(result$harmonize_audit$harmonized_value, c(0.005, 0.0075, 0.01))
})

headless_snapshot_defaults <- function() {
  list(
    functional_categories = tibble::tibble(term = "Solvent", source = "ComptoxR", active = TRUE),
    stop_words = tibble::tibble(term = "test", source = "app_default", active = TRUE),
    block_patterns = tibble::tibble(term = "^proprietary", source = "app_default", active = TRUE),
    strip_terms = tibble::tibble(term = "pure", source = "app_default", active = TRUE),
    isotope_lookup = list(lookup = tibble::tibble(), elem_alt_names = character())
  )
}

headless_snapshot_from_refs <- function(reference_lists, defaults) {
  snapshot <- lapply(cleaning_reference_list_names(), function(type) {
    list(
      default_hash = reference_snapshot_hash(defaults[[type]], type),
      overrides = reference_list_snapshot_overrides(reference_lists[[type]], defaults[[type]], type)
    )
  })
  names(snapshot) <- cleaning_reference_list_names()
  snapshot
}

test_that("curate_headless reconstructs reference snapshots for cleaning replay", {
  input_path <- tempfile(fileext = ".csv")
  readr::write_csv(
    tibble::tibble(chemical = "field blank", casrn = "67-64-1"),
    input_path
  )
  withr::defer(unlink(input_path))

  defaults <- headless_snapshot_defaults()
  effective <- defaults
  effective$stop_words <- dplyr::bind_rows(
    tibble::tibble(
      term = "field blank",
      pattern = "field blank",
      match_mode = "literal_word",
      source = "user",
      active = TRUE,
      notes = NA_character_
    ),
    effective$stop_words
  )
  snapshot <- headless_snapshot_from_refs(effective, defaults)
  seen_refs <- NULL

  local_mocked_bindings(
    load_all_default_reference_lists = function(cache_dir = NULL) defaults,
    run_cleaning_pipeline = function(df, tag_map, reference_lists, ...) {
      seen_refs <<- reference_lists
      list(cleaned_data = df, audit_trail = tibble::tibble(), new_tags = list())
    },
    run_curation_pipeline = function(clean_data, column_tags, ...) {
      list(
        results = init_resolution_state(clean_data),
        consensus_summary = tibble::tibble(status = character(), n = integer())
      )
    }
  )

  curate_headless(
    input_path = input_path,
    output_path = NULL,
    tag_map = list(chemical = "Name", casrn = "CASRN"),
    header_row = 1L,
    reference_list_snapshot = snapshot,
    write_files = FALSE,
    verbose = FALSE
  )

  expect_true("field blank" %in% seen_refs$stop_words$term)
  expect_equal(
    seen_refs$stop_words$source[seen_refs$stop_words$term == "field blank"],
    "user"
  )
})

test_that("curate_headless activates snapshot rows in memory and rejects ambiguous reference inputs", {
  input_path <- tempfile(fileext = ".csv")
  readr::write_csv(
    tibble::tibble(chemical = "field blank", casrn = "67-64-1"),
    input_path
  )
  withr::defer(unlink(input_path))

  defaults <- headless_snapshot_defaults()
  effective <- defaults
  effective$stop_words <- dplyr::bind_rows(
    tibble::tibble(
      term = "field blank",
      pattern = "field blank",
      match_mode = "literal_word",
      source = "user",
      active = FALSE,
      notes = NA_character_
    ),
    effective$stop_words
  )
  snapshot <- headless_snapshot_from_refs(effective, defaults)
  seen_refs <- NULL

  local_mocked_bindings(
    load_all_default_reference_lists = function(cache_dir = NULL) defaults,
    run_cleaning_pipeline = function(df, tag_map, reference_lists, ...) {
      seen_refs <<- reference_lists
      list(cleaned_data = df, audit_trail = tibble::tibble(), new_tags = list())
    },
    run_curation_pipeline = function(clean_data, column_tags, ...) {
      list(
        results = init_resolution_state(clean_data),
        consensus_summary = tibble::tibble(status = character(), n = integer())
      )
    }
  )

  curate_headless(
    input_path = input_path,
    output_path = NULL,
    tag_map = list(chemical = "Name", casrn = "CASRN"),
    header_row = 1L,
    reference_list_snapshot = snapshot,
    activate_all_references = TRUE,
    write_files = FALSE,
    verbose = FALSE
  )

  expect_true(all(seen_refs$stop_words$active))
  expect_false(effective$stop_words$active[effective$stop_words$term == "field blank"])

  expect_error(
    curate_headless(
      input_path = input_path,
      output_path = NULL,
      tag_map = list(chemical = "Name", casrn = "CASRN"),
      header_row = 1L,
      reference_lists = defaults,
      reference_list_snapshot = snapshot,
      write_files = FALSE,
      verbose = FALSE
    ),
    "either reference_lists or reference_list_snapshot"
  )
})
