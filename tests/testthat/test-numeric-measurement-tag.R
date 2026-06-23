test_that("Numeric measurements parse and harmonize with the shared Unit tag", {
  df <- tibble::tibble(
    result = c("5", "10"),
    reporting_limit = c("1000", "2000"),
    unit = c("ug/L", "ug/L")
  )
  unit_map <- tibble::tibble(
    from_unit = "ug/L",
    to_unit = "mg/L",
    multiplier = 0.001,
    category = "mass_concentration"
  )

  result <- harmonize_tagged_numeric_measurements(
    input_df = df,
    tag_values = list(result = "Result", reporting_limit = "Numeric", unit = "Unit"),
    unit_map = unit_map,
    corrections = tibble::tibble(pattern = character(), replacement = character())
  )

  audit <- result$audit
  expect_equal(sort(unique(audit$measurement_role)), c("Numeric", "Result"))
  expect_equal(
    audit$harmonized_value[audit$measurement_column == "reporting_limit"],
    c(1, 2)
  )
  expect_equal(
    audit$harmonized_unit[audit$measurement_column == "reporting_limit"],
    c("mg/L", "mg/L")
  )
  expect_equal(result$toxval_harmonized$measurement_role, c("Result", "Result"))
  expect_equal(result$toxval_harmonized$harmonized_value, c(0.005, 0.01))
})

test_that("multiple Numeric columns produce distinct audit rows", {
  df <- tibble::tibble(
    reporting_limit = c("1000", "2000"),
    detection_limit = c("500", "750"),
    unit = c("ug/L", "ug/L")
  )
  unit_map <- tibble::tibble(
    from_unit = "ug/L",
    to_unit = "mg/L",
    multiplier = 0.001,
    category = "mass_concentration"
  )

  result <- harmonize_tagged_numeric_measurements(
    input_df = df,
    tag_values = list(reporting_limit = "Numeric", detection_limit = "Numeric", unit = "Unit"),
    unit_map = unit_map
  )

  expect_equal(nrow(result$audit), 4)
  expect_equal(
    sort(unique(result$audit$measurement_column)),
    c("detection_limit", "reporting_limit")
  )
  expect_equal(nrow(result$toxval_harmonized), nrow(df))
  expect_true(all(is.na(result$toxval_harmonized$harmonized_value)))
})

test_that("ReportingLimit and Uncertainty produce semantic audit roles", {
  df <- tibble::tibble(
    result = c("5", "10"),
    reporting_limit = c("1", "2"),
    uncertainty = c("0.5", "0.75"),
    coverage = c("two_sigma", "two_sigma"),
    unit = c("ug/L", "ug/L")
  )
  unit_map <- tibble::tibble(
    from_unit = "ug/L",
    to_unit = "mg/L",
    multiplier = 0.001,
    category = "mass_concentration"
  )

  result <- harmonize_tagged_numeric_measurements(
    input_df = df,
    tag_values = list(
      result = "Result",
      reporting_limit = "ReportingLimit",
      uncertainty = "Uncertainty",
      coverage = "UncertaintyCoverage",
      unit = "Unit"
    ),
    unit_map = unit_map
  )

  expect_equal(
    sort(unique(result$audit$measurement_role)),
    c("ReportingLimit", "Result", "Uncertainty")
  )
  expect_false("coverage" %in% result$audit$measurement_column)
  expect_equal(
    result$audit$harmonized_value[result$audit$measurement_role == "ReportingLimit"],
    c(0.001, 0.002)
  )
  expect_equal(
    result$audit$harmonized_value[result$audit$measurement_role == "Uncertainty"],
    c(0.0005, 0.00075)
  )
})

test_that("Numeric ranges expand only in audit, not primary ToxVal harmonized rows", {
  df <- tibble::tibble(
    result = "20",
    reporting_limit = "5-10",
    unit = "ug/L"
  )
  unit_map <- tibble::tibble(
    from_unit = "ug/L",
    to_unit = "mg/L",
    multiplier = 0.001,
    category = "mass_concentration"
  )

  result <- harmonize_tagged_numeric_measurements(
    input_df = df,
    tag_values = list(result = "Result", reporting_limit = "Numeric", unit = "Unit"),
    unit_map = unit_map
  )

  numeric_audit <- result$audit[result$audit$measurement_role == "Numeric", ]
  expect_equal(nrow(numeric_audit), 3)
  expect_equal(numeric_audit$range_bin, c("low", "mid", "high"))
  expect_equal(nrow(result$toxval_harmonized), 1)
  expect_equal(result$toxval_harmonized$measurement_column, "result")
})

test_that("Numeric measurements without Unit are parsed with NA harmonized units", {
  df <- tibble::tibble(reporting_limit = c("<5", "10"))

  result <- harmonize_tagged_numeric_measurements(
    input_df = df,
    tag_values = list(reporting_limit = "Numeric"),
    unit_map = tibble::tibble()
  )

  expect_equal(result$audit$numeric_value, c(5, 10))
  expect_true(all(is.na(result$audit$harmonized_unit)))
  expect_equal(result$audit$conversion_factor, c(1, 1))
})
