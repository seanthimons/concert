# File upload edge cases (#7)

write_bytes_tmp <- function(..., ext = ".csv") {
  path <- tempfile(fileext = ext)
  parts <- lapply(list(...), function(p) if (is.character(p)) charToRaw(p) else p)
  writeBin(do.call(c, parts), path)
  path
}

ingest <- function(path) {
  raw <- suppressWarnings(safely_read_file(path, tools::file_ext(path)))
  extract_clean_data(raw, detect_data_start(raw))
}

test_that("CSV with a one-cell title above the header keeps every column", {
  path <- write_bytes_tmp("Report X\nGenerated 2026\n\nname,casrn,v1\nChem 1,67-64-1,0.5\nChem 2,71-43-2,0.7\n")
  on.exit(unlink(path))

  raw <- suppressWarnings(read_csv_robust(path))
  expect_equal(ncol(raw), 3)

  clean <- ingest(path)
  expect_equal(names(clean), c("name", "casrn", "v1"))
  expect_equal(clean$casrn, c("67-64-1", "71-43-2"))
})

test_that("empty and binary files fail with a readable message", {
  empty <- write_bytes_tmp(raw(0))
  binary <- write_bytes_tmp(as.raw(c(0x50, 0x4B, 0x03, 0x04, 0x00, 0x00, 0x08, 0x00)))
  on.exit(unlink(c(empty, binary)))

  expect_error(read_csv_robust(empty), "empty")
  expect_error(read_csv_robust(binary), "binary")
})

test_that("headers-only and single-column CSVs load", {
  headers <- write_bytes_tmp("name,casrn,value\n")
  single <- write_bytes_tmp("casrn\n67-64-1\n71-43-2\n")
  on.exit(unlink(c(headers, single)))

  clean <- ingest(headers)
  expect_equal(names(clean), c("name", "casrn", "value"))
  expect_equal(nrow(clean), 0)
  expect_equal(ingest(single)$casrn, c("67-64-1", "71-43-2"))
})

test_that("UTF-8 BOM, Latin-1 and Windows-1252 decode correctly", {
  bom <- write_bytes_tmp(as.raw(c(0xEF, 0xBB, 0xBF)), "name,casrn\nAcetone,67-64-1\n")
  latin1 <- write_bytes_tmp("name,casrn\nCaf", as.raw(0xE9), "ine,58-08-2\n")
  cp1252 <- write_bytes_tmp("name,casrn\n", as.raw(0x93), "quoted", as.raw(0x94), ",58-08-2\n")
  on.exit(unlink(c(bom, latin1, cp1252)))

  expect_equal(names(ingest(bom)), c("name", "casrn"))
  expect_equal(ingest(latin1)$name, "Caféine")
  expect_equal(ingest(cp1252)$name, "“quoted”")
})

test_that("ragged, truncated and multi-line rows keep every record", {
  ragged <- write_bytes_tmp("name,casrn,value\nAcetone,67-64-1\nBenzene,71-43-2,3,extra\n")
  truncated <- write_bytes_tmp("name,casrn,value\nAcetone,67-64-1,1\nBenzene,71-4")
  multiline <- write_bytes_tmp("name,casrn\n\"Acetone\nsolvent\",67-64-1\nBenzene,71-43-2\n")
  on.exit(unlink(c(ragged, truncated, multiline)))

  r <- ingest(ragged)
  expect_equal(dim(r), c(2L, 4L))
  expect_equal(r[[4]], c(NA, "extra"))
  # readr alone silently drops a short unterminated last line
  expect_equal(ingest(truncated)$casrn, c("67-64-1", "71-4"))
  expect_equal(ingest(multiline)$name, c("Acetone\nsolvent", "Benzene"))
})

test_that("semicolon and tab delimited files are detected", {
  semi <- write_bytes_tmp("name;casrn;value\nAcetone;67-64-1;1,5\nBenzene;71-43-2;2,0\n")
  tab <- write_bytes_tmp("name\tcasrn\tvalue\nAcetone\t67-64-1\t1\nBenzene\t71-43-2\t2\n")
  on.exit(unlink(c(semi, tab)))

  s <- ingest(semi)
  expect_equal(names(s), c("name", "casrn", "value"))
  expect_equal(s$value, c("1,5", "2,0"))
  expect_equal(names(ingest(tab)), c("name", "casrn", "value"))
})

test_that("multi-sheet workbooks read the first sheet; empty workbooks error", {
  skip_if_not_installed("writexl")
  multi <- tempfile(fileext = ".xlsx")
  empty <- tempfile(fileext = ".xlsx")
  on.exit(unlink(c(multi, empty)))
  writexl::write_xlsx(list(First = data.frame(name = "Acetone", casrn = "67-64-1"), Second = data.frame(other = 1)), multi)
  writexl::write_xlsx(list(Empty = data.frame()), empty)

  expect_equal(names(ingest(multi)), c("name", "casrn"))
  expect_error(read_excel_robust(empty), "empty")
})

test_that("repository sample files ingest with the expected header", {
  data_dir <- test_path("..", "..", "data")
  skip_if_not(dir.exists(data_dir), "sample data not shipped with the built package")

  frontmatter <- ingest(file.path(data_dir, "sample_frontmatter.csv"))
  expect_equal(names(frontmatter)[1:2], c("Chemical Name", "CAS Number"))
  expect_equal(nrow(frontmatter), 5)

  messy <- ingest(file.path(data_dir, "sample_messy.csv"))
  expect_equal(names(messy)[1:2], c("Chemical", "CAS"))
  expect_equal(nrow(messy), 4)

  xlsx <- ingest(file.path(data_dir, "sample_frontmatter.xlsx"))
  expect_equal(names(xlsx), c("Name", "Age", "Department"))
})
