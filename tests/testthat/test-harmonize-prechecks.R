# test-harmonize-prechecks.R
# Unit tests for the 4 harmonization pre-check functions (Phase 42 RECO-01)
# Covers: should_run / est_changes contract for each function, empty-col guards,
# all-NA guards, and basic counting correctness.

# ---- Shared test data -------------------------------------------------------

make_test_df <- function() {
  tibble::tibble(
    chemical_name = c("Acetone", "Ethanol", "Benzene", "Toluene", "Xylene"),
    cas = c("67-64-1", "64-17-5", "71-43-2", "108-88-3", "1330-20-7"),
    result = c("1.5", "2.0", "0.5", "3.1", "4.2"),
    unit = c("mg/L", "ug/L", "ppb", "WEIRD_UNIT", "mg/L"),
    duration_val = c("96", "14", NA, "2", "6"),
    duration_unit = c("hr", "days", NA, "wk", "mo"),
    study_date = c("2020-01-15", "15JAN2020", NA, "01/15/2020", "2020"),
    media = c("freshwater", "soil", NA, "UNKNOWN_MEDIA", "air")
  )
}

make_unit_map <- function() {
  tibble::tibble(
    from_unit = c("mg/L", "ug/L", "ppb", "ppm"),
    to_unit = rep("mg/L", 4),
    multiplier = c(1, 0.001, 0.001, 1),
    category = rep("concentration", 4),
    confidence = rep("HIGH", 4),
    source = rep("test", 4)
  )
}

make_media_map <- function() {
  tibble::tibble(
    term = c("freshwater", "soil", "air"),
    canonical_term = c("freshwater", "soil", "air"),
    source = rep("amos", 3)
  )
}

# ==============================================================================
# precheck_harmonize_units tests
# ==============================================================================

test_that("precheck_harmonize_units: should_run TRUE, est_changes = total non-NA unit values", {
  df <- make_test_df()
  unit_map <- make_unit_map()
  result <- precheck_harmonize_units(df, unit_cols = "unit", unit_map = unit_map)

  expect_true(result$should_run)
  # All 5 rows have non-NA, non-empty unit values
  expect_equal(result$est_changes, 5L)
})

test_that("precheck_harmonize_units: empty unit_cols -> should_run FALSE, est_changes 0", {
  df <- make_test_df()
  unit_map <- make_unit_map()
  result <- precheck_harmonize_units(df, unit_cols = character(0), unit_map = unit_map)

  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)
})

test_that("precheck_harmonize_units: all-NA unit column -> should_run FALSE", {
  df <- tibble::tibble(
    chemical_name = c("Acetone", "Ethanol"),
    unit = c(NA_character_, NA_character_)
  )
  unit_map <- make_unit_map()
  result <- precheck_harmonize_units(df, unit_cols = "unit", unit_map = unit_map)

  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)
})

test_that("precheck_harmonize_units: multiple unit columns counted correctly", {
  df <- tibble::tibble(
    unit1 = c("mg/L", "ug/L"),
    unit2 = c("ppb", NA_character_)
  )
  unit_map <- make_unit_map()
  result <- precheck_harmonize_units(df, unit_cols = c("unit1", "unit2"), unit_map = unit_map)

  expect_true(result$should_run)
  # unit1: 2 non-NA; unit2: 1 non-NA -> total 3
  expect_equal(result$est_changes, 3L)
})

test_that("precheck_harmonize_units: returns named list with correct types", {
  df <- make_test_df()
  unit_map <- make_unit_map()
  result <- precheck_harmonize_units(df, unit_cols = "unit", unit_map = unit_map)

  expect_named(result, c("should_run", "est_changes"))
  expect_type(result$should_run, "logical")
  expect_type(result$est_changes, "integer")
})

# ==============================================================================
# precheck_harmonize_duration tests
# ==============================================================================

test_that("precheck_harmonize_duration: should_run TRUE when duration cols have values", {
  df <- make_test_df()
  unit_map <- make_unit_map()
  result <- precheck_harmonize_duration(
    df,
    dur_cols = "duration_val",
    dur_unit_cols = "duration_unit",
    unit_map = unit_map
  )

  expect_true(result$should_run)
  # duration_val: 4 non-NA; duration_unit: 4 non-NA -> est_changes = 8
  expect_equal(result$est_changes, 8L)
})

test_that("precheck_harmonize_duration: no dur cols -> should_run FALSE, est_changes 0", {
  df <- make_test_df()
  unit_map <- make_unit_map()
  result <- precheck_harmonize_duration(
    df,
    dur_cols = character(0),
    dur_unit_cols = character(0),
    unit_map = unit_map
  )

  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)
})

test_that("precheck_harmonize_duration: all-NA duration cols -> should_run FALSE", {
  df <- tibble::tibble(
    dur = c(NA_character_, NA_character_),
    dur_unit = c(NA_character_, NA_character_)
  )
  unit_map <- make_unit_map()
  result <- precheck_harmonize_duration(
    df,
    dur_cols = "dur",
    dur_unit_cols = "dur_unit",
    unit_map = unit_map
  )

  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)
})

test_that("precheck_harmonize_duration: returns named list with correct types", {
  df <- make_test_df()
  unit_map <- make_unit_map()
  result <- precheck_harmonize_duration(df, "duration_val", "duration_unit", unit_map)

  expect_named(result, c("should_run", "est_changes"))
  expect_type(result$should_run, "logical")
  expect_type(result$est_changes, "integer")
})

# ==============================================================================
# precheck_harmonize_dates tests
# ==============================================================================

test_that("precheck_harmonize_dates: should_run TRUE, est_changes = non-NA date values", {
  df <- make_test_df()
  result <- precheck_harmonize_dates(df, date_cols = "study_date")

  expect_true(result$should_run)
  # study_date: 4 non-NA values (row 3 is NA)
  expect_equal(result$est_changes, 4L)
})

test_that("precheck_harmonize_dates: empty date_cols -> should_run FALSE, est_changes 0", {
  df <- make_test_df()
  result <- precheck_harmonize_dates(df, date_cols = character(0))

  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)
})

test_that("precheck_harmonize_dates: all-NA date col -> should_run FALSE", {
  df <- tibble::tibble(study_date = c(NA_character_, NA_character_, NA_character_))
  result <- precheck_harmonize_dates(df, date_cols = "study_date")

  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)
})

test_that("precheck_harmonize_dates: multiple date columns summed", {
  df <- tibble::tibble(
    date1 = c("2020-01-15", NA),
    date2 = c("2021-03-10", "2022-07-04")
  )
  result <- precheck_harmonize_dates(df, date_cols = c("date1", "date2"))

  expect_true(result$should_run)
  # date1: 1 non-NA; date2: 2 non-NA -> total 3
  expect_equal(result$est_changes, 3L)
})

test_that("precheck_harmonize_dates: returns named list with correct types", {
  df <- make_test_df()
  result <- precheck_harmonize_dates(df, date_cols = "study_date")

  expect_named(result, c("should_run", "est_changes"))
  expect_type(result$should_run, "logical")
  expect_type(result$est_changes, "integer")
})

# ==============================================================================
# precheck_harmonize_media tests
# ==============================================================================

test_that("precheck_harmonize_media: should_run TRUE, est_changes = non-NA media values", {
  df <- make_test_df()
  media_map <- make_media_map()
  result <- precheck_harmonize_media(df, media_cols = "media", media_map = media_map)

  expect_true(result$should_run)
  # media col: 4 non-NA values (row 3 is NA)
  expect_equal(result$est_changes, 4L)
})

test_that("precheck_harmonize_media: empty media_cols -> should_run FALSE, est_changes 0", {
  df <- make_test_df()
  media_map <- make_media_map()
  result <- precheck_harmonize_media(df, media_cols = character(0), media_map = media_map)

  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)
})

test_that("precheck_harmonize_media: all-NA media col -> should_run FALSE", {
  df <- tibble::tibble(media = c(NA_character_, NA_character_, NA_character_))
  media_map <- make_media_map()
  result <- precheck_harmonize_media(df, media_cols = "media", media_map = media_map)

  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)
})

test_that("precheck_harmonize_media: NULL media_map still works", {
  df <- make_test_df()
  result <- precheck_harmonize_media(df, media_cols = "media", media_map = NULL)

  expect_true(result$should_run)
  expect_equal(result$est_changes, 4L)
})

test_that("precheck_harmonize_media: returns named list with correct types", {
  df <- make_test_df()
  media_map <- make_media_map()
  result <- precheck_harmonize_media(df, media_cols = "media", media_map = media_map)

  expect_named(result, c("should_run", "est_changes"))
  expect_type(result$should_run, "logical")
  expect_type(result$est_changes, "integer")
})

# ==============================================================================
# Contract compliance: all 4 functions return proper should_run/est_changes
# ==============================================================================

test_that("all 4 harmonization pre-checks return list with should_run and est_changes", {
  df <- make_test_df()
  unit_map <- make_unit_map()
  media_map <- make_media_map()

  results <- list(
    units = precheck_harmonize_units(df, "unit", unit_map),
    duration = precheck_harmonize_duration(df, "duration_val", "duration_unit", unit_map),
    dates = precheck_harmonize_dates(df, "study_date"),
    media = precheck_harmonize_media(df, "media", media_map)
  )

  for (nm in names(results)) {
    r <- results[[nm]]
    expect_named(r, c("should_run", "est_changes"), label = paste(nm, "names"))
    expect_type(r$should_run, "logical")
    expect_length(r$should_run, 1)
    expect_type(r$est_changes, "integer")
    expect_length(r$est_changes, 1)
  }
})
