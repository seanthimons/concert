# test-numeric-parser.R
# TDD tests for parse_numeric_results() and internal helpers
# Covers: normalization, qualifier extraction, narrative detection, output shape, error handling

# ---- Normalization (PARS-01) ----

test_that("normalize: whitespace is stripped around value", {
  result <- parse_numeric_results(c("  5.0  "))
  expect_equal(result$numeric_value, 5.0)
})

test_that("normalize: commas between digits are removed", {
  result <- parse_numeric_results(c("1,234.5"))
  expect_equal(result$numeric_value, 1234.5)
})

test_that("normalize: x10^ notation converts to numeric (lowercase)", {
  result <- parse_numeric_results(c("2.5x10^3"))
  expect_equal(result$numeric_value, 2500)
})

test_that("normalize: X10^ notation converts to numeric (uppercase, case-insensitive)", {
  result <- parse_numeric_results(c("2.5X10^3"))
  expect_equal(result$numeric_value, 2500)
})

test_that("normalize: Fortran positive exponent (+02) is handled", {
  result <- parse_numeric_results(c("4.56+02"))
  expect_equal(result$numeric_value, 456)
})

test_that("normalize: Fortran negative exponent (-02) is handled", {
  result <- parse_numeric_results(c("4.56-02"))
  expect_equal(result$numeric_value, 0.0456)
})

test_that("normalize: standard sci notation lowercase e passes through", {
  result <- parse_numeric_results(c("1.23e4"))
  expect_equal(result$numeric_value, 12300)
})

test_that("normalize: standard sci notation uppercase E case-insensitive passes through", {
  result <- parse_numeric_results(c("1.23E-4"))
  expect_equal(result$numeric_value, 0.000123)
})

# ---- Qualifier extraction (PARS-02) ----

test_that("qualifier: '<5' extracts numeric_value=5 and qualifier='<'", {
  result <- parse_numeric_results(c("<5"))
  expect_equal(result$numeric_value, 5)
  expect_equal(result$qualifier, "<")
})

test_that("qualifier: '> 100' with space extracts numeric_value=100 and qualifier='>'", {
  result <- parse_numeric_results(c("> 100"))
  expect_equal(result$numeric_value, 100)
  expect_equal(result$qualifier, ">")
})

test_that("qualifier: '<=0.5' extracts numeric_value=0.5 and qualifier='<='", {
  result <- parse_numeric_results(c("<=0.5"))
  expect_equal(result$numeric_value, 0.5)
  expect_equal(result$qualifier, "<=")
})

test_that("qualifier: '>=10' extracts numeric_value=10 and qualifier='>='", {
  result <- parse_numeric_results(c(">=10"))
  expect_equal(result$numeric_value, 10)
  expect_equal(result$qualifier, ">=")
})

test_that("qualifier: '~50' extracts numeric_value=50 and qualifier='~'", {
  result <- parse_numeric_results(c("~50"))
  expect_equal(result$numeric_value, 50)
  expect_equal(result$qualifier, "~")
})

test_that("qualifier: unicode >=>=  '>=100' is normalized from unicode (D-06)", {
  result <- parse_numeric_results(c("\u2265100"))
  expect_equal(result$numeric_value, 100)
  expect_equal(result$qualifier, ">=")
})

test_that("qualifier: unicode <= '<=0.01' is normalized from unicode (D-06)", {
  result <- parse_numeric_results(c("\u22640.01"))
  expect_equal(result$numeric_value, 0.01)
  expect_equal(result$qualifier, "<=")
})

test_that("qualifier: plain value '5.0' has empty string qualifier (D-07)", {
  result <- parse_numeric_results(c("5.0"))
  expect_equal(result$qualifier, "")
})

# ---- Output tibble shape (PARS-04) ----

test_that("output: tibble has exactly 6 columns in correct order", {
  result <- parse_numeric_results(c("5.0"))
  expect_equal(
    names(result),
    c("orig_row_id", "orig_result", "numeric_value", "qualifier", "range_bin", "parse_flag")
  )
})

test_that("output: numeric_value is class numeric (double)", {
  result <- parse_numeric_results(c("42"))
  expect_type(result$numeric_value, "double")
})

test_that("output: qualifier is class character", {
  result <- parse_numeric_results(c("42"))
  expect_type(result$qualifier, "character")
})

test_that("output: range_bin is class character", {
  result <- parse_numeric_results(c("42"))
  expect_type(result$range_bin, "character")
})

test_that("output: parse_flag is class character", {
  result <- parse_numeric_results(c("42"))
  expect_type(result$parse_flag, "character")
})

test_that("output: single non-range value has range_bin = 'as_is'", {
  result <- parse_numeric_results(c("5.0"))
  expect_equal(result$range_bin, "as_is")
})

# ---- orig_result capture (PARS-05) ----

test_that("orig_result: exact raw input is preserved including whitespace and symbols", {
  input <- "  < 5.0  "
  result <- parse_numeric_results(input)
  expect_equal(result$orig_result, "  < 5.0  ")
})

# ---- Error handling: narrative values (D-01) ----

test_that("narrative: 'BDL' returns NA numeric_value and parse_flag='narrative'", {
  result <- parse_numeric_results(c("BDL"))
  expect_true(is.na(result$numeric_value))
  expect_equal(result$parse_flag, "narrative")
  expect_equal(result$qualifier, "")
})

test_that("narrative: 'ND' returns NA numeric_value and parse_flag='narrative'", {
  result <- parse_numeric_results(c("ND"))
  expect_true(is.na(result$numeric_value))
  expect_equal(result$parse_flag, "narrative")
})

test_that("narrative: 'non-detect' returns parse_flag='narrative'", {
  result <- parse_numeric_results(c("non-detect"))
  expect_equal(result$parse_flag, "narrative")
})

test_that("narrative: 'trace' returns parse_flag='narrative'", {
  result <- parse_numeric_results(c("trace"))
  expect_equal(result$parse_flag, "narrative")
})

test_that("narrative: empty string returns NA numeric_value and parse_flag='narrative'", {
  result <- parse_numeric_results(c(""))
  expect_true(is.na(result$numeric_value))
  expect_equal(result$parse_flag, "narrative")
})

test_that("narrative: NA input returns NA numeric_value and parse_flag='narrative'", {
  result <- parse_numeric_results(NA_character_)
  expect_true(is.na(result$numeric_value))
  expect_equal(result$parse_flag, "narrative")
})

# ---- Error handling: unparseable (D-12) ----

test_that("unparseable: 'abc123xyz' returns NA numeric_value and parse_flag='unparseable'", {
  result <- suppressWarnings(parse_numeric_results(c("abc123xyz")))
  expect_true(is.na(result$numeric_value))
  expect_equal(result$parse_flag, "unparseable")
})

# ---- Warning behavior (D-13) ----

test_that("warning: vector with 2 unparseable values emits warning containing '2'", {
  expect_warning(
    parse_numeric_results(c("abc", "xyz")),
    "2"
  )
})

# ---- Success flag ----

test_that("parse_flag: successfully parsed values have parse_flag = '' (empty string)", {
  result <- parse_numeric_results(c("42.5"))
  expect_equal(result$parse_flag, "")
})

# ---- Multi-value vector tests ----

test_that("multi-value: vector of 5 returns 5-row tibble with correct values", {
  input <- c("< 5.0", "2.5x10^3", "BDL", "4.56+02", "\u2265100")
  result <- parse_numeric_results(input)
  expect_equal(nrow(result), 5)
  expect_equal(result$numeric_value[1], 5.0)
  expect_equal(result$qualifier[1], "<")
  expect_equal(result$numeric_value[2], 2500)
  expect_true(is.na(result$numeric_value[3]))
  expect_equal(result$parse_flag[3], "narrative")
  expect_equal(result$numeric_value[4], 456)
  expect_equal(result$qualifier[5], ">=")
  expect_equal(result$numeric_value[5], 100)
})

test_that("orig_row_id: assigned as sequential integers from 1 to length", {
  result <- parse_numeric_results(c("1", "2", "3"))
  expect_equal(result$orig_row_id, 1:3)
})
