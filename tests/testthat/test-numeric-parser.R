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
    parse_numeric_results(c("abc1", "2xyz")),
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

# ---- Range splitting (PARS-03) ----

test_that("range: '5-10' produces 3 rows all with orig_row_id = 1", {
  result <- parse_numeric_results(c("5-10"))
  expect_equal(nrow(result), 3)
  expect_equal(result$orig_row_id, c(1L, 1L, 1L))
})

test_that("range: '5-10' low row has numeric_value=5, qualifier='>=', range_bin='low'", {
  result <- parse_numeric_results(c("5-10"))
  low <- result[result$range_bin == "low", ]
  expect_equal(low$numeric_value, 5)
  expect_equal(low$qualifier, ">=")
  expect_equal(low$range_bin, "low")
})

test_that("range: '5-10' mid row has numeric_value=7.5, qualifier='~', range_bin='mid'", {
  result <- parse_numeric_results(c("5-10"))
  mid <- result[result$range_bin == "mid", ]
  expect_equal(mid$numeric_value, 7.5)
  expect_equal(mid$qualifier, "~")
  expect_equal(mid$range_bin, "mid")
})

test_that("range: '5-10' high row has numeric_value=10, qualifier='<=', range_bin='high'", {
  result <- parse_numeric_results(c("5-10"))
  high <- result[result$range_bin == "high", ]
  expect_equal(high$numeric_value, 10)
  expect_equal(high$qualifier, "<=")
  expect_equal(high$range_bin, "high")
})

test_that("range: '0.5-1.0' decimal range splits correctly (low=0.5, mid=0.75, high=1.0)", {
  result <- parse_numeric_results(c("0.5-1.0"))
  expect_equal(nrow(result), 3)
  expect_equal(result$numeric_value[result$range_bin == "low"], 0.5)
  expect_equal(result$numeric_value[result$range_bin == "mid"], 0.75)
  expect_equal(result$numeric_value[result$range_bin == "high"], 1.0)
})

test_that("range: '100-200' mid = 150", {
  result <- parse_numeric_results(c("100-200"))
  expect_equal(result$numeric_value[result$range_bin == "mid"], 150)
})

test_that("range: parse_flag is '' (empty string) for all range rows", {
  result <- parse_numeric_results(c("5-10"))
  expect_true(all(result$parse_flag == ""))
})

test_that("range: orig_result preserved as '5-10' for all 3 range rows (not split)", {
  result <- parse_numeric_results(c("5-10"))
  expect_true(all(result$orig_result == "5-10"))
})

# ---- Numeric pre-guard: NOT ranges ----

test_that("not a range: '-5' is a negative number, returns 1 row with numeric_value=-5", {
  result <- parse_numeric_results(c("-5"))
  expect_equal(nrow(result), 1)
  expect_equal(result$numeric_value, -5)
  expect_equal(result$range_bin, "as_is")
})

test_that("not a range: negative decimal '-0.5' returns 1 row with numeric_value=-0.5", {
  result <- parse_numeric_results(c("-0.5"))
  expect_equal(nrow(result), 1)
  expect_equal(result$numeric_value, -0.5)
})

test_that("not a range: '1e-3' scientific notation returns 1 row with numeric_value=0.001", {
  result <- parse_numeric_results(c("1e-3"))
  expect_equal(nrow(result), 1)
  expect_equal(result$numeric_value, 0.001)
})

test_that("not a range: '1.5E-4' scientific notation returns 1 row with numeric_value=0.00015", {
  result <- parse_numeric_results(c("1.5E-4"))
  expect_equal(nrow(result), 1)
  expect_equal(result$numeric_value, 0.00015)
})

test_that("not a range: Fortran exponent '4.56+02' returns 1 row with numeric_value=456", {
  result <- parse_numeric_results(c("4.56+02"))
  expect_equal(nrow(result), 1)
  expect_equal(result$numeric_value, 456)
})

test_that("not a range: '<5' qualified value returns 1 row with range_bin='as_is' (D-04)", {
  result <- parse_numeric_results(c("<5"))
  expect_equal(nrow(result), 1)
  expect_equal(result$range_bin, "as_is")
})

test_that("not a range: '>100' qualified value returns 1 row with range_bin='as_is' (D-04)", {
  result <- parse_numeric_results(c(">100"))
  expect_equal(nrow(result), 1)
  expect_equal(result$range_bin, "as_is")
})

# ---- Range edge cases: negative bounds ----

test_that("range: '-10--5' negative range produces 3 rows, low=-10, mid=-7.5, high=-5", {
  result <- parse_numeric_results(c("-10--5"))
  expect_equal(nrow(result), 3)
  expect_equal(result$numeric_value[result$range_bin == "low"], -10)
  expect_equal(result$numeric_value[result$range_bin == "mid"], -7.5)
  expect_equal(result$numeric_value[result$range_bin == "high"], -5)
})

test_that("range: '-10-5' negative to positive range produces 3 rows, low=-10, mid=-2.5, high=5", {
  result <- parse_numeric_results(c("-10-5"))
  expect_equal(nrow(result), 3)
  expect_equal(result$numeric_value[result$range_bin == "low"], -10)
  expect_equal(result$numeric_value[result$range_bin == "mid"], -2.5)
  expect_equal(result$numeric_value[result$range_bin == "high"], 5)
})

# ---- Range integration: mixed vectors ----

test_that("range integration: c('5-10', '20', '<3') produces 5 rows total", {
  result <- suppressWarnings(parse_numeric_results(c("5-10", "20", "<3")))
  expect_equal(nrow(result), 5)
})

test_that("range integration: orig_row_id linkage — first range gets id=1, second value gets id=2", {
  result <- parse_numeric_results(c("5-10", "20"))
  # 3 rows with id=1 (range), 1 row with id=2 (single)
  expect_equal(sum(result$orig_row_id == 1), 3)
  expect_equal(sum(result$orig_row_id == 2), 1)
})

# ---- SSWQS salvage rules: x10 without caret / with spaces ----

test_that("salvage: '6 x 10-4' spaced x10 with implicit exponent converts to 6e-4", {
  result <- parse_numeric_results(c("6 x 10-4"))
  expect_equal(result$numeric_value, 6e-4)
  expect_equal(result$parse_flag, "")
})

test_that("salvage: '3 X 10-8' uppercase X converts to 3e-8", {
  result <- parse_numeric_results(c("3 X 10-8"))
  expect_equal(result$numeric_value, 3e-8)
})

test_that("salvage: '5.0x10-9' compact caretless form converts to 5e-9", {
  result <- parse_numeric_results(c("5.0x10-9"))
  expect_equal(result$numeric_value, 5e-9)
})

test_that("salvage: '5.0 x 10^-9' spaced caret form converts to 5e-9", {
  result <- parse_numeric_results(c("5.0 x 10^-9"))
  expect_equal(result$numeric_value, 5e-9)
})

test_that("salvage: '7x106' bare positive exponent converts to 7e6", {
  result <- parse_numeric_results(c("7x106"))
  expect_equal(result$numeric_value, 7e6)
})

test_that("salvage: '6 x 10-10' two-digit exponent converts to 6e-10", {
  result <- parse_numeric_results(c("6 x 10-10"))
  expect_equal(result$numeric_value, 6e-10)
})

# ---- SSWQS salvage rules: spaced E notation ----

test_that("salvage: '5.0 E - 9' fully spaced E converts to 5e-9", {
  result <- parse_numeric_results(c("5.0 E - 9"))
  expect_equal(result$numeric_value, 5e-9)
})

test_that("salvage: '5.0 E -9' converts to 5e-9", {
  result <- parse_numeric_results(c("5.0 E -9"))
  expect_equal(result$numeric_value, 5e-9)
})

test_that("salvage: '5.1 E-9' converts to 5.1e-9", {
  result <- parse_numeric_results(c("5.1 E-9"))
  expect_equal(result$numeric_value, 5.1e-9)
})

# ---- SSWQS salvage rules: word multiplier and typos ----

test_that("salvage: '7 million' converts to 7e6", {
  result <- parse_numeric_results(c("7 million"))
  expect_equal(result$numeric_value, 7e6)
  expect_equal(result$parse_flag, "")
})

test_that("salvage: '0..00013' doubled decimal typo converts to 0.00013", {
  result <- parse_numeric_results(c("0..00013"))
  expect_equal(result$numeric_value, 0.00013)
})

test_that("salvage: '0.00036*' trailing footnote asterisk is stripped", {
  result <- parse_numeric_results(c("0.00036*"))
  expect_equal(result$numeric_value, 0.00036)
})

# ---- Fortran guard tightening: X.Y-Z ranges are no longer eaten as exponents ----

test_that("range: '0.63-3,200' comma range splits (low=0.63, high=3200), not Fortran", {
  result <- parse_numeric_results(c("0.63-3,200"))
  expect_equal(nrow(result), 3)
  expect_equal(result$numeric_value[result$range_bin == "low"], 0.63)
  expect_equal(result$numeric_value[result$range_bin == "high"], 3200)
})

test_that("range: '6.5-9' pH-style range splits, not parsed as 6.5e-9", {
  result <- parse_numeric_results(c("6.5-9"))
  expect_equal(nrow(result), 3)
  expect_equal(result$numeric_value[result$range_bin == "low"], 6.5)
  expect_equal(result$numeric_value[result$range_bin == "high"], 9)
})

test_that("not a range: leading-zero exponent '4.56-02' still parses as Fortran 0.0456", {
  result <- parse_numeric_results(c("4.56-02"))
  expect_equal(nrow(result), 1)
  expect_equal(result$numeric_value, 0.0456)
})

# ---- Zero-digit unparseable reclassified as narrative ----

test_that("zero-digit: 'See note' returns parse_flag='narrative', NA, and no warning", {
  result <- expect_no_warning(parse_numeric_results(c("See note")))
  expect_true(is.na(result$numeric_value))
  expect_equal(result$parse_flag, "narrative")
})

test_that("zero-digit: 'Not Detectable' returns parse_flag='narrative' with no warning", {
  result <- expect_no_warning(parse_numeric_results(c("Not Detectable")))
  expect_equal(result$parse_flag, "narrative")
})

test_that("digit-bearing unparseable values still flag and warn", {
  expect_warning(result <- parse_numeric_results(c("19/15", "10% increase", "6.90E+0.1")), "3")
  expect_equal(result$parse_flag, rep("unparseable", 3))
  expect_true(all(is.na(result$numeric_value)))
})
