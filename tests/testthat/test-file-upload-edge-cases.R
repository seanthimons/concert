# File upload edge cases (#7)

write_lines_tmp <- function(lines, ext = ".csv") {
  path <- tempfile(fileext = ext)
  writeLines(lines, path)
  path
}

test_that("CSV with a one-cell title above the header keeps every column", {
  path <- write_lines_tmp(c("Report X", "Generated 2026", "", "name,casrn,v1", "Chem 1,67-64-1,0.5", "Chem 2,71-43-2,0.7"))
  on.exit(unlink(path))

  raw <- suppressWarnings(read_csv_robust(path))
  expect_equal(ncol(raw), 3)
  expect_equal(raw$V2[raw$V1 %in% "Chem 1"], "67-64-1")

  clean <- extract_clean_data(raw, detect_data_start(raw))
  expect_equal(names(clean), c("name", "casrn", "v1"))
  expect_equal(nrow(clean), 2)
})
