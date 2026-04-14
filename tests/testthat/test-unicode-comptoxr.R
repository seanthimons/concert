# Test file for ComptoxR::clean_unicode integration
# Tests chemistry-specific unicode handling

library(testthat)
library(here)

# Source cleaning pipeline (which will call ComptoxR::clean_unicode)
source(here::here("load_packages.R"))

test_that("ComptoxR::clean_unicode handles chemistry-specific unicode", {
  # Test: Greek alpha becomes 'alpha' (plain text, current ComptoxR format)
  expect_equal(ComptoxR::clean_unicode("\u03B1-tocopherol"), "alpha-tocopherol")

  # Test: Greek beta becomes 'beta'
  expect_equal(ComptoxR::clean_unicode("\u03B2-carotene"), "beta-carotene")

  # Test: NA passthrough
  expect_equal(ComptoxR::clean_unicode(NA_character_), NA_character_)
  expect_true(is.na(ComptoxR::clean_unicode(NA)))
})

test_that("run_cleaning_pipeline converts Greek letters to plain text", {
  # Source the cleaning pipeline
  source(here::here("R", "cleaning_pipeline.R"))

  # Create test dataframe with Greek alpha
  test_df <- tibble::tibble(
    chemical_name = c("acetone", "\u03B1-tocopherol", "ethanol")
  )

  result <- run_cleaning_pipeline(test_df)

  # Verify: Greek alpha becomes plain text 'alpha' (current ComptoxR format)
  expect_equal(result$cleaned_data$chemical_name[2], "alpha-tocopherol")
})
