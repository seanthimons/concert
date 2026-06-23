test_that("harmonization detection bridge uses explicit semantic numeric tags", {
  df <- tibble::tibble(
    analyte = c("Benzene", "Radium-226"),
    result = c("5", "0.84"),
    reporting_limit = c("1", "0.30"),
    uncertainty = c(NA_character_, "0.21"),
    uncertainty_coverage = c(NA_character_, "two_sigma"),
    qualifier = c("U", NA_character_),
    unit = c("mg/L", "pCi/L")
  )
  unit_map <- tibble::tibble(
    from_unit = c("mg/L", "pCi/L"),
    to_unit = c("mg/L", "pCi/L"),
    multiplier = c(1, 1),
    category = c("mass_concentration", "radiological_activity")
  )
  tag_values <- list(
    result = "Result",
    reporting_limit = "ReportingLimit",
    uncertainty = "Uncertainty",
    uncertainty_coverage = "UncertaintyCoverage",
    qualifier = "Qualifier",
    unit = "Unit"
  )

  measurement_result <- harmonize_tagged_numeric_measurements(
    input_df = df,
    tag_values = tag_values,
    unit_map = unit_map
  )
  detection <- classify_harmonized_detection(
    input_df = df,
    tag_values = tag_values,
    measurement_result = measurement_result
  )

  expect_equal(nrow(detection$expanded_detection), 2)
  expect_equal(detection$expanded_detection$result_flag, c(TRUE, TRUE))
  expect_equal(
    detection$expanded_detection$detection_measurement_type,
    c("chemical_concentration", "radiological_activity")
  )
  expect_true(detection$expanded_detection$qualifier_followup_flag[1])
  expect_true(detection$expanded_detection$detection_review_flag[1])
  expect_equal(detection$expanded_detection$detection_event_class[2], "robust_reportable_detect")

  classified_rows <- append_detection_fields(df, detection$row_detection)
  expect_true(all(c(
    "result_flag",
    "detection_event_class",
    "detection_basis",
    "detection_review_flag",
    "qualifier_followup_flag",
    "numeric_followup_flag"
  ) %in% names(classified_rows)))
  expect_equal(classified_rows$result_flag, c(TRUE, TRUE))
})

test_that("generic Numeric reporting-limit-shaped columns are not inferred for detection", {
  df <- tibble::tibble(
    result = "5",
    reporting_limit = "10",
    unit = "mg/L"
  )
  unit_map <- tibble::tibble(
    from_unit = "mg/L",
    to_unit = "mg/L",
    multiplier = 1,
    category = "mass_concentration"
  )
  tag_values <- list(result = "Result", reporting_limit = "Numeric", unit = "Unit")

  measurement_result <- harmonize_tagged_numeric_measurements(
    input_df = df,
    tag_values = tag_values,
    unit_map = unit_map
  )
  detection <- classify_harmonized_detection(
    input_df = df,
    tag_values = tag_values,
    measurement_result = measurement_result
  )

  expect_true(detection$expanded_detection$result_flag)
  expect_equal(detection$expanded_detection$detection_event_class, "review_required")
  expect_equal(
    detection$expanded_detection$detection_basis,
    "positive_result_missing_reporting_limit"
  )
})

test_that("harmonization detection rejects source result_flag", {
  df <- tibble::tibble(result = "5", result_flag = TRUE)
  unit_map <- tibble::tibble()
  measurement_result <- harmonize_tagged_numeric_measurements(
    input_df = df,
    tag_values = list(result = "Result"),
    unit_map = unit_map,
    apply_units = FALSE
  )

  expect_error(
    classify_harmonized_detection(df, list(result = "Result"), measurement_result),
    "result_flag"
  )
})
