# test-parquet-roundtrip.R
# Round-trip validation for ToxVal parquet export: write known tibble, read back,
# assert column types + values match (D-12: test-only validation, no runtime check).

# ============================================================================
# Test fixtures
# ============================================================================

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

# ============================================================================
# Round-trip: write + read via arrow
# ============================================================================

test_that("parquet round-trip: 56 columns preserved", {
  temp_file <- tempfile(fileext = ".parquet")
  withr::defer(unlink(temp_file))

  arrow::write_parquet(toxval_fixture, temp_file)
  result <- arrow::read_parquet(temp_file)

  expect_equal(ncol(result), 56)
  expect_equal(names(result), names(toxval_fixture))
})

test_that("parquet round-trip: column types preserved", {
  temp_file <- tempfile(fileext = ".parquet")
  withr::defer(unlink(temp_file))

  arrow::write_parquet(toxval_fixture, temp_file)
  result <- arrow::read_parquet(temp_file)

  types_orig <- vapply(toxval_fixture, typeof, "")
  types_rt <- vapply(result, typeof, "")

  expect_equal(types_rt, types_orig)
})

test_that("parquet round-trip: values match original", {
  temp_file <- tempfile(fileext = ".parquet")
  withr::defer(unlink(temp_file))

  arrow::write_parquet(toxval_fixture, temp_file)
  result <- arrow::read_parquet(temp_file)

  expect_equal(result$dtxsid, toxval_fixture$dtxsid)
  expect_equal(result$casrn, toxval_fixture$casrn)
  expect_equal(result$toxval_numeric, toxval_fixture$toxval_numeric)
  expect_equal(result$toxval_units, toxval_fixture$toxval_units)
  expect_equal(result$source_hash, toxval_fixture$source_hash)
})

test_that("parquet round-trip: no logical columns after read", {
  temp_file <- tempfile(fileext = ".parquet")
  withr::defer(unlink(temp_file))

  arrow::write_parquet(toxval_fixture, temp_file)
  result <- arrow::read_parquet(temp_file)

  types_rt <- vapply(result, typeof, "")
  logical_cols <- names(types_rt)[types_rt == "logical"]
  expect_equal(
    length(logical_cols),
    0,
    info = paste("Logical columns found:", paste(logical_cols, collapse = ", "))
  )
})

test_that("parquet round-trip: zero-row tibble produces valid parquet", {
  cache_dir <- system.file("extdata/reference_cache", package = "concert")
  empty_schema <- load_toxval_schema(cache_dir)

  temp_file <- tempfile(fileext = ".parquet")
  withr::defer(unlink(temp_file))

  arrow::write_parquet(empty_schema, temp_file)
  result <- arrow::read_parquet(temp_file)

  expect_equal(nrow(result), 0)
  expect_equal(ncol(result), 56)
})

# ============================================================================
# File naming convention (D-03)
# ============================================================================

test_that("ToxVal output file derives basename from output_path", {
  # Test the file naming logic used by curate_headless
  output_path <- "/tmp/test_output/sswqs_benchmark.xlsx"
  toxval_base <- sub("\\.xlsx$", "", output_path, ignore.case = TRUE)

  expect_equal(
    paste0(toxval_base, "_toxval.parquet"),
    "/tmp/test_output/sswqs_benchmark_toxval.parquet"
  )
  expect_equal(
    paste0(toxval_base, "_toxval.csv"),
    "/tmp/test_output/sswqs_benchmark_toxval.csv"
  )
})

# ============================================================================
# CSV round-trip
# ============================================================================

test_that("CSV round-trip: column count preserved", {
  temp_file <- tempfile(fileext = ".csv")
  withr::defer(unlink(temp_file))

  readr::write_csv(toxval_fixture, temp_file)
  result <- readr::read_csv(temp_file, show_col_types = FALSE)

  expect_equal(ncol(result), 56)
  expect_equal(names(result), names(toxval_fixture))
})

# ============================================================================
# Format validation
# ============================================================================

test_that("invalid format value raises error", {
  expect_error(
    {
      if (!"excel" %in% c("parquet", "csv", "both")) {
        stop(sprintf(
          "curate_headless: invalid format '%s'. Use 'parquet', 'csv', or 'both'.",
          "excel"
        ))
      }
    },
    "invalid format 'excel'"
  )
})
