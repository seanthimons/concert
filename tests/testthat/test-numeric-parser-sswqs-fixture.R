# test-numeric-parser-sswqs-fixture.R
# Regression corpus: all 988 distinct non-numeric criterion_value strings from
# the raw EPA SSWQS criteria workbook, pinned to their expected parse outcome.
# Regenerate with data-raw/sswqs_parser_fixture.R and audit the diff.

test_that("SSWQS corpus fixture: parse outcomes match pinned expectations", {
  fixture <- read.csv(
    test_path("data", "sswqs_criterion_values.csv"),
    stringsAsFactors = FALSE,
    colClasses = c("character", "character", "numeric", "numeric"),
    fileEncoding = "UTF-8"
  )
  expect_equal(nrow(fixture), 988)

  result <- suppressWarnings(parse_numeric_results(fixture$raw_value))

  n_rows <- tabulate(result$orig_row_id, nbins = nrow(fixture))
  first <- result[!duplicated(result$orig_row_id), ]
  first <- first[order(first$orig_row_id), ]

  actual_flag <- ifelse(
    n_rows == 3L,
    "range",
    ifelse(first$parse_flag == "", "value", first$parse_flag)
  )
  actual_low <- as.numeric(tapply(result$numeric_value, result$orig_row_id, min))
  actual_high <- as.numeric(tapply(result$numeric_value, result$orig_row_id, max))

  expect_equal(actual_flag, fixture$expected_flag)
  expect_equal(actual_low, fixture$expected_low)
  expect_equal(actual_high, fixture$expected_high)
})

test_that("SSWQS corpus fixture: headline strings are pinned independently of the CSV", {
  # Spot checks so a bad fixture regeneration cannot silently weaken the test
  result <- parse_numeric_results(c("6 x 10-4", "7 million", "See note"))
  expect_equal(result$numeric_value[1], 6e-4)
  expect_equal(result$numeric_value[2], 7e6)
  expect_equal(result$parse_flag[3], "narrative")

  range_result <- parse_numeric_results(c("0.63-3,200"))
  expect_equal(nrow(range_result), 3)
  expect_equal(range_result$numeric_value[range_result$range_bin == "high"], 3200)

  expect_warning(dual <- parse_numeric_results(c("19/15")), "1")
  expect_equal(dual$parse_flag, "unparseable")
})
