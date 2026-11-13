# curate_headless(cache_dir = ) reuses the post-search state (#148).

cache_fixture <- function() {
  dir <- withr::local_tempdir(.local_envir = parent.frame())
  input_path <- file.path(dir, "inventory.csv")
  readr::write_csv(
    tibble::tibble(
      chemical_name = c("Acetone", "Chromium", "Lead"),
      cas_number = c("67-64-1", NA, "7439-92-1"),
      result = c("1", "2", "3"),
      unit = c("mg/L", "mg/L", "mg/L")
    ),
    input_path
  )
  list(dir = dir, input_path = input_path, cache_dir = file.path(dir, "cache"))
}

cache_pipeline_result <- function(cleaned_data, ...) {
  cleaned_data$dtxsid_chemical_name <- c("DTXSID8021482", "DTXSID1020322", "DTXSID6024161")
  cleaned_data$preferredName_chemical_name <- c("Acetone", "Chromium", "Lead")
  cleaned_data$source_tier_chemical_name <- "exact"
  cleaned_data$dtxsid_cas_number <- c("DTXSID8021482", "DTXSID9999999", NA)
  cleaned_data$preferredName_cas_number <- c("Acetone", "Chromium(VI)", NA)
  cleaned_data$source_tier_cas_number <- "cas"
  cleaned_data$consensus_status <- c("agree", "disagree", "single")
  cleaned_data$consensus_dtxsid <- c("DTXSID8021482", NA, "DTXSID6024161")
  cleaned_data$consensus_source <- c("chemical_name", NA, "chemical_name")
  cleaned_data$consensus_name <- NA_character_
  cleaned_data$qc_tier <- 1L
  list(
    results = init_resolution_state(cleaned_data),
    consensus_summary = list(n_agree = 1, n_disagree = 1, n_agree_caveat = 0, n_single = 1, n_error = 0)
  )
}

# Stands in for the CompTox detail fetch: one row per uncached DTXSID.
cache_enrich <- function(dtxsids, existing_cache = NULL, ...) {
  new <- setdiff(unique(dtxsids), existing_cache$dtxsid)
  fresh <- tibble::tibble(
    dtxsid = new,
    casrn = paste0("CAS-", new),
    molecular_formula = "X",
    molecular_weight = 1
  )
  list(cache = dplyr::bind_rows(existing_cache, fresh), failed_dtxsids = character(0))
}

cache_postprocess <- function(resolution_state, column_tags, dtxsid_cols = NULL, enrichment_cache = NULL) {
  ids <- collect_candidate_dtxsids(resolution_state, dtxsid_cols)
  empty_postprocess_result(resolution_state, cache_enrich(ids, enrichment_cache)$cache, character(0))
}

cache_validate <- function(dtxsids, ...) {
  tibble::tibble(searchValue = dtxsids, dtxsid = dtxsids, preferredName = "Picked", rank = 1L, is_valid = TRUE)
}

read_workbook <- function(path) {
  names <- readxl::excel_sheets(path)
  sheets <- stats::setNames(lapply(names, function(s) readxl::read_excel(path, sheet = s)), names)
  config <- sheets[["Pipeline Config"]]
  sheets[["Pipeline Config"]] <- config[config$key != "export_timestamp", ]
  sheets
}

test_that("a review-only rerun reuses the search and matches a from-scratch run", {
  fx <- cache_fixture()
  calls <- 0L
  local_mocked_bindings(
    run_curation_pipeline = function(cleaned_data, ...) {
      calls <<- calls + 1L
      cache_pipeline_result(cleaned_data)
    },
    postprocess_curation_candidates = cache_postprocess,
    enrich_candidates = cache_enrich,
    validate_manual_dtxsids = cache_validate
  )
  run <- function(out, ...) {
    curate_headless(
      input_path = fx$input_path,
      output_path = file.path(fx$dir, out),
      tag_map = list(chemical_name = "Name", cas_number = "CASRN", result = "Result", unit = "Unit"),
      header_row = 1L,
      ...
    )
  }
  # DTXSID1020807 is a pick that no search returned.
  picks <- tibble::tibble(name = "Chromium", casrn = NA, dtxsid = "DTXSID1020807")
  flags <- tibble::tibble(name = "Lead", flag = "FOLLOW-UP", reason = "check")

  expect_message(run("first.xlsx", cache_dir = fx$cache_dir, postprocess_candidates = TRUE), "searching afresh")
  expect_equal(calls, 1L)
  expect_message(
    rerun <- run("rerun.xlsx", cache_dir = fx$cache_dir, postprocess_candidates = TRUE, review_picks = picks,
      row_flags = flags),
    "Reusing cached curation search"
  )
  expect_equal(calls, 1L)

  scratch <- suppressMessages(run("scratch.xlsx", postprocess_candidates = TRUE, review_picks = picks, row_flags = flags))
  expect_equal(calls, 2L)
  expect_equal(rerun, scratch)
  rerun_book <- read_workbook(file.path(fx$dir, "rerun.xlsx"))
  expect_equal(rerun_book, read_workbook(file.path(fx$dir, "scratch.xlsx")))
  curated <- rerun_book[["Curated Data"]]
  expect_equal(curated$consensus_dtxsid[curated$chemical_name == "Chromium"], "DTXSID1020807")
  expect_equal(curated$consensus_casrn[curated$chemical_name == "Chromium"], "CAS-DTXSID1020807")

  # A cache filled with postprocessing must not leak into a run without it.
  plain <- suppressMessages(run("plain.xlsx", cache_dir = fx$cache_dir, postprocess_candidates = FALSE))
  expect_equal(calls, 2L)
  expect_true(all(is.na(read_workbook(file.path(fx$dir, "plain.xlsx"))[["Curated Data"]]$consensus_casrn)))
})

test_that("upstream changes and refresh_cache repeat the search", {
  fx <- cache_fixture()
  calls <- 0L
  local_mocked_bindings(run_curation_pipeline = function(cleaned_data, ...) {
    calls <<- calls + 1L
    cache_pipeline_result(cleaned_data)
  })
  tags <- list(chemical_name = "Name", cas_number = "CASRN", result = "Result", unit = "Unit")
  run <- function(tag_map = tags, ...) {
    curate_headless(fx$input_path, NULL, tag_map, header_row = 1L, write_files = FALSE, verbose = FALSE,
      cache_dir = fx$cache_dir, ...)
  }
  run()
  run()
  expect_equal(calls, 1L)

  run(wqx_threshold = 0.9)
  expect_equal(calls, 2L)
  run(tag_map = modifyList(tags, list(cas_number = "Other")))
  expect_equal(calls, 3L)
  run(refresh_cache = TRUE)
  expect_equal(calls, 4L)

  # A non-chemical cell is part of the cached rows, so it invalidates too.
  input <- readr::read_csv(fx$input_path, col_types = "cccc")
  input$result[1] <- "9"
  readr::write_csv(input, fx$input_path)
  out <- run()
  expect_equal(calls, 5L)
  expect_equal(out$data$result[1], "9")
})
