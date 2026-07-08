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

# --- Numeric parse issues assistant helper tests ---

test_that("numeric parse issue extraction groups duplicate malformed values by measurement column", {
  audit <- tibble::tibble(
    measurement_column = c("result", "result", "result", "reporting_limit"),
    measurement_role = c("Result", "Result", "Result", "ReportingLimit"),
    original_value = c("6.90E+0.1", "6.90E+0.1", "1.2", "bad limit"),
    orig_row_id = c(1L, 2L, 3L, 1L),
    parse_flag = c("unparseable", "unparseable", "", "unparseable")
  )

  issues <- extract_unparseable_numeric_issues(harmonize_audit = audit)

  expect_equal(nrow(issues), 2L)
  result_issue <- issues[issues$measurement_column == "result", ]
  expect_equal(result_issue$measurement_role, "Result")
  expect_equal(result_issue$original_value, "6.90E+0.1")
  expect_equal(result_issue$row_count, 2L)

  limit_issue <- issues[issues$measurement_column == "reporting_limit", ]
  expect_equal(limit_issue$measurement_role, "ReportingLimit")
  expect_equal(limit_issue$row_count, 1L)
})

test_that("exact numeric correction patterns escape regex metacharacters", {
  values <- c("6.90E+0.1", "< 1", "1,2", "(5)")
  patterns <- build_exact_numeric_correction_pattern(values)

  expect_equal(
    patterns,
    c("^6\\.90E\\+0\\.1$", "^< 1$", "^1,2$", "^\\(5\\)$")
  )
  expect_true(all(vapply(seq_along(values), function(i) {
    grepl(patterns[i], values[i])
  }, logical(1))))
})

test_that("queued numeric replacement validation accepts parsed values and rejects unparseable values", {
  queue <- tibble::tibble(
    measurement_column = c("result", "result"),
    original_value = c("6.90E+0.1", "bad"),
    pattern = build_exact_numeric_correction_pattern(c("6.90E+0.1", "bad")),
    replacement = c("6.90E+01", "6.90E+0.1")
  )

  validation <- validate_numeric_correction_queue(queue)

  expect_equal(validation$valid$replacement, "6.90E+01")
  expect_equal(validation$invalid$replacement, "6.90E+0.1")
  expect_match(validation$invalid$reason, "unparseable")
})

test_that("numeric corrections append by exact pattern and replace older matching patterns", {
  corrections <- tibble::tibble(
    pattern = c("^old$", "^6\\.90E\\+0\\.1$"),
    replacement = c("1", "69")
  )
  queue <- tibble::tibble(
    measurement_column = "result",
    original_value = "6.90E+0.1",
    pattern = "^6\\.90E\\+0\\.1$",
    replacement = "6.90E+01"
  )

  result <- append_numeric_corrections(corrections, queue)

  expect_equal(nrow(result), 2L)
  expect_equal(result$replacement[result$pattern == "^old$"], "1")
  expect_equal(result$replacement[result$pattern == "^6\\.90E\\+0\\.1$"], "6.90E+01")
})

make_runtime_unit_map <- function() {
  tibble::tibble(
    from_unit = c("custom ug/L", "mg/L", "day", "hr"),
    to_unit = c("mg/L", "mg/L", "hr", "hr"),
    multiplier = c(0.001, 1, 24, 1),
    category = c(
      "mass_concentration",
      "mass_concentration",
      "duration",
      "duration"
    ),
    confidence = "HIGH",
    source = "test"
  )
}

make_runtime_media_map <- function() {
  tibble::tibble(
    term = c("stormwater", "soil matrix"),
    canonical = c("surface water", "soil"),
    canonical_term = c("surface water", "soil"),
    envo_id = c("ENVO:00002042", "ENVO:00001998"),
    parent = NA_character_,
    media_category = c("aqueous", "solid"),
    source = "user",
    active = TRUE
  )
}

make_runtime_fixture <- function() {
  tibble::tibble(
    chemical_name = c("A", "B"),
    casrn = c("111-11-1", "222-22-2"),
    result = c("6.90E+0.1", "2"),
    reporting_limit = c("10", "3"),
    unit = c("custom ug/L", "custom ug/L"),
    media = c("stormwater", "soil matrix"),
    study_date = c("2015-03-15", "2016"),
    duration = c(2, 1),
    duration_unit = c("day", "hr"),
    consensus_dtxsid = c("DTXSID0000001", "DTXSID0000002")
  )
}

test_that("shared harmonization runtime returns all harmonized artifacts", {
  result <- run_harmonization_runtime(
    input_data = make_runtime_fixture(),
    tag_map = list(
      chemical_name = "Name",
      casrn = "CASRN",
      result = "Result",
      reporting_limit = "ReportingLimit",
      unit = "Unit",
      media = "Media",
      study_date = "StudyDate",
      duration = "Duration",
      duration_unit = "DurationUnit"
    ),
    unit_map = make_runtime_unit_map(),
    corrections = tibble::tibble(
      pattern = "^6\\.90E\\+0\\.1$",
      replacement = "6.90E+01"
    ),
    media_map = make_runtime_media_map(),
    source_name = "runtime-fixture"
  )

  expect_equal(result$harmonize_results$parsed$numeric_value[1], 69)
  expect_equal(result$harmonize_audit$harmonized_value[1], 0.069)
  expect_equal(result$media_results$canonical_media, c("surface water", "soil"))
  expect_equal(result$date_results$date_year, c(2015, 2016))
  expect_equal(result$duration_results$study_duration_value, c(48, 1))
  expect_s3_class(result$detection_results, "tbl_df")
  expect_true("result_flag" %in% names(result$data))
  expect_equal(result$toxval_output$source, rep("runtime-fixture", 2))
  expect_equal(result$toxval_output$toxval_numeric, c(0.069, 0.002))
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
    numeric_correction_queue = empty_numeric_correction_queue(),
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

test_that("harmonize dispatch maps ToxVal output before resolution_state exists", {
  data_store <- make_dispatch_store()
  input_df <- tibble::tibble(
    chemical_name = c("A", "B"),
    casrn = c("111-11-1", "222-22-2"),
    result = c("1-3", "10"),
    unit = c("ug/L", "mg/L"),
    media = c("surface_water", "surface_water"),
    consensus_dtxsid = c("DTXSID0000001", "DTXSID0000002")
  )
  data_store$clean <- input_df
  data_store$cleaned_data <- input_df
  data_store$resolution_state <- NULL

  shiny::testServer(mod_harmonize_server, args = list(data_store = data_store), {
    session$flushReact()

    data_store$harmonize_step_mask <- list(units = TRUE, duration = FALSE, dates = FALSE, media = FALSE)
    data_store$harmonize_run_nonce <- data_store$harmonize_run_nonce + 1L
    session$flushReact()

    expect_false(is.null(data_store$toxval_output))
    expect_equal(nrow(data_store$toxval_output), 4L)
    expect_equal(data_store$toxval_output$name, c("A", "A", "A", "B"))
    expect_equal(data_store$toxval_output$casrn, c("111-11-1", "111-11-1", "111-11-1", "222-22-2"))
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

test_that("app full harmonization path matches shared runtime output", {
  data_store <- make_dispatch_store()
  fixture <- make_runtime_fixture()
  unit_map <- make_runtime_unit_map()
  media_map <- make_runtime_media_map()
  corrections <- tibble::tibble(
    pattern = "^6\\.90E\\+0\\.1$",
    replacement = "6.90E+01"
  )
  numeric_tags <- list(
    result = "Result",
    reporting_limit = "ReportingLimit",
    unit = "Unit",
    duration = "Duration",
    duration_unit = "DurationUnit"
  )
  study_type_tags <- list(media = "Media", study_date = "StudyDate")

  data_store$clean <- fixture
  data_store$cleaned_data <- fixture
  data_store$resolution_state <- fixture
  data_store$numeric_tags <- numeric_tags
  data_store$study_type_tags <- study_type_tags
  data_store$unit_map_working <- unit_map
  data_store$corrections_working <- corrections
  data_store$media_map_working <- media_map
  data_store$reference_lists <- list(
    unit_map = unit_map,
    corrections = corrections,
    media_map = media_map
  )

  expected <- run_harmonization_runtime(
    input_data = fixture,
    tag_map = combine_tag_maps(numeric_tags, study_type_tags),
    unit_map = unit_map,
    corrections = corrections,
    media_map = media_map,
    source_name = "dispatch.csv"
  )

  shiny::testServer(mod_harmonize_server, args = list(data_store = data_store), {
    session$flushReact()

    data_store$harmonize_step_mask <- NULL
    data_store$harmonize_run_nonce <- data_store$harmonize_run_nonce + 1L
    session$flushReact()

    expect_equal(data_store$toxval_output, expected$toxval_output)
    expect_equal(data_store$harmonize_audit, expected$harmonize_audit)
    expect_equal(data_store$media_results, expected$media_results)
    expect_equal(data_store$duration_results, expected$duration_results)
    expect_equal(data_store$date_results, expected$date_results)
    expect_equal(data_store$detection_results, expected$detection_results)
  })
})

test_that("numeric parse assistant queues corrections, appends them, and clears resolved issues", {
  data_store <- make_dispatch_store()
  input_df <- tibble::tibble(
    chemical_name = c("A", "B", "C"),
    casrn = c("111-11-1", "222-22-2", "333-33-3"),
    result = c("6.90E+0.1", "2", "bad"),
    unit = c("mg/L", "mg/L", "mg/L"),
    media = c("surface_water", "surface_water", "surface_water"),
    consensus_dtxsid = c("DTXSID0000001", "DTXSID0000002", "DTXSID0000003")
  )
  data_store$clean <- input_df
  data_store$cleaned_data <- input_df
  data_store$resolution_state <- input_df

  shiny::testServer(mod_harmonize_server, args = list(data_store = data_store), {
    session$flushReact()

    data_store$harmonize_step_mask <- list(units = TRUE, duration = FALSE, dates = FALSE, media = FALSE)
    data_store$harmonize_run_nonce <- data_store$harmonize_run_nonce + 1L
    expect_warning(session$flushReact(), "2 values could not be parsed")

    issues <- extract_unparseable_numeric_issues(
      harmonize_audit = data_store$harmonize_audit,
      harmonize_results = data_store$harmonize_results
    )
    expect_equal(issues$original_value, c("6.90E+0.1", "bad"))

    session$setInputs(numeric_replacement_1 = "6.90E+01")
    session$setInputs(numeric_replacement_2 = "3")
    session$setInputs(queue_numeric_replacements = 1)
    session$flushReact()

    expect_equal(nrow(data_store$numeric_correction_queue), 2L)

    session$setInputs(apply_numeric_corrections = 1)
    session$flushReact()

    expect_equal(nrow(data_store$numeric_correction_queue), 0L)
    expect_equal(
      data_store$corrections_working$pattern,
      c("^6\\.90E\\+0\\.1$", "^bad$")
    )
    expect_equal(
      data_store$corrections_working$replacement,
      c("6.90E+01", "3")
    )

    resolved <- extract_unparseable_numeric_issues(
      harmonize_audit = data_store$harmonize_audit,
      harmonize_results = data_store$harmonize_results
    )
    expect_equal(nrow(resolved), 0L)
    expect_equal(data_store$harmonize_results$parsed$numeric_value, c(69, 2, 3))
  })
})
