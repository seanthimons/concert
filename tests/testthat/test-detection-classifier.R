# Tests for numeric-only detection classification.

classify_one <- function(
  result = NA_real_,
  rl = NA_real_,
  uncertainty = NA_real_,
  qualifier = NA_character_,
  parser_qualifier = NA_character_,
  raw_result_text = NA_character_,
  unit = NA_character_,
  measurement_type = NA_character_,
  coverage = NA_character_,
  detect_operator = ">"
) {
  df <- tibble::tibble(
    result_value = result,
    reporting_limit_value = rl,
    uncertainty_value = uncertainty,
    qualifier = qualifier,
    result_qualifier = parser_qualifier,
    raw_result_text = raw_result_text,
    result_unit = unit,
    measurement_type = measurement_type,
    uncertainty_coverage = coverage
  )

  classify_detection_events(df, detect_operator = detect_operator)
}

test_that("qualifier codes never change numeric result_flag or class", {
  baseline <- classify_one(result = 5, rl = 1)

  qualifiers <- c(
    "J",
    "U",
    "B",
    "RL",
    "NDJ",
    "BDL",
    "B (<10x blank)",
    "not detected by lab narrative"
  )

  for (qualifier in qualifiers) {
    row <- classify_one(result = 5, rl = 1, qualifier = qualifier)

    expect_identical(row$result_flag, baseline$result_flag, info = qualifier)
    expect_identical(row$detection_event_class, baseline$detection_event_class, info = qualifier)
    expect_true(row$qualifier_followup_flag, info = qualifier)
    expect_true(row$detection_review_flag, info = qualifier)
    expect_equal(row$qualifier_followup_values, qualifier, info = qualifier)
  }
})

test_that("parser qualifiers from raw numeric parsing only raise follow-up context", {
  row <- classify_one(result = 15, rl = 10, parser_qualifier = "<", raw_result_text = "<15")

  expect_true(row$result_flag)
  expect_equal(row$detection_event_class, "robust_reportable_detect")
  expect_true(row$qualifier_followup_flag)
  expect_true(row$detection_review_flag)
  expect_equal(row$qualifier_followup_values, "<")
})

test_that("missing reporting limit with positive result is detect plus review", {
  row <- classify_one(result = 0.5, rl = NA_real_)

  expect_true(row$result_flag)
  expect_equal(row$detection_event_class, "review_required")
  expect_equal(row$detection_basis, "positive_result_missing_reporting_limit")
  expect_true(row$detection_review_flag)
  expect_true(row$numeric_followup_flag)
  expect_match(row$numeric_followup_reason, "positive_result_missing_reporting_limit")
})

test_that("strict default treats result equal to reporting limit as non-detect", {
  row <- classify_one(result = 1, rl = 1)

  expect_false(row$result_flag)
  expect_equal(row$detection_event_class, "non_reportable")
  expect_equal(row$detection_basis, "result_at_or_below_reporting_limit")
})

test_that("detect_operator greater-equal treats result equal to reporting limit as detect", {
  row <- classify_one(result = 1, rl = 1, detect_operator = ">=")

  expect_true(row$result_flag)
  expect_equal(row$detection_event_class, "robust_reportable_detect")
})

test_that("zero and missing numeric results are not detects", {
  zero <- classify_one(result = 0, rl = NA_real_)
  missing <- classify_one(result = NA_real_, rl = 1)

  expect_false(zero$result_flag)
  expect_equal(zero$detection_event_class, "non_reportable")
  expect_false(zero$detection_review_flag)

  expect_false(missing$result_flag)
  expect_equal(missing$detection_event_class, "indeterminate")
  expect_equal(missing$detection_basis, "missing_result")
  expect_true(missing$detection_review_flag)
})

test_that("negative uncertainty is invalid and cannot produce inverted intervals", {
  row <- classify_one(result = 20, rl = 10, uncertainty = -100)

  expect_true(row$result_flag)
  expect_true(row$invalid_uncertainty_flag)
  expect_true(is.na(row$lower_2sigma))
  expect_true(is.na(row$upper_2sigma))
  expect_equal(row$detection_event_class, "review_required")
  expect_equal(row$detection_basis, "invalid_negative_uncertainty")
  expect_true(row$detection_review_flag)
})

test_that("negative radiological and non-radiological results differ", {
  rad <- classify_one(result = -0.04, rl = 0.3, unit = "pCi/L")
  chem <- classify_one(result = -2, rl = 1, unit = "mg/L")

  expect_false(rad$result_flag)
  expect_equal(rad$detection_event_class, "negative_reported_non_detect")
  expect_equal(rad$detection_basis, "negative_background_subtracted_result")
  expect_equal(rad$detection_measurement_type, "radiological_activity")

  expect_false(chem$result_flag)
  expect_equal(chem$detection_event_class, "review_required")
  expect_equal(chem$detection_conflict, "negative_non_radiological_result")
  expect_equal(chem$detection_measurement_type, "chemical_concentration")
  expect_true(chem$detection_review_flag)
})

test_that("uncertainty still enriches event class without changing numeric result_flag", {
  robust <- classify_one(result = 0.84, rl = 0.30, uncertainty = 0.21)
  estimated <- classify_one(result = 0.35, rl = 0.30, uncertainty = 0.10)
  ambiguous <- classify_one(result = 0.20, rl = 0.30, uncertainty = 0.15)

  expect_true(robust$result_flag)
  expect_equal(robust$detection_event_class, "robust_reportable_detect")

  expect_true(estimated$result_flag)
  expect_equal(estimated$detection_event_class, "estimated_reportable_detect")

  expect_false(ambiguous$result_flag)
  expect_equal(ambiguous$detection_event_class, "threshold_ambiguous")
  expect_true(ambiguous$detection_review_flag)
})

test_that("one-sigma uncertainty is doubled and negative uncertainty returns NA", {
  expect_equal(normalize_uncertainty_to_two_sigma(0.15, "one_sigma"), 0.30)
  expect_true(is.na(normalize_uncertainty_to_two_sigma(-0.15, "two_sigma")))
})

test_that("source result_flag is rejected", {
  expect_error(
    classify_detection_events(tibble::tibble(result_value = 1, result_flag = TRUE)),
    "result_flag"
  )
})

test_that("classify_detection_events is exported by the package namespace", {
  expect_true("classify_detection_events" %in% getNamespaceExports("concert"))
})
