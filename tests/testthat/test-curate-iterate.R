iterate_fixture <- function() {
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
  list(dir = dir, input_path = input_path)
}

mock_pipeline_result <- function(cleaned_data, ...) {
  n <- nrow(cleaned_data)
  cleaned_data$dtxsid_chemical_name <- c("DTXSID8021482", "DTXSID1020322", "DTXSID6024161")[seq_len(n)]
  cleaned_data$preferredName_chemical_name <- c("Acetone", "Chromium", "Lead")[seq_len(n)]
  cleaned_data$source_tier_chemical_name <- "exact"
  cleaned_data$dtxsid_cas_number <- c("DTXSID8021482", "DTXSID9999999", NA)[seq_len(n)]
  cleaned_data$preferredName_cas_number <- c("Acetone", "Chromium(VI)", NA)[seq_len(n)]
  cleaned_data$source_tier_cas_number <- "cas"
  cleaned_data$consensus_status <- c("agree", "disagree", "single")[seq_len(n)]
  cleaned_data$consensus_dtxsid <- c("DTXSID8021482", NA, "DTXSID6024161")[seq_len(n)]
  cleaned_data$consensus_source <- c("chemical_name", NA, "chemical_name")[seq_len(n)]
  cleaned_data$consensus_name <- NA_character_
  cleaned_data$qc_tier <- 1L
  list(
    results = init_resolution_state(cleaned_data),
    consensus_summary = list(n_agree = 1, n_disagree = 1, n_agree_caveat = 0, n_single = 1, n_error = 0)
  )
}

mock_postprocess <- function(resolution_state, ...) {
  empty_postprocess_result(resolution_state, NULL, character(0))
}

mock_validate <- function(dtxsids, ...) {
  tibble::tibble(
    searchValue = dtxsids,
    dtxsid = dtxsids,
    preferredName = "Chromium",
    rank = 1L,
    is_valid = grepl("^DTXSID", dtxsids)
  )
}

test_that("curate_decisions_template writes a sourceable decisions file with suggestions", {
  fx <- iterate_fixture()
  path <- curate_decisions_template(fx$input_path, fx$dir)

  expect_true(file.exists(path))
  env <- new.env()
  sys.source(path, envir = env)
  expect_equal(env$header_row, 1L)
  expect_equal(env$tag_map$chemical_name, "Name")
  expect_equal(env$tag_map$cas_number, "CASRN")
  expect_true(env$accept_suggestions)
  expect_true(is.list(env$reference_list_snapshot))
  expect_match(paste(readLines(path), collapse = "\n"), "# review_picks <- tibble::tibble", fixed = TRUE)
})

test_that("curate_iterate loops from pending to done and reuses the search cache", {
  fx <- iterate_fixture()
  calls <- 0L
  local_mocked_bindings(
    run_curation_pipeline = function(cleaned_data, ...) {
      calls <<- calls + 1L
      mock_pipeline_result(cleaned_data)
    },
    postprocess_curation_candidates = mock_postprocess,
    validate_manual_dtxsids = mock_validate
  )

  decisions <- file.path(fx$dir, "decisions.R")
  writeLines(
    c(
      sprintf("input_path <- %s", deparse(fx$input_path)),
      "tag_map <- list(chemical_name = \"Name\", cas_number = \"CASRN\", result = \"Result\", unit = \"Unit\")",
      "header_row <- 1L"
    ),
    decisions
  )

  first <- curate_iterate(decisions, verbose = FALSE)
  expect_false(first$done)
  expect_equal(first$pending$pending_type, "disagree")
  expect_equal(first$pending$name, "Chromium")
  expect_match(first$pending$candidates, "DTXSID1020322 | Chromium | Exact match", fixed = TRUE)
  expect_equal(calls, 1L)
  expect_true(file.exists(file.path(fx$dir, "pending.csv")))
  expect_match(paste(readLines(file.path(fx$dir, "status.md")), collapse = "\n"), "done: FALSE", fixed = TRUE)
  expect_match(paste(readLines(file.path(fx$dir, "replay.R")), collapse = "\n"), "curate_headless(", fixed = TRUE)
  expect_length(list.files(file.path(fx$dir, "cache"), pattern = "^curation_"), 1L)

  cat(
    "review_picks <- tibble::tibble(name = \"Chromium\", casrn = NA, dtxsid = \"DTXSID1020322\")\n",
    file = decisions,
    append = TRUE
  )
  second <- curate_iterate(decisions, verbose = FALSE)
  expect_true(second$done)
  expect_equal(nrow(second$pending), 0)
  expect_equal(calls, 1L)
  rs <- second$state$resolution_state
  expect_equal(rs$consensus_status[rs$chemical_name == "Chromium"], "manual")
  expect_equal(rs$consensus_dtxsid[rs$chemical_name == "Chromium"], "DTXSID1020322")
  expect_true(file.exists(file.path(fx$dir, "curated.xlsx")))

  replay <- paste(readLines(file.path(fx$dir, "replay.R")), collapse = "\n")
  expect_match(replay, "review_picks <- ", fixed = TRUE)
  expect_match(replay, "review_picks = review_picks", fixed = TRUE)
})

test_that("curate_iterate reports unmatched picks and clears pending via row_flags", {
  fx <- iterate_fixture()
  local_mocked_bindings(
    run_curation_pipeline = mock_pipeline_result,
    postprocess_curation_candidates = mock_postprocess,
    validate_manual_dtxsids = mock_validate
  )

  decisions <- file.path(fx$dir, "decisions.R")
  writeLines(
    c(
      sprintf("input_path <- %s", deparse(fx$input_path)),
      "tag_map <- list(chemical_name = \"Name\", cas_number = \"CASRN\")",
      "review_picks <- tibble::tibble(name = \"Not here\", casrn = NA, dtxsid = \"DTXSID1020322\")",
      "row_flags <- tibble::tibble(name = \"Chromium\", casrn = NA, flag = \"FOLLOW-UP\", reason = \"needs chemist\")"
    ),
    decisions
  )

  result <- curate_iterate(decisions, verbose = FALSE)
  expect_true(result$done)
  expect_equal(result$state$unmatched_decisions, "review_picks: name=Not here casrn=NA")
  status <- paste(readLines(file.path(fx$dir, "status.md")), collapse = "\n")
  expect_match(status, "Unmatched decisions", fixed = TRUE)
  rs <- result$state$resolution_state
  expect_equal(rs$row_flag[rs$chemical_name == "Chromium"], "FOLLOW-UP")
})

test_that("stage_review rejects unknown DTXSIDs", {
  fx <- iterate_fixture()
  local_mocked_bindings(
    run_curation_pipeline = mock_pipeline_result,
    validate_manual_dtxsids = mock_validate
  )
  state <- stage_ingest(fx$input_path, tag_map = list(chemical_name = "Name", cas_number = "CASRN"))
  state <- suppressMessages(stage_clean(state))
  state <- suppressMessages(stage_curate(state))
  expect_error(
    suppressMessages(stage_review(state, review_picks = tibble::tibble(name = "Chromium", dtxsid = "bogus"))),
    "does not know: bogus"
  )
})

test_that("curate_iterate writes an error status when a stage fails", {
  fx <- iterate_fixture()
  decisions <- file.path(fx$dir, "decisions.R")
  writeLines(
    c(
      sprintf("input_path <- %s", deparse(fx$input_path)),
      "tag_map <- list(missing_column = \"Name\")"
    ),
    decisions
  )

  expect_error(curate_iterate(decisions, verbose = FALSE), "not found after normalization")
  status <- paste(readLines(file.path(fx$dir, "status.md")), collapse = "\n")
  expect_match(status, "## Error", fixed = TRUE)
  expect_match(status, "done: FALSE", fixed = TRUE)
})
