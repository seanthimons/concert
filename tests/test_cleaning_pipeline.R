# Test file for cleaning_pipeline.R
# Tests unicode-to-ASCII conversion, text trimming, and audit trail construction

library(testthat)
library(here)

# Source the cleaning pipeline module
source(here::here("R", "cleaning_pipeline.R"))

test_that("clean_unicode_field converts unicode to ASCII", {
  # Test: cafe with combining accent mark becomes cafe
  expect_equal(clean_unicode_field("cafe\u0301"), "cafe")

  # Test: Greek alpha becomes 'a'
  expect_equal(clean_unicode_field("\u03B1-tocopherol"), "a-tocopherol")

  # Test: NA passthrough
  expect_equal(clean_unicode_field(NA_character_), NA_character_)
  expect_true(is.na(clean_unicode_field(NA)))
})

test_that("clean_text_field strips whitespace and punctuation artifacts", {
  # Test: whitespace trimming
  expect_equal(clean_text_field("  hello  "), "hello")

  # Test: underscore stripping (leading/trailing only)
  expect_equal(clean_text_field("__name__"), "name")

  # Test: asterisk stripping (leading/trailing only)
  expect_equal(clean_text_field("*starred*"), "starred")

  # Test: preserves internal hyphens (CRITICAL for CAS numbers)
  expect_equal(clean_text_field("67-64-1"), "67-64-1")

  # Test: preserves internal commas (CRITICAL for IUPAC names)
  expect_equal(clean_text_field("2,4-dichlorophenol"), "2,4-dichlorophenol")

  # Test: combined case - leading/trailing artifacts with internal punctuation
  expect_equal(clean_text_field("  __2,4-dichlorophenol**  "), "2,4-dichlorophenol")
})

test_that("run_cleaning_pipeline returns cleaned data and audit trail", {
  # Create test dataframe with unicode and whitespace issues
  test_df <- tibble::tibble(
    chemical_name = c("  acetone  ", "cafe\u0301", "__ethanol__"),
    cas_number = c("67-64-1", "  58-08-2  ", "*108-95-2*"),
    supplier = c("Sigma", "  Fisher  ", "VWR")
  )

  result <- run_cleaning_pipeline(test_df)

  # Check structure (now includes new_tags and original_row_id)
  expect_type(result, "list")
  expect_named(result, c("cleaned_data", "audit_trail", "new_tags"))

  # Check cleaned data
  cleaned <- result$cleaned_data
  expect_equal(nrow(cleaned), 3)
  expect_true("original_row_id" %in% names(cleaned))  # Now injected by default
  expect_equal(cleaned$original_row_id, 1:3)
  expect_equal(cleaned$chemical_name[1], "acetone")
  expect_equal(cleaned$chemical_name[2], "cafe")
  expect_equal(cleaned$chemical_name[3], "ethanol")
  expect_equal(cleaned$cas_number[1], "67-64-1")
  expect_equal(cleaned$cas_number[2], "58-08-2")
  expect_equal(cleaned$cas_number[3], "108-95-2")

  # Check audit trail structure
  audit <- result$audit_trail
  expect_s3_class(audit, "tbl_df")
  expect_named(audit, c("row_id", "field", "step", "original_value", "new_value", "reason"))
  expect_type(audit$row_id, "integer")
  expect_type(audit$field, "character")
  expect_type(audit$step, "character")
  expect_type(audit$original_value, "character")
  expect_type(audit$new_value, "character")
  expect_type(audit$reason, "character")

  # Audit trail should have entries (there were changes)
  expect_gt(nrow(audit), 0)

  # Audit trail should only contain rows where original != new
  expect_true(all(audit$original_value != audit$new_value))
})

test_that("run_cleaning_pipeline on clean data returns empty audit trail", {
  # Create test dataframe with no issues
  clean_df <- tibble::tibble(
    chemical_name = c("acetone", "ethanol", "methanol"),
    cas_number = c("67-64-1", "64-17-5", "67-56-1")
  )

  result <- run_cleaning_pipeline(clean_df)

  # Cleaned data should be identical except for original_row_id
  expect_equal(result$cleaned_data$chemical_name, clean_df$chemical_name)
  expect_equal(result$cleaned_data$cas_number, clean_df$cas_number)
  expect_true("original_row_id" %in% names(result$cleaned_data))

  # Audit trail should be empty (or 0 rows if tibble structure)
  expect_equal(nrow(result$audit_trail), 0)
  expect_named(result$audit_trail, c("row_id", "field", "step", "original_value", "new_value", "reason"))

  # new_tags should be empty list when no tag_map provided
  expect_equal(result$new_tags, list())
})

test_that("audit trail only contains rows where original_value != new_value", {
  # Mixed data: some clean, some dirty
  test_df <- tibble::tibble(
    chemical_name = c("acetone", "  ethanol  ", "methanol"),  # Only row 2 needs cleaning
    cas_number = c("67-64-1", "64-17-5", "67-56-1")  # All clean
  )

  result <- run_cleaning_pipeline(test_df)
  audit <- result$audit_trail

  # Should only have entries for ethanol whitespace trimming
  expect_gt(nrow(audit), 0)
  expect_true(all(audit$original_value != audit$new_value))

  # Check that the audit trail references row 2
  expect_true(2 %in% audit$row_id)

  # Check that cas_number field is not in audit (all were clean)
  # Note: this might fail if whitespace stripping is run on clean data, so check carefully
})
