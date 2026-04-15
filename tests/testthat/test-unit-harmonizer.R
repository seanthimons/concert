# test-unit-harmonizer.R
# TDD tests for harmonize_units() and normalize_unit_string()
# Covers: normalization, case-safe lookup, conversion arithmetic, output shape

# ---- Helper: create minimal unit_map for testing ----

make_test_unit_map <- function() {
  tibble::tibble(
    from_unit = c("mg/L", "ug/L", "ppb", "ppm", "ng/L", "mg/kg bw/day"),
    to_unit = c("mg/L", "mg/L", "mg/L", "mg/L", "mg/L", "mg/kg bw/day"),
    multiplier = c(1, 0.001, 0.001, 1, 1e-6, 1),
    category = c("concentration", "concentration", "concentration", "concentration", "concentration", "dose"),
    confidence = rep("HIGH", 6),
    source = rep("test", 6)
  )
}

# ---- Normalization (UNIT-02) ----

test_that("normalize: whitespace is trimmed from edges", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("  mg/L  "), unit_map)
  # After normalization, "  mg/L  " should match mg/L exactly
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$unit_flag, "")
})

test_that("normalize: U+00B5 micro symbol normalizes to ASCII u", {
  unit_map <- make_test_unit_map()
  # U+00B5 is the micro sign
  result <- harmonize_units(c(10), c("\u00B5g/L"), unit_map)
  # Should match ug/L after normalization
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$conversion_factor, 0.001)
})

test_that("normalize: U+03BC mu symbol normalizes to ASCII u", {
  unit_map <- make_test_unit_map()
  # U+03BC is the Greek lowercase mu

  result <- harmonize_units(c(10), c("\u03BCg/L"), unit_map)
  # Should match ug/L after normalization
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$conversion_factor, 0.001)
})

test_that("normalize: single spaces around '/' collapsed", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mg / L"), unit_map)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$unit_flag, "")
})

test_that("normalize: multiple spaces around '/' collapsed", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mg  /  L"), unit_map)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$unit_flag, "")
})

test_that("normalize: combined trim + micro + spaces", {
  unit_map <- make_test_unit_map()
  # Combine: edge whitespace, micro symbol, and spaces around /
  result <- harmonize_units(c(10), c("  \u00B5g / L  "), unit_map)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$conversion_factor, 0.001)
})

# ---- Case-sensitive lookup (UNIT-01, D-03) ----

test_that("case-sensitive: exact 'mg/L' match", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mg/L"), unit_map)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$conversion_factor, 1)
  expect_equal(result$unit_flag, "")
})
test_that("case-sensitive: exact 'ug/L' match with conversion", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("ug/L"), unit_map)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$conversion_factor, 0.001)
  expect_equal(result$unit_flag, "")
})

test_that("case-sensitive: exact 'ppb' match with conversion", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("ppb"), unit_map)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$conversion_factor, 0.001)
  expect_equal(result$unit_flag, "")
})

# ---- Case-insensitive fallback (UNIT-01, D-04) ----

test_that("case-fallback: 'MG/L' not exact match, fallback works", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("MG/L"), unit_map)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$conversion_factor, 1)
  expect_equal(result$unit_flag, "case_fallback")
})

test_that("case-fallback: 'Mg/L' mixed case triggers fallback", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("Mg/L"), unit_map)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$unit_flag, "case_fallback")
})

test_that("case-fallback: 'UG/L' uppercase triggers fallback with conversion", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("UG/L"), unit_map)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$conversion_factor, 0.001)
  expect_equal(result$unit_flag, "case_fallback")
})

test_that("case-fallback: 'PPB' uppercase triggers fallback", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("PPB"), unit_map)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$unit_flag, "case_fallback")
})

# ---- Unmatched pass-through (D-01, D-05) ----

test_that("unmatched: 'NTU' not in table passes through", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(5), c("NTU"), unit_map)
  expect_equal(result$harmonized_value, 5)
  expect_equal(result$harmonized_unit, "NTU")
  expect_equal(result$conversion_factor, 1)
  expect_equal(result$unit_flag, "unmatched")
})

test_that("unmatched: 'CFU/100mL' complex unit passes through", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(100), c("CFU/100mL"), unit_map)
  expect_equal(result$harmonized_value, 100)
  expect_equal(result$harmonized_unit, "CFU/100mL")
  expect_equal(result$conversion_factor, 1)
  expect_equal(result$unit_flag, "unmatched")
})

test_that("unmatched: 'xyz_unknown' passes through", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(42), c("xyz_unknown"), unit_map)
  expect_equal(result$harmonized_value, 42)
  expect_equal(result$harmonized_unit, "xyz_unknown")
  expect_equal(result$conversion_factor, 1)
  expect_equal(result$unit_flag, "unmatched")
})

# ---- Conversion arithmetic (UNIT-04) ----

test_that("arithmetic: value=5, unit='ug/L' -> harmonized_value=0.005", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(5), c("ug/L"), unit_map)
  expect_equal(result$harmonized_value, 0.005)
})

test_that("arithmetic: value=1000, unit='ng/L' -> harmonized_value=0.001", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1000), c("ng/L"), unit_map)
  expect_equal(result$harmonized_value, 0.001)
})

test_that("arithmetic: value=10, unit='mg/L' -> harmonized_value=10 (no conversion)", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(10), c("mg/L"), unit_map)
  expect_equal(result$harmonized_value, 10)
})

test_that("arithmetic: unmatched unit value=2.5 -> harmonized_value=2.5 (pass-through)", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(2.5), c("unmatched_unit"), unit_map)
  expect_equal(result$harmonized_value, 2.5)
})

# ---- Output tibble shape (UNIT-05, D-07) ----

test_that("output shape: tibble has exactly 6 columns in order", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mg/L"), unit_map)
  expect_equal(
    names(result),
    c("orig_row_id", "orig_unit", "harmonized_value", "harmonized_unit", "conversion_factor", "unit_flag")
  )
})

test_that("output shape: orig_row_id is integer", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mg/L"), unit_map)
  expect_type(result$orig_row_id, "integer")
})

test_that("output shape: harmonized_value is numeric (double)", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mg/L"), unit_map)
  expect_type(result$harmonized_value, "double")
})

test_that("output shape: conversion_factor is numeric (double)", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mg/L"), unit_map)
  expect_type(result$conversion_factor, "double")
})

test_that("output shape: orig_unit is character", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mg/L"), unit_map)
  expect_type(result$orig_unit, "character")
})

test_that("output shape: harmonized_unit is character", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mg/L"), unit_map)
  expect_type(result$harmonized_unit, "character")
})

test_that("output shape: unit_flag is character", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mg/L"), unit_map)
  expect_type(result$unit_flag, "character")
})

test_that("output shape: unit_flag is '' (empty string) for exact match, not NA", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mg/L"), unit_map)
  expect_equal(result$unit_flag, "")
  expect_false(is.na(result$unit_flag))
})

# ---- Vector input ----

test_that("vector: 3-element input returns 3 rows", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(
    values = c(5, 10, 100),
    units = c("ug/L", "MG/L", "NTU"),
    unit_map = unit_map
  )
  expect_equal(nrow(result), 3)
})

test_that("vector: orig_row_id assigned as 1, 2, 3 for 3-element input", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(
    values = c(5, 10, 100),
    units = c("ug/L", "MG/L", "NTU"),
    unit_map = unit_map
  )
  expect_equal(result$orig_row_id, 1:3)
})

test_that("vector: orig_unit preserves original input before normalization", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(
    values = c(5, 10),
    units = c("MG/L", "  ug/L  "),
    unit_map = unit_map
  )
  expect_equal(result$orig_unit[1], "MG/L")
  expect_equal(result$orig_unit[2], "  ug/L  ")
})

test_that("vector: correct handling per unit type", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(
    values = c(5, 10, 100),
    units = c("ug/L", "MG/L", "NTU"),
    unit_map = unit_map
  )
  # Row 1: ug/L exact match, conversion
  expect_equal(result$harmonized_value[1], 0.005)
  expect_equal(result$unit_flag[1], "")
  # Row 2: MG/L case fallback
  expect_equal(result$harmonized_value[2], 10)
  expect_equal(result$unit_flag[2], "case_fallback")
  # Row 3: NTU unmatched
  expect_equal(result$harmonized_value[3], 100)
  expect_equal(result$unit_flag[3], "unmatched")
})

# ---- Compound units via explicit enumeration (UNIT-03) ----

test_that("compound: 'mg/kg bw/day' in table works same as simple units", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(10), c("mg/kg bw/day"), unit_map)
  expect_equal(result$harmonized_unit, "mg/kg bw/day")
  expect_equal(result$conversion_factor, 1)
  expect_equal(result$unit_flag, "")
})

test_that("compound: units are table-driven, no special parsing", {
  unit_map <- make_test_unit_map()
  # A compound unit not in the table should pass through unmatched
  result <- harmonize_units(c(5), c("mg/kg/day"), unit_map)
  expect_equal(result$harmonized_unit, "mg/kg/day")
  expect_equal(result$unit_flag, "unmatched")
})
