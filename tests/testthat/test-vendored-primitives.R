# Contract tests for curation primitives vendored from ComptoxR into concert.
# These lock the behavior concert's cleaning/curation pipelines depend on so the
# functions can be owned locally without depending on ComptoxR.

test_that("is_cas validates format and check digit", {
  expect_true(is_cas("50-00-0"))
  expect_true(is_cas("7732-18-5"))
  expect_false(is_cas("50-00-1")) # bad check digit
  expect_false(is_cas("not-a-casrn"))
  expect_equal(is_cas(c("50-00-0", "50-00-1", NA, "7732-18-5")), c(TRUE, FALSE, NA, TRUE))
})

test_that("as_cas coerces, pads, and validates", {
  expect_equal(as_cas("50-00-0"), "50-00-0")
  expect_equal(as_cas("0050-00-0"), "50-00-0") # leading zeros trimmed
  expect_equal(as_cas("50000"), "50-00-0") # missing hyphens
  expect_equal(as_cas("CAS: 7732-18-5"), "7732-18-5") # extra text
  expect_true(is.na(as_cas("50-00-1"))) # bad check digit
  expect_true(is.na(as_cas("not-a-casrn")))
})

test_that("extract_cas returns a list of all valid CASRNs per element", {
  text <- c(
    "The CAS for formaldehyde is 50-00-0, and water is 7732-18-5.",
    "An invalid number is 50-00-1, but a padded one is 007732-18-5.",
    "No valid CASRNs here.",
    NA
  )
  res <- extract_cas(text)
  expect_type(res, "list")
  expect_equal(res[[1]], c("50-00-0", "7732-18-5")) # order preserved, both kept
  expect_equal(res[[2]], "7732-18-5") # invalid dropped, padded kept
  expect_equal(res[[3]], character(0))
  expect_equal(res[[4]], character(0)) # NA-safe
})

test_that("clean_unicode maps chemistry unicode and is NOT a silent no-op", {
  # Proves concert's own unicode_map (sysdata.rda) is loaded in the namespace.
  expect_equal(clean_unicode("17\u03b2-Estradiol"), "17beta-Estradiol")
  expect_equal(clean_unicode("\u03b1-tocopherol"), "alpha-tocopherol")
  expect_equal(clean_unicode("Concentration \u2265 10 \u00b5g/L"), "Concentration >= 10 ug/L")
  expect_true(is.na(clean_unicode(NA_character_)))
  # data.frame method cleans all character columns, preserves shape
  df <- data.frame(a = "\u03b2-carotene", b = 1L, stringsAsFactors = FALSE)
  out <- clean_unicode(df)
  expect_equal(out$a, "beta-carotene")
  expect_equal(out$b, 1L)
})

test_that("extract_mixture detects ratio patterns (the gap flag_multi_analyte does not cover)", {
  names_in <- c(
    "Ethanol, water (1:1)",
    "Sodium chloride",
    "Styrene-butadiene copolymer (3:1)",
    "gasoline 70/30 w/w",
    "1,2-Dichlorobenzene",
    NA
  )
  expect_equal(
    extract_mixture(names_in),
    c(TRUE, FALSE, TRUE, TRUE, FALSE, NA)
  )
})

test_that("extract_formulas extracts formulas embedded in brackets", {
  res <- extract_formulas(c(
    "Water (H2O) and ethanol (C2H5OH).",
    "Complex: [Pt(NH3)2Cl2] catalyst.",
    "iron (III) chloride", # oxidation-state Roman numeral ignored
    "C9-12 alcohols" # carbon range ignored
  ))
  expect_type(res, "list")
  expect_true("H2O" %in% res[[1]])
  expect_true("C2H5OH" %in% res[[1]])
  expect_true(any(grepl("Pt", res[[2]])))
  expect_equal(res[[3]], character(0))
  expect_equal(res[[4]], character(0))
})
