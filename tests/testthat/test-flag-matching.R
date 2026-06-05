# Test file for reference list flag matching
# Tests flag_reference_matches function with exact-then-substring matching

test_that("flag_reference_matches performs exact matching", {
  df <- tibble::tibble(
    chemical_name = c("plasticizer", "acetone", "solvent")
  )

  reference_list <- tibble::tibble(
    term = c("plasticizer", "solvent"),
    source = "app_default",
    active = TRUE
  )

  result <- flag_reference_matches(df, c("chemical_name"), reference_list, "warning", "functional category")

  # Check structure
  expect_type(result, "list")
  expect_named(result, c("cleaned_data", "audit_trail"))

  # plasticizer should be flagged as exact match
  expect_equal(result$cleaned_data$cleaning_flag[1], "WARN: functional category [exact]")

  # solvent should be flagged as exact match
  expect_equal(result$cleaned_data$cleaning_flag[3], "WARN: functional category [exact]")

  # acetone should NOT be flagged
  expect_true(is.na(result$cleaned_data$cleaning_flag[2]) || result$cleaned_data$cleaning_flag[2] == "")

  # Check audit trail
  expect_true(nrow(result$audit_trail) > 0)
  expect_true(any(grepl("exact", result$audit_trail$reason, ignore.case = TRUE)))
})

test_that("flag_reference_matches performs substring matching", {
  df <- tibble::tibble(
    chemical_name = c("dibutyl phthalate plasticizer", "acetone", "ethanol")
  )

  reference_list <- tibble::tibble(
    term = c("plasticizer"),
    source = "app_default",
    active = TRUE
  )

  result <- flag_reference_matches(df, c("chemical_name"), reference_list, "warning", "functional category")

  # "dibutyl phthalate plasticizer" should be flagged as substring match
  expect_equal(result$cleaned_data$cleaning_flag[1], "WARN: functional category [substring]")

  # acetone and ethanol should NOT be flagged
  expect_true(is.na(result$cleaned_data$cleaning_flag[2]) || result$cleaned_data$cleaning_flag[2] == "")
  expect_true(is.na(result$cleaned_data$cleaning_flag[3]) || result$cleaned_data$cleaning_flag[3] == "")

  # Check audit trail includes substring match info
  expect_true(any(grepl("substring", result$audit_trail$reason, ignore.case = TRUE)))
})

test_that("flag_reference_matches prioritizes exact match over substring", {
  df <- tibble::tibble(
    chemical_name = c("plasticizer", "dibutyl phthalate plasticizer")
  )

  reference_list <- tibble::tibble(
    term = c("plasticizer"),
    source = "app_default",
    active = TRUE
  )

  result <- flag_reference_matches(df, c("chemical_name"), reference_list, "warning", "functional category")

  # First should be exact match
  expect_equal(result$cleaned_data$cleaning_flag[1], "WARN: functional category [exact]")

  # Second should be substring match
  expect_equal(result$cleaned_data$cleaning_flag[2], "WARN: functional category [substring]")
})

test_that("flag_reference_matches is case-insensitive", {
  df <- tibble::tibble(
    chemical_name = c("PLASTICIZER", "Plasticizer", "plasticizer", "DIBUTYL PLASTICIZER")
  )

  reference_list <- tibble::tibble(
    term = c("plasticizer"),
    source = "app_default",
    active = TRUE
  )

  result <- flag_reference_matches(df, c("chemical_name"), reference_list, "warning", "functional category")

  # All should be flagged
  expect_equal(result$cleaned_data$cleaning_flag[1], "WARN: functional category [exact]")
  expect_equal(result$cleaned_data$cleaning_flag[2], "WARN: functional category [exact]")
  expect_equal(result$cleaned_data$cleaning_flag[3], "WARN: functional category [exact]")
  expect_equal(result$cleaned_data$cleaning_flag[4], "WARN: functional category [substring]")
})

test_that("flag_reference_matches skips inactive entries", {
  df <- tibble::tibble(
    chemical_name = c("plasticizer", "solvent", "acetone")
  )

  reference_list <- tibble::tibble(
    term = c("plasticizer", "solvent"),
    source = "app_default",
    active = c(TRUE, FALSE)  # solvent is inactive
  )

  result <- flag_reference_matches(df, c("chemical_name"), reference_list, "warning", "functional category")

  # plasticizer should be flagged (active=TRUE)
  expect_equal(result$cleaned_data$cleaning_flag[1], "WARN: functional category [exact]")

  # solvent should NOT be flagged (active=FALSE)
  expect_true(is.na(result$cleaned_data$cleaning_flag[2]) || result$cleaned_data$cleaning_flag[2] == "")

  # acetone should NOT be flagged (no match)
  expect_true(is.na(result$cleaned_data$cleaning_flag[3]) || result$cleaned_data$cleaning_flag[3] == "")
})

test_that("flag_reference_matches does not flag inactive broad legacy review terms", {
  df <- tibble::tibble(
    chemical_name = c("ingredient", "surfactant blend", "acetone")
  )

  reference_list <- tibble::tibble(
    term = c("ingredient", "surfactant", "blend"),
    source = "legacy_review",
    active = FALSE
  )

  result <- flag_reference_matches(df, c("chemical_name"), reference_list, "warning", "stop word")

  expect_true(all(is.na(result$cleaned_data$cleaning_flag) | result$cleaned_data$cleaning_flag == ""))
  expect_equal(nrow(result$audit_trail), 0)
})

test_that("flag_reference_matches supports blocking flag type", {
  df <- tibble::tibble(
    chemical_name = c("proprietary", "acetone")
  )

  reference_list <- tibble::tibble(
    term = c("proprietary"),
    source = "app_default",
    active = TRUE
  )

  result <- flag_reference_matches(df, c("chemical_name"), reference_list, "blocking", "proprietary term")

  # proprietary should be flagged as BLOCK
  expect_equal(result$cleaned_data$cleaning_flag[1], "BLOCK: proprietary term [exact]")

  # acetone should NOT be flagged
  expect_true(is.na(result$cleaned_data$cleaning_flag[2]) || result$cleaned_data$cleaning_flag[2] == "")
})

test_that("flag_reference_matches evaluates block patterns as regex patterns", {
  df <- tibble::tibble(
    chemical_name = c("proprietary blend", "confidential business information", "acetone")
  )

  reference_list <- tibble::tibble(
    term = c("propriet", "confid"),
    source = "legacy_seed",
    active = TRUE
  )

  result <- flag_reference_matches(df, c("chemical_name"), reference_list, "blocking", "block pattern")

  expect_equal(result$cleaned_data$cleaning_flag[1], "BLOCK: block pattern [substring]")
  expect_equal(result$cleaned_data$cleaning_flag[2], "BLOCK: block pattern [substring]")
  expect_true(is.na(result$cleaned_data$cleaning_flag[3]) || result$cleaned_data$cleaning_flag[3] == "")
})

test_that("flag_reference_matches records match source in audit trail", {
  df <- tibble::tibble(
    chemical_name = c("plasticizer", "solvent")
  )

  reference_list <- tibble::tibble(
    term = c("plasticizer", "solvent"),
    source = c("comptoxr", "user"),
    active = TRUE
  )

  result <- flag_reference_matches(df, c("chemical_name"), reference_list, "warning", "functional category")

  # Check audit trail includes source
  expect_true(any(grepl("comptoxr", result$audit_trail$reason, ignore.case = TRUE)))
  expect_true(any(grepl("user", result$audit_trail$reason, ignore.case = TRUE)))
})

test_that("flag_reference_matches handles NA name values without error", {
  df <- tibble::tibble(
    chemical_name = c("plasticizer", NA, "acetone")
  )

  reference_list <- tibble::tibble(
    term = c("plasticizer"),
    source = "app_default",
    active = TRUE
  )

  result <- flag_reference_matches(df, c("chemical_name"), reference_list, "warning", "functional category")

  # Should not crash
  expect_type(result, "list")

  # NA should remain unflagged
  expect_true(is.na(result$cleaned_data$cleaning_flag[2]) || result$cleaned_data$cleaning_flag[2] == "")

  # plasticizer should be flagged
  expect_equal(result$cleaned_data$cleaning_flag[1], "WARN: functional category [exact]")
})

test_that("flag_reference_matches does not overwrite existing cleaning_flag", {
  df <- tibble::tibble(
    chemical_name = c("H2O", "plasticizer"),
    cleaning_flag = c("BLOCK: bare formula", NA)
  )

  reference_list <- tibble::tibble(
    term = c("H2O", "plasticizer"),
    source = "app_default",
    active = TRUE
  )

  result <- flag_reference_matches(df, c("chemical_name"), reference_list, "warning", "functional category")

  # H2O should keep its existing flag (bare formula has higher priority)
  expect_equal(result$cleaned_data$cleaning_flag[1], "BLOCK: bare formula")

  # plasticizer should get flagged
  expect_equal(result$cleaned_data$cleaning_flag[2], "WARN: functional category [exact]")
})

test_that("flag_reference_matches works across multiple name columns", {
  df <- tibble::tibble(
    chemical_name = c("plasticizer", "acetone"),
    product_name = c("solvent", "ethanol")
  )

  reference_list <- tibble::tibble(
    term = c("plasticizer", "solvent"),
    source = "app_default",
    active = TRUE
  )

  result <- flag_reference_matches(df, c("chemical_name", "product_name"), reference_list, "warning", "functional category")

  # plasticizer in chemical_name should be flagged
  expect_equal(result$cleaned_data$cleaning_flag[1], "WARN: functional category [exact]")

  # solvent in product_name should be flagged
  expect_equal(result$cleaned_data$cleaning_flag[1], "WARN: functional category [exact]")
})

test_that("flag_reference_matches does NOT flag chemical names containing stop word substrings", {
  df <- tibble::tibble(
    chemical_name = c("Naphthalene", "Sodium bicarbonate", "acetone")
  )

  reference_list <- tibble::tibble(
    term = c("na", "test", "sample"),
    source = "stop_words",
    active = TRUE
  )

  result <- flag_reference_matches(df, c("chemical_name"), reference_list, "blocking", "stop word")

  # None should be flagged - "na" should not match inside "Naphthalene" or "Sodium"
  expect_true(is.na(result$cleaned_data$cleaning_flag[1]) || result$cleaned_data$cleaning_flag[1] == "")
  expect_true(is.na(result$cleaned_data$cleaning_flag[2]) || result$cleaned_data$cleaning_flag[2] == "")
  expect_true(is.na(result$cleaned_data$cleaning_flag[3]) || result$cleaned_data$cleaning_flag[3] == "")
})

test_that("flag_reference_matches still flags whole-word stop words in longer text", {
  df <- tibble::tibble(
    chemical_name = c("test sample unknown", "na", "N/A")
  )

  reference_list <- tibble::tibble(
    term = c("test", "na", "n/a", "unknown"),
    source = "stop_words",
    active = TRUE
  )

  result <- flag_reference_matches(df, c("chemical_name"), reference_list, "blocking", "stop word")

  # "test sample unknown" should be flagged (contains standalone "test" word)
  expect_equal(result$cleaned_data$cleaning_flag[1], "BLOCK: stop word [substring]")

  # "na" should be flagged as exact match
  expect_equal(result$cleaned_data$cleaning_flag[2], "BLOCK: stop word [exact]")

  # "N/A" should be flagged as exact match for "n/a"
  expect_equal(result$cleaned_data$cleaning_flag[3], "BLOCK: stop word [exact]")
})
