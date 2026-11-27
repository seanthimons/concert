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
  expect_equal(
    clean_unicode(c("\u2010", "\u200b", "\u2032", "\u03b2", "\u00b1", "\u03b1", "\u2192", "\u00a0", "\u0394", "\u2019")),
    c("-", "", "'", "beta", "+/-", "alpha", "->", " ", "delta", "'")
  )
  expect_true(is.na(clean_unicode(NA_character_)))
  # data.frame method cleans all character columns, preserves shape
  df <- data.frame(a = "\u03b2-carotene", b = 1L, stringsAsFactors = FALSE)
  out <- clean_unicode(df)
  expect_equal(out$a, "beta-carotene")
  expect_equal(out$b, 1L)
})

test_that("unicode records from real uncurated data clean to single-spaced ASCII (#202)", {
  names_in <- c(
    "Palygorskite fibers (> 5\u00b5m in length)",
    "TRIM\u00ae VX",
    "Vertasil\u00ae  Trisiloxanyl-cannabidiol"
  )
  # clean_unicode maps the characters but leaves whitespace alone
  expect_equal(
    clean_unicode(names_in),
    c("Palygorskite fibers (> 5um in length)", "TRIM VX", "Vertasil  Trisiloxanyl-cannabidiol")
  )
  # the pipeline's unicode step collapses space runs in the cells it changes, fixing the double space
  cleaned <- suppressMessages(run_cleaning_pipeline(tibble::tibble(chemical_name = names_in)))
  expect_equal(
    cleaned$cleaned_data$chemical_name,
    c("Palygorskite fibers (> 5um in length)", "TRIM VX", "Vertasil Trisiloxanyl-cannabidiol")
  )
  expect_setequal(cleaned$audit_trail$step, "unicode_to_ascii")
})

test_that("degree sign maps to 'deg ' so names keep meaning and units still harmonize", {
  expect_equal(clean_unicode("\u00b0C"), "deg C")
  # temperature ranges inside petroleum UVCB descriptions keep their units
  cleaned <- suppressMessages(run_cleaning_pipeline(tibble::tibble(
    chemical_name = "naphtha [boiling range approximately -40 \u00b0c to 80 \u00b0c (-40 \u00b0f to 176 \u00b0f)]"
  )))
  expect_equal(
    cleaned$cleaned_data$chemical_name,
    "naphtha [boiling range approximately -40 deg c to 80 deg c (-40 deg f to 176 deg f)]"
  )
  # cleaned temperature units still resolve against the unit map
  units <- clean_text_field(clean_unicode(c("\u00b0C", "\u00b0F", "\u00b0 C")))
  expect_equal(units, c("deg C", "deg F", "deg C"))
  result <- suppressWarnings(harmonize_units(c(20, 68, 20), units, load_unit_map(), use_dedup = FALSE))
  expect_equal(result$harmonized_unit, rep("deg C", 3))
  expect_equal(result$harmonized_value, c(20, 20, 20), tolerance = 1e-12)
  expect_equal(result$unit_flag, rep("", 3))
})

test_that("unicode step leaves no stray spaces when the whitespace step is masked off", {
  # The app can run the unicode step alone (whitespace box unchecked, prechecks off)
  df <- tibble::tibble(chemical_name = c("heated to 30\u00b0", "TRIM\u00ae  VX"), unit = c("\u00b0 C", "\u00b0F"))
  cleaned <- suppressMessages(run_cleaning_pipeline_masked(
    df,
    mask = list(unicode = TRUE, whitespace = FALSE),
    respect_prechecks = FALSE
  ))
  expect_equal(cleaned$cleaned_data$chemical_name, c("heated to 30deg", "TRIM VX"))
  expect_equal(cleaned$cleaned_data$unit, c("deg C", "deg F"))
  expect_false("trim_whitespace_punctuation" %in% cleaned$audit_trail$step)
})

test_that("unicode step keeps line breaks in cells it changes", {
  cleaned <- suppressMessages(run_cleaning_pipeline_masked(
    tibble::tibble(note = c("25 \u00b0C\nsee ref 3", "30\u00b0\nnext", "30\u00b0\r\nnext")),
    mask = list(unicode = TRUE, whitespace = FALSE),
    respect_prechecks = FALSE
  ))
  expect_equal(cleaned$cleaned_data$note, c("25 deg C\nsee ref 3", "30deg\nnext", "30deg\r\nnext"))
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
