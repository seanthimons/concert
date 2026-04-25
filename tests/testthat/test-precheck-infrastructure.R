# Test file for pre-check predicate infrastructure
# Tests for build_skip_result() and precheck_* functions -- Phase 37 SKIP-01/SKIP-02/SKIP-03
#
# Test structure per SKIP-03 requirement:
#   (a) Clean data -> should_run = FALSE
#   (b) Dirty data -> should_run = TRUE with correct est_changes
#   (c) SKIP-03 false-negative companion: prove the pre-check catches
#       every vector that the corresponding step would transform

# ==============================================================================
# build_skip_result tests (SKIP-02)
# ==============================================================================

test_that("build_skip_result returns empty typed audit and message", {
  df <- tibble::tibble(a = c("x", "y"))
  expect_message(result <- build_skip_result(df, "test_step"), "Step test_step skipped")
  expect_identical(result$cleaned_data, df)
  expect_equal(nrow(result$audit_trail), 0L)
  expect_named(result$audit_trail, c("row_id", "field", "step", "original_value", "new_value", "reason"))
  expect_type(result$audit_trail$row_id, "integer")
  expect_type(result$audit_trail$field, "character")
  expect_type(result$audit_trail$step, "character")
  expect_type(result$audit_trail$original_value, "character")
  expect_type(result$audit_trail$new_value, "character")
  expect_type(result$audit_trail$reason, "character")
})

test_that("build_skip_result message includes the step name", {
  df <- tibble::tibble(name = c("acetone"))
  expect_message(
    build_skip_result(df, "unicode_to_ascii"),
    "unicode_to_ascii"
  )
})

# ==============================================================================
# precheck_unicode_to_ascii tests
# ==============================================================================

# (a) Clean ASCII data -> should_run = FALSE
test_that("precheck_unicode_to_ascii returns FALSE for pure ASCII", {
  df <- tibble::tibble(name = c("acetone", "ethanol"), cas = c("67-64-1", "64-17-5"))
  result <- precheck_unicode_to_ascii(df)
  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)
})

# (b) Non-ASCII data -> should_run = TRUE with correct count
test_that("precheck_unicode_to_ascii returns TRUE for non-ASCII with correct est_changes", {
  df <- tibble::tibble(name = c("\u03B1-tocopherol", "ethanol"))
  result <- precheck_unicode_to_ascii(df)
  expect_true(result$should_run)
  expect_equal(result$est_changes, 1L)
})

# Edge: dataframe with no character columns
test_that("precheck_unicode_to_ascii returns FALSE for dataframe with no character columns", {
  df <- tibble::tibble(value = 1:5, other = 6:10)
  result <- precheck_unicode_to_ascii(df)
  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)
})

# (c) SKIP-03 false-negative companion: tricky non-ASCII that clean_unicode transforms
test_that("SKIP-03: precheck_unicode_to_ascii catches all vectors clean_unicode would change", {
  tricky <- c("2\u2032-deoxyadenosine", "\u03B2-carotene", "plain text")
  df <- tibble::tibble(name = tricky)
  precheck <- precheck_unicode_to_ascii(df)
  # Pre-check must say should_run for these values
  expect_true(precheck$should_run)
  expect_true(precheck$est_changes >= 2L)
  # Verify the step would indeed change these values
  cleaned <- ComptoxR::clean_unicode(tricky)
  expect_true(any(!is.na(tricky) & !is.na(cleaned) & tricky != cleaned))
})

# ==============================================================================
# precheck_trim_whitespace tests
# ==============================================================================

# (a) Clean data -> FALSE
test_that("precheck_trim_whitespace returns FALSE for already-clean data", {
  df <- tibble::tibble(name = c("acetone", "ethanol"), cas = c("67-64-1", "64-17-5"))
  result <- precheck_trim_whitespace(df)
  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)
})

# (b) Leading/trailing whitespace -> TRUE, est_changes reflects count
test_that("precheck_trim_whitespace returns TRUE for leading/trailing whitespace", {
  df <- tibble::tibble(name = c("  ethanol  ", "acetone"))
  result <- precheck_trim_whitespace(df)
  expect_true(result$should_run)
  expect_equal(result$est_changes, 1L)
})

# Edge: underscore/asterisk artifacts trigger detection
test_that("precheck_trim_whitespace detects leading asterisk artifacts", {
  df <- tibble::tibble(name = c("*starred*", "plain"))
  result <- precheck_trim_whitespace(df)
  expect_true(result$should_run)
  expect_equal(result$est_changes, 1L)
})

# (c) SKIP-03 false-negative companion: trailing space only
test_that("SKIP-03: precheck_trim_whitespace catches trailing-space-only strings", {
  df <- tibble::tibble(name = c("acetone ", "ethanol"))
  precheck <- precheck_trim_whitespace(df)
  # Pre-check must fire for trailing space
  expect_true(precheck$should_run)
  expect_equal(precheck$est_changes, 1L)
  # Verify clean_text_field would change it
  cleaned <- clean_text_field(df$name)
  expect_true(any(df$name != cleaned, na.rm = TRUE))
})

# ==============================================================================
# precheck_normalize_cas tests
# ==============================================================================

# (a) No CASRN columns in tag_map -> FALSE
test_that("precheck_normalize_cas returns FALSE when no CASRN columns in tag_map", {
  df <- tibble::tibble(name = c("acetone", "ethanol"))
  tag_map <- list(name = "Name")
  result <- precheck_normalize_cas(df, tag_map)
  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)
})

# (b) CASRN column with unformatted digit string -> TRUE
test_that("precheck_normalize_cas returns TRUE for unformatted pure-digit CAS", {
  df <- tibble::tibble(cas = c("67641", "64-17-5"))
  tag_map <- list(cas = "CASRN")
  result <- precheck_normalize_cas(df, tag_map)
  expect_true(result$should_run)
  expect_equal(result$est_changes, 1L)
})

# Placeholder text detection
test_that("precheck_normalize_cas detects placeholder CAS values", {
  df <- tibble::tibble(cas = c("no cas", "67-64-1", "n/a", "proprietary"))
  tag_map <- list(cas = "CASRN")
  result <- precheck_normalize_cas(df, tag_map)
  expect_true(result$should_run)
  expect_equal(result$est_changes, 3L)
})

# (c) SKIP-03 false-negative companion: leading-zero digit string
test_that("SKIP-03: precheck_normalize_cas catches leading-zero digit strings", {
  df <- tibble::tibble(cas = c("067641", "64-17-5"))
  tag_map <- list(cas = "CASRN")
  precheck <- precheck_normalize_cas(df, tag_map)
  # Leading-zero string is still all digits -- pre-check must fire
  expect_true(precheck$should_run)
  expect_equal(precheck$est_changes, 1L)
  # Verify ComptoxR would change it
  cleaned <- ComptoxR::as_cas("067641")
  expect_false(isTRUE(identical("067641", cleaned)))
})

# ==============================================================================
# precheck_name_cleaning tests
# ==============================================================================

# (a) No name_cols -> FALSE
test_that("precheck_name_cleaning returns FALSE when name_cols is empty", {
  df <- tibble::tibble(name = c("acetone", "ethanol"))
  result <- precheck_name_cleaning(df, character(0))
  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)
})

# (b) Non-empty name values -> TRUE
test_that("precheck_name_cleaning returns TRUE when name columns have non-empty values", {
  df <- tibble::tibble(name = c("acetone", "ethanol"))
  result <- precheck_name_cleaning(df, "name")
  expect_true(result$should_run)
  expect_equal(result$est_changes, 2L)
})

# All NA values -> FALSE
test_that("precheck_name_cleaning returns FALSE when all name values are NA", {
  df <- tibble::tibble(name = NA_character_)
  result <- precheck_name_cleaning(df, "name")
  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)
})

# (c) SKIP-03 false-negative companion: whitespace-only values are treated as empty
test_that("SKIP-03: precheck_name_cleaning whitespace-only strings count as empty", {
  df_ws <- tibble::tibble(name = c("   ", "  "))
  result_ws <- precheck_name_cleaning(df_ws, "name")
  # Whitespace-only trims to "" -- should not be considered candidates
  expect_false(result_ws$should_run)
  expect_equal(result_ws$est_changes, 0L)
  # But real values are correctly detected
  df_real <- tibble::tibble(name = c("acetone", "   "))
  result_real <- precheck_name_cleaning(df_real, "name")
  expect_true(result_real$should_run)
  expect_equal(result_real$est_changes, 1L)
})

# ==============================================================================
# precheck_isotope_shortcodes tests
# ==============================================================================

# Helper: minimal isotope lookup for testing
make_isotope_lookup <- function() {
  tibble::tibble(
    shortcode = c("u234", "Pb210", "C14"),
    full_name = c("Uranium-234", "Lead-210", "Carbon-14")
  )
}

# (a) No isotope_lookup -> FALSE
test_that("precheck_isotope_shortcodes returns FALSE when isotope_lookup is NULL", {
  df <- tibble::tibble(name = c("uranium compound", "lead compound"))
  result <- precheck_isotope_shortcodes(df, "name", NULL)
  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)
})

# Empty isotope_lookup -> FALSE
test_that("precheck_isotope_shortcodes returns FALSE when isotope_lookup is empty", {
  df <- tibble::tibble(name = c("u234 compound"))
  empty_lookup <- tibble::tibble(shortcode = character(0), full_name = character(0))
  result <- precheck_isotope_shortcodes(df, "name", empty_lookup)
  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)
})

# (b) Text containing known shortcode -> TRUE
test_that("precheck_isotope_shortcodes returns TRUE for text with shortcode match", {
  df <- tibble::tibble(name = c("u234 alpha decay", "normal compound"))
  result <- precheck_isotope_shortcodes(df, "name", make_isotope_lookup())
  expect_true(result$should_run)
  expect_equal(result$est_changes, 1L)
})

# (c) SKIP-03 false-negative companion: embedded shortcode must match via word boundary
test_that("SKIP-03: precheck_isotope_shortcodes uses word boundaries to avoid false negatives", {
  # "Pb210" shortcode embedded mid-word should NOT trigger (word-boundary protected)
  df_no_boundary <- tibble::tibble(name = c("compound_Pb210x"))
  result_no_boundary <- precheck_isotope_shortcodes(df_no_boundary, "name", make_isotope_lookup())
  # Expect no match because shortcode is not at a word boundary
  expect_false(result_no_boundary$should_run)

  # "Pb210" as a standalone token SHOULD trigger
  df_boundary <- tibble::tibble(name = c("Pb210 decay product"))
  result_boundary <- precheck_isotope_shortcodes(df_boundary, "name", make_isotope_lookup())
  expect_true(result_boundary$should_run)
  expect_equal(result_boundary$est_changes, 1L)
})

# ==============================================================================
# precheck_multi_analyte tests
# ==============================================================================

# (a) Simple names without separators -> FALSE
test_that("precheck_multi_analyte returns FALSE for simple chemical names", {
  df <- tibble::tibble(name = c("acetone", "ethanol", "benzene"))
  result <- precheck_multi_analyte(df, "name")
  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)
})

# (b) "acetone and ethanol" -> TRUE
test_that("precheck_multi_analyte returns TRUE for names with ' and ' separator", {
  df <- tibble::tibble(name = c("acetone and ethanol", "benzene"))
  result <- precheck_multi_analyte(df, "name")
  expect_true(result$should_run)
  expect_equal(result$est_changes, 1L)
})

# Ampersand and slash separators
test_that("precheck_multi_analyte detects ' & ' and ' / ' separators", {
  df <- tibble::tibble(name = c("acetone & ethanol", "toluene / benzene", "methanol"))
  result <- precheck_multi_analyte(df, "name")
  expect_true(result$should_run)
  expect_equal(result$est_changes, 2L)
})

# (c) SKIP-03 false-negative companion: "sand" contains "and" but NOT flanked by spaces
test_that("SKIP-03: precheck_multi_analyte does not trigger on 'and' inside a word", {
  df <- tibble::tibble(name = c("sand", "mandarin", "standard"))
  result <- precheck_multi_analyte(df, "name")
  # These should NOT trigger because 'and' is not flanked by whitespace on both sides
  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)

  # But whitespace-flanked 'and' DOES trigger
  df2 <- tibble::tibble(name = c("sand and water"))
  result2 <- precheck_multi_analyte(df2, "name")
  expect_true(result2$should_run)
})

# ==============================================================================
# precheck_chiral_restore tests
# ==============================================================================

# (a) No placeholders -> FALSE
test_that("precheck_chiral_restore returns FALSE when no chiral placeholders present", {
  df <- tibble::tibble(name = c("(R)-acetone", "S-limonene", "plain compound"))
  result <- precheck_chiral_restore(df, "name")
  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)
})

# (b) "###CHIRAL_PLUS### compound" -> TRUE
test_that("precheck_chiral_restore returns TRUE for chiral placeholder in values", {
  df <- tibble::tibble(name = c("###CHIRAL_PLUS### compound", "normal name"))
  result <- precheck_chiral_restore(df, "name")
  expect_true(result$should_run)
  expect_equal(result$est_changes, 1L)
})

# Multiple placeholders counted correctly
test_that("precheck_chiral_restore counts multiple placeholder rows correctly", {
  df <- tibble::tibble(name = c(
    "###CHIRAL_PLUS### methyl ester",
    "###CHIRAL_MINUS### compound",
    "plain"
  ))
  result <- precheck_chiral_restore(df, "name")
  expect_true(result$should_run)
  expect_equal(result$est_changes, 2L)
})

# (c) SKIP-03 false-negative companion: "###CHIRAL" without underscore should NOT match
test_that("SKIP-03: precheck_chiral_restore requires '###CHIRAL_' with underscore", {
  # "###CHIRAL" alone (no underscore) is not a valid placeholder
  df_no_underscore <- tibble::tibble(name = c("###CHIRAL something"))
  result_no <- precheck_chiral_restore(df_no_underscore, "name")
  # The pattern "###CHIRAL_" requires the underscore -- no match expected
  expect_false(result_no$should_run)
  expect_equal(result_no$est_changes, 0L)

  # "###CHIRAL_PLUS###" (with underscore) MUST match
  df_valid <- tibble::tibble(name = c("###CHIRAL_PLUS### compound"))
  result_valid <- precheck_chiral_restore(df_valid, "name")
  expect_true(result_valid$should_run)
  expect_equal(result_valid$est_changes, 1L)
})

# Empty name_cols guard
test_that("precheck_chiral_restore returns FALSE when name_cols is empty", {
  df <- tibble::tibble(name = c("###CHIRAL_PLUS### compound"))
  result <- precheck_chiral_restore(df, character(0))
  expect_false(result$should_run)
  expect_equal(result$est_changes, 0L)
})
