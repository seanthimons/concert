# Test file for isotope shortcode expansion, chiral designation protection, and multi-analyte flagging
# Tests for: protect_chiral_designations, expand_isotope_shortcodes, flag_multi_analyte

# ==============================================================================
# Tests for protect_chiral_designations()
# ==============================================================================

test_that("protect_chiral_designations flags (+)-catechin with WARNING and replaces marker", {
  df <- tibble::tibble(chemical_name = c("(+)-catechin", "acetone"))
  result <- protect_chiral_designations(df, c("chemical_name"))

  expect_type(result, "list")
  expect_named(result, c("cleaned_data", "audit_trail"))

  # Value should be changed (placeholder injected)
  expect_true(result$cleaned_data$chemical_name[1] != "(+)-catechin")
  # Should contain placeholder prefix
  expect_true(grepl("###CHIRAL_", result$cleaned_data$chemical_name[1]))
  # WARNING flag set
  expect_true(grepl("WARNING: chiral", result$cleaned_data$cleaning_flag[1]))
  # acetone unchanged
  expect_equal(result$cleaned_data$chemical_name[2], "acetone")
  expect_true(is.na(result$cleaned_data$cleaning_flag[2]))
})

test_that("protect_chiral_designations flags (-)-epicatechin", {
  df <- tibble::tibble(chemical_name = c("(-)-epicatechin"))
  result <- protect_chiral_designations(df, c("chemical_name"))

  expect_true(grepl("###CHIRAL_", result$cleaned_data$chemical_name[1]))
  expect_true(grepl("WARNING: chiral", result$cleaned_data$cleaning_flag[1]))
})

test_that("protect_chiral_designations flags (R)-limonene", {
  df <- tibble::tibble(chemical_name = c("(R)-limonene"))
  result <- protect_chiral_designations(df, c("chemical_name"))

  expect_true(grepl("###CHIRAL_", result$cleaned_data$chemical_name[1]))
  expect_true(grepl("WARNING: chiral", result$cleaned_data$cleaning_flag[1]))
})

test_that("protect_chiral_designations flags (S)-ibuprofen", {
  df <- tibble::tibble(chemical_name = c("(S)-ibuprofen"))
  result <- protect_chiral_designations(df, c("chemical_name"))

  expect_true(grepl("###CHIRAL_", result$cleaned_data$chemical_name[1]))
  expect_true(grepl("WARNING: chiral", result$cleaned_data$cleaning_flag[1]))
})

test_that("protect_chiral_designations flags (R,S)-methadone", {
  df <- tibble::tibble(chemical_name = c("(R,S)-methadone"))
  result <- protect_chiral_designations(df, c("chemical_name"))

  expect_true(grepl("###CHIRAL_", result$cleaned_data$chemical_name[1]))
  expect_true(grepl("WARNING: chiral", result$cleaned_data$cleaning_flag[1]))
})

test_that("protect_chiral_designations flags (dl)-alanine", {
  df <- tibble::tibble(chemical_name = c("(dl)-alanine"))
  result <- protect_chiral_designations(df, c("chemical_name"))

  expect_true(grepl("###CHIRAL_", result$cleaned_data$chemical_name[1]))
  expect_true(grepl("WARNING: chiral", result$cleaned_data$cleaning_flag[1]))
})

test_that("protect_chiral_designations does NOT flag acetone (no chiral marker)", {
  df <- tibble::tibble(chemical_name = c("acetone"))
  result <- protect_chiral_designations(df, c("chemical_name"))

  expect_equal(result$cleaned_data$chemical_name[1], "acetone")
  expect_true(is.na(result$cleaned_data$cleaning_flag[1]) ||
    !grepl("WARNING: chiral", result$cleaned_data$cleaning_flag[1]))
})

test_that("protect_chiral_designations handles NA values without error", {
  df <- tibble::tibble(chemical_name = c(NA_character_, "(R)-limonene", "acetone"))
  result <- protect_chiral_designations(df, c("chemical_name"))

  expect_type(result, "list")
  # NA should remain NA
  expect_true(is.na(result$cleaned_data$chemical_name[1]))
  # (R)-limonene should be flagged
  expect_true(grepl("WARNING: chiral", result$cleaned_data$cleaning_flag[2]))
})

test_that("protect_chiral_designations handles empty dataframe", {
  df <- tibble::tibble(chemical_name = character())
  result <- protect_chiral_designations(df, c("chemical_name"))

  expect_type(result, "list")
  expect_named(result, c("cleaned_data", "audit_trail"))
  expect_equal(nrow(result$cleaned_data), 0)
  expect_equal(nrow(result$audit_trail), 0)
})

test_that("protect_chiral_designations creates audit trail entry for flagged rows", {
  df <- tibble::tibble(chemical_name = c("(+)-catechin", "acetone"))
  result <- protect_chiral_designations(df, c("chemical_name"))

  expect_true(nrow(result$audit_trail) > 0)
  expect_true("protect_chiral_designations" %in% result$audit_trail$step)
})

test_that("protect_chiral_designations appends WARNING with separator when flag already exists", {
  df <- tibble::tibble(
    chemical_name = c("(+)-catechin"),
    cleaning_flag = c("BLOCK: something")
  )
  result <- protect_chiral_designations(df, c("chemical_name"))

  # Should contain both flags joined by "; "
  expect_true(grepl("BLOCK: something", result$cleaned_data$cleaning_flag[1]))
  expect_true(grepl("WARNING: chiral", result$cleaned_data$cleaning_flag[1]))
  expect_true(grepl(";", result$cleaned_data$cleaning_flag[1]))
})

# ==============================================================================
# Tests for expand_isotope_shortcodes()
# ==============================================================================

test_that("expand_isotope_shortcodes expands u234 to Uranium-234", {
  df <- tibble::tibble(chemical_name = c("u234"))
  result <- expand_isotope_shortcodes(df, c("chemical_name"))

  expect_type(result, "list")
  expect_named(result, c("cleaned_data", "audit_trail"))
  expect_equal(result$cleaned_data$chemical_name[1], "Uranium-234")
})

test_that("expand_isotope_shortcodes expands pb210 to Lead-210 (greedy match Pb before P)", {
  df <- tibble::tibble(chemical_name = c("pb210"))
  result <- expand_isotope_shortcodes(df, c("chemical_name"))

  expect_equal(result$cleaned_data$chemical_name[1], "Lead-210")
})

test_that("expand_isotope_shortcodes expands ra226 to Radium-226", {
  df <- tibble::tibble(chemical_name = c("ra226"))
  result <- expand_isotope_shortcodes(df, c("chemical_name"))

  expect_equal(result$cleaned_data$chemical_name[1], "Radium-226")
})

test_that("expand_isotope_shortcodes normalizes 'radium 226' to Radium-226 (spelled-out form)", {
  df <- tibble::tibble(chemical_name = c("radium 226"))
  result <- expand_isotope_shortcodes(df, c("chemical_name"))

  expect_equal(result$cleaned_data$chemical_name[1], "Radium-226")
})

test_that("expand_isotope_shortcodes normalizes 'strontium 90' to Strontium-90", {
  df <- tibble::tibble(chemical_name = c("strontium 90"))
  result <- expand_isotope_shortcodes(df, c("chemical_name"))

  expect_equal(result$cleaned_data$chemical_name[1], "Strontium-90")
})

test_that("expand_isotope_shortcodes normalizes 'cesium-137' to Caesium-137 (capitalize, ComptoxR IUPAC name)", {
  # Note: ComptoxR uses IUPAC name "Caesium" not American "Cesium"
  df <- tibble::tibble(chemical_name = c("cesium-137"))
  result <- expand_isotope_shortcodes(df, c("chemical_name"))

  expect_equal(result$cleaned_data$chemical_name[1], "Caesium-137")
})

test_that("expand_isotope_shortcodes normalizes 'iodine 131' to Iodine-131", {
  df <- tibble::tibble(chemical_name = c("iodine 131"))
  result <- expand_isotope_shortcodes(df, c("chemical_name"))

  expect_equal(result$cleaned_data$chemical_name[1], "Iodine-131")
})

test_that("expand_isotope_shortcodes does NOT expand C12H22O11 (carbon backbone exclusion, ISOT-03)", {
  df <- tibble::tibble(chemical_name = c("C12H22O11"))
  result <- expand_isotope_shortcodes(df, c("chemical_name"))

  expect_equal(result$cleaned_data$chemical_name[1], "C12H22O11")
})

test_that("expand_isotope_shortcodes does NOT expand d-glucose (deuterium d-prefix exclusion, ISOT-03)", {
  df <- tibble::tibble(chemical_name = c("d-glucose"))
  result <- expand_isotope_shortcodes(df, c("chemical_name"))

  expect_equal(result$cleaned_data$chemical_name[1], "d-glucose")
})

test_that("expand_isotope_shortcodes does NOT expand 14C-glucose (compound prefix, D-02)", {
  df <- tibble::tibble(chemical_name = c("14C-glucose"))
  result <- expand_isotope_shortcodes(df, c("chemical_name"))

  expect_equal(result$cleaned_data$chemical_name[1], "14C-glucose")
})

test_that("expand_isotope_shortcodes flags 'unat' as unresolvable WARNING", {
  df <- tibble::tibble(chemical_name = c("unat"))
  result <- expand_isotope_shortcodes(df, c("chemical_name"))

  # Value should remain unchanged
  expect_equal(result$cleaned_data$chemical_name[1], "unat")
  # Should be flagged
  expect_true(!is.na(result$cleaned_data$cleaning_flag[1]))
  expect_true(grepl("WARNING.*unresolvable|unresolvable.*unat", result$cleaned_data$cleaning_flag[1], ignore.case = TRUE))
})

test_that("expand_isotope_shortcodes leaves 'tritium' unchanged (already a common name)", {
  df <- tibble::tibble(chemical_name = c("tritium"))
  result <- expand_isotope_shortcodes(df, c("chemical_name"))

  expect_equal(result$cleaned_data$chemical_name[1], "tritium")
})

test_that("expand_isotope_shortcodes handles NA values without error", {
  df <- tibble::tibble(chemical_name = c(NA_character_, "u234", "acetone"))
  result <- expand_isotope_shortcodes(df, c("chemical_name"))

  expect_type(result, "list")
  expect_true(is.na(result$cleaned_data$chemical_name[1]))
  expect_equal(result$cleaned_data$chemical_name[2], "Uranium-234")
})

test_that("expand_isotope_shortcodes handles empty dataframe", {
  df <- tibble::tibble(chemical_name = character())
  result <- expand_isotope_shortcodes(df, c("chemical_name"))

  expect_type(result, "list")
  expect_named(result, c("cleaned_data", "audit_trail"))
  expect_equal(nrow(result$cleaned_data), 0)
  expect_equal(nrow(result$audit_trail), 0)
})

test_that("expand_isotope_shortcodes expands tokens within multi-analyte string pb206 + pb207 + pb208", {
  df <- tibble::tibble(chemical_name = c("pb206 + pb207 + pb208"))
  result <- expand_isotope_shortcodes(df, c("chemical_name"))

  expect_equal(result$cleaned_data$chemical_name[1], "Lead-206 + Lead-207 + Lead-208")
})

test_that("expand_isotope_shortcodes creates audit trail entry for expanded shortcodes", {
  df <- tibble::tibble(chemical_name = c("u234", "acetone"))
  result <- expand_isotope_shortcodes(df, c("chemical_name"))

  expect_true(nrow(result$audit_trail) >= 1)
  expect_true("expand_isotope_shortcodes" %in% result$audit_trail$step)
})

# ==============================================================================
# Tests for flag_multi_analyte()
# ==============================================================================

test_that("flag_multi_analyte flags 'nitrate + nitrite' with WARNING potential multi-analyte", {
  df <- tibble::tibble(chemical_name = c("nitrate + nitrite", "acetone"))
  result <- flag_multi_analyte(df, c("chemical_name"))

  expect_type(result, "list")
  expect_named(result, c("cleaned_data", "audit_trail"))

  # Value should be UNCHANGED
  expect_equal(result$cleaned_data$chemical_name[1], "nitrate + nitrite")
  # WARNING flag set
  expect_true(grepl("WARNING: potential multi-analyte", result$cleaned_data$cleaning_flag[1]))
  # acetone unchanged, no flag
  expect_equal(result$cleaned_data$chemical_name[2], "acetone")
  expect_true(is.na(result$cleaned_data$cleaning_flag[2]) ||
    !grepl("WARNING: potential multi-analyte", result$cleaned_data$cleaning_flag[2]))
})

test_that("flag_multi_analyte flags 'lead and arsenic'", {
  df <- tibble::tibble(chemical_name = c("lead and arsenic"))
  result <- flag_multi_analyte(df, c("chemical_name"))

  expect_equal(result$cleaned_data$chemical_name[1], "lead and arsenic")
  expect_true(grepl("WARNING: potential multi-analyte", result$cleaned_data$cleaning_flag[1]))
})

test_that("flag_multi_analyte flags 'pb206 + pb207 + pb208'", {
  df <- tibble::tibble(chemical_name = c("pb206 + pb207 + pb208"))
  result <- flag_multi_analyte(df, c("chemical_name"))

  expect_equal(result$cleaned_data$chemical_name[1], "pb206 + pb207 + pb208")
  expect_true(grepl("WARNING: potential multi-analyte", result$cleaned_data$cleaning_flag[1]))
})

test_that("flag_multi_analyte flags 'plutonium 239 and 240'", {
  df <- tibble::tibble(chemical_name = c("plutonium 239 and 240"))
  result <- flag_multi_analyte(df, c("chemical_name"))

  expect_equal(result$cleaned_data$chemical_name[1], "plutonium 239 and 240")
  expect_true(grepl("WARNING: potential multi-analyte", result$cleaned_data$cleaning_flag[1]))
})

test_that("flag_multi_analyte does NOT flag 'acetone' (no + or and)", {
  df <- tibble::tibble(chemical_name = c("acetone"))
  result <- flag_multi_analyte(df, c("chemical_name"))

  expect_equal(result$cleaned_data$chemical_name[1], "acetone")
  expect_true(is.na(result$cleaned_data$cleaning_flag[1]) ||
    !grepl("WARNING: potential multi-analyte", result$cleaned_data$cleaning_flag[1]))
})

test_that("flag_multi_analyte does NOT flag 'Sodium chloride' (no naked + or and)", {
  df <- tibble::tibble(chemical_name = c("Sodium chloride"))
  result <- flag_multi_analyte(df, c("chemical_name"))

  expect_equal(result$cleaned_data$chemical_name[1], "Sodium chloride")
  expect_true(is.na(result$cleaned_data$cleaning_flag[1]) ||
    !grepl("WARNING: potential multi-analyte", result$cleaned_data$cleaning_flag[1]))
})

test_that("flag_multi_analyte does NOT flag '(+)-catechin' (the + is inside parentheses, not naked)", {
  df <- tibble::tibble(chemical_name = c("(+)-catechin"))
  result <- flag_multi_analyte(df, c("chemical_name"))

  expect_equal(result$cleaned_data$chemical_name[1], "(+)-catechin")
  expect_true(is.na(result$cleaned_data$cleaning_flag[1]) ||
    !grepl("WARNING: potential multi-analyte", result$cleaned_data$cleaning_flag[1]))
})

test_that("flag_multi_analyte handles NA values without error", {
  df <- tibble::tibble(chemical_name = c(NA_character_, "nitrate + nitrite"))
  result <- flag_multi_analyte(df, c("chemical_name"))

  expect_type(result, "list")
  expect_true(is.na(result$cleaned_data$chemical_name[1]))
  expect_true(grepl("WARNING: potential multi-analyte", result$cleaned_data$cleaning_flag[2]))
})

test_that("flag_multi_analyte handles empty dataframe", {
  df <- tibble::tibble(chemical_name = character())
  result <- flag_multi_analyte(df, c("chemical_name"))

  expect_type(result, "list")
  expect_named(result, c("cleaned_data", "audit_trail"))
  expect_equal(nrow(result$cleaned_data), 0)
  expect_equal(nrow(result$audit_trail), 0)
})

test_that("flag_multi_analyte creates audit trail entry for each flagged row", {
  df <- tibble::tibble(chemical_name = c("nitrate + nitrite", "acetone"))
  result <- flag_multi_analyte(df, c("chemical_name"))

  expect_true(nrow(result$audit_trail) >= 1)
  expect_true("flag_multi_analyte" %in% result$audit_trail$step)
  # The value should be unchanged in audit trail (original == new)
  flagged_row <- result$audit_trail[result$audit_trail$step == "flag_multi_analyte", ]
  expect_true(nrow(flagged_row) > 0)
  expect_equal(flagged_row$original_value[1], flagged_row$new_value[1])
})
