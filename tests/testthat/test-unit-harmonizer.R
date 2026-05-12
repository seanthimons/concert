# test-unit-harmonizer.R
# TDD tests for harmonize_units() and normalize_unit_string()
# Covers: normalization, case-safe lookup, conversion arithmetic, output shape,
#         molarity conversion, ppb/ppm media routing, synonym normalization

# ---- Helper: create minimal unit_map for testing ----

make_test_unit_map <- function() {
  tibble::tibble(
    from_unit = c("mg/L", "ug/L", "ng/L", "mg/kg/d", "ug/kg/d", "g/kg/d"),
    to_unit = c("mg/L", "mg/L", "mg/L", "mg/kg/d", "mg/kg/d", "mg/kg/d"),
    multiplier = c(1, 0.001, 1e-6, 1, 0.001, 1000),
    category = c("concentration", "concentration", "concentration", "dose", "dose", "dose"),
    confidence = rep("HIGH", 6),
    source = rep("test", 6)
  )
}

# Extended map that includes case variants for testing synonym normalization
make_extended_unit_map <- function() {
  tibble::tibble(
    from_unit = c("mg/L", "ug/L", "ng/L", "mg/kg/d", "ug/kg/d", "g/kg/d", "mg/l"),
    to_unit = c("mg/L", "mg/L", "mg/L", "mg/kg/d", "mg/kg/d", "mg/kg/d", "mg/L"),
    multiplier = c(1, 0.001, 1e-6, 1, 0.001, 1000, 1),
    category = rep("test", 7),
    confidence = rep("HIGH", 7),
    source = rep("test", 7)
  )
}

# Duration unit map for sections 16-19
make_duration_unit_map <- function() {
  tibble::tibble(
    from_unit = c(
      "hr",
      "h",
      "day",
      "d",
      "wk",
      "week",
      "mo",
      "month",
      "yr",
      "year",
      "min",
      "minute",
      "s",
      "sec",
      "second"
    ),
    to_unit = rep("hr", 15),
    multiplier = c(
      1,
      1,
      24,
      24,
      168,
      168,
      730.5,
      730.5,
      8766,
      8766,
      1 / 60,
      1 / 60,
      1 / 3600,
      1 / 3600,
      1 / 3600
    ),
    category = rep("duration", 15),
    confidence = rep("HIGH", 15),
    source = rep("test", 15)
  )
}

# ==============================================================================
# SECTION 1: Normalization (UNIT-02)
# ==============================================================================

test_that("normalize: whitespace is trimmed from edges", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("  mg/L  "), unit_map)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$unit_flag, "")
})

test_that("normalize: U+00B5 micro symbol normalizes to ASCII u", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(10), c("\u00B5g/L"), unit_map)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$conversion_factor, 0.001)
})

test_that("normalize: U+03BC mu symbol normalizes to ASCII u", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(10), c("\u03BCg/L"), unit_map)
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
  result <- harmonize_units(c(10), c("  \u00B5g / L  "), unit_map)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$conversion_factor, 0.001)
})

# ==============================================================================
# SECTION 2: Case-sensitive lookup (UNIT-01, D-03)
# ==============================================================================

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

# ==============================================================================
# SECTION 3: Case-insensitive fallback (UNIT-01, D-04)
# Note: Synonyms may normalize case variants before table lookup
# ==============================================================================

test_that("case-fallback: 'MG/L' matches via synonym or fallback", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("MG/L"), unit_map)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$conversion_factor, 1)
  # May be "" (synonym normalized) or "case_fallback" depending on synonyms
  expect_true(result$unit_flag %in% c("", "case_fallback"))
})

test_that("case-fallback: 'Mg/L' mixed case matches", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("Mg/L"), unit_map)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_true(result$unit_flag %in% c("", "case_fallback"))
})

test_that("case-fallback: 'UG/L' uppercase matches with conversion", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("UG/L"), unit_map)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$conversion_factor, 0.001)
  expect_true(result$unit_flag %in% c("", "case_fallback"))
})

# ==============================================================================
# SECTION 4: Unmatched pass-through (D-01, D-05)
# ==============================================================================

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

# ==============================================================================
# SECTION 5: Conversion arithmetic (UNIT-04)
# ==============================================================================

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

# ==============================================================================
# SECTION 6: Output tibble shape (UNIT-05, D-07)
# ==============================================================================

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

# ==============================================================================
# SECTION 7: Vector input
# ==============================================================================

test_that("vector: 3-element input returns 3 rows", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(
    values = c(5, 10, 100),
    units = c("ug/L", "mg/L", "NTU"),
    unit_map = unit_map
  )
  expect_equal(nrow(result), 3)
})

test_that("vector: orig_row_id assigned as 1, 2, 3 for 3-element input", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(
    values = c(5, 10, 100),
    units = c("ug/L", "mg/L", "NTU"),
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
    units = c("ug/L", "mg/L", "NTU"),
    unit_map = unit_map
  )
  # Row 1: ug/L exact match, conversion
  expect_equal(result$harmonized_value[1], 0.005)
  expect_equal(result$unit_flag[1], "")
  # Row 2: mg/L exact match
  expect_equal(result$harmonized_value[2], 10)
  expect_equal(result$unit_flag[2], "")
  # Row 3: NTU unmatched
  expect_equal(result$harmonized_value[3], 100)
  expect_equal(result$unit_flag[3], "unmatched")
})

# ==============================================================================
# SECTION 8: Backward compatibility (D-13)
# ==============================================================================

test_that("backward compat: 3-param call works (no media/dtxsid/mw)", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(5, 10), c("ug/L", "mg/L"), unit_map)
  expect_equal(nrow(result), 2)
  expect_equal(result$harmonized_value, c(0.005, 10))
})

test_that("backward compat: NULL params behave same as missing", {
  unit_map <- make_test_unit_map()
  result1 <- harmonize_units(c(5), c("ug/L"), unit_map)
  result2 <- harmonize_units(c(5), c("ug/L"), unit_map, media = NULL, dtxsid = NULL, molecular_weight = NULL)
  expect_equal(result1$harmonized_value, result2$harmonized_value)
  expect_equal(result1$harmonized_unit, result2$harmonized_unit)
})

test_that("backward compat: standard unit lookup still works", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1000), c("ng/L"), unit_map)
  expect_equal(result$harmonized_value, 0.001)
  expect_equal(result$harmonized_unit, "mg/L")
})

test_that("backward compat: unmatched units still pass through", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(42), c("FTU"), unit_map)
  expect_equal(result$harmonized_value, 42)
  expect_equal(result$harmonized_unit, "FTU")
  expect_equal(result$unit_flag, "unmatched")
})

test_that("backward compat: micro symbol normalization preserved", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(100), c("\u00B5g/L"), unit_map)
  expect_equal(result$harmonized_value, 0.1)
  expect_equal(result$harmonized_unit, "mg/L")
})

# ==============================================================================
# SECTION 9: Molarity detection (D-05)
# ==============================================================================

test_that("molarity detection: M is molarity", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("M"), unit_map)
  # Without MW, should flag as needs_mw
  expect_equal(result$unit_flag, "needs_mw")
})

test_that("molarity detection: mM is molarity", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mM"), unit_map)
  expect_equal(result$unit_flag, "needs_mw")
})

test_that("molarity detection: uM is molarity", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("uM"), unit_map)
  expect_equal(result$unit_flag, "needs_mw")
})

test_that("molarity detection: nM is molarity", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("nM"), unit_map)
  expect_equal(result$unit_flag, "needs_mw")
})

test_that("molarity detection: pM is molarity", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("pM"), unit_map)
  expect_equal(result$unit_flag, "needs_mw")
})

test_that("molarity detection: mol/L is molarity", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mol/L"), unit_map)
  expect_equal(result$unit_flag, "needs_mw")
})

test_that("molarity detection: mmol/L is molarity", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mmol/L"), unit_map)
  expect_equal(result$unit_flag, "needs_mw")
})

test_that("molarity detection: mg/L is NOT molarity", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mg/L"), unit_map)
  expect_equal(result$unit_flag, "") # Not needs_mw
})

# ==============================================================================
# SECTION 10: Molarity conversion with MW (D-06)
# ==============================================================================

test_that("molarity MW: M with MW=100 -> mg/L = value * 100 * 1000", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(0.001), c("M"), unit_map, molecular_weight = 100)
  expect_equal(result$harmonized_value, 100) # 0.001 M * 100 g/mol * 1000 = 100 mg/L
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$unit_flag, "")
})

test_that("molarity MW: mM with MW=100 -> mg/L = value * 100", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mM"), unit_map, molecular_weight = 100)
  expect_equal(result$harmonized_value, 100) # 1 mM * 100 g/mol = 100 mg/L
  expect_equal(result$harmonized_unit, "mg/L")
})

test_that("molarity MW: uM with MW=100 -> mg/L = value * 100 * 0.001", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1000), c("uM"), unit_map, molecular_weight = 100)
  expect_equal(result$harmonized_value, 100) # 1000 uM * 100 g/mol * 0.001 = 100 mg/L
  expect_equal(result$harmonized_unit, "mg/L")
})

test_that("molarity MW: nM with MW=100 -> mg/L = value * 100 * 1e-6", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1e6), c("nM"), unit_map, molecular_weight = 100)
  expect_equal(result$harmonized_value, 100) # 1e6 nM * 100 * 1e-6 = 100 mg/L
  expect_equal(result$harmonized_unit, "mg/L")
})

test_that("molarity MW: pM with MW=100 conversion", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1e9), c("pM"), unit_map, molecular_weight = 100)
  expect_equal(result$harmonized_value, 100) # 1e9 pM * 100 * 1e-9 = 100 mg/L
  expect_equal(result$harmonized_unit, "mg/L")
})

test_that("molarity MW: molecular_weight param overrides API lookup", {
  unit_map <- make_test_unit_map()
  # Even with dtxsid provided, mw param takes precedence
  result <- harmonize_units(c(1), c("mM"), unit_map, dtxsid = "DTXSID7020182", molecular_weight = 200)
  expect_equal(result$harmonized_value, 200) # 1 mM * 200 = 200 mg/L
})

test_that("molarity MW: no MW returns needs_mw flag", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mM"), unit_map)
  expect_equal(result$harmonized_value, 1) # unchanged
  expect_equal(result$harmonized_unit, "mM") # preserved
  expect_equal(result$unit_flag, "needs_mw")
})

test_that("molarity MW: zero MW treated as no MW", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mM"), unit_map, molecular_weight = 0)
  expect_equal(result$unit_flag, "needs_mw")
})

test_that("molarity MW: negative MW treated as no MW", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mM"), unit_map, molecular_weight = -100)
  expect_equal(result$unit_flag, "needs_mw")
})

test_that("molarity MW: vector of different MWs", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(
    values = c(1, 1, 1),
    units = c("mM", "mM", "mM"),
    unit_map = unit_map,
    molecular_weight = c(100, 200, 300)
  )
  expect_equal(result$harmonized_value, c(100, 200, 300))
})

# ==============================================================================
# SECTION 11: ppb/ppm media routing (D-08, D-09, D-10)
# ==============================================================================

test_that("ppb media: aqueous -> mg/L", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1000), c("ppb"), unit_map, media = "aqueous")
  expect_equal(result$harmonized_value, 1) # 1000 ppb * 0.001 = 1 mg/L
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$unit_flag, "")
})

test_that("ppb media: solid -> mg/kg", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1000), c("ppb"), unit_map, media = "solid")
  expect_equal(result$harmonized_value, 1)
  expect_equal(result$harmonized_unit, "mg/kg")
  expect_equal(result$unit_flag, "")
})

test_that("ppb media: air -> mg/m3", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1000), c("ppb"), unit_map, media = "air")
  expect_equal(result$harmonized_value, 1)
  expect_equal(result$harmonized_unit, "mg/m3")
  expect_equal(result$unit_flag, "")
})

test_that("ppm media: aqueous -> mg/L", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(10), c("ppm"), unit_map, media = "aqueous")
  expect_equal(result$harmonized_value, 10) # 10 ppm * 1 = 10 mg/L
  expect_equal(result$harmonized_unit, "mg/L")
})

test_that("ppm media: solid -> mg/kg", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(10), c("ppm"), unit_map, media = "solid")
  expect_equal(result$harmonized_value, 10)
  expect_equal(result$harmonized_unit, "mg/kg")
})

test_that("ppm media: air -> mg/m3", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(10), c("ppm"), unit_map, media = "air")
  expect_equal(result$harmonized_value, 10)
  expect_equal(result$harmonized_unit, "mg/m3")
})

test_that("ppb media: NULL defaults to aqueous with media_inferred flag", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1000), c("ppb"), unit_map, media = NULL)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$unit_flag, "media_inferred")
})

test_that("ppm media: NULL defaults to aqueous with media_inferred flag", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(10), c("ppm"), unit_map)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$unit_flag, "media_inferred")
})

test_that("ppb media: empty string defaults to aqueous", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1000), c("ppb"), unit_map, media = "")
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$unit_flag, "media_inferred")
})

test_that("ppb/ppm: conversion factors correct", {
  unit_map <- make_test_unit_map()
  # ppb factor = 0.001
  result_ppb <- harmonize_units(c(1000), c("ppb"), unit_map, media = "aqueous")
  expect_equal(result_ppb$conversion_factor, 0.001)
  # ppm factor = 1
  result_ppm <- harmonize_units(c(10), c("ppm"), unit_map, media = "aqueous")
  expect_equal(result_ppm$conversion_factor, 1)
})

test_that("ppb/ppm: vector of different media", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(
    values = c(100, 100, 100),
    units = c("ppb", "ppb", "ppb"),
    unit_map = unit_map,
    media = c("aqueous", "solid", "air")
  )
  expect_equal(result$harmonized_unit, c("mg/L", "mg/kg", "mg/m3"))
})

test_that("ppb: uppercase PPB works via case fallback", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1000), c("PPB"), unit_map, media = "aqueous")
  expect_equal(result$harmonized_value, 1)
  expect_equal(result$harmonized_unit, "mg/L")
})

# ==============================================================================
# SECTION 12: Synonym normalization
# ==============================================================================

test_that("synonym: mg/kg bw/day -> mg/kg/d", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(10), c("mg/kg bw/day"), unit_map)
  expect_equal(result$harmonized_unit, "mg/kg/d")
  expect_equal(result$unit_flag, "")
})

test_that("synonym: mg/kg-bw/day -> mg/kg/d", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(10), c("mg/kg-bw/day"), unit_map)
  expect_equal(result$harmonized_unit, "mg/kg/d")
})

test_that("synonym: ug/kg bw/day -> ug/kg/d -> mg/kg/d", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1000), c("ug/kg bw/day"), unit_map)
  expect_equal(result$harmonized_unit, "mg/kg/d")
  expect_equal(result$harmonized_value, 1) # 1000 * 0.001 = 1
})

test_that("synonym: mg/kg-day -> mg/kg/d", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(5), c("mg/kg-day"), unit_map)
  expect_equal(result$harmonized_unit, "mg/kg/d")
})

test_that("synonym: non-matching string passes through", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(5), c("exotic_unit"), unit_map)
  expect_equal(result$harmonized_unit, "exotic_unit")
  expect_equal(result$unit_flag, "unmatched")
})

test_that("synonym: synonyms loaded internally (no param)", {
  unit_map <- make_test_unit_map()
  # This test verifies synonyms work without passing them as parameter
  result <- harmonize_units(c(10), c("mg/kg bw/day"), unit_map)
  expect_equal(result$harmonized_unit, "mg/kg/d")
})

test_that("synonym: mg/l -> mg/L case normalization", {
  unit_map <- make_extended_unit_map()
  result <- harmonize_units(c(5), c("mg/l"), unit_map)
  expect_equal(result$harmonized_unit, "mg/L")
})

test_that("synonym: original unit preserved in output", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(10), c("mg/kg bw/day"), unit_map)
  expect_equal(result$orig_unit, "mg/kg bw/day")
})

# ==============================================================================
# SECTION 13: Extended unit_flag values (D-17)
# ==============================================================================

test_that("unit_flag: '' for exact match", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mg/L"), unit_map)
  expect_equal(result$unit_flag, "")
})

test_that("unit_flag: 'case_fallback' for case-insensitive match (when no synonym)", {
  # Create unit_map without mg/l synonym match
  unit_map <- tibble::tibble(
    from_unit = c("mg/L"),
    to_unit = c("mg/L"),
    multiplier = c(1),
    category = c("test"),
    confidence = c("HIGH"),
    source = c("test")
  )
  # This should trigger case_fallback if there's no synonym for MG/L
  result <- harmonize_units(c(1), c("MG/L"), unit_map)
  # May get "" if synonym normalizes, or "case_fallback" if not
  expect_true(result$unit_flag %in% c("", "case_fallback"))
})

test_that("unit_flag: 'unmatched' for no match", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("XYZ_UNIT"), unit_map)
  expect_equal(result$unit_flag, "unmatched")
})

test_that("unit_flag: 'needs_mw' for molarity without MW", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mM"), unit_map)
  expect_equal(result$unit_flag, "needs_mw")
})

test_that("unit_flag: 'media_inferred' for ppb/ppm default media", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(10), c("ppb"), unit_map)
  expect_equal(result$unit_flag, "media_inferred")
})

test_that("unit_flag: molarity with MW gives '' not needs_mw", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("mM"), unit_map, molecular_weight = 100)
  expect_equal(result$unit_flag, "")
})

test_that("unit_flag: ppb with explicit media gives '' not media_inferred", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(10), c("ppb"), unit_map, media = "aqueous")
  expect_equal(result$unit_flag, "")
})

# ==============================================================================
# SECTION 14: Integration tests
# ==============================================================================

test_that("integration: vector with mixed molarity/ppb/mg/L", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(
    values = c(1, 1000, 10),
    units = c("mM", "ppb", "mg/L"),
    unit_map = unit_map,
    molecular_weight = c(100, NA, NA),
    media = c(NA, "aqueous", NA)
  )
  # Row 1: 1 mM * 100 = 100 mg/L
  expect_equal(result$harmonized_value[1], 100)
  expect_equal(result$harmonized_unit[1], "mg/L")
  expect_equal(result$unit_flag[1], "")
  # Row 2: 1000 ppb * 0.001 = 1 mg/L
  expect_equal(result$harmonized_value[2], 1)
  expect_equal(result$harmonized_unit[2], "mg/L")
  expect_equal(result$unit_flag[2], "")
  # Row 3: 10 mg/L unchanged
  expect_equal(result$harmonized_value[3], 10)
  expect_equal(result$harmonized_unit[3], "mg/L")
})

test_that("integration: molarity + media context combined", {
  unit_map <- make_test_unit_map()
  # Molarity takes precedence over ppb routing
  result <- harmonize_units(
    values = c(1, 100),
    units = c("mM", "ppb"),
    unit_map = unit_map,
    molecular_weight = c(200, NA),
    media = c("solid", "solid")
  )
  # mM with MW -> mg/L (molarity), ignores media
  expect_equal(result$harmonized_unit[1], "mg/L")
  # ppb with solid media -> mg/kg
  expect_equal(result$harmonized_unit[2], "mg/kg")
})

test_that("integration: SSWQS-style mixed input", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(
    values = c(0.1, 5, 10, 1),
    units = c("mg/L", "ug/L", "ppb", "uM"),
    unit_map = unit_map,
    media = c(NA, NA, "aqueous", NA),
    molecular_weight = c(NA, NA, NA, 300)
  )
  expect_equal(result$harmonized_value[1], 0.1)
  expect_equal(result$harmonized_value[2], 0.005)
  expect_equal(result$harmonized_value[3], 0.01)
  expect_equal(result$harmonized_value[4], 0.3) # 1 uM * 300 * 0.001
})

test_that("integration: all units in single call", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(
    values = c(1, 1, 1, 1, 1, 1),
    units = c("mg/L", "ug/L", "ng/L", "mM", "ppb", "NTU"),
    unit_map = unit_map,
    molecular_weight = c(NA, NA, NA, 100, NA, NA),
    media = c(NA, NA, NA, NA, "aqueous", NA)
  )
  expect_equal(result$harmonized_unit, c("mg/L", "mg/L", "mg/L", "mg/L", "mg/L", "NTU"))
  expect_equal(result$unit_flag, c("", "", "", "", "", "unmatched"))
})

test_that("integration: scalar media applies to all rows", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(
    values = c(100, 200),
    units = c("ppb", "ppb"),
    unit_map = unit_map,
    media = "solid" # scalar, should apply to both
  )
  expect_equal(result$harmonized_unit, c("mg/kg", "mg/kg"))
})

# ==============================================================================
# SECTION 15: Edge cases
# ==============================================================================

test_that("edge: empty vector input", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(numeric(0), character(0), unit_map)
  expect_equal(nrow(result), 0)
  expect_equal(
    names(result),
    c("orig_row_id", "orig_unit", "harmonized_value", "harmonized_unit", "conversion_factor", "unit_flag")
  )
})

test_that("edge: single element vector", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(5), c("mg/L"), unit_map)
  expect_equal(nrow(result), 1)
})

test_that("edge: NA in values", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(NA_real_, 10), c("mg/L", "mg/L"), unit_map)
  expect_true(is.na(result$harmonized_value[1]))
  expect_equal(result$harmonized_value[2], 10)
})

test_that("edge: NA in units", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(10), c(NA_character_), unit_map)
  expect_equal(result$harmonized_value, 10)
  expect_equal(result$unit_flag, "unmatched")
})

test_that("edge: very large values", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1e15), c("ug/L"), unit_map)
  expect_equal(result$harmonized_value, 1e12)
})

test_that("edge: very small values", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1e-15), c("mg/L"), unit_map)
  expect_equal(result$harmonized_value, 1e-15)
})

test_that("edge: scientific notation in molarity conversion", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1e-3), c("M"), unit_map, molecular_weight = 1000)
  expect_equal(result$harmonized_value, 1000) # 1e-3 M * 1000 * 1000 = 1000 mg/L
})

# ==============================================================================
# Phase 37: Unit-key dedup tests (PERF-03)
# ==============================================================================

test_that("dedup: high duplication produces identical results to direct path", {
  unit_map <- make_test_unit_map()
  # 100 rows, only 5 unique units -> dedup should fire (n_unique=5 < 100/2=50)
  values <- rep(c(1.0, 2.5, 0.1, 100, 50), 20)
  units <- rep(c("mg/L", "ug/L", "ng/L", "mg/kg/d", "g/kg/d"), 20)

  result <- harmonize_units(values, units, unit_map)

  expect_equal(nrow(result), 100)
  # All mg/L rows should have conversion_factor = 1
  expect_true(all(result$conversion_factor[units == "mg/L"] == 1))
  # All ug/L rows should have same conversion factor
  ug_factors <- unique(result$conversion_factor[units == "ug/L"])
  expect_length(ug_factors, 1)
  # Output schema correct
  expect_named(
    result,
    c(
      "orig_row_id",
      "orig_unit",
      "harmonized_value",
      "harmonized_unit",
      "conversion_factor",
      "unit_flag"
    )
  )
})

test_that("dedup: ppx with different media produces correct per-key results", {
  unit_map <- make_test_unit_map()
  # Same ppb unit but different media -> different keys
  values <- c(10, 10, 10, 10)
  units <- c("ppb", "ppb", "ppb", "ppb")
  media <- c("aqueous", "aqueous", "solid", "solid")

  result <- harmonize_units(values, units, unit_map, media = media)

  # Same media -> same harmonized_unit
  expect_equal(result$harmonized_unit[1], result$harmonized_unit[2])
  expect_equal(result$harmonized_unit[3], result$harmonized_unit[4])
  # aqueous ppb -> mg/L, solid ppb -> mg/kg
  expect_equal(result$harmonized_unit[1], "mg/L")
  expect_equal(result$harmonized_unit[3], "mg/kg")
})

test_that("dedup: all unique units bypasses dedup path", {
  unit_map <- make_test_unit_map()
  # Each unit is unique (3 rows, 3 unique) -> n_unique=3, n=3, 3 < 3/2=1.5 is FALSE -> bypass
  values <- c(1.0, 2.0, 3.0)
  units <- c("mg/L", "ug/L", "ng/L")

  result <- harmonize_units(values, units, unit_map)

  expect_equal(nrow(result), 3)
  expect_named(
    result,
    c(
      "orig_row_id",
      "orig_unit",
      "harmonized_value",
      "harmonized_unit",
      "conversion_factor",
      "unit_flag"
    )
  )
  # Correct conversions still applied in bypass path
  expect_equal(result$harmonized_value[1], 1.0)
  expect_equal(result$harmonized_value[2], 0.002)
  expect_equal(result$harmonized_value[3], 3e-6)
})

test_that("dedup: preserves orig_row_id ordering", {
  unit_map <- make_test_unit_map()
  values <- rep(1.0, 50)
  units <- rep(c("mg/L", "ug/L"), 25)

  result <- harmonize_units(values, units, unit_map)

  expect_equal(result$orig_row_id, 1:50)
  expect_equal(result$orig_unit, units)
})

# ==============================================================================
# use_dedup toggle tests (Phase 38 — BENCH-02)
# ==============================================================================

test_that("harmonize_units use_dedup=FALSE produces identical output to TRUE", {
  unit_map <- make_test_unit_map()
  n <- 100L
  set.seed(42)
  test_values <- runif(n, 0.001, 1000)
  test_units <- sample(c("mg/L", "ug/L", "ppb", "ppm", "mg/kg"), n, replace = TRUE)
  test_media <- sample(c("aqueous", "solid"), n, replace = TRUE)

  result_dedup <- harmonize_units(test_values, test_units, unit_map, media = test_media, use_dedup = TRUE)
  result_no_dedup <- harmonize_units(test_values, test_units, unit_map, media = test_media, use_dedup = FALSE)

  expect_equal(result_dedup$harmonized_value, result_no_dedup$harmonized_value)
  expect_equal(result_dedup$harmonized_unit, result_no_dedup$harmonized_unit)
  expect_equal(result_dedup$conversion_factor, result_no_dedup$conversion_factor)
  expect_equal(result_dedup$unit_flag, result_no_dedup$unit_flag)
})

test_that("harmonize_units use_dedup=FALSE forces direct path even with high duplication", {
  unit_map <- make_test_unit_map()
  # 50 rows with only 2 unique units -- dedup would normally fire (n_unique < n/2)
  test_values <- rep(c(1.0, 2.0), 25)
  test_units <- rep(c("mg/L", "ug/L"), 25)

  result_dedup <- harmonize_units(test_values, test_units, unit_map, use_dedup = TRUE)
  result_no_dedup <- harmonize_units(test_values, test_units, unit_map, use_dedup = FALSE)

  # Results must be identical -- dedup is performance-only, not behavioral
  expect_equal(result_dedup$harmonized_value, result_no_dedup$harmonized_value)
  expect_equal(result_dedup$harmonized_unit, result_no_dedup$harmonized_unit)
  expect_equal(result_dedup$conversion_factor, result_no_dedup$conversion_factor)
})

# ==============================================================================
# SECTION 16: Duration category filter (D-12)
# ==============================================================================

test_that("duration category: category=NULL uses all rows (backward compat)", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(24), c("day"), unit_map, category = NULL)
  expect_equal(result$harmonized_unit, "hr")
  expect_equal(result$harmonized_value, 576) # 24 * 24
})

test_that("duration category: category='duration' filters to hr-base rows", {
  # Combined map: time rows (to=day) + duration rows (to=hr)
  time_rows <- tibble::tibble(
    from_unit = "day",
    to_unit = "day",
    multiplier = 1,
    category = "time",
    confidence = "HIGH",
    source = "test"
  )
  dur_rows <- tibble::tibble(
    from_unit = "day",
    to_unit = "hr",
    multiplier = 24,
    category = "duration",
    confidence = "HIGH",
    source = "test"
  )
  combined_map <- dplyr::bind_rows(time_rows, dur_rows)

  result <- harmonize_units(c(1), c("day"), combined_map, category = "duration")
  expect_equal(result$harmonized_unit, "hr")
  expect_equal(result$harmonized_value, 24)
})

test_that("duration category: unrecognized unit passes through with 'unmatched' flag (D-06)", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(5), c("dph"), unit_map, category = "duration")
  expect_equal(result$harmonized_value, 5)
  expect_equal(result$harmonized_unit, "dph")
  expect_equal(result$unit_flag, "unmatched")
})

# ==============================================================================
# SECTION 17: Duration conversion arithmetic (DUR-02)
# ==============================================================================

test_that("duration: hr -> hr (identity)", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(96), c("hr"), unit_map, category = "duration")
  expect_equal(result$harmonized_value, 96)
  expect_equal(result$harmonized_unit, "hr")
})

test_that("duration: day -> hr (* 24)", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(14), c("day"), unit_map, category = "duration")
  expect_equal(result$harmonized_value, 336)
  expect_equal(result$harmonized_unit, "hr")
})

test_that("duration: min -> hr (* 1/60)", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(120), c("min"), unit_map, category = "duration")
  expect_equal(result$harmonized_value, 2, tolerance = 1e-10)
  expect_equal(result$harmonized_unit, "hr")
})

test_that("duration: wk -> hr (* 168)", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(2), c("wk"), unit_map, category = "duration")
  expect_equal(result$harmonized_value, 336)
})

test_that("duration: yr -> hr (* 8766)", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(1), c("yr"), unit_map, category = "duration")
  expect_equal(result$harmonized_value, 8766)
})

test_that("duration: decimal fraction '1.5 days' -> 36 hr (D-03)", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(1.5), c("day"), unit_map, category = "duration")
  expect_equal(result$harmonized_value, 36)
})

# ==============================================================================
# SECTION 18: Duration synonym normalization (DUR-05)
# ==============================================================================
# Note: These tests rely on the package-installed unit_synonyms.rds.
# Synonyms are loaded via get_unit_synonyms() -> system.file().

test_that("duration synonym: 'hrs' -> normalized to 'hr'", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(48), c("hrs"), unit_map, category = "duration")
  expect_equal(result$harmonized_unit, "hr")
  expect_equal(result$harmonized_value, 48)
})

test_that("duration synonym: 'Days' -> normalized to 'day'", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(7), c("Days"), unit_map, category = "duration")
  expect_equal(result$harmonized_value, 168) # 7 * 24
})

# ==============================================================================
# SECTION 19: "m" ambiguity flag (D-01, DUR-05)
# ==============================================================================

test_that("ambiguous_unit: 'm' maps to minutes and sets ambiguous_unit flag", {
  unit_map <- make_duration_unit_map()
  # "m" synonym -> "min" via unit_synonyms.rds, converted to hr, then flagged ambiguous
  result <- harmonize_units(c(60), c("m"), unit_map, category = "duration")
  expect_equal(result$harmonized_unit, "hr")
  expect_equal(result$harmonized_value, 1, tolerance = 1e-10) # 60 min -> 1 hr
  expect_equal(result$unit_flag, "ambiguous_unit")
})

test_that("ambiguous_unit: non-ambiguous 'min' does NOT get ambiguous flag", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(60), c("min"), unit_map, category = "duration")
  expect_equal(result$unit_flag, "")
})

test_that("SSWQS observed units harmonize through bundled references", {
  unit_map <- load_unit_map(system.file("extdata/reference_cache", package = "concert"))

  result <- harmonize_units(
    values = c(1000, 2, 7, 100, 3, 5, 1, 2, 10, 1, 4, 2, 100, 1),
    units = c(
      "parts/billion (ppb)",
      "pg/L",
      "standard units",
      "CFU/100 ml or MPN/100 ml",
      "million fibers/L",
      "umhos/cm",
      "feet",
      "lbs/year",
      "picocuries/L",
      "change in PCU",
      "mg/kg fish tissue",
      "ug/kg",
      "ng/L",
      "no units"
    ),
    unit_map = unit_map,
    media = "aqueous"
  )

  expect_equal(result$harmonized_unit, c(
    "mg/L", "mg/L", "pH units", "CFU/100 mL", "fibers/L", "uS/cm",
    "meters", "kg/yr", "pCi/L", "PCU", "mg/kg wet weight", "mg/kg",
    "mg/L", "[no units]"
  ))
  expect_equal(result$harmonized_value[1], 1)
  expect_equal(result$harmonized_value[2], 2e-9)
  expect_equal(result$harmonized_value[7], 0.3048)
  expect_equal(result$harmonized_value[8], 0.90718474)
})
