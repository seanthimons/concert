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
