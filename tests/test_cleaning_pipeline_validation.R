# test_cleaning_pipeline_validation.R
# End-to-end validation tests for cleaning pipeline bug fixes
#
# Purpose: Validate that all three bug fixes from Phase 16-01 work correctly
# through the full integrated pipeline:
# 1. Formula detection doesn't flag valid chemical names (Naphthalene, Sodium chloride)
# 2. Stop word matching uses whole-word boundaries (na doesn't flag Naphthalene)
# 3. IUPAC letter-comma-letter patterns aren't split (N,N-Dimethylformamide)

library(testthat)
library(here)
library(tibble)
library(dplyr)
library(stringr)

# Source the pipeline
source(here::here("R", "cleaning_pipeline.R"))

# Test Group 1: Formula detection false positives fixed
test_that("Validation: Formula detection false positives fixed", {
  # Create test dataset
  test_df <- tibble::tibble(
    casrn = c("91-20-3", "7647-14-5", NA, NA, NA),
    name = c("Naphthalene", "Sodium chloride", "C10H22", "NaCl", "CaCl2")
  )

  tag_map <- list(casrn = "CASRN", name = "Name")

  # Run pipeline
  result <- run_cleaning_pipeline(test_df, tag_map = tag_map, reference_lists = NULL)
  cleaned <- result$cleaned_data

  # Run formula detection (mimicking mod_clean_data.R order)
  name_cols <- names(tag_map)[tag_map == "Name"]
  formula_result <- detect_bare_formulas(cleaned, name_cols)
  final_data <- formula_result$cleaned_data

  # Test: Naphthalene should NOT be flagged as formula
  naphthalene_row <- final_data %>% dplyr::filter(name == "Naphthalene")
  expect_equal(nrow(naphthalene_row), 1)
  expect_true(is.na(naphthalene_row$cleaning_flag) || naphthalene_row$cleaning_flag == "")

  # Test: Sodium chloride should NOT be flagged as formula
  sodium_chloride_row <- final_data %>% dplyr::filter(name == "Sodium chloride")
  expect_equal(nrow(sodium_chloride_row), 1)
  expect_true(is.na(sodium_chloride_row$cleaning_flag) || sodium_chloride_row$cleaning_flag == "")

  # Test: C10H22 SHOULD be blocked as bare formula
  c10h22_row <- final_data %>% dplyr::filter(formula_blocked_name == "C10H22")
  expect_equal(nrow(c10h22_row), 1)
  expect_equal(c10h22_row$cleaning_flag, "BLOCK: bare formula")
  expect_true(is.na(c10h22_row$name))

  # Test: NaCl SHOULD be blocked as bare formula
  nacl_row <- final_data %>% dplyr::filter(formula_blocked_name == "NaCl")
  expect_equal(nrow(nacl_row), 1)
  expect_equal(nacl_row$cleaning_flag, "BLOCK: bare formula")
  expect_true(is.na(nacl_row$name))

  # Test: CaCl2 SHOULD be blocked as bare formula
  cacl2_row <- final_data %>% dplyr::filter(formula_blocked_name == "CaCl2")
  expect_equal(nrow(cacl2_row), 1)
  expect_equal(cacl2_row$cleaning_flag, "BLOCK: bare formula")
  expect_true(is.na(cacl2_row$name))
})

# Test Group 2: Stop word matching uses whole-word boundaries
test_that("Validation: Stop word matching uses whole-word boundaries", {
  # Create test dataset
  test_df <- tibble::tibble(
    casrn = c("91-20-3", "144-55-8", NA, NA),
    name = c("Naphthalene", "Sodium bicarbonate", "na", "test")
  )

  tag_map <- list(casrn = "CASRN", name = "Name")

  # Create stop words tibble matching load_stop_words() structure
  stop_words <- tibble::tibble(
    term = c("test", "sample", "unknown", "na", "n/a"),
    source = "app_default",
    active = TRUE
  )

  # Run pipeline
  result <- run_cleaning_pipeline(test_df, tag_map = tag_map, reference_lists = NULL)
  cleaned <- result$cleaned_data

  # Run formula detection first (to set up cleaning_flag column)
  name_cols <- names(tag_map)[tag_map == "Name"]
  formula_result <- detect_bare_formulas(cleaned, name_cols)
  after_formula <- formula_result$cleaned_data

  # Then run stop word flagging (mimicking mod_clean_data.R order)
  flag_result <- flag_reference_matches(
    after_formula,
    name_cols,
    stop_words,
    flag_type = "warning",
    flag_label = "stop word"
  )
  final_data <- flag_result$cleaned_data

  # Test: Naphthalene should NOT be flagged by "na" stop word
  naphthalene_row <- final_data %>% dplyr::filter(name == "Naphthalene")
  expect_equal(nrow(naphthalene_row), 1)
  expect_true(is.na(naphthalene_row$cleaning_flag) || naphthalene_row$cleaning_flag == "")

  # Test: Sodium bicarbonate should NOT be flagged by "na" stop word
  sodium_bicarb_row <- final_data %>% dplyr::filter(name == "Sodium bicarbonate")
  expect_equal(nrow(sodium_bicarb_row), 1)
  expect_true(is.na(sodium_bicarb_row$cleaning_flag) || sodium_bicarb_row$cleaning_flag == "")

  # Test: "na" exact match SHOULD be flagged
  na_row <- final_data %>% dplyr::filter(name == "na")
  expect_equal(nrow(na_row), 1)
  expect_true(stringr::str_detect(na_row$cleaning_flag, "WARN: stop word"))

  # Test: "test" exact match SHOULD be flagged
  test_row <- final_data %>% dplyr::filter(name == "test")
  expect_equal(nrow(test_row), 1)
  expect_true(stringr::str_detect(test_row$cleaning_flag, "WARN: stop word"))
})

# Test Group 3: IUPAC letter-comma-letter protected
test_that("Validation: IUPAC letter-comma-letter protected", {
  # Create test dataset
  test_df <- tibble::tibble(
    casrn = c("68-12-2", "1330-20-7"),
    name = c("N,N-Dimethylformamide", "xylene, dimethylbenzene, xylol")
  )

  tag_map <- list(casrn = "CASRN", name = "Name")

  # Run pipeline (synonym splitting happens inside run_cleaning_pipeline)
  result <- run_cleaning_pipeline(test_df, tag_map = tag_map, reference_lists = NULL)
  final_data <- result$cleaned_data

  # Test: N,N-Dimethylformamide should NOT split (1 row only)
  dmf_rows <- final_data %>% dplyr::filter(stringr::str_detect(name, "Dimethylformamide"))
  expect_equal(nrow(dmf_rows), 1)
  expect_equal(dmf_rows$name, "N,N-Dimethylformamide")
  expect_equal(dmf_rows$synonym_count, 1L)

  # Test: "xylene, dimethylbenzene, xylol" SHOULD split into 3 rows
  xylene_rows <- final_data %>% dplyr::filter(original_row_id == 2)
  expect_equal(nrow(xylene_rows), 3)
  expect_equal(xylene_rows$synonym_count[1], 3L)
  expect_true("xylene" %in% xylene_rows$name)
  expect_true("dimethylbenzene" %in% xylene_rows$name)
  expect_true("xylol" %in% xylene_rows$name)
})

# Test Group 4: Full pipeline integration - all three fixes working together
test_that("Validation: Full pipeline integration", {
  # Create mixed dataset with all three issue types
  test_df <- tibble::tibble(
    casrn = c(
      "91-20-3",      # Naphthalene (formula false positive)
      "68-12-2",      # N,N-Dimethylformamide (IUPAC comma)
      "7647-14-5",    # Sodium bicarbonate → Sodium chloride (stop word false positive)
      NA,             # C10H22 (true formula)
      NA              # test (true stop word)
    ),
    name = c(
      "Naphthalene",
      "N,N-Dimethylformamide",
      "Sodium chloride",
      "C10H22",
      "test"
    )
  )

  tag_map <- list(casrn = "CASRN", name = "Name")

  # Create stop words
  stop_words <- tibble::tibble(
    term = c("test", "sample", "na"),
    source = "app_default",
    active = TRUE
  )

  # Run full pipeline
  result <- run_cleaning_pipeline(test_df, tag_map = tag_map, reference_lists = NULL)
  cleaned <- result$cleaned_data

  # Run formula detection
  name_cols <- names(tag_map)[tag_map == "Name"]
  formula_result <- detect_bare_formulas(cleaned, name_cols)
  after_formula <- formula_result$cleaned_data

  # Run stop word flagging
  flag_result <- flag_reference_matches(
    after_formula,
    name_cols,
    stop_words,
    flag_type = "warning",
    flag_label = "stop word"
  )
  final_data <- flag_result$cleaned_data

  # Verify all fixes work together:

  # 1. Naphthalene passes through (no formula flag)
  naphthalene_row <- final_data %>% dplyr::filter(name == "Naphthalene")
  expect_equal(nrow(naphthalene_row), 1)
  expect_true(is.na(naphthalene_row$cleaning_flag) || naphthalene_row$cleaning_flag == "")

  # 2. N,N-Dimethylformamide doesn't split
  dmf_rows <- final_data %>% dplyr::filter(stringr::str_detect(name, "Dimethylformamide"))
  expect_equal(nrow(dmf_rows), 1)
  expect_equal(dmf_rows$name, "N,N-Dimethylformamide")

  # 3. Sodium chloride passes through (no stop word flag from "na" substring)
  sodium_row <- final_data %>% dplyr::filter(name == "Sodium chloride")
  expect_equal(nrow(sodium_row), 1)
  expect_true(is.na(sodium_row$cleaning_flag) || sodium_row$cleaning_flag == "")

  # 4. C10H22 is blocked as formula
  c10h22_row <- final_data %>% dplyr::filter(formula_blocked_name == "C10H22")
  expect_equal(nrow(c10h22_row), 1)
  expect_equal(c10h22_row$cleaning_flag, "BLOCK: bare formula")

  # 5. "test" is flagged as stop word
  test_row <- final_data %>% dplyr::filter(name == "test")
  expect_equal(nrow(test_row), 1)
  expect_true(stringr::str_detect(test_row$cleaning_flag, "WARN: stop word"))
})

# Test Group 5: Additional IUPAC protection cases
test_that("Validation: butane, 2,2-dimethyl stays intact (existing IUPAC protection)", {
  # Test that existing digit-comma-digit protection still works
  test_df <- tibble::tibble(
    casrn = "75-83-2",
    name = "butane, 2,2-dimethyl"
  )

  tag_map <- list(casrn = "CASRN", name = "Name")

  # Run pipeline
  result <- run_cleaning_pipeline(test_df, tag_map = tag_map, reference_lists = NULL)
  final_data <- result$cleaned_data

  # Should NOT split - protected by existing inverted IUPAC logic
  expect_equal(nrow(final_data), 1)
  expect_equal(final_data$name, "butane, 2,2-dimethyl")
  expect_equal(final_data$synonym_count, 1L)
})
