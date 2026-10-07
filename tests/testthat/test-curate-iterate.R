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
  cleaned_data$pubchem_query <- c(NA, "Chromium", NA)[seq_len(n)]
  cleaned_data$pubchem_cid_candidates <- c(NA, "23951", NA)[seq_len(n)]
  cleaned_data$pubchem_dtxsid_candidates <- c(NA, "23951:DTXSID1020322", NA)[seq_len(n)]
  cleaned_data$parent_name_candidate <- c(NA, "Chromium", NA)[seq_len(n)]
  cleaned_data$parent_dtxsid_candidates <- c(NA, "DTXSID1020322", NA)[seq_len(n)]
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
  expect_true(env$pubchem)
  expect_true(env$desalt)
  expect_equal(env$desalt_workflows, c("qsar-ready", "ms-ready"))
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
  expect_true(all(c("pubchem_query", "pubchem_cid_candidates", "pubchem_dtxsid_candidates",
                    "parent_name_candidate", "parent_dtxsid_candidates") %in% names(first$pending)))
  expect_equal(first$pending$pubchem_dtxsid_candidates, "23951:DTXSID1020322")
  expect_equal(first$pending$parent_dtxsid_candidates, "DTXSID1020322")
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

test_that("low_similarity_rows flags accepted matches whose preferred name drifts", {
  rs <- init_resolution_state(tibble::tibble(
    chemical_name = c("Total PFAS", "Lead", "COD", "TKN"),
    consensus_dtxsid = c("DTXSID1", "DTXSID2", "DTXSID3", "DTXSID4"),
    consensus_source = "chemical_name",
    consensus_status = c("single", "single", "single", "single"),
    preferredName_chemical_name = c("Total Furans", "Lead", "Total Oxygen Demand", "Nitrogen")
  ))
  rs$row_flag[4] <- "VERIFIED"
  state <- list(resolution_state = rs, merged_chemical_tags = list(chemical_name = "Name"))

  out <- low_similarity_rows(state)
  expect_setequal(out$name, c("Total PFAS", "COD"))
  expect_equal(out$preferred_name[out$name == "COD"], "Total Oxygen Demand")

  expect_equal(nrow(low_similarity_rows(list(resolution_state = rs[0, ], merged_chemical_tags = list()))), 0)
})

test_that("pending reopens contradictory verification with provenance and multi-analyte priority", {
  rs <- tibble::tibble(
    chemical_name = c("PFHxDA", "Unresolved", "Deferred", "Bad", "Carbon", "Known", "A + B"),
    original_row_id = c(9406L, 2:7),
    consensus_status = c("error", "suggested", "error", "error", "wqx", "manual", "error"),
    consensus_dtxsid = c(NA, "DTXSID1", NA, NA, NA, "DTXSID1", NA),
    consensus_name = c(NA, NA, NA, NA, "Carbon", NA, NA),
    consensus_source = NA_character_,
    row_flag = c("VERIFIED", "VERIFIED", "FOLLOW-UP", "BAD", "VERIFIED", "VERIFIED", "VERIFIED"),
    row_flag_reason = "Historical review",
    .pinned = TRUE,
    tied_dtxsids_chemical_name = c("DTXSID1070800; DTXSID701026646", rep(NA, 6)),
    cleaning_flag = c(rep(NA, 6), multi_analyte_warning_label())
  )
  state <- list(resolution_state = rs, merged_chemical_tags = list(chemical_name = "Name"))
  pending <- pending_rows(state)
  expect_equal(pending$row_index, c(9406L, 2L, 7L))
  expect_equal(pending$pending_type, c("verified_unresolved", "verified_unresolved", "multi_analyte"))
  expect_equal(pending$row_flag, rep("VERIFIED", 3))
  expect_equal(pending$row_flag_reason, rep("Historical review", 3))
  expect_equal(pending$tied_dtxsids[1], "DTXSID1070800; DTXSID701026646")
  expect_identical(names(pending), names(empty_pending()))
  expect_identical(state$resolution_state, rs)

  path <- tempfile(fileext = ".md")
  write_status_md(path, state, pending, FALSE, list(input_path = "fixture.csv"))
  status <- paste(readLines(path), collapse = "\n")
  expect_match(status, "done: FALSE", fixed = TRUE)
  expect_match(status, "VERIFIED rows with unresolved current identity: 3.", fixed = TRUE)
})

test_that("iterated review keeps stale VERIFIED ties pending until an explicit disposition", {
  fx <- iterate_fixture()
  local_mocked_bindings(
    run_curation_pipeline = function(cleaned_data, ...) {
      out <- mock_pipeline_result(cleaned_data)
      out$results$consensus_status[2] <- "error"
      out$results$consensus_dtxsid[2] <- NA_character_
      out$results$tied_dtxsids_chemical_name <- c(NA, "DTXSID1020322; DTXSID9999999", NA)
      out
    },
    postprocess_curation_candidates = mock_postprocess,
    validate_manual_dtxsids = mock_validate
  )
  decisions <- file.path(fx$dir, "decisions.R")
  base <- c(
    sprintf("input_path <- %s", deparse(fx$input_path)),
    'tag_map <- list(chemical_name = "Name", cas_number = "CASRN", result = "Result", unit = "Unit")',
    "header_row <- 1L",
    'row_flags <- tibble::tibble(name = "Chromium", flag = "VERIFIED", reason = "Historical review")'
  )
  writeLines(base, decisions)
  first <- curate_iterate(decisions, verbose = FALSE)
  expect_false(first$done)
  expect_equal(first$pending$pending_type, "verified_unresolved")
  expect_equal(first$pending$row_flag_reason, "Historical review")
  expect_match(paste(readLines(file.path(fx$dir, "replay.R")), collapse = "\n"), "VERIFIED", fixed = TRUE)
  replayed <- source(file.path(fx$dir, "replay.R"), local = new.env())$value
  expect_equal(replayed$data$row_flag[2], "VERIFIED")
  expect_equal(replayed$data$row_flag_reason[2], "Historical review")
  expect_true(is.na(replayed$data$consensus_dtxsid[2]))
  imported <- readxl::read_xlsx(file.path(fx$dir, "curated.xlsx"), sheet = "Curated Data")
  expect_true(imported$needs_review[2])
  expect_equal(imported$tied_dtxsids_chemical_name[2], "DTXSID1020322; DTXSID9999999")
  again <- curate_iterate(decisions, verbose = FALSE)
  expect_equal(again$pending, first$pending)

  writeLines(c(base, 'review_picks <- tibble::tibble(name = "Chromium", dtxsid = "DTXSID1020322")'), decisions)
  picked <- curate_iterate(decisions, verbose = FALSE)
  expect_true(picked$done)
  expect_equal(picked$state$resolution_state$consensus_dtxsid[2], "DTXSID1020322")
  expect_equal(picked$state$resolution_state$row_flag[2], "VERIFIED")

  writeLines(sub('flag = "VERIFIED"', 'flag = "FOLLOW-UP"', base, fixed = TRUE), decisions)
  deferred <- curate_iterate(decisions, verbose = FALSE)
  expect_true(deferred$done)
  expect_true(is.na(deferred$state$resolution_state$consensus_dtxsid[2]))
})

test_that("captured candidate work reopens iteration and exact acknowledgments survive replay", {
  fx <- iterate_fixture()
  discovered <- FALSE
  fail <- FALSE
  local_mocked_bindings(
    run_curation_pipeline = function(cleaned_data, ...) {
      if (fail) stop("fixture outage")
      out <- mock_pipeline_result(cleaned_data)
      rs <- out$results
      rs$consensus_status <- c("single", "single", "unresolvable")
      rs$consensus_dtxsid <- c("DTXSID8021482", "DTXSID1020322", NA)
      rs$dtxsid_chemical_name[3] <- NA_character_
      rs$resolver_dtxsid_candidate <- c(NA, NA, if (discovered) "DTXSID999" else NA_character_)
      rs$resolver_lookup_status <- c(NA, NA, if (discovered) "unverified" else "no_hit")
      out$results <- rs
      out
    }, postprocess_curation_candidates = mock_postprocess, validate_manual_dtxsids = mock_validate
  )
  decisions <- file.path(fx$dir, "decisions.R")
  writeLines(c(sprintf("input_path <- %s", deparse(fx$input_path)),
    "tag_map <- list(chemical_name = 'Name', cas_number = 'CASRN')",
    "row_flags <- data.frame(name='Lead', flag='FOLLOW-UP', reason='Deliberate unresolved disposition')"), decisions)
  first <- curate_iterate(decisions, verbose = FALSE)
  expect_true(first$queue_complete)
  expect_false(first$reconciliation_complete)
  evidence <- capture_review_state(first$state, "Lead", disposition = "no_hit", flag = "FOLLOW-UP")
  cat("\nreview_decision_evidence <- ", script_literal(evidence), "\n", file = decisions, append = TRUE)
  discovered <- TRUE
  unlink(list.files(file.path(fx$dir, "cache"), pattern = "^curation_", full.names = TRUE))
  second <- curate_iterate(decisions, verbose = FALSE)
  expect_false(second$done)
  expect_equal(second$pending$pending_type, "candidate_validation")
  expect_true(file.exists(file.path(fx$dir, "candidate_review.csv")))
  expect_true(file.exists(file.path(fx$dir, "identity_review.csv")))
  expect_identical(second$state$review_decision_evidence, evidence)
  rs <- second$state$resolution_state
  rows <- which(rs$chemical_name == "Lead")
  cols <- review_scope_columns(second$state)
  scope <- review_evidence_scope(second$state$review_automated_state, rows, cols)
  current <- review_evidence_snapshot(second$state$review_automated_state, rs, rows,
    second$state$candidate_validation, "source_dtxsid", cols)
  ack <- acknowledge_review_evidence(evidence, review_decision_key("Lead"), 1L, scope, current)
  cat("\nreview_decision_evidence <- ", script_literal(ack), "\n", file = decisions, append = TRUE)
  third <- curate_iterate(decisions, verbose = FALSE)
  expect_true(third$done)
  expect_true(third$reconciliation_complete)
  expect_false(third$identity_review_complete)
  expect_equal(third$state$resolution_state$row_flag[3], "FOLLOW-UP")
  env <- new.env(parent = globalenv())
  replay_result <- NULL
  suppressMessages(for (expr in parse(file.path(fx$dir, "replay.R"))) replay_result <- eval(expr, env))
  expect_identical(env$review_decision_evidence, ack)
  expect_equal(replay_result$data$row_flag[3], "FOLLOW-UP")
  path <- file.path(fx$dir, "curated.xlsx")
  restored <- hydrate_session_state(parse_concert_export(path))$state
  expect_identical(restored$review_decision_evidence, ack)

  fail <- TRUE
  unlink(list.files(file.path(fx$dir, "cache"), pattern = "^curation_", full.names = TRUE))
  expect_error(curate_iterate(decisions, verbose = FALSE), "fixture outage")
  expect_equal(nrow(readr::read_csv(file.path(fx$dir, "candidate_review.csv"), show_col_types = FALSE)), 0)
  expect_equal(nrow(readr::read_csv(file.path(fx$dir, "review_reconciliation.csv"), show_col_types = FALSE)), 0)
})
