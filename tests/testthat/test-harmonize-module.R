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
  cache_dir <- system.file("extdata", "reference_cache", package = "concert")
  skip_if(cache_dir == "", message = "concert not installed as package")
  skip_if_not(exists("load_corrections"),
              message = "load_corrections not exported from installed concert package")
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

# --- Shiny harmonization dispatch regression tests ---

make_dispatch_unit_map <- function() {
  tibble::tibble(
    from_unit = c("mg/L", "ug/L"),
    to_unit = c("mg/L", "mg/L"),
    multiplier = c(1, 0.001),
    category = c("concentration", "concentration"),
    confidence = c("HIGH", "HIGH"),
    source = c("test", "test")
  )
}

make_dispatch_media_map <- function() {
  tibble::tibble(
    term = c("surface water", "tissue"),
    canonical = c("surface water", "tissue"),
    canonical_term = c("surface water", "tissue"),
    envo_id = c("ENVO:00002042", "ENVO:01001434"),
    parent = NA_character_,
    media_category = c("aqueous", "solid"),
    source = "concert",
    assertion_mode = "auto",
    confidence = "high",
    active = TRUE
  )
}

make_dispatch_store <- function() {
  input_df <- tibble::tibble(
    chemical_name = c("A", "B", "C"),
    casrn = c("111-11-1", "222-22-2", "333-33-3"),
    result = c("1", "2", "3"),
    unit = c("ug/L", "mg/L", "ug/L"),
    media = c("surface_water", "surface_water", "fish_tissue"),
    consensus_dtxsid = c("DTXSID0000001", "DTXSID0000002", "DTXSID0000003")
  )
  unit_map <- make_dispatch_unit_map()
  media_map <- make_dispatch_media_map()
  corrections <- tibble::tibble(pattern = character(), replacement = character())

  shiny::reactiveValues(
    clean = input_df,
    cleaned_data = input_df,
    file_info = list(name = "dispatch.csv"),
    numeric_tags = list(result = "Result", unit = "Unit"),
    study_type_tags = list(media = "Media"),
    reference_lists = list(
      unit_map = unit_map,
      corrections = corrections,
      media_map = media_map
    ),
    unit_map_working = unit_map,
    corrections_working = corrections,
    media_map_working = media_map,
    resolution_state = input_df,
    harmonize_results = NULL,
    harmonize_audit = NULL,
    media_results = NULL,
    duration_results = NULL,
    date_results = NULL,
    detection_results = NULL,
    toxval_output = NULL,
    harmonize_results_stale = FALSE,
    changed_units = character(0),
    harmonize_step_mask = NULL,
    harmonize_run_nonce = 0L
  )
}

rendered_ui_text <- function(ui) {
  paste(htmltools::renderTags(ui)$html, collapse = "\n")
}

test_that("harmonize_run_nonce dispatch populates media results and canonical row counts", {
  data_store <- make_dispatch_store()

  shiny::testServer(mod_harmonize_server, args = list(data_store = data_store), {
    session$flushReact()

    data_store$harmonize_step_mask <- list(units = FALSE, duration = FALSE, dates = FALSE, media = TRUE)
    data_store$harmonize_run_nonce <- data_store$harmonize_run_nonce + 1L
    session$flushReact()

    expect_false(is.null(data_store$media_results))
    expect_equal(data_store$media_results$canonical_media[1:2], c("surface water", "surface water"))

    rows <- concert:::build_media_editor_rows(data_store$media_map_working, data_store$media_results)
    surface <- rows[rows$term == "surface water", ]
    expect_equal(nrow(surface), 1L)
    expect_equal(surface$hit_count, 2L)
    expect_null(data_store$harmonize_step_mask)
  })
})

test_that("harmonize_run_nonce dispatch populates unit results and leaves pre-run panel state", {
  data_store <- make_dispatch_store()

  shiny::testServer(mod_harmonize_server, args = list(data_store = data_store), {
    session$flushReact()

    before <- rendered_ui_text(output$unmatched_panel)
    expect_match(before, "Run harmonization to see unmatched units", fixed = TRUE)

    data_store$harmonize_step_mask <- list(units = TRUE, duration = FALSE, dates = FALSE, media = FALSE)
    data_store$harmonize_run_nonce <- data_store$harmonize_run_nonce + 1L
    session$flushReact()

    expect_false(is.null(data_store$harmonize_results))
    expect_equal(data_store$harmonize_results$harmonized$harmonized_unit, rep("mg/L", 3))

    after <- rendered_ui_text(output$unmatched_panel)
    expect_false(grepl("Run harmonization to see unmatched units", after, fixed = TRUE))
    expect_match(after, "All units matched successfully", fixed = TRUE)
    expect_null(data_store$harmonize_step_mask)
  })
})

test_that("manual harmonization run defaults all steps after masked request clears stale mask", {
  data_store <- make_dispatch_store()

  shiny::testServer(mod_harmonize_server, args = list(data_store = data_store), {
    session$flushReact()

    data_store$harmonize_step_mask <- list(units = TRUE, duration = FALSE, dates = FALSE, media = FALSE)
    data_store$harmonize_run_nonce <- data_store$harmonize_run_nonce + 1L
    session$flushReact()

    expect_false(is.null(data_store$harmonize_results))
    expect_null(data_store$media_results)
    expect_null(data_store$harmonize_step_mask)

    session$setInputs(run_harmonization = 1)
    session$flushReact()

    expect_false(is.null(data_store$media_results))
    expect_equal(data_store$media_results$canonical_media[1], "surface water")
  })
})
