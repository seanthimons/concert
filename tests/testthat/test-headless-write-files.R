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
