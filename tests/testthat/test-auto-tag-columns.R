# Test name-based column tag suggestions
# Feature: Auto-Tag Columns on Upload (heuristic, name-only, precision-first)
#
# NOTE: fixtures use post-janitor::clean_names() names (snake_case), since the
# suggester runs after clean_names() in the upload pipeline.

test_that("suggest_column_tags maps representative headers to expected tags", {
  result <- suggest_column_tags(c(
    "cas_number",
    "chemical_name",
    "concentration_mg_l",
    "units",
    "species",
    "media",
    "study_date",
    "duration_unit"
  ))

  expect_type(result, "list")
  expect_equal(result$cas_number, "CASRN")
  expect_equal(result$chemical_name, "Name")
  expect_equal(result$concentration_mg_l, "Result")
  expect_equal(result$units, "Unit")
  expect_equal(result$species, "Species")
  expect_equal(result$media, "Media")
  expect_equal(result$study_date, "StudyDate")
  expect_equal(result$duration_unit, "DurationUnit")
})

test_that("suggest_column_tags disambiguates by most specific keyword", {
  # duration_unit must win DurationUnit over Duration (longer phrase)
  expect_equal(suggest_column_tags("duration_unit")[["duration_unit"]], "DurationUnit")
  # cas_number must be CASRN, never Name
  expect_equal(suggest_column_tags("cas_number")[["cas_number"]], "CASRN")
  # exposure_time is a Duration concept, never ExposureRoute
  res <- suggest_column_tags("exposure_time")[["exposure_time"]]
  expect_equal(res, "Duration")
})

test_that("suggest_column_tags is precision-first and ignores decoys", {
  result <- suggest_column_tags(c(
    "supplier_name",
    "common_name",
    "file_name",
    "received_date",
    "record_id"
  ))

  expect_equal(result$supplier_name, "")
  expect_equal(result$common_name, "")
  expect_equal(result$file_name, "")
  expect_equal(result$received_date, "")
  expect_equal(result$record_id, "")
})

test_that("suggest_column_tags emits at most one suggestion per singular tag", {
  # Two name-like and two cas-like columns -> only one Name and one CASRN kept.
  result <- suggest_column_tags(c("chemical_name", "compound", "cas_number", "casrn"))

  expect_equal(sum(unlist(result) == "Name"), 1L)
  expect_equal(sum(unlist(result) == "CASRN"), 1L)
})

test_that("suggest_column_tags returns '' for unknown headers", {
  result <- suggest_column_tags(c("notes", "v1", "x_2"))
  expect_equal(unname(unlist(result)), c("", "", ""))
})

test_that("suggest_column_tags handles empty input", {
  result <- suggest_column_tags(character(0))
  expect_type(result, "list")
  expect_length(result, 0)
})

test_that("suggest_column_tags output aligns 1:1 with input names", {
  cols <- c("cas_number", "notes", "units")
  result <- suggest_column_tags(cols)
  expect_named(result, cols)
  expect_length(result, length(cols))
})

test_that("suggest_column_tags only emits values in the classify_tags taxonomy", {
  taxonomy <- c(
    "Name",
    "CASRN",
    "Other",
    "Result",
    "Numeric",
    "Unit",
    "Qualifier",
    "Duration",
    "DurationUnit",
    "Species",
    "ExposureRoute",
    "StudyDate",
    "Media"
  )

  headers <- c(
    "cas_number",
    "chemical_name",
    "compound",
    "molecular_formula",
    "smiles",
    "result_value",
    "concentration",
    "numeric_measurement",
    "unit",
    "qualifier",
    "duration",
    "duration_unit",
    "species",
    "organism",
    "exposure_route",
    "route",
    "study_date",
    "sample_matrix",
    "media",
    "supplier_name",
    "notes"
  )

  emitted <- unique(unlist(suggest_column_tags(headers)))
  emitted <- emitted[nzchar(emitted)]
  expect_true(all(emitted %in% taxonomy))
})
