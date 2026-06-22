# test-date-parser.R
# Tests for parse_dates() -- DATE-01 through DATE-03
# Covers: format families, output schema, partial dates, ambiguity flagging,
#         2-digit year detection, unparseable strings

# ---- Helper: canonical test vector ----
make_test_dates <- function() {
  c(
    "2015-03-15", # ymd ISO
    "03/15/2015", # mdy US
    "15/03/2015", # dmy European
    "15MAR2015", # SAS dBY
    "2015", # year-only partial
    "Mar 2015", # month-year partial (bY)
    "2015-03", # month-year numeric (Ym)
    "03/04/15", # 2-digit year -> inferred_format
    "01/02/2015", # ambiguous (day=1<=12, month=2<=12)
    "N/A", # unparseable
    NA_character_ # NA input
  )
}

# ==============================================================================
# SECTION 1: Output schema (DATE-02)
# ==============================================================================

test_that("parse_dates returns 5-column tibble with correct names", {
  result <- parse_dates(c("2015-03-15"))

  expect_s3_class(result, "tbl_df")
  expect_named(result, c("orig_row_id", "raw_date", "parsed_date", "date_year", "date_flag"))
})

test_that("parse_dates returns correct column types", {
  result <- parse_dates(c("2015-03-15"))

  expect_type(result$orig_row_id, "integer")
  expect_type(result$raw_date, "character")
  expect_type(result$parsed_date, "character")
  expect_type(result$date_year, "integer")
  expect_type(result$date_flag, "character")
})

test_that("parse_dates orig_row_id matches input position", {
  result <- parse_dates(c("2015-01-01", "2016-06-15"))

  expect_equal(result$orig_row_id, c(1L, 2L))
})

test_that("parse_dates raw_date preserves original input string", {
  input <- c("2015-03-15", "N/A")
  result <- parse_dates(input)

  expect_equal(result$raw_date, input)
})

# ==============================================================================
# SECTION 2: Format families (DATE-01)
# ==============================================================================

test_that("parse_dates handles ISO ymd format", {
  result <- parse_dates(c("2015-03-15"))

  expect_equal(result$parsed_date, "2015-03-15")
  expect_equal(result$date_year, 2015L)
  expect_equal(result$date_flag, "")
})

test_that("parse_dates handles YYYYMMDD compact format", {
  result <- parse_dates(c("20150315"))

  expect_equal(result$parsed_date, "2015-03-15")
  expect_equal(result$date_year, 2015L)
  expect_equal(result$date_flag, "")
})

test_that("parse_dates handles SAS dBY format (15MAR2015)", {
  result <- parse_dates(c("15MAR2015"))

  expect_equal(result$parsed_date, "2015-03-15")
  expect_equal(result$date_year, 2015L)
  expect_equal(result$date_flag, "")
})

test_that("parse_dates handles MDY US format", {
  result <- parse_dates(c("03/15/2015"))

  expect_equal(result$parsed_date, "2015-03-15")
  expect_equal(result$date_year, 2015L)
  expect_equal(result$date_flag, "")
})

test_that("parse_dates handles DMY European format (day > 12)", {
  # day=15 > 12 so this is unambiguously DMY
  result <- parse_dates(c("15/03/2015"))

  expect_equal(result$parsed_date, "2015-03-15")
  expect_equal(result$date_year, 2015L)
  expect_equal(result$date_flag, "")
})

test_that("parse_dates handles named month-year format (bY)", {
  result <- parse_dates(c("Mar 2015"))

  expect_equal(result$parsed_date, "2015-03-01")
  expect_equal(result$date_year, 2015L)
  expect_equal(result$date_flag, "partial")
})

test_that("parse_dates handles numeric month-year format (Ym)", {
  result <- parse_dates(c("2015-03"))

  expect_equal(result$parsed_date, "2015-03-01")
  expect_equal(result$date_year, 2015L)
  expect_equal(result$date_flag, "partial")
})

# ==============================================================================
# SECTION 3: Ambiguity flagging (DATE-03)
# ==============================================================================

test_that("parse_dates flags ambiguous date (day<=12 and month<=12)", {
  # 01/02/2015: day=1, month=2 (or month=1, day=2) -- both <= 12
  result <- parse_dates(c("01/02/2015"))

  expect_equal(result$date_flag, "ambiguous")
})

test_that("parse_dates does NOT flag unambiguous date (day=13 > 12)", {
  # 13/02/2015: day=13 > 12, not ambiguous
  result <- parse_dates(c("13/02/2015"))

  expect_equal(result$date_flag, "")
})

test_that("parse_dates does NOT flag unambiguous MDY date (month=3, day=15)", {
  # 03/15/2015: day=15 > 12, not ambiguous
  result <- parse_dates(c("03/15/2015"))

  expect_equal(result$date_flag, "")
})

# ==============================================================================
# SECTION 4: Partial dates (D-03, D-04)
# ==============================================================================

test_that("parse_dates flags year-only as partial and imputes to Jan 1", {
  result <- parse_dates(c("2015"))

  expect_equal(result$parsed_date, "2015-01-01")
  expect_equal(result$date_year, 2015L)
  expect_equal(result$date_flag, "partial")
})

test_that("parse_dates flags named month-year as partial and imputes day to 1", {
  result <- parse_dates(c("Mar 2015"))

  expect_equal(result$parsed_date, "2015-03-01")
  expect_equal(result$date_year, 2015L)
  expect_equal(result$date_flag, "partial")
})

test_that("parse_dates flags numeric month-year as partial and imputes day to 1", {
  result <- parse_dates(c("2015-03"))

  expect_equal(result$parsed_date, "2015-03-01")
  expect_equal(result$date_year, 2015L)
  expect_equal(result$date_flag, "partial")
})

test_that("parse_dates populates date_year for partial dates (D-05)", {
  year_only <- parse_dates(c("2015"))
  month_year <- parse_dates(c("Mar 2015"))

  expect_false(is.na(year_only$date_year))
  expect_false(is.na(month_year$date_year))
  expect_equal(year_only$date_year, 2015L)
  expect_equal(month_year$date_year, 2015L)
})

test_that("parse_dates does NOT flag year-only as ambiguous (D-04 pitfall guard)", {
  # 2015 -> 2015-01-01, day=1<=12, month=1<=12 -- partial takes priority over ambiguous
  result <- parse_dates(c("2015"))

  expect_equal(result$date_flag, "partial")
  expect_false(result$date_flag == "ambiguous")
})

# ==============================================================================
# SECTION 5: 2-digit year (D-08, D-09)
# ==============================================================================

test_that("parse_dates flags 2-digit year as inferred_format", {
  result <- parse_dates(c("03/04/15"))

  expect_equal(result$date_flag, "inferred_format")
})

test_that("parse_dates produces a valid parsed_date for 2-digit year input", {
  result <- parse_dates(c("03/04/15"))

  expect_false(is.na(result$parsed_date))
  expect_match(result$parsed_date, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
})

test_that("parse_dates extracts date_year for 2-digit year input", {
  result <- parse_dates(c("03/04/15"))

  expect_false(is.na(result$date_year))
  expect_type(result$date_year, "integer")
})

test_that("parse_dates flags 2-digit year with time as inferred_format", {
  result <- parse_dates(c("03/04/15 14:30"))

  expect_equal(result$date_flag, "inferred_format")
})

test_that("parse_dates flags 2-digit year with T-separated time as inferred_format", {
  result <- parse_dates(c("03/04/15T14:30"))

  expect_equal(result$date_flag, "inferred_format")
})

test_that("parse_dates does NOT flag 4-digit year with time as inferred_format", {
  result <- parse_dates(c("03/15/2015 14:30"))

  expect_false(result$date_flag == "inferred_format")
})

# ==============================================================================
# SECTION 6: Unparseable / empty (D-10)
# ==============================================================================

test_that("parse_dates returns unparseable for N/A string", {
  result <- parse_dates(c("N/A"))

  expect_equal(result$date_flag, "unparseable")
  expect_true(is.na(result$parsed_date))
  expect_true(is.na(result$date_year))
})

test_that("parse_dates returns unparseable for 'ongoing' string", {
  result <- parse_dates(c("ongoing"))

  expect_equal(result$date_flag, "unparseable")
  expect_true(is.na(result$parsed_date))
  expect_true(is.na(result$date_year))
})

test_that("parse_dates returns unparseable for 'not reported' string", {
  result <- parse_dates(c("not reported"))

  expect_equal(result$date_flag, "unparseable")
  expect_true(is.na(result$parsed_date))
  expect_true(is.na(result$date_year))
})

test_that("parse_dates returns unparseable for 'TBD' string", {
  result <- parse_dates(c("TBD"))

  expect_equal(result$date_flag, "unparseable")
  expect_true(is.na(result$parsed_date))
  expect_true(is.na(result$date_year))
})

test_that("parse_dates returns unparseable for empty string", {
  result <- parse_dates(c(""))

  expect_equal(result$date_flag, "unparseable")
  expect_true(is.na(result$parsed_date))
  expect_true(is.na(result$date_year))
})

test_that("parse_dates returns unparseable for NA input", {
  result <- parse_dates(c(NA_character_))

  expect_equal(result$date_flag, "unparseable")
  expect_true(is.na(result$parsed_date))
  expect_true(is.na(result$date_year))
})

test_that("parse_dates preserves raw_date for unparseable input", {
  result <- parse_dates(c("N/A"))

  expect_equal(result$raw_date, "N/A")
})

# ==============================================================================
# SECTION 7: Empty input guard
# ==============================================================================

test_that("parse_dates returns 0-row tibble for character(0) input", {
  result <- parse_dates(character(0))

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
})

test_that("parse_dates 0-row tibble has correct column names", {
  result <- parse_dates(character(0))

  expect_named(result, c("orig_row_id", "raw_date", "parsed_date", "date_year", "date_flag"))
})

test_that("parse_dates 0-row tibble has correct column types", {
  result <- parse_dates(character(0))

  expect_type(result$orig_row_id, "integer")
  expect_type(result$raw_date, "character")
  expect_type(result$parsed_date, "character")
  expect_type(result$date_year, "integer")
  expect_type(result$date_flag, "character")
})

# ==============================================================================
# SECTION 8: Time-bearing dates (date extracted, time discarded)
# ==============================================================================

test_that("parse_dates extracts date from ISO datetime with space separator", {
  result <- parse_dates(c("2015-03-15 14:30:00"))

  expect_equal(result$parsed_date, "2015-03-15")
  expect_equal(result$date_year, 2015L)
})

test_that("parse_dates extracts date from ISO datetime with T separator", {
  result <- parse_dates(c("2015-03-15T14:30:00"))

  expect_equal(result$parsed_date, "2015-03-15")
  expect_equal(result$date_year, 2015L)
})

test_that("parse_dates extracts date from ISO datetime with T separator and Z suffix", {
  result <- parse_dates(c("2015-03-15T14:30:00Z"))

  expect_equal(result$parsed_date, "2015-03-15")
  expect_equal(result$date_year, 2015L)
})

test_that("parse_dates extracts date from MDY datetime with AM/PM", {
  result <- parse_dates(c("03/15/2015 2:30 PM"))

  expect_equal(result$parsed_date, "2015-03-15")
  expect_equal(result$date_year, 2015L)
})

test_that("parse_dates extracts date from ISO datetime without seconds", {
  result <- parse_dates(c("2015-03-15 14:30"))

  expect_equal(result$parsed_date, "2015-03-15")
  expect_equal(result$date_year, 2015L)
})

test_that("parse_dates extracts date from DMY datetime (day > 12)", {
  result <- parse_dates(c("15/03/2015 14:30:00"))

  expect_equal(result$parsed_date, "2015-03-15")
  expect_equal(result$date_year, 2015L)
})

test_that("parse_dates extracts date from named-month datetime", {
  result <- parse_dates(c("March 15, 2015 14:30"))

  expect_equal(result$parsed_date, "2015-03-15")
  expect_equal(result$date_year, 2015L)
})
