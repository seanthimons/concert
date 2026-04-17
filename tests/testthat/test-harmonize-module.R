# Test harmonize module helper functions
# Tests for apply_corrections, add_passthrough_mapping, and QC metric computation
#
# Note: apply_corrections and add_passthrough_mapping are internal helpers defined
# inside mod_harmonize_server's moduleServer closure. These tests replicate the
# exact logic (mirroring R/mod_harmonize.R lines 109-141) so the contract can be
# tested without Shiny module plumbing.

# --- apply_corrections logic tests ---

test_that("apply_corrections applies pattern replacements correctly", {
  # Replicate apply_corrections logic from R/mod_harmonize.R
  apply_corrections_test <- function(values, corrections_tbl) {
    if (is.null(corrections_tbl) || nrow(corrections_tbl) == 0) return(values)
    result <- values
    for (i in seq_len(nrow(corrections_tbl))) {
      tryCatch(
        result <- gsub(corrections_tbl$pattern[i], corrections_tbl$replacement[i], result),
        error = function(e) {
          warning(sprintf("Correction pattern '%s' failed: %s",
                          corrections_tbl$pattern[i], e$message))
        }
      )
    }
    result
  }

  corrections <- tibble::tibble(
    pattern = c("1\\.5E 3", "N\\.D\\."),
    replacement = c("1.5E3", "NA")
  )

  values <- c("1.5E 3", "0.5", "N.D.", "1.5E 3 mg")
  result <- apply_corrections_test(values, corrections)

  expect_equal(result[1], "1.5E3")
  expect_equal(result[2], "0.5")
  expect_equal(result[3], "NA")
  expect_equal(result[4], "1.5E3 mg")
})

test_that("apply_corrections returns values unchanged with empty corrections", {
  apply_corrections_test <- function(values, corrections_tbl) {
    if (is.null(corrections_tbl) || nrow(corrections_tbl) == 0) return(values)
    result <- values
    for (i in seq_len(nrow(corrections_tbl))) {
      tryCatch(
        result <- gsub(corrections_tbl$pattern[i], corrections_tbl$replacement[i], result),
        error = function(e) {
          warning(sprintf("Correction pattern '%s' failed: %s",
                          corrections_tbl$pattern[i], e$message))
        }
      )
    }
    result
  }

  values <- c("1.5", "2.0", "N/A")
  empty_tbl <- tibble::tibble(pattern = character(), replacement = character())

  expect_equal(apply_corrections_test(values, empty_tbl), values)
  expect_equal(apply_corrections_test(values, NULL), values)
})

test_that("apply_corrections skips bad regex patterns without crashing", {
  apply_corrections_test <- function(values, corrections_tbl) {
    if (is.null(corrections_tbl) || nrow(corrections_tbl) == 0) return(values)
    result <- values
    for (i in seq_len(nrow(corrections_tbl))) {
      tryCatch(
        result <- gsub(corrections_tbl$pattern[i], corrections_tbl$replacement[i], result),
        error = function(e) {
          warning(sprintf("Correction pattern '%s' failed: %s",
                          corrections_tbl$pattern[i], e$message))
        }
      )
    }
    result
  }

  corrections <- tibble::tibble(
    pattern = c("[invalid(", "good_pattern"),
    replacement = c("x", "replaced")
  )

  values <- c("good_pattern", "other")
  # Should not error, should skip bad pattern and apply good one
  expect_warning(
    result <- apply_corrections_test(values, corrections),
    "failed"
  )
  expect_equal(result[1], "replaced")
  expect_equal(result[2], "other")
})

# --- add_passthrough_mapping logic tests ---

test_that("add_passthrough_mapping creates correct identity mapping", {
  base_map <- tibble::tibble(
    from_unit = "mg/L",
    to_unit = "mg/L",
    multiplier = 1,
    category = "mass_concentration",
    confidence = "HIGH",
    source = "ECOTOX"
  )

  result <- dplyr::bind_rows(base_map, tibble::tibble(
    from_unit   = "NTU",
    to_unit     = "NTU",
    multiplier  = 1,
    category    = "dimensionless",
    confidence  = "LOW",
    source      = "user_passthrough"
  ))

  expect_equal(nrow(result), 2)
  new_row <- result[result$from_unit == "NTU", ]
  expect_equal(new_row$to_unit, "NTU")
  expect_equal(new_row$multiplier, 1)
  expect_equal(new_row$category, "dimensionless")
  expect_equal(new_row$confidence, "LOW")
  expect_equal(new_row$source, "user_passthrough")
})

# --- QC metric computation logic tests ---

test_that("QC metrics compute correctly from known pipeline output", {
  parsed <- tibble::tibble(
    orig_row_id = 1:5,
    orig_result = c("1.5", "2.0", "N/A", "3.5", "bad"),
    numeric_value = c(1.5, 2.0, NA, 3.5, NA),
    qualifier = rep("", 5),
    range_bin = rep("as_is", 5),
    parse_flag = c("", "", "non_numeric", "", "non_numeric")
  )

  harmonized <- tibble::tibble(
    orig_row_id = 1:5,
    orig_unit = c("mg/L", "ug/L", "mg/L", "ppb", "NTU"),
    harmonized_value = c(1.5, 0.002, NA, 0.0035, NA),
    harmonized_unit = c("mg/L", "mg/L", "mg/L", "mg/L", "NTU"),
    conversion_factor = c(1, 0.001, 1, 0.001, 1),
    unit_flag = c("", "", "", "", "unmatched")
  )

  input_data <- tibble::tibble(
    result = c("1.5", "2.0", "N/A", "3.5", "bad"),
    consensus_dtxsid = c("DTXSID123", "DTXSID456", NA, "DTXSID789", NA)
  )

  hr <- list(parsed = parsed, harmonized = harmonized, input_data = input_data)

  n_parsed     <- nrow(hr$parsed)
  n_harmonized <- sum(hr$harmonized$unit_flag != "unmatched", na.rm = TRUE)
  n_dtxsid     <- sum(!is.na(hr$input_data$consensus_dtxsid))
  n_na_numeric <- sum(is.na(hr$parsed$numeric_value))

  expect_equal(n_parsed, 5)
  expect_equal(n_harmonized, 4)
  expect_equal(n_dtxsid, 3)
  expect_equal(n_na_numeric, 2)
})

test_that("QC metric handles missing consensus_dtxsid column", {
  input_data <- tibble::tibble(result = c("1.0", "2.0"))
  # No consensus_dtxsid column
  n_dtxsid <- if ("consensus_dtxsid" %in% names(input_data)) {
    sum(!is.na(input_data$consensus_dtxsid))
  } else {
    0L
  }
  expect_equal(n_dtxsid, 0L)
})

# --- load_corrections integration test ---

test_that("load_corrections returns correct tibble structure", {
  cache_dir <- system.file("extdata", "reference_cache", package = "chemreg")
  skip_if(cache_dir == "", message = "chemreg not installed as package")
  skip_if_not(exists("load_corrections"),
              message = "load_corrections not exported from installed chemreg package")
  result <- load_corrections(cache_dir)
  expect_s3_class(result, "tbl_df")
  expect_equal(names(result), c("pattern", "replacement"))
})

# --- Incremental merge regression tests (orig_row_id lineage) ---

test_that("incremental merge preserves orig_row_id (mutable-column-only)", {
  # Simulate existing harmonized results with lineage-tracking orig_row_id
  old_harmonize <- tibble::tibble(
    orig_row_id = c(10L, 20L, 30L, 40L, 50L),
    orig_unit = c("mg/L", "ug/L", "mg/L", "ppb", "NTU"),
    harmonized_value = c(1.5, 2.0, 3.0, 4.0, 5.0),
    harmonized_unit = c("mg/L", "mg/L", "mg/L", "mg/L", "NTU"),
    conversion_factor = c(1, 0.001, 1, 0.001, 1),
    unit_flag = c("", "", "", "", "unmatched")
  )

  # Simulate harmonize_units() output for affected rows — returns orig_row_id = 1:n

  affected_mask <- c(FALSE, TRUE, FALSE, TRUE, TRUE)
  incremental_result <- tibble::tibble(
    orig_row_id = 1:3, # BUG: harmonize_units always returns 1:n
    orig_unit = c("ug/L", "ppb", "NTU"),
    harmonized_value = c(0.002, 0.004, 5.0),
    harmonized_unit = c("mg/L", "mg/L", "NTU"),
    conversion_factor = c(0.001, 0.001, 1),
    unit_flag = c("", "", "passthrough")
  )

  # Apply the FIXED mutable-column-only merge
  new_harmonize <- old_harmonize
  mutable_cols <- c("harmonized_value", "harmonized_unit", "conversion_factor", "unit_flag")
  new_harmonize[affected_mask, mutable_cols] <- incremental_result[, mutable_cols]

  # orig_row_id MUST be unchanged — this is the lineage contract
  expect_identical(new_harmonize$orig_row_id, old_harmonize$orig_row_id)
  # orig_unit MUST also be unchanged
  expect_identical(new_harmonize$orig_unit, old_harmonize$orig_unit)
})

test_that("incremental merge only changes mutable columns for affected rows", {
  old_harmonize <- tibble::tibble(
    orig_row_id = c(10L, 20L, 30L),
    orig_unit = c("mg/L", "ug/L", "mg/L"),
    harmonized_value = c(1.5, 2.0, 3.0),
    harmonized_unit = c("mg/L", "mg/L", "mg/L"),
    conversion_factor = c(1, 0.001, 1),
    unit_flag = c("", "", "")
  )

  affected_mask <- c(FALSE, TRUE, FALSE)
  incremental_result <- tibble::tibble(
    orig_row_id = 1L,
    orig_unit = "ug/L",
    harmonized_value = 0.005,
    harmonized_unit = "mg/L",
    conversion_factor = 0.001,
    unit_flag = "converted"
  )

  new_harmonize <- old_harmonize
  mutable_cols <- c("harmonized_value", "harmonized_unit", "conversion_factor", "unit_flag")
  new_harmonize[affected_mask, mutable_cols] <- incremental_result[, mutable_cols]

  # Unaffected rows (1 and 3) must be identical
  expect_identical(new_harmonize[1, ], old_harmonize[1, ])
  expect_identical(new_harmonize[3, ], old_harmonize[3, ])

  # Affected row (2) has updated mutable cols but preserved identity cols
  expect_equal(new_harmonize$orig_row_id[2], 20L)
  expect_equal(new_harmonize$orig_unit[2], "ug/L")
  expect_equal(new_harmonize$harmonized_value[2], 0.005)
  expect_equal(new_harmonize$unit_flag[2], "converted")
})
