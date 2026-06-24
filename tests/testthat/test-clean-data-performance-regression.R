test_that("masked cleaning matches headless cleaning on duplicated analytes", {
  df <- tibble::tibble(
    chemical_name = rep(c("  acetone  ", "technical benzene", "water"), each = 100),
    casrn = rep(c("67641", "71-43-2", "7732185"), each = 100)
  )
  tag_map <- c(chemical_name = "Name", casrn = "CASRN")
  reference_lists <- list(
    strip_terms = empty_reference_list_tbl(),
    isotope_lookup = list(
      lookup = tibble::tibble(
        symbol = character(),
        mass = character(),
        element_name = character(),
        shortcode = character(),
        canonical = character(),
        dtxsid = character()
      ),
      elem_alt_names = character()
    ),
    functional_categories = empty_reference_list_tbl(),
    stop_words = empty_reference_list_tbl(),
    block_patterns = empty_reference_list_tbl()
  )
  mask <- list(
    unicode = TRUE,
    whitespace = TRUE,
    cas = TRUE,
    names = TRUE,
    isotopes = TRUE,
    multi = TRUE,
    chiral = TRUE,
    truncated = TRUE,
    bare_formula = FALSE,
    reference_flags = FALSE
  )

  headless <- run_cleaning_pipeline(df, tag_map, reference_lists)
  masked <- run_cleaning_pipeline_masked(
    df,
    tag_map,
    reference_lists,
    mask = mask,
    respect_prechecks = FALSE
  )

  compare_cols <- intersect(names(headless$cleaned_data), names(masked$cleaned_data))
  expect_equal(masked$cleaned_data[compare_cols], headless$cleaned_data[compare_cols])
  expect_equal(masked$new_tags, headless$new_tags)
})

test_that("reference matching expands distinct-name matches back to duplicated rows", {
  names_in <- rep(c("acetone plasticizer", "benzene", "term42"), length.out = 10000)
  df <- tibble::tibble(chemical_name = names_in)
  refs <- tibble::tibble(
    term = c(paste0("term", seq_len(250)), "plasticizer"),
    pattern = c(paste0("term", seq_len(250)), "plasticizer"),
    match_mode = "literal_word",
    source = "test",
    active = TRUE,
    notes = NA_character_
  )

  result <- flag_reference_matches(
    df,
    "chemical_name",
    refs,
    "warning",
    "functional category"
  )

  expected_rows <- which(names_in %in% c("acetone plasticizer", "term42"))
  expect_equal(which(!is.na(result$cleaned_data$cleaning_flag)), expected_rows)
  expect_equal(sort(result$audit_trail$row_id), expected_rows)
  expect_true(all(grepl("WARN: functional category", result$cleaned_data$cleaning_flag[expected_rows])))
})

test_that("role_value_by_row handles high-cardinality role values", {
  n_rows <- 10000L
  audit <- tibble::tibble(
    measurement_role = c(rep("ReportingLimit", n_rows), rep("ReportingLimit", 3), "Uncertainty"),
    orig_row_id = c(seq_len(n_rows), 500L, n_rows + 1L, NA_integer_, 1L),
    harmonized_value = c(seq_len(n_rows) / 10, 999, 1, 2, 3)
  )

  reporting_limit <- role_value_by_row(audit, "ReportingLimit", n_rows)
  uncertainty <- role_value_by_row(audit, "Uncertainty", n_rows)

  expect_equal(reporting_limit$value[1:3], c(0.1, 0.2, 0.3))
  expect_equal(reporting_limit$value[500], 50)
  expect_true(reporting_limit$multiple[500])
  expect_false(reporting_limit$multiple[501])
  expect_equal(uncertainty$value[1], 3)
  expect_false(uncertainty$multiple[1])
})

test_that("collapse_detection_to_rows aggregates repeated source rows without rescanning", {
  n_rows <- 10000L
  expanded_detection <- tibble::tibble(
    orig_row_id = rep(seq_len(n_rows), each = 2),
    result_flag = rep(c(FALSE, TRUE), n_rows),
    detected_binary = rep(c(FALSE, TRUE), n_rows),
    reportable_detect_binary = rep(c(FALSE, TRUE), n_rows),
    detection_event_class = rep(c("non_reportable", "robust_reportable_detect"), n_rows),
    detection_basis = rep(c("non_positive_result", "positive_result_above_reporting_limit"), n_rows),
    detection_review_flag = rep(c(FALSE, TRUE), n_rows),
    detection_conflict = NA_character_,
    qualifier_followup_flag = FALSE,
    qualifier_followup_values = NA_character_,
    numeric_followup_flag = FALSE,
    numeric_followup_reason = NA_character_,
    invalid_uncertainty_flag = FALSE,
    missing_reporting_limit_flag = FALSE,
    detection_measurement_type = "chemical_concentration"
  )

  row_detection <- collapse_detection_to_rows(expanded_detection, n_rows)

  expect_equal(nrow(row_detection), n_rows)
  expect_true(all(row_detection$result_flag))
  expect_true(all(row_detection$detected_binary))
  expect_true(all(row_detection$reportable_detect_binary))
  expect_true(all(row_detection$detection_review_flag))
  expect_true(all(row_detection$numeric_followup_flag))
  expect_equal(unique(row_detection$detection_event_class), "review_required")
  expect_true(all(grepl("multiple_result_values", row_detection$numeric_followup_reason)))
})

test_that("numeric measurement columns use fast parsing path through harmonization", {
  n_rows <- 10000L
  df <- tibble::tibble(
    result = rep(c(1.2, NA_real_, 4.8, 0.5), length.out = n_rows),
    reporting_limit = rep(c(0.1, 0.2, 0.5, 1.0), length.out = n_rows),
    units = rep(c("ug/L", "mg/L", "ng/L", "pCi/L"), length.out = n_rows)
  )
  unit_map <- tibble::tibble(
    from_unit = c("ug/L", "mg/L", "ng/L", "pCi/L"),
    to_unit = c("mg/L", "mg/L", "mg/L", "pCi/L"),
    multiplier = c(0.001, 1, 0.000001, 1),
    category = "concentration"
  )

  result <- harmonize_tagged_numeric_measurements(
    input_df = df,
    tag_values = c(result = "Result", reporting_limit = "ReportingLimit", units = "Unit"),
    unit_map = unit_map
  )

  expect_equal(nrow(result$primary$parsed), n_rows)
  expect_equal(nrow(result$auxiliary$reporting_limit$parsed), n_rows)
  expect_equal(result$primary$parsed$numeric_value[1:4], df$result[1:4])
  expect_equal(result$primary$parsed$parse_flag[2], "narrative")
  expect_equal(sort(unique(result$audit$measurement_role)), c("ReportingLimit", "Result"))
})
