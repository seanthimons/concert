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

test_that("write_curation_output keeps the existing workbook when the new one cannot be read back", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "out.xlsx")
  expect_identical(write_curation_output(path, "xlsx", sheets = list(a = data.frame(x = 1))), path)
  before <- tools::md5sum(path)

  # Stand in for writexl on a full temp disk: no error, a file with nothing in it.
  local_mocked_bindings(write_xlsx = function(x, path, ...) file.create(path), .package = "writexl")
  expect_error(
    write_curation_output(path, "xlsx", sheets = list(a = data.frame(x = 2))),
    "out.xlsx could not be written"
  )
  expect_identical(tools::md5sum(path), before)
  expect_identical(readxl::read_excel(path)$x, 1)
  expect_identical(list.files(dir), "out.xlsx")
})

test_that("check_xlsx_readable rejects a workbook with an empty part", {
  skip_if(!nzchar(Sys.which("zip")))
  dir <- withr::local_tempdir()
  good <- file.path(dir, "good.xlsx")
  writexl::write_xlsx(list(a = data.frame(x = 1), b = data.frame()), good)
  expect_identical(check_xlsx_readable(good), good)

  parts <- file.path(dir, "parts")
  utils::unzip(good, exdir = parts)
  file.create(file.path(parts, "xl", "worksheets", "sheet1.xml"))
  bad <- file.path(dir, "bad.xlsx")
  withr::with_dir(parts, utils::zip(bad, list.files(".", recursive = TRUE, all.files = TRUE), flags = "-q"))
  expect_error(check_xlsx_readable(bad), "empty parts: xl/worksheets/sheet1.xml")
})
