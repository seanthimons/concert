# Test file for perform_unicode_qc function
# Tests post-curation QC detection (read-only, no modification)

test_that("perform_unicode_qc on clean data returns zero issues", {
  # All ASCII data
  clean_df <- tibble::tibble(
    chemical_name = c("acetone", "ethanol", "benzene"),
    cas_number = c("67-64-1", "64-17-5", "71-43-2")
  )

  result <- perform_unicode_qc(clean_df)

  expect_type(result, "list")
  expect_named(result, c("rows_with_non_ascii", "row_indices", "unhandled_chars"))
  expect_equal(result$rows_with_non_ascii, 0)
  expect_equal(length(result$row_indices), 0)
  expect_equal(length(result$unhandled_chars), 0)
})

test_that("perform_unicode_qc detects Greek letters", {
  # Data with Greek alpha
  test_df <- tibble::tibble(
    chemical_name = c("acetone", "\u03B1-tocopherol", "ethanol"),
    cas_number = c("67-64-1", "58-08-2", "64-17-5")
  )

  result <- perform_unicode_qc(test_df)

  expect_equal(result$rows_with_non_ascii, 1)
  expect_equal(result$row_indices, 2)
  expect_equal(length(result$unhandled_chars), 1)

  # Check specific codepoint
  expect_true("U+03B1" %in% names(result$unhandled_chars))
  expect_equal(result$unhandled_chars[["U+03B1"]]$char, "\u03B1")
  expect_equal(result$unhandled_chars[["U+03B1"]]$codepoint, "U+03B1")
  expect_equal(result$unhandled_chars[["U+03B1"]]$count, 1)
})

test_that("perform_unicode_qc does NOT modify input dataframe", {
  # Data with Greek letters
  test_df <- tibble::tibble(
    chemical_name = c("acetone", "\u03B1-tocopherol", "\u03B2-carotene"),
    cas_number = c("67-64-1", "58-08-2", "7235-40-7")
  )

  # Make a copy to compare
  original_df <- test_df

  result <- perform_unicode_qc(test_df)

  # Input should be unchanged
  expect_equal(test_df, original_df)
  expect_equal(test_df$chemical_name[2], "\u03B1-tocopherol")
  expect_equal(test_df$chemical_name[3], "\u03B2-carotene")
})

test_that("perform_unicode_qc handles NA values without crashing", {
  # Data with NAs
  test_df <- tibble::tibble(
    chemical_name = c("acetone", NA, "\u03B1-tocopherol"),
    cas_number = c("67-64-1", "58-08-2", NA)
  )

  result <- perform_unicode_qc(test_df)

  expect_type(result, "list")
  expect_equal(result$rows_with_non_ascii, 1)  # Only row 3 has non-ASCII
  expect_equal(result$row_indices, 3)
})

test_that("perform_unicode_qc handles dataframes with no character columns", {
  # Only numeric columns
  numeric_df <- tibble::tibble(
    id = c(1, 2, 3),
    value = c(100.5, 200.3, 300.7)
  )

  result <- perform_unicode_qc(numeric_df)

  expect_equal(result$rows_with_non_ascii, 0)
  expect_equal(length(result$row_indices), 0)
  expect_equal(length(result$unhandled_chars), 0)
})

test_that("perform_unicode_qc handles empty dataframe", {
  empty_df <- tibble::tibble()

  result <- perform_unicode_qc(empty_df)

  expect_equal(result$rows_with_non_ascii, 0)
  expect_equal(length(result$row_indices), 0)
  expect_equal(length(result$unhandled_chars), 0)
})

test_that("perform_unicode_qc reports correct codepoints and counts", {
  # Multiple occurrences of same character
  test_df <- tibble::tibble(
    name = c("\u03B1-tocopherol", "\u03B1-lipoic acid", "acetone"),
    formula = c("C29H50O2", "C8H14O2S2", "C3H6O"),
    description = c("\u03B1 form", "\u03B1 isomer", "\u03B2-ketone")
  )

  result <- perform_unicode_qc(test_df)

  expect_equal(result$rows_with_non_ascii, 3)  # Rows 1, 2, 3
  expect_equal(sort(result$row_indices), c(1, 2, 3))

  # Alpha appears 4 times, beta once
  expect_true("U+03B1" %in% names(result$unhandled_chars))
  expect_true("U+03B2" %in% names(result$unhandled_chars))
  expect_equal(result$unhandled_chars[["U+03B1"]]$count, 4)
  expect_equal(result$unhandled_chars[["U+03B2"]]$count, 1)
})

test_that("perform_unicode_qc reports mixed ASCII and non-ASCII correctly", {
  # Mix of clean and dirty rows
  test_df <- tibble::tibble(
    chemical_name = c("acetone", "\u03B1-tocopherol", "ethanol", "\u03B2-carotene", "benzene"),
    cas_number = c("67-64-1", "58-08-2", "64-17-5", "7235-40-7", "71-43-2")
  )

  result <- perform_unicode_qc(test_df)

  expect_equal(result$rows_with_non_ascii, 2)  # Rows 2 and 4
  expect_equal(sort(result$row_indices), c(2, 4))
  expect_equal(length(result$unhandled_chars), 2)  # Alpha and beta
})
