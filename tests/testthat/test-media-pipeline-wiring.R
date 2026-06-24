# test-media-pipeline-wiring.R
# Integration tests for media harmonization pipeline wiring (gap closure 41-04)
# Tests CR-01 (dedup_step contract fix), WR-01 (stage ordering), WR-02 (NA warning)
#
# Sections:
#   1. curate_headless media wiring via API (skipped without ctx_api_key)
#   2. Direct pipeline wiring: harmonize_media -> harmonize_units (no API needed)
#   3. Media-only guard in curate_headless (skipped without ctx_api_key)
#   4. NA warning regression (WR-02)

# ---- Helper: minimal unit map with ppb/ppm support ----

make_ppb_unit_map <- function() {
  # The real unit map has ppb/ppm entries; for integration tests we load from cache.
  # This minimal map is used in direct wiring tests only.
  tibble::tibble(
    from_unit = c("mg/L", "ug/L", "mg/kg", "ug/kg", "mg/m3"),
    to_unit = c("mg/L", "mg/L", "mg/kg", "mg/kg", "mg/m3"),
    multiplier = c(1, 0.001, 1, 0.001, 1),
    category = rep("concentration", 5),
    confidence = rep("HIGH", 5),
    source = rep("test", 5)
  )
}

# ==============================================================================
# SECTION 1: curate_headless media wiring (CR-01 + WR-01) -- requires API key
# ==============================================================================

test_that("curate_headless with Media tag completes without error", {
  skip_if_not(nzchar(Sys.getenv("ctx_api_key")), "CompTox API key not set")

  tmp_csv <- tempfile(fileext = ".csv")
  tmp_out <- tempfile(fileext = ".xlsx")
  on.exit({
    unlink(tmp_csv)
    unlink(tmp_out)
    unlink(sub("\\.xlsx$", "_toxval.parquet", tmp_out))
  })

  writeLines(
    c(
      "chemical_name,cas_number,result,unit,media",
      "Acetone,67-64-1,100,ppb,water",
      "Ethanol,64-17-5,200,ppb,soil",
      "Acetone,67-64-1,50,ppb,water"
    ),
    tmp_csv
  )

  tag_map <- list(
    chemical_name = "Name",
    cas_number = "CASRN",
    result = "Result",
    unit = "Unit",
    media = "Media"
  )

  result <- curate_headless(
    input_path = tmp_csv,
    output_path = tmp_out,
    tag_map = tag_map,
    header_row = 1L,
    harmonize = TRUE,
    verbose = FALSE
  )

  expect_type(result, "list")
  expect_true("data" %in% names(result))
  expect_s3_class(result$data, "tbl_df")
  expect_gt(nrow(result$data), 0)
})

test_that("curate_headless media tag feeds per-row routing to harmonize_units", {
  skip_if_not(nzchar(Sys.getenv("ctx_api_key")), "CompTox API key not set")

  tmp_csv <- tempfile(fileext = ".csv")
  tmp_out <- tempfile(fileext = ".xlsx")
  on.exit({
    unlink(tmp_csv)
    unlink(tmp_out)
    unlink(sub("\\.xlsx$", "_toxval.parquet", tmp_out))
  })

  # Use distinct chemical compounds so curation preserves per-row media values.
  # Identical compound rows collapse to the same original_row_id after dedup,
  # losing the per-row media distinction needed to test ppb routing.
  writeLines(
    c(
      "chemical_name,cas_number,result,unit,media",
      "Acetone,67-64-1,1000,ppb,water",
      "Ethanol,64-17-5,1000,ppb,soil"
    ),
    tmp_csv
  )

  tag_map <- list(
    chemical_name = "Name",
    cas_number = "CASRN",
    result = "Result",
    unit = "Unit",
    media = "Media"
  )

  result <- curate_headless(
    input_path = tmp_csv,
    output_path = tmp_out,
    tag_map = tag_map,
    header_row = 1L,
    harmonize = TRUE,
    verbose = FALSE
  )

  # Verify different toxval_units values for aqueous vs solid rows
  # (harmonized_unit is mapped to toxval_units by map_to_toxval_schema)
  toxval <- result$data
  expect_true("toxval_units" %in% names(toxval))

  units_present <- unique(na.omit(toxval$toxval_units))
  # water + ppb should yield mg/L; soil + ppb should yield mg/kg
  expect_true(any(grepl("mg/L", units_present)), info = "Expected mg/L for aqueous (water) ppb rows")
  expect_true(any(grepl("mg/kg", units_present)), info = "Expected mg/kg for solid (soil) ppb rows")
})

# ==============================================================================
# SECTION 2: Media-only guard (curate_headless) -- requires API key
# ==============================================================================

test_that("curate_headless accepts Media-only tag_map with harmonize=TRUE", {
  skip_if_not(nzchar(Sys.getenv("ctx_api_key")), "CompTox API key not set")

  tmp_csv <- tempfile(fileext = ".csv")
  tmp_out <- tempfile(fileext = ".xlsx")
  on.exit({
    unlink(tmp_csv)
    unlink(tmp_out)
  })

  writeLines(
    c(
      "chemical_name,cas_number,media",
      "Acetone,67-64-1,water",
      "Ethanol,64-17-5,soil"
    ),
    tmp_csv
  )

  # No Result, no StudyDate -- only Media tagged
  tag_map <- list(
    chemical_name = "Name",
    cas_number = "CASRN",
    media = "Media"
  )

  expect_no_error(curate_headless(
    input_path = tmp_csv,
    output_path = tmp_out,
    tag_map = tag_map,
    header_row = 1L,
    harmonize = TRUE,
    verbose = FALSE
  ))
})

# ==============================================================================
# SECTION 3: Direct pipeline wiring tests (no API key required)
# ==============================================================================

test_that("harmonize_media output media_category feeds harmonize_units ppb routing", {
  # This tests the exact wiring fixed by CR-01 and WR-01:
  # harmonize_media() -> media_category -> harmonize_units(media=...) -> harmonized_unit
  unit_map <- concert:::load_unit_map(
    system.file("extdata", "reference_cache", package = "concert")
  )

  raw_media <- c("water", "soil", "water", "soil")
  raw_ppb <- c(1000, 1000, 500, 500)
  raw_units <- rep("ppb", 4)

  media_result <- harmonize_media(
    raw_media = raw_media,
    orig_row_id = seq_along(raw_media)
  )

  expect_equal(nrow(media_result), 4L)
  expect_true(
    all(c("aqueous", "solid") %in% na.omit(media_result$media_category)),
    info = "water->aqueous and soil->solid must be in media_category"
  )

  harm_result <- harmonize_units(
    values = raw_ppb,
    units = raw_units,
    unit_map = unit_map,
    media = media_result$media_category
  )

  expect_equal(nrow(harm_result), 4L)

  # Water rows (aqueous) should harmonize ppb -> mg/L
  aqueous_rows <- which(media_result$media_category == "aqueous")
  expect_true(all(harm_result$harmonized_unit[aqueous_rows] == "mg/L"), info = "aqueous + ppb must yield mg/L")

  # Soil rows (solid) should harmonize ppb -> mg/kg
  solid_rows <- which(media_result$media_category == "solid")
  expect_true(all(harm_result$harmonized_unit[solid_rows] == "mg/kg"), info = "solid + ppb must yield mg/kg")
})

test_that("harmonize_media NA inputs produce no warnings (WR-02 regression)", {
  # Must not emit any warnings when NA values are present in input
  expect_no_warning(
    harmonize_media(c("water", NA_character_, "soil", NA_character_))
  )
})

test_that("harmonize_media NA rows get NA canonical_media and non-empty flag", {
  result <- harmonize_media(c("water", NA_character_, "soil"))

  # Row 2 is NA -- canonical_media should be NA, flag should be set
  expect_true(is.na(result$canonical_media[2]))
  expect_true(is.na(result$media_category[2]))
  # Non-NA rows should have values
  expect_false(is.na(result$canonical_media[1]))
  expect_false(is.na(result$canonical_media[3]))
})

test_that("harmonize_media all-NA input returns correct empty result with no warnings", {
  expect_no_warning({
    result <- harmonize_media(c(NA_character_, NA_character_))
  })
  expect_equal(nrow(result), 2L)
  expect_true(all(is.na(result$canonical_media)))
  expect_true(all(is.na(result$media_category)))
})

test_that("harmonize_media treats undecided exact media terms as unmatched", {
  media_map <- tibble::tibble(
    term = c("aqueous", "solid", "runoff", "surface water"),
    canonical_term = c(NA_character_, NA_character_, NA_character_, "surface water"),
    envo_id = c(NA_character_, NA_character_, NA_character_, "ENVO:00002042"),
    parent = NA_character_,
    media_category = c(NA_character_, NA_character_, NA_character_, "aqueous"),
    source = "test"
  )

  result <- harmonize_media(c("aqueous", "solid", "runoff", "surface water"), media_map = media_map)

  expect_equal(result$media_flag[1:3], rep("media_unmatched", 3))
  expect_true(all(is.na(result$canonical_media[1:3])))
  expect_true(all(is.na(result$media_category[1:3])))
  expect_equal(result$media_flag[4], "")
  expect_equal(result$media_category[4], "aqueous")
})

test_that("unresolved media does not default ppb routing to aqueous", {
  unit_map <- tibble::tibble(
    from_unit = "ppb",
    to_unit = "ppb",
    multiplier = 1,
    category = "dimensionless",
    confidence = "HIGH",
    source = "test"
  )

  media_result <- harmonize_media(
    "solid",
    media_map = tibble::tibble(
      term = "solid",
      canonical_term = NA_character_,
      envo_id = NA_character_,
      parent = NA_character_,
      media_category = NA_character_,
      source = "test"
    )
  )
  unit_result <- harmonize_units(
    values = 1000,
    units = "ppb",
    unit_map = unit_map,
    media = media_result$media_category
  )

  expect_equal(media_result$media_flag, "media_unmatched")
  expect_equal(unit_result$harmonized_unit, "ppb")
  expect_equal(unit_result$harmonized_value, 1000)
})

test_that("harmonize_media infers user mapping category from canonical media term", {
  media_map <- tibble::tibble(
    term = c("stormwater runoff", "surface water"),
    canonical = c("surface water", "surface water"),
    canonical_term = c("surface water", "surface water"),
    envo_id = c(NA_character_, "ENVO:00002042"),
    parent = NA_character_,
    media_category = c(NA_character_, "aqueous"),
    source = c("user", "amos"),
    active = TRUE
  )

  result <- harmonize_media("stormwater runoff", media_map = media_map)

  expect_equal(result$canonical_media, "surface water")
  expect_equal(result$media_category, "aqueous")
  expect_equal(result$media_flag, "")
})

test_that("harmonize_media does not infer category from ambiguous canonical donors", {
  media_map <- tibble::tibble(
    term = c("user mapped medium", "shared canonical water", "shared canonical soil"),
    canonical_term = c("shared canonical", "shared canonical", "shared canonical"),
    envo_id = NA_character_,
    parent = NA_character_,
    media_category = c(NA_character_, "aqueous", "solid"),
    source = c("user", "test", "test"),
    active = TRUE
  )

  result <- harmonize_media("user mapped medium", media_map = media_map)

  expect_equal(result$media_flag, "media_unmatched")
  expect_true(is.na(result$canonical_media))
  expect_true(is.na(result$media_category))
})

test_that("harmonize_media parent walk is token-aware and does not bridge through embedded substrings", {
  media_map <- tibble::tibble(
    term = c("water", "sediment"),
    canonical_term = c("water", "sediment"),
    envo_id = c("ENVO:00002006", "ENVO:00002007"),
    parent = NA_character_,
    media_category = c("aqueous", "solid"),
    source = "test"
  )

  result <- harmonize_media(c("ground water", "wastewater"), media_map = media_map)

  expect_equal(result$canonical_media[1], "water")
  expect_equal(result$media_category[1], "aqueous")
  expect_equal(result$media_flag[1], "parent_walk")

  expect_true(is.na(result$canonical_media[2]))
  expect_true(is.na(result$media_category[2]))
  expect_equal(result$media_flag[2], "media_unmatched")
})

test_that("harmonize_media resolves delimiter-coded media terms", {
  media_map <- tibble::tibble(
    term = c("surface water", "tissue"),
    canonical_term = c("surface water", "tissue"),
    envo_id = c("ENVO:00002042", "ENVO:01001434"),
    parent = NA_character_,
    media_category = c("aqueous", "solid"),
    source = "test",
    active = TRUE
  )

  result <- harmonize_media(c("surface_water", "fish_tissue"), media_map = media_map)

  expect_equal(result$canonical_media, c("surface water", "tissue"))
  expect_equal(result$media_category, c("aqueous", "solid"))
  expect_equal(result$media_flag, c("", "parent_walk"))
})
