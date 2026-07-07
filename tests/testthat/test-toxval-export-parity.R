# test-toxval-export-parity.R
# The Shiny app and headless pipeline both write the flat ToxVal table through
# write_curation_output(). These tests assert the CSV and Parquet forms round-trip
# to an identical 56-column schema, so the two entry points cannot drift.

# Build fixture via the mapper (avoids duplicating 56-column construction)
curated_fixture <- tibble::tibble(
  dtxsid = c("DTXSID7020182", "DTXSID2021731"),
  casrn = c("71-43-2", "7440-02-0"),
  name = c("Benzene", "Nickel"),
  qualifier = c("<", ""),
  orig_result = c("< 0.5", "10.0")
)
harmonized_fixture <- tibble::tibble(
  orig_row_id = 1:2,
  orig_unit = c("ug/L", "mg/L"),
  harmonized_value = c(0.0005, 10.0),
  harmonized_unit = c("mg/L", "mg/L"),
  conversion_factor = c(0.001, 1),
  unit_flag = c("", "")
)
toxval_fixture <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

test_that("write_curation_output csv and parquet match the schema template", {
  schema <- get_empty_schema()

  csv_path <- tempfile(fileext = ".csv")
  parquet_path <- tempfile(fileext = ".parquet")
  withr::defer(unlink(c(csv_path, parquet_path)))

  write_curation_output(csv_path, "csv", toxval_tibble = toxval_fixture)
  write_curation_output(parquet_path, "parquet", toxval_tibble = toxval_fixture)

  csv_rt <- readr::read_csv(csv_path, show_col_types = FALSE)
  parquet_rt <- arrow::read_parquet(parquet_path)

  # Both carry the full 56-column schema, in schema order
  expect_equal(names(csv_rt), names(schema))
  expect_equal(names(parquet_rt), names(schema))
})

test_that("csv and parquet round-trips are schema-identical to each other", {
  csv_path <- tempfile(fileext = ".csv")
  parquet_path <- tempfile(fileext = ".parquet")
  withr::defer(unlink(c(csv_path, parquet_path)))

  write_curation_output(csv_path, "csv", toxval_tibble = toxval_fixture)
  write_curation_output(parquet_path, "parquet", toxval_tibble = toxval_fixture)

  csv_rt <- readr::read_csv(csv_path, show_col_types = FALSE)
  parquet_rt <- arrow::read_parquet(parquet_path)

  # Same columns, same order (the app-path vs headless-path guarantee)
  expect_equal(names(csv_rt), names(parquet_rt))

  # Parquet preserves types exactly against the source tibble
  expect_equal(vapply(parquet_rt, typeof, ""), vapply(toxval_fixture, typeof, ""))

  # Key values agree across both formats
  expect_equal(csv_rt$dtxsid, parquet_rt$dtxsid)
  expect_equal(csv_rt$toxval_numeric, parquet_rt$toxval_numeric)
  expect_equal(csv_rt$source_hash, parquet_rt$source_hash)
})

test_that("write_curation_output xlsx builds the multi-sheet workbook", {
  sheets <- list(
    "ToxVal Output" = toxval_fixture,
    "Summary" = tibble::tibble(Metric = "Total Rows", Value = 2)
  )
  xlsx_path <- tempfile(fileext = ".xlsx")
  withr::defer(unlink(xlsx_path))

  write_curation_output(xlsx_path, "xlsx", sheets = sheets)

  expect_true(file.exists(xlsx_path))
  expect_setequal(readxl::excel_sheets(xlsx_path), names(sheets))
})
