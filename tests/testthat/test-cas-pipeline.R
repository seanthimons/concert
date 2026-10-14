# Test file for CAS pipeline functions
# Tests for CAS-RN normalization, validation, rescue from text, and multi-CAS detection

# Test data setup
test_df <- tibble::tibble(
  cas_number = c("67-64-1", "67641", "no cas", "n/a", "proprietary", "-", "67-64-2", "108-88-3"),
  chemical_name = c("Acetone", "Toluene", "acetone (67-64-1)", "ethanol 64-17-5", "Water", "NaCl", "Unknown", "Benzene"),
  description = c("solvent", "solvent", "common solvent", "alcohol", "universal", "salt", "mixture 71-43-2, 108-88-3", "aromatic")
)

test_tag_map <- list(cas_number = "CASRN", chemical_name = "Name", description = "Other")

# ==============================================================================
# inject_row_lineage
# ==============================================================================

test_that("inject_row_lineage adds original_row_id as first column", {
  df <- tibble::tibble(a = 1:3, b = c("x", "y", "z"))
  result <- inject_row_lineage(df)

  expect_equal(names(result)[1], "original_row_id")
  expect_equal(result$original_row_id, 1:3)
})

test_that("inject_row_lineage preserves all existing columns", {
  df <- tibble::tibble(a = 1:3, b = c("x", "y", "z"), c = 4:6)
  result <- inject_row_lineage(df)

  expect_equal(ncol(result), 4)  # original 3 + row_id
  expect_true(all(c("original_row_id", "a", "b", "c") %in% names(result)))
  expect_equal(result$a, df$a)
  expect_equal(result$b, df$b)
  expect_equal(result$c, df$c)
})

# ==============================================================================
# normalize_cas_fields
# ==============================================================================

test_that("normalize_cas_fields converts unformatted CAS to standard format", {
  df <- tibble::tibble(cas = c("67641", "108883"))
  tag_map <- list(cas = "CASRN")

  result <- normalize_cas_fields(df, tag_map)
  cleaned <- result$cleaned_data

  expect_equal(cleaned$cas[1], "67-64-1")
  expect_equal(cleaned$cas[2], "108-88-3")
})

test_that("normalize_cas_fields converts placeholder text to NA (CAS-01)", {
  df <- tibble::tibble(cas = c("no cas", "n/a", "proprietary", "-", "N/A", "NO CAS", "NOCAS_1355346"))
  tag_map <- list(cas = "CASRN")

  result <- normalize_cas_fields(df, tag_map)
  cleaned <- result$cleaned_data

  expect_true(all(is.na(cleaned$cas)))
  expect_true(is.na(as_cas("NOCAS_1355346")))
  expect_equal(as_cas("CAS: 7732-18-5"), "7732-18-5")
})

test_that("normalize_cas_fields sets invalid checksum CAS to NA (CAS-02)", {
  df <- tibble::tibble(cas = c("67-64-2", "108-88-4"))  # Invalid checksums
  tag_map <- list(cas = "CASRN")

  result <- normalize_cas_fields(df, tag_map)
  cleaned <- result$cleaned_data

  expect_true(is.na(cleaned$cas[1]))
  expect_true(is.na(cleaned$cas[2]))
})

test_that("normalize_cas_fields preserves valid CAS unchanged", {
  df <- tibble::tibble(cas = c("67-64-1", "108-88-3", "64-17-5"))
  tag_map <- list(cas = "CASRN")

  result <- normalize_cas_fields(df, tag_map)
  cleaned <- result$cleaned_data

  expect_equal(cleaned$cas[1], "67-64-1")
  expect_equal(cleaned$cas[2], "108-88-3")
  expect_equal(cleaned$cas[3], "64-17-5")
})

test_that("normalize_cas_fields preserves slash-delimited CAS in generated CASRN columns", {
  df <- tibble::tibble(cas = c("67-64-1/64-17-5", "108-88-3"))
  tag_map <- list(cas = "CASRN")

  result <- normalize_cas_fields(df, tag_map)
  cleaned <- result$cleaned_data

  expect_equal(cleaned$cas[1], "67-64-1")
  expect_true("cas_extract_cas_2" %in% names(cleaned))
  expect_equal(cleaned$cas_extract_cas_2[1], "64-17-5")
  expect_true(is.na(cleaned$cas_extract_cas_2[2]))
  expect_equal(result$new_tags$cas_extract_cas_2, "CASRN")
})

test_that("normalize_cas_fields returns audit trail with step='normalize_cas'", {
  df <- tibble::tibble(cas = c("67641", "no cas", "67-64-1"))
  tag_map <- list(cas = "CASRN")

  result <- normalize_cas_fields(df, tag_map)
  audit <- result$audit_trail

  expect_s3_class(audit, "tbl_df")
  expect_named(audit, c("row_id", "field", "step", "original_value", "new_value", "reason"))
  expect_true(all(audit$step == "normalize_cas"))
  expect_gt(nrow(audit), 0)  # Should have changes for rows 1 and 2
})

test_that("normalize_cas_fields skips gracefully when no CASRN columns", {
  df <- tibble::tibble(name = c("Acetone", "Ethanol"))
  tag_map <- list(name = "Name")  # No CASRN columns

  result <- normalize_cas_fields(df, tag_map)

  expect_equal(result$cleaned_data, df)
  expect_equal(nrow(result$audit_trail), 0)
})

# ==============================================================================
# rescue_cas_from_text
# ==============================================================================

test_that("rescue_cas_from_text extracts CAS to cas_extract_{col} column (CAS-03)", {
  df <- tibble::tibble(
    cas = c("67-64-1", NA_character_),
    name = c("acetone (67-64-1)", "ethanol 64-17-5")
  )
  tag_map <- list(cas = "CASRN", name = "Name")

  result <- rescue_cas_from_text(df, tag_map)
  cleaned <- result$cleaned_data

  expect_true("cas_extract_name" %in% names(cleaned))
  expect_equal(cleaned$cas_extract_name[1], "67-64-1")
  expect_equal(cleaned$cas_extract_name[2], "64-17-5")
})

test_that("rescue_cas_from_text strips CAS and parens from source text", {
  df <- tibble::tibble(
    cas = NA_character_,
    name = c("acetone (67-64-1)", "ethanol [64-17-5]")
  )
  tag_map <- list(cas = "CASRN", name = "Name")

  result <- rescue_cas_from_text(df, tag_map)
  cleaned <- result$cleaned_data

  expect_equal(cleaned$name[1], "acetone")
  expect_equal(cleaned$name[2], "ethanol")
})

test_that("rescue_cas_from_text returns new_tags mapping cas_extract_{col} to CASRN", {
  df <- tibble::tibble(
    cas = NA_character_,
    name = c("acetone (67-64-1)", "water")
  )
  tag_map <- list(cas = "CASRN", name = "Name")

  result <- rescue_cas_from_text(df, tag_map)

  expect_type(result$new_tags, "list")
  expect_true("cas_extract_name" %in% names(result$new_tags))
  expect_equal(result$new_tags$cas_extract_name, "CASRN")
})

test_that("rescue_cas_from_text skips columns already tagged as CASRN", {
  df <- tibble::tibble(
    cas = c("67-64-1", "108-88-3"),
    name = c("acetone", "toluene")
  )
  tag_map <- list(cas = "CASRN", name = "Name")

  result <- rescue_cas_from_text(df, tag_map)
  cleaned <- result$cleaned_data

  # Should not try to extract from cas column
  expect_false("cas_extract_cas" %in% names(cleaned))
})

test_that("rescue_cas_from_text returns empty result when no CAS found", {
  df <- tibble::tibble(
    cas = NA_character_,
    name = c("water", "sodium chloride")
  )
  tag_map <- list(cas = "CASRN", name = "Name")

  result <- rescue_cas_from_text(df, tag_map)
  cleaned <- result$cleaned_data

  expect_equal(ncol(cleaned), ncol(df))  # No new columns
  expect_equal(length(result$new_tags), 0)  # No new tags
  expect_equal(nrow(result$audit_trail), 0)  # No changes
})

# ==============================================================================
# detect_multi_cas
# ==============================================================================

test_that("detect_multi_cas flags rows with >1 CAS as multi_cas=TRUE (CAS-04)", {
  df <- tibble::tibble(
    cas = c("67-64-1", "108-88-3", NA_character_),
    cas_extract_name = c(NA_character_, "64-17-5", NA_character_)
  )
  tag_map <- list(cas = "CASRN", cas_extract_name = "CASRN")

  result <- detect_multi_cas(df, tag_map)

  expect_true("multi_cas" %in% names(result))
  expect_true("multi_cas_count" %in% names(result))
  expect_false(result$multi_cas[1])  # Only 1 CAS
  expect_true(result$multi_cas[2])   # 2 CAS values
  expect_false(result$multi_cas[3])  # 0 CAS values
})

test_that("detect_multi_cas sets multi_cas_count to actual count", {
  df <- tibble::tibble(
    cas1 = c("67-64-1", NA_character_, "108-88-3"),
    cas2 = c("64-17-5", NA_character_, NA_character_),
    cas3 = c(NA_character_, NA_character_, "71-43-2")
  )
  tag_map <- list(cas1 = "CASRN", cas2 = "CASRN", cas3 = "CASRN")

  result <- detect_multi_cas(df, tag_map)

  expect_equal(result$multi_cas_count[1], 2)  # Row 1: 2 CAS
  expect_equal(result$multi_cas_count[2], 0)  # Row 2: 0 CAS
  expect_equal(result$multi_cas_count[3], 2)  # Row 3: 2 CAS
})

test_that("detect_multi_cas sets rows with 0-1 CAS to multi_cas=FALSE", {
  df <- tibble::tibble(
    cas = c("67-64-1", NA_character_, NA_character_)
  )
  tag_map <- list(cas = "CASRN")

  result <- detect_multi_cas(df, tag_map)

  expect_false(result$multi_cas[1])  # 1 CAS
  expect_false(result$multi_cas[2])  # 0 CAS
  expect_false(result$multi_cas[3])  # 0 CAS
  expect_equal(result$multi_cas_count[1], 1)
  expect_equal(result$multi_cas_count[2], 0)
  expect_equal(result$multi_cas_count[3], 0)
})

test_that("run_cleaning_pipeline flags slash-delimited CAS as multi-CAS", {
  df <- tibble::tibble(
    cas_number = "67-64-1/64-17-5",
    chemical_name = "acetone"
  )
  tag_map <- list(cas_number = "CASRN", chemical_name = "Name")

  result <- run_cleaning_pipeline(df, tag_map)
  cleaned <- result$cleaned_data

  expect_equal(cleaned$cas_number[1], "67-64-1")
  expect_true("cas_extract_cas_number_2" %in% names(cleaned))
  expect_equal(cleaned$cas_extract_cas_number_2[1], "64-17-5")
  expect_true(cleaned$multi_cas[1])
  expect_equal(cleaned$multi_cas_count[1], 2)
  expect_equal(result$new_tags$cas_extract_cas_number_2, "CASRN")
})

# ==============================================================================
# run_cleaning_pipeline integration
# ==============================================================================

test_that("run_cleaning_pipeline with tag_map runs CAS steps in order", {
  df <- tibble::tibble(
    cas_number = c("67641", "no cas"),
    chemical_name = c("acetone", "ethanol 64-17-5")
  )
  tag_map <- list(cas_number = "CASRN", chemical_name = "Name")

  result <- run_cleaning_pipeline(df, tag_map)
  cleaned <- result$cleaned_data

  # Should have original_row_id from inject_row_lineage
  expect_true("original_row_id" %in% names(cleaned))

  # CAS should be normalized
  expect_equal(cleaned$cas_number[1], "67-64-1")
  expect_true(is.na(cleaned$cas_number[2]))

  # Should have extracted CAS from name
  expect_true("cas_extract_chemical_name" %in% names(cleaned))
  expect_equal(cleaned$cas_extract_chemical_name[2], "64-17-5")

  # Should have multi_cas flags
  expect_true("multi_cas" %in% names(cleaned))
  expect_true("multi_cas_count" %in% names(cleaned))
})

test_that("run_cleaning_pipeline without tag_map runs only basic cleaning", {
  df <- tibble::tibble(
    cas_number = c("  67641  ", "  no cas  "),
    chemical_name = c("  acetone  ", "  ethanol  ")
  )

  result <- run_cleaning_pipeline(df)  # No tag_map
  cleaned <- result$cleaned_data

  # Should have row_id
  expect_true("original_row_id" %in% names(cleaned))

  # Should have basic text cleaning (trimming)
  expect_equal(cleaned$cas_number[1], "67641")  # Trimmed but NOT normalized
  expect_equal(cleaned$chemical_name[1], "acetone")

  # Should NOT have CAS-specific columns
  expect_false("cas_extract_chemical_name" %in% names(cleaned))
  expect_false("multi_cas" %in% names(cleaned))
})

test_that("run_cleaning_pipeline returns combined audit trail from all steps", {
  df <- tibble::tibble(
    cas_number = c("  67641  ", "no cas"),
    chemical_name = c("acetone (67-64-1)", "  ethanol  ")
  )
  tag_map <- list(cas_number = "CASRN", chemical_name = "Name")

  result <- run_cleaning_pipeline(df, tag_map)
  audit <- result$audit_trail

  # Should have entries from multiple steps
  steps <- unique(audit$step)
  expect_true("trim_whitespace_punctuation" %in% steps)
  expect_true("normalize_cas" %in% steps)
  expect_true("rescue_cas" %in% steps)
})

test_that("run_cleaning_pipeline returns new_tags from rescue step", {
  df <- tibble::tibble(
    cas_number = NA_character_,
    chemical_name = c("acetone (67-64-1)", "ethanol")
  )
  tag_map <- list(cas_number = "CASRN", chemical_name = "Name")

  result <- run_cleaning_pipeline(df, tag_map)

  expect_type(result$new_tags, "list")
  expect_true("cas_extract_chemical_name" %in% names(result$new_tags))
  expect_equal(result$new_tags$cas_extract_chemical_name, "CASRN")
})

# ==============================================================================
# Spreadsheet date coercion (#35)
# ==============================================================================

test_that("repair_cas_date_coercion restores Google Sheets date shapes and leaves real CAS alone", {
  x <- c("0103-02-06", "19303-09-04", "10-13-2009", "4175-03-05", "9/2/1975", "0103-02-07", "67-64-1", "50-00-0", NA)
  fix <- repair_cas_date_coercion(x)

  expect_equal(fix$flagged, c(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE))
  expect_equal(fix$repair, c("103-02-6", "19303-09-4", "10-13-9", "4175-03-5", NA, NA, NA, NA, NA))
})

test_that("normalize_cas_fields repairs date-coerced CAS before as_cas() can mangle them", {
  # as_cas("4175-03-05") is the checksum-valid but wrong 41750-30-5
  expect_equal(as_cas("4175-03-05"), "41750-30-5")

  df <- tibble::tibble(cas = c("4175-03-05", "0103-02-06", "9/2/1975", "67-64-1"))
  result <- normalize_cas_fields(df, list(cas = "CASRN"))

  expect_equal(result$cleaned_data$cas, c("4175-03-5", "103-02-6", NA, "67-64-1"))
  audit <- result$audit_trail
  expect_equal(audit$step, rep("repair_cas_dates", 3))
  expect_equal(audit$original_value, c("4175-03-05", "0103-02-06", "9/2/1975"))
  expect_match(audit$reason[3], "cannot be recovered")
})

test_that("precheck_normalize_cas reports date-coerced cells for the pre-flight warning", {
  df <- tibble::tibble(cas = c("67-64-1", "0103-02-06", "9/2/1975"))
  pc <- precheck_normalize_cas(df, list(cas = "CASRN"))

  expect_equal(pc$date_coerced$row, c(2L, 3L))
  expect_equal(pc$date_coerced$repair, c("103-02-6", NA))
  html <- as.character(cas_date_warning(pc$date_coerced))
  expect_match(html, "Row 2, cas: 0103-02-06 -&gt; 103-02-6", fixed = TRUE)
  expect_match(html, "NA (unrecoverable)", fixed = TRUE)
  expect_null(cas_date_warning(pc$date_coerced[0, ]))
})

test_that("read_excel_robust renders xlsx date cells in text columns as ISO dates", {
  skip_if_not_installed("writexl")
  path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(path))
  # Without the fix the date cells come back as serials ("27639") under the
  # text header row. writexl can't write pre-1900 dates, so use 75-09-2.
  writexl::write_xlsx(
    data.frame(cas = as.POSIXct("1975-09-02", tz = "UTC"), name = "dichloromethane"),
    path
  )
  df <- read_excel_robust(path)

  expect_equal(df$V1, c("cas", "1975-09-02"))
  expect_equal(repair_cas_date_coercion(df$V1)$repair[2], "75-09-2")
})
