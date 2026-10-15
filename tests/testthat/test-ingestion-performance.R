# Ceilings are ~10x the measured time on a dev laptop (scripts/benchmark_ingestion.R)
# and well under the pre-vectorization times, so they catch algorithmic
# regressions (per-element closures, quadratic loops) without flaking on CI.

source(test_path("..", "..", "scripts", "benchmark_ingestion.R"), local = TRUE)

expect_faster_than <- function(expr, seconds) {
  elapsed <- system.time(expr)[["elapsed"]]
  expect_lt(elapsed, seconds, label = sprintf("%.2fs elapsed", elapsed))
}

test_that("CAS helpers stay vectorized at 100k values", {
  skip_on_cran()
  x <- rep(c("67-64-1", "71-43-2", "0103-02-06", "67641", "50-00-1", "no cas", NA), length.out = 1e5)
  # Before vectorization: is_cas 23s, as_cas 46s, extract_cas 50s
  expect_faster_than(is_cas(x), 3)
  expect_faster_than(as_cas(x), 3)
  expect_faster_than(extract_cas(x), 5)
  expect_faster_than(repair_cas_date_coercion(x), 3)
})

test_that("100k-row CSV with a preamble ingests and normalizes CAS in budget", {
  skip_on_cran()
  df <- ingestion_benchmark_data(1e5)
  csv <- write_ingestion_csv(df)
  on.exit(unlink(csv))

  # Before: ~116s end to end, 98s of it in normalize_cas_fields
  elapsed <- system.time({
    raw <- suppressWarnings(read_csv_robust(csv))
    det <- detect_data_start(raw)
    clean <- extract_clean_data(raw, det)
    pc <- precheck_normalize_cas(clean, list(casrn = "CASRN"))
    result <- normalize_cas_fields(clean, list(casrn = "CASRN"))
  })[["elapsed"]]

  expect_lt(elapsed, 30, label = sprintf("%.2fs elapsed", elapsed))
  expect_equal(nrow(result$cleaned_data), 1e5)
  expect_equal(nrow(pc$date_coerced), 2e4)
  expect_equal(unique(result$cleaned_data$casrn[df$casrn == "0103-02-06"]), "103-02-6")
})

test_that("100k-row xlsx reads in budget", {
  skip_on_cran()
  skip_if_not_installed("writexl")
  xlsx <- tempfile(fileext = ".xlsx")
  on.exit(unlink(xlsx))
  writexl::write_xlsx(ingestion_benchmark_data(1e5), xlsx)
  expect_faster_than(read_excel_robust(xlsx), 30)
})
