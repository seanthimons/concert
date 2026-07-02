# test-toxval-mapper.R
# Tests for ToxVal schema mapper functionality

# Test fixtures
curated_fixture <- tibble::tibble(
 dtxsid = c("DTXSID7020182", "DTXSID2021731"),
 casrn = c("71-43-2", "7440-02-0"),
 name = c("Benzene", "Nickel"),
 qualifier = c("<", ""),
 orig_result = c("< 0.5", "10.0")
)

harmonized_fixture <- tibble::tibble(
 orig_row_id = 1:2,
 orig_unit = c("ug/L", "mg/L"),
 harmonized_value = c(0.0005, 10.0),
 harmonized_unit = c("mg/L", "mg/L"),
 conversion_factor = c(0.001, 1),
 unit_flag = c("", "")
)

# ============================================================================
# Schema Template Tests
# ============================================================================

test_that("load_toxval_schema returns 0-row tibble with 56 columns", {
 cache_dir <- system.file("extdata/reference_cache", package = "concert")
 schema <- load_toxval_schema(cache_dir)

 expect_true(tibble::is_tibble(schema))
 expect_equal(nrow(schema), 0)
 expect_equal(ncol(schema), 56)
})

test_that("toxval schema column names match ToxVal database order", {
 cache_dir <- system.file("extdata/reference_cache", package = "concert")
 schema <- load_toxval_schema(cache_dir)

 expected_cols <- c(
   "dtxsid", "casrn", "name", "source", "sub_source",
   "toxval_type", "toxval_subtype", "toxval_type_supercategory",
   "qualifier", "toxval_numeric", "toxval_units",
   "risk_assessment_class", "study_type", "study_duration_class",
   "study_duration_value", "study_duration_units",
   "species_common", "strain", "latin_name", "species_supercategory",
   "sex", "generation", "lifestage",
   "exposure_route", "exposure_method", "exposure_form", "media",
   "toxicological_effect", "toxicological_effect_category",
   "experimental_record", "study_group", "year",
   "qc_category", "qc_status", "source_hash",
   "source_url", "subsource_url",
   "toxval_type_original", "toxval_subtype_original",
   "toxval_numeric_original", "toxval_units_original",
   "study_type_original", "study_duration_class_original",
   "study_duration_value_original", "study_duration_units_original",
   "species_original", "strain_original", "sex_original",
   "generation_original", "lifestage_original",
   "exposure_route_original", "exposure_method_original",
   "exposure_form_original", "media_original",
   "toxicological_effect_original", "original_year"
 )

 expect_equal(names(schema), expected_cols)
})

test_that("toxval schema has correct column types", {
 cache_dir <- system.file("extdata/reference_cache", package = "concert")
 schema <- load_toxval_schema(cache_dir)

 types <- vapply(schema, typeof, "")

 # Character columns
 char_cols <- c(
   "dtxsid", "casrn", "name", "source", "sub_source",
   "toxval_type", "toxval_subtype", "toxval_type_supercategory",
   "qualifier", "toxval_units", "risk_assessment_class",
   "study_type", "study_duration_class", "study_duration_units",
   "species_common", "strain", "latin_name", "species_supercategory",
   "sex", "generation", "lifestage", "exposure_route", "exposure_method",
   "exposure_form", "media", "toxicological_effect",
   "toxicological_effect_category", "experimental_record", "study_group",
   "qc_category", "qc_status", "source_hash", "source_url", "subsource_url",
   "toxval_type_original", "toxval_subtype_original", "toxval_units_original",
   "study_type_original", "study_duration_class_original",
   "study_duration_units_original", "species_original", "strain_original",
   "sex_original", "generation_original", "lifestage_original",
   "exposure_route_original", "exposure_method_original",
   "exposure_form_original", "media_original", "toxicological_effect_original"
 )
 for (col in char_cols) {
   expect_equal(types[[col]], "character", info = paste("Column:", col))
 }

 # Numeric columns
 num_cols <- c(
   "toxval_numeric", "study_duration_value", "year",
   "toxval_numeric_original", "study_duration_value_original", "original_year"
 )
 for (col in num_cols) {
   expect_equal(types[[col]], "double", info = paste("Column:", col))
 }
})

test_that("toxval schema has no logical columns (no bare NAs)", {
 cache_dir <- system.file("extdata/reference_cache", package = "concert")
 schema <- load_toxval_schema(cache_dir)

 types <- vapply(schema, typeof, "")
 logical_cols <- names(types)[types == "logical"]

 expect_equal(length(logical_cols), 0,
   info = paste("Found logical columns:", paste(logical_cols, collapse = ", ")))
})

# ============================================================================
# Basic Mapping Tests
# ============================================================================

test_that("map_to_toxval_schema returns 56-column tibble", {
 result <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

 expect_true(tibble::is_tibble(result))
 expect_equal(ncol(result), 56)
 expect_equal(nrow(result), 2)
})

test_that("map_to_toxval_schema column order matches schema", {
 cache_dir <- system.file("extdata/reference_cache", package = "concert")
 schema <- load_toxval_schema(cache_dir)
 result <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

 expect_equal(names(result), names(schema))
})

test_that("dtxsid, casrn, name populated from curated_data", {
 result <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

 expect_equal(result$dtxsid, curated_fixture$dtxsid)
 expect_equal(result$casrn, curated_fixture$casrn)
 expect_equal(result$name, curated_fixture$name)
})

test_that("identifier fallbacks scan all candidate columns", {
 curated <- tibble::tibble(
   dtxsid = "DTXSID7020182",
   registry_id = "71-43-2",
   registry_id_tag = "CASRN",
   chemical_name = "Benzene"
 )
 result <- map_to_toxval_schema(curated, harmonized_fixture[1, ])

 expect_equal(result$casrn, "71-43-2")
 expect_equal(result$name, "Benzene")
})

test_that("consensus_dtxsid takes precedence over bare dtxsid", {
 curated <- dplyr::mutate(curated_fixture, consensus_dtxsid = c("DTXSID999", NA_character_))
 result <- map_to_toxval_schema(curated, harmonized_fixture)

 expect_equal(result$dtxsid, c("DTXSID999", "DTXSID2021731"))
})

test_that("range-expanded harmonized rows align through orig_row_id", {
 harmonized <- tibble::tibble(
   orig_row_id = c(1L, 1L, 2L),
   orig_unit = c("ug/L", "ug/L", "mg/L"),
   harmonized_value = c(0.0005, 0.001, 10),
   harmonized_unit = c("mg/L", "mg/L", "mg/L"),
   conversion_factor = c(0.001, 0.001, 1),
   unit_flag = c("", "", "")
 )

 result <- map_to_toxval_schema(curated_fixture, harmonized)

 expect_equal(nrow(result), 3)
 expect_equal(result$name, c("Benzene", "Benzene", "Nickel"))
 expect_equal(result$qualifier, c("<", "<", ""))
})

test_that("SSWQS metadata passes through when present", {
 curated <- dplyr::mutate(
   curated_fixture,
   source = "EPA SSWQS",
   sub_source = c("CA", "OR"),
   source_url = "https://example.test",
   toxval_subtype = "chronic",
   study_type = "Media Exposure Guidelines",
   media = "water",
   species_common = "Human",
   latin_name = "Homo sapiens",
   risk_assessment_class = "Water",
   qc_status = "needs_review",
   qc_category = "ambiguous",
   year = c(2024, 2025)
 )

 result <- map_to_toxval_schema(curated, harmonized_fixture, source_name = "EPA SSWQS")

 expect_equal(result$source, rep("EPA SSWQS", 2))
 expect_equal(result$sub_source, c("CA", "OR"))
 expect_equal(result$source_url, rep("https://example.test", 2))
 expect_equal(result$toxval_subtype, rep("chronic", 2))
 expect_equal(result$media, rep("water", 2))
 expect_equal(result$qc_status, rep("needs_review", 2))
 expect_equal(result$qc_category, rep("ambiguous", 2))
 expect_equal(result$year, c(2024, 2025))
})

test_that("toxval_numeric, toxval_units populated from harmonized_data", {
 result <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

 expect_equal(result$toxval_numeric, harmonized_fixture$harmonized_value)
 expect_equal(result$toxval_units, harmonized_fixture$harmonized_unit)
})

test_that("qualifier populated from curated_data", {
 result <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

 expect_equal(result$qualifier, curated_fixture$qualifier)
})

test_that("source defaults to user_upload when source_name is NULL", {
 result <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

 expect_equal(result$source, rep("user_upload", 2))
})

test_that("source set to custom value when source_name provided", {
 result <- map_to_toxval_schema(curated_fixture, harmonized_fixture,
   source_name = "ECOTOX")

 expect_equal(result$source, rep("ECOTOX", 2))
})

test_that("qc_category is always user_curated", {
 result <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

 expect_equal(result$qc_category, rep("user_curated", 2))
})

test_that("qc_status is pass for clean data", {
 result <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

 expect_equal(result$qc_status, rep("pass", 2))
})

# ============================================================================
# Typed NA Enforcement Tests
# ============================================================================

test_that("unmapped character columns are NA_character_", {
 result <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

 # Check a sample of unmapped character columns
 expect_true(is.na(result$sub_source[1]))
 expect_equal(typeof(result$sub_source), "character")

 expect_true(is.na(result$risk_assessment_class[1]))
 expect_equal(typeof(result$risk_assessment_class), "character")

 expect_true(is.na(result$species_common[1]))
 expect_equal(typeof(result$species_common), "character")
})

test_that("unmapped numeric columns are NA_real_", {
 result <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

 expect_true(is.na(result$study_duration_value[1]))
 expect_equal(typeof(result$study_duration_value), "double")

 expect_true(is.na(result$year[1]))
 expect_equal(typeof(result$year), "double")
})

test_that("no column in output has typeof logical", {
 result <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

 types <- vapply(result, typeof, "")
 logical_cols <- names(types)[types == "logical"]

 expect_equal(length(logical_cols), 0,
   info = paste("Found logical columns:", paste(logical_cols, collapse = ", ")))
})

# ============================================================================
# Audit Column Tests (*_original)
# ============================================================================

test_that("toxval_numeric_original comes from orig_result", {
 result <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

 # The orig_result in curated_fixture contains the pre-normalization strings
 # These should become toxval_numeric_original (converted to numeric)
 expect_equal(result$toxval_numeric_original, c(0.5, 10.0))
})

test_that("toxval_units_original comes from orig_unit", {
 result <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

 expect_equal(result$toxval_units_original, harmonized_fixture$orig_unit)
})

test_that("identity-mapped fields have same original values", {
 result <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

 # toxval_type_original should equal toxval_type (both NA or both same)
 expect_equal(result$toxval_type_original, result$toxval_type)
})

test_that("all audit columns present (18 with _original suffix + original_year)", {
 result <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

 # 18 columns ending in _original (toxval_type_original through toxicological_effect_original)
 original_cols <- grep("_original$", names(result), value = TRUE)
 expect_equal(length(original_cols), 18)

 # Plus original_year (column 56, doesn't match _original$ regex)
 expect_true("original_year" %in% names(result))

 # Total audit columns: 19
 expect_equal(length(original_cols) + 1, 19)
})

# ============================================================================
# Source Hash Tests
# ============================================================================

test_that("source_hash is non-NA character for each row", {
 result <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

 expect_false(any(is.na(result$source_hash)))
 expect_equal(typeof(result$source_hash), "character")
})

test_that("different rows produce different hashes", {
 result <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

 expect_true(result$source_hash[1] != result$source_hash[2])
})

test_that("same row content produces same hash (deterministic)", {
 result1 <- map_to_toxval_schema(curated_fixture, harmonized_fixture)
 result2 <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

 expect_equal(result1$source_hash, result2$source_hash)
})

test_that("source_hash is SHA256 format (64 hex chars)", {
 result <- map_to_toxval_schema(curated_fixture, harmonized_fixture)

 # SHA256 hashes are 64 hexadecimal characters
 expect_true(all(nchar(result$source_hash) == 64))
 expect_true(all(grepl("^[a-f0-9]{64}$", result$source_hash)))
})

# ============================================================================
# Edge Case Tests
# ============================================================================

test_that("zero-row input returns zero-row output with 56 typed columns", {
 empty_curated <- curated_fixture[0, ]
 empty_harmonized <- harmonized_fixture[0, ]

 result <- map_to_toxval_schema(empty_curated, empty_harmonized)

 expect_equal(nrow(result), 0)
 expect_equal(ncol(result), 56)

 # Verify column types preserved
 types <- vapply(result, typeof, "")
 expect_false(any(types == "logical"))
})

test_that("single-row input works correctly", {
 single_curated <- curated_fixture[1, ]
 single_harmonized <- harmonized_fixture[1, ]

 result <- map_to_toxval_schema(single_curated, single_harmonized)

 expect_equal(nrow(result), 1)
 expect_equal(ncol(result), 56)
 expect_equal(result$dtxsid, "DTXSID7020182")
})

test_that("missing optional columns in curated_data produce typed NAs", {
 # curated_data without qualifier or orig_result
 minimal_curated <- tibble::tibble(
   dtxsid = "DTXSID7020182",
   casrn = "71-43-2",
   name = "Benzene"
 )
 minimal_harmonized <- harmonized_fixture[1, ]

 result <- map_to_toxval_schema(minimal_curated, minimal_harmonized)

 expect_equal(nrow(result), 1)
 expect_true(is.na(result$qualifier))
 expect_equal(typeof(result$qualifier), "character")
})

test_that("NA values in harmonized_data produce valid typed output", {
 harmonized_with_na <- tibble::tibble(
   orig_row_id = 1L,
   orig_unit = NA_character_,
   harmonized_value = NA_real_,
   harmonized_unit = NA_character_,
   conversion_factor = NA_real_,
   unit_flag = NA_character_
 )

 result <- map_to_toxval_schema(curated_fixture[1, ], harmonized_with_na)

 expect_equal(nrow(result), 1)
 expect_true(is.na(result$toxval_numeric))
 expect_equal(typeof(result$toxval_numeric), "double")
 expect_true(is.na(result$toxval_units))
 expect_equal(typeof(result$toxval_units), "character")
})
