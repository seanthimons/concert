# Test file for clean_unicode integration
# Tests chemistry-specific unicode handling

test_that("clean_unicode handles chemistry-specific unicode", {
  # Test: Greek alpha becomes 'alpha' (plain text, current ComptoxR format)
  expect_equal(clean_unicode("\u03B1-tocopherol"), "alpha-tocopherol")

  # Test: Greek beta becomes 'beta'
  expect_equal(clean_unicode("\u03B2-carotene"), "beta-carotene")

  # Test: NA passthrough
  expect_equal(clean_unicode(NA_character_), NA_character_)
  expect_true(is.na(clean_unicode(NA)))
})

test_that("run_cleaning_pipeline converts Greek letters to plain text", {
  # Create test dataframe with Greek alpha
  test_df <- tibble::tibble(
    chemical_name = c("acetone", "\u03B1-tocopherol", "ethanol")
  )

  result <- run_cleaning_pipeline(test_df)

  # Verify: Greek alpha becomes plain text 'alpha' (current ComptoxR format)
  expect_equal(result$cleaned_data$chemical_name[2], "alpha-tocopherol")
})
