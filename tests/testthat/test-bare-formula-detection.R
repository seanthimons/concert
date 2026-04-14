# Test file for bare molecular formula detection
# Tests detect_bare_formulas function using ComptoxR validator regex

test_that("detect_bare_formulas identifies H2O as bare formula", {
  df <- tibble::tibble(
    chemical_name = c("H2O", "acetone", "ethanol")
  )

  result <- detect_bare_formulas(df, c("chemical_name"))

  # Check structure
  expect_type(result, "list")
  expect_named(result, c("cleaned_data", "audit_trail"))

  # H2O should be blocked
  expect_true(is.na(result$cleaned_data$chemical_name[1]))
  expect_equal(result$cleaned_data$cleaning_flag[1], "BLOCK: bare formula")
  expect_equal(result$cleaned_data$formula_blocked_chemical_name[1], "H2O")

  # acetone and ethanol should NOT be blocked
  expect_equal(result$cleaned_data$chemical_name[2], "acetone")
  expect_equal(result$cleaned_data$chemical_name[3], "ethanol")
  expect_true(is.na(result$cleaned_data$cleaning_flag[2]) || result$cleaned_data$cleaning_flag[2] != "BLOCK: bare formula")
  expect_true(is.na(result$cleaned_data$cleaning_flag[3]) || result$cleaned_data$cleaning_flag[3] != "BLOCK: bare formula")

  # Check audit trail
  expect_true(nrow(result$audit_trail) > 0)
  expect_true("detect_bare_formula" %in% result$audit_trail$step)
})

test_that("detect_bare_formulas identifies NaCl and CuSO4 as bare formulas", {
  df <- tibble::tibble(
    chemical_name = c("NaCl", "CuSO4", "acetone")
  )

  result <- detect_bare_formulas(df, c("chemical_name"))

  # NaCl and CuSO4 should be blocked
  expect_true(is.na(result$cleaned_data$chemical_name[1]))
  expect_true(is.na(result$cleaned_data$chemical_name[2]))
  expect_equal(result$cleaned_data$cleaning_flag[1], "BLOCK: bare formula")
  expect_equal(result$cleaned_data$cleaning_flag[2], "BLOCK: bare formula")

  # acetone should NOT be blocked
  expect_equal(result$cleaned_data$chemical_name[3], "acetone")
})

test_that("detect_bare_formulas does NOT detect acetone as formula", {
  df <- tibble::tibble(
    chemical_name = c("acetone", "ethanol", "methanol")
  )

  result <- detect_bare_formulas(df, c("chemical_name"))

  # None should be blocked (lowercase, not element pattern)
  expect_equal(result$cleaned_data$chemical_name[1], "acetone")
  expect_equal(result$cleaned_data$chemical_name[2], "ethanol")
  expect_equal(result$cleaned_data$chemical_name[3], "methanol")

  # No blocking flags
  expect_true(all(is.na(result$cleaned_data$cleaning_flag) | result$cleaned_data$cleaning_flag != "BLOCK: bare formula"))
})

test_that("detect_bare_formulas does NOT detect mixed text as formula", {
  df <- tibble::tibble(
    chemical_name = c("CuSO4 pentahydrate", "H2O solution", "ethanol")
  )

  result <- detect_bare_formulas(df, c("chemical_name"))

  # Mixed text should NOT be blocked (text breaks formula pattern)
  expect_equal(result$cleaned_data$chemical_name[1], "CuSO4 pentahydrate")
  expect_equal(result$cleaned_data$chemical_name[2], "H2O solution")
  expect_equal(result$cleaned_data$chemical_name[3], "ethanol")
})

test_that("detect_bare_formulas handles NA values without error", {
  df <- tibble::tibble(
    chemical_name = c("H2O", NA, "acetone")
  )

  result <- detect_bare_formulas(df, c("chemical_name"))

  # Should not crash
  expect_type(result, "list")

  # NA should remain NA
  expect_true(is.na(result$cleaned_data$chemical_name[2]))

  # H2O should be blocked
  expect_true(is.na(result$cleaned_data$chemical_name[1]))
  expect_equal(result$cleaned_data$cleaning_flag[1], "BLOCK: bare formula")
})

test_that("detect_bare_formulas handles empty dataframe without error", {
  df <- tibble::tibble(
    chemical_name = character()
  )

  result <- detect_bare_formulas(df, c("chemical_name"))

  # Should not crash
  expect_type(result, "list")
  expect_equal(nrow(result$cleaned_data), 0)
  expect_equal(nrow(result$audit_trail), 0)
})

test_that("detect_bare_formulas records audit trail with column name in reason", {
  df <- tibble::tibble(
    substance_name = c("H2O", "NaCl")
  )

  result <- detect_bare_formulas(df, c("substance_name"))

  # Check audit trail includes column name
  expect_true(nrow(result$audit_trail) > 0)
  expect_true(any(grepl("substance_name", result$audit_trail$reason)))
  expect_equal(result$audit_trail$step, rep("detect_bare_formula", nrow(result$audit_trail)))
})

test_that("detect_bare_formulas works across multiple name columns", {
  df <- tibble::tibble(
    chemical_name = c("H2O", "acetone"),
    product_name = c("ethanol", "NaCl")
  )

  result <- detect_bare_formulas(df, c("chemical_name", "product_name"))

  # H2O should be blocked in chemical_name
  expect_true(is.na(result$cleaned_data$chemical_name[1]))
  expect_equal(result$cleaned_data$formula_blocked_chemical_name[1], "H2O")

  # NaCl should be blocked in product_name
  expect_true(is.na(result$cleaned_data$product_name[2]))
  expect_equal(result$cleaned_data$formula_blocked_product_name[2], "NaCl")

  # Others should NOT be blocked
  expect_equal(result$cleaned_data$chemical_name[2], "acetone")
  expect_equal(result$cleaned_data$product_name[1], "ethanol")
})

test_that("detect_bare_formulas does NOT flag valid chemical names as formulas", {
  df <- tibble::tibble(
    chemical_name = c("Naphthalene", "Sodium chloride", "Ethanol", "Methanol")
  )

  result <- detect_bare_formulas(df, c("chemical_name"))

  # None of these should be blocked (they are real chemical names, not bare formulas)
  expect_equal(result$cleaned_data$chemical_name[1], "Naphthalene")
  expect_equal(result$cleaned_data$chemical_name[2], "Sodium chloride")
  expect_equal(result$cleaned_data$chemical_name[3], "Ethanol")
  expect_equal(result$cleaned_data$chemical_name[4], "Methanol")

  # No blocking flags
  expect_true(all(is.na(result$cleaned_data$cleaning_flag) | result$cleaned_data$cleaning_flag != "BLOCK: bare formula"))
})

test_that("detect_bare_formulas does NOT flag abbreviations as formulas", {
  df <- tibble::tibble(
    chemical_name = c("DEHP", "PFOA", "DDT", "PCB")
  )

  result <- detect_bare_formulas(df, c("chemical_name"))

  # Abbreviations should NOT be blocked (all uppercase, no lowercase element symbols)
  expect_equal(result$cleaned_data$chemical_name[1], "DEHP")
  expect_equal(result$cleaned_data$chemical_name[2], "PFOA")
  expect_equal(result$cleaned_data$chemical_name[3], "DDT")
  expect_equal(result$cleaned_data$chemical_name[4], "PCB")

  # No blocking flags
  expect_true(all(is.na(result$cleaned_data$cleaning_flag) | result$cleaned_data$cleaning_flag != "BLOCK: bare formula"))
})

test_that("detect_bare_formulas still correctly identifies true bare formulas after fix", {
  df <- tibble::tibble(
    chemical_name = c("C10H22", "NaCl", "CaCl2", "H2O")
  )

  result <- detect_bare_formulas(df, c("chemical_name"))

  # All of these SHOULD be blocked (true bare formulas)
  expect_true(is.na(result$cleaned_data$chemical_name[1]))
  expect_true(is.na(result$cleaned_data$chemical_name[2]))
  expect_true(is.na(result$cleaned_data$chemical_name[3]))
  expect_true(is.na(result$cleaned_data$chemical_name[4]))

  expect_equal(result$cleaned_data$cleaning_flag[1], "BLOCK: bare formula")
  expect_equal(result$cleaned_data$cleaning_flag[2], "BLOCK: bare formula")
  expect_equal(result$cleaned_data$cleaning_flag[3], "BLOCK: bare formula")
  expect_equal(result$cleaned_data$cleaning_flag[4], "BLOCK: bare formula")
})
