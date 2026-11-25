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

mock_enrich <- function(dtxsids, existing_cache = NULL, ...) {
  list(cache = existing_cache, failed_dtxsids = character(0))
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
    enrich_candidates = mock_enrich,
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
  expect_length(list.files(file.path(fx$dir, "cache"), pattern = "^curation_", recursive = TRUE), 1L)

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
    enrich_candidates = mock_enrich,
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
    "invalid, ambiguous or unavailable: bogus"
  )
})

test_that("review_picks takes a WQX name and narrows by an input column", {
  dir <- withr::local_tempdir()
  input <- file.path(dir, "in.csv")
  readr::write_csv(tibble::tibble(chemical_name = c("Chromium", "Chromium", "Lead"),
    site = c("a", "b", "a")), input)
  local_mocked_bindings(run_curation_pipeline = mock_pipeline_result, validate_manual_dtxsids = mock_validate)
  state <- stage_ingest(input, tag_map = list(chemical_name = "Name"))
  state <- suppressMessages(stage_curate(suppressMessages(stage_clean(state))))
  review <- function(...) suppressMessages(stage_review(state, ...))
  dictionary <- load_wqx_dictionary(resolve_curation_reference_cache_dir())
  alias <- dictionary[dictionary$type != "canonical" & dictionary$name != dictionary$canonical_name, ][1, ]

  # Unscoped: every row with the name. An alias becomes its canonical name.
  rs <- review(review_picks = tibble::tibble(name = "Chromium", wqx_name = alias$name))$resolution_state
  expect_equal(rs$consensus_name[1:2], rep(alias$canonical_name, 2))
  expect_equal(rs$consensus_status, c("wqx", "wqx", "single"))
  expect_equal(rs$.resolution_method[1:2], rep("manual_wqx", 2))
  expect_true(all(is.na(rs$consensus_dtxsid[1:2])))
  expect_true(all(reviewed_wqx_rows(rs)[1:2]))

  # Scoped: only the row from site b; the flag only the row from site a.
  out <- review(
    review_picks = tibble::tibble(name = "Chromium", site = "b", wqx_name = "pH"),
    row_flags = tibble::tibble(name = "Chromium", site = "a", flag = "FOLLOW-UP")
  )
  rs <- out$resolution_state
  expect_equal(rs$consensus_status, c("agree", "wqx", "single"))
  expect_equal(rs$consensus_name[2], "pH")
  expect_equal(rs$row_flag, c("FOLLOW-UP", NA, NA))
  expect_length(out$unmatched_decisions, 0)
  expect_equal(
    review(review_picks = tibble::tibble(name = "Chromium", site = "z", wqx_name = "pH"))$unmatched_decisions,
    "review_picks: name=Chromium casrn=NA site=z"
  )

  # A narrowed flag is captured under its own id and then settles.
  expect_true(out$review_reconciliation$actionable)
  evidence <- capture_review_state(out, "Chromium", disposition = "no_hit", flag = "FOLLOW-UP", scope = list(site = "a"))
  settled <- review(row_flags = tibble::tibble(name = "Chromium", site = "a", flag = "FOLLOW-UP"),
    review_decision_evidence = evidence)$review_reconciliation
  expect_equal(settled$decision_id, review_decision_key("Chromium", scope = list(site = "a")))
  expect_false(settled$actionable)

  expect_error(review(review_picks = tibble::tibble(name = "Chromium", wqx_name = "Not a characteristic")),
    "not a WQX characteristic: Not a characteristic")
  expect_error(review(review_picks = tibble::tibble(name = "Chromium", dtxsid = "DTXSID1020322", wqx_name = "pH")),
    "exactly one of dtxsid or wqx_name")
  expect_error(review(review_picks = tibble::tibble(name = "Chromium", dtxsid = NA, wqx_name = NA)),
    "exactly one of dtxsid or wqx_name")
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

test_that("low_similarity_rows reads the unsuffixed Name column's preferred name (#134)", {
  rs <- init_resolution_state(tibble::tibble(
    chemical_name = c("Total PFAS", "Lead"),
    consensus_dtxsid = c("DTXSID1", "DTXSID2"),
    consensus_source = c("Name", "dtxsid"),
    consensus_status = "single",
    preferredName = c("Total Furans", "Lead")
  ))
  state <- list(resolution_state = rs, merged_chemical_tags = list(chemical_name = "Name"))
  expect_equal(low_similarity_rows(state)$name, "Total PFAS")
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
    enrich_candidates = mock_enrich,
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
  expect_true("Chromium,VERIFIED,Historical review" %in% readLines(file.path(fx$dir, "replay.R")))
  expect_message(
    replayed <- source(file.path(fx$dir, "replay.R"), local = new.env())$value,
    "1 VERIFIED rows have no current identity"
  )
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
    }, postprocess_curation_candidates = mock_postprocess, enrich_candidates = mock_enrich, validate_manual_dtxsids = mock_validate
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
  unlink(list.files(file.path(fx$dir, "cache"), pattern = "^curation_", recursive = TRUE, full.names = TRUE))
  second <- curate_iterate(decisions, verbose = FALSE)
  expect_false(second$done)
  expect_equal(second$pending$pending_type, "candidate_validation")
  expect_true(file.exists(file.path(fx$dir, "candidate_review.csv")))
  expect_true(file.exists(file.path(fx$dir, "identity_review.csv")))
  # An "unverified" resolver lookup is a failed lookup, reported in status.md.
  expect_true(any(readLines(file.path(fx$dir, "status.md")) == "| resolver | 1 | rows |"))
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
  unlink(list.files(file.path(fx$dir, "cache"), pattern = "^curation_", recursive = TRUE, full.names = TRUE))
  expect_error(curate_iterate(decisions, verbose = FALSE), "fixture outage")
  expect_equal(nrow(readr::read_csv(file.path(fx$dir, "candidate_review.csv"), show_col_types = FALSE)), 0)
  expect_equal(nrow(readr::read_csv(file.path(fx$dir, "review_reconciliation.csv"), show_col_types = FALSE)), 0)
})

test_that("accepted suggestions leave the pending queue but keep other blockers (#92)", {
  row <- tibble::tibble(
    original_row_id = 5576L,
    chemical_name = "Zeranol",
    consensus_status = "suggested",
    consensus_dtxsid = "DTXSID4022315",
    consensus_name = "Zearalanol",
    consensus_source = NA_character_,
    row_flag = "VERIFIED",
    row_flag_reason = "Low-similarity match confirmed",
    .pinned = TRUE,
    .resolution_method = "bulk-accept",
    needs_review = FALSE
  )
  state <- list(resolution_state = row, merged_chemical_tags = list(chemical_name = "Name"))
  expect_true(identity_review_state(row)$identity_eligible)
  expect_equal(nrow(pending_rows(state)), 0)

  state$resolution_state$identity_scope <- "aggregate"
  expect_equal(pending_rows(state)$pending_type, "verified_unresolved")
})

test_that("only FOLLOW-UP/BAD dispositions hide scope blockers from pending (#110)", {
  rs <- tibble::tibble(
    original_row_id = 1:4,
    chemical_name = c("Verified", "Unflagged", "Deferred", "Bad"),
    consensus_status = "single",
    consensus_dtxsid = "DTXSID1",
    consensus_name = "X",
    consensus_source = NA_character_,
    row_flag = c("VERIFIED", NA, "FOLLOW-UP", "BAD"),
    row_flag_reason = "Historical review",
    .pinned = TRUE,
    identity_scope = "aggregate"
  )
  pending <- pending_rows(list(resolution_state = rs, merged_chemical_tags = list(chemical_name = "Name")))
  expect_equal(pending$row_index, 1:2)
  expect_equal(pending$pending_type, rep("identity_scope", 2))
  expect_equal(pending$row_flag, c("VERIFIED", NA))
})

test_that("replay.R carries keyed decision tables that reproduce the decisions", {
  dir <- withr::local_tempdir()
  input_path <- file.path(dir, "inventory.csv")
  readr::write_csv(
    tibble::tibble(
      chemical_name = c("Acetone", "Lead + Zinc", "Lead + Zinc"),
      cas_number = c("67-64-1", NA, NA)
    ),
    input_path
  )
  local_mocked_bindings(
    run_curation_pipeline = function(cleaned_data, ...) {
      cleaned_data$consensus_status <- "single"
      cleaned_data$consensus_dtxsid <- "DTXSID8021482"
      cleaned_data$consensus_source <- "chemical_name"
      list(results = init_resolution_state(cleaned_data), consensus_summary = list())
    },
    postprocess_curation_candidates = mock_postprocess,
    enrich_candidates = mock_enrich,
    validate_manual_dtxsids = mock_validate
  )
  decisions <- file.path(dir, "decisions.R")
  writeLines(
    c(
      sprintf("input_path <- %s", deparse(input_path)),
      "tag_map <- list(chemical_name = \"Name\", cas_number = \"CASRN\")",
      "multi_analyte_resolutions <- tibble::tibble(row_index = 2:3, action = \"keep\")",
      "review_picks <- tibble::tibble(name = \"Acetone\", casrn = \"67-64-1\", dtxsid = \"DTXSID8021482\",",
      "  note = \"confirmed against the SDS\")",
      "row_flags <- tibble::tibble(name = \"NA\", flag = \"FOLLOW-UP\", reason = \"a, \\\"quoted\\\" reason\")"
    ),
    decisions
  )
  result <- curate_iterate(decisions, verbose = FALSE)

  replay <- readLines(file.path(dir, "replay.R"))
  expect_false(any(grepl("row_index", replay)))
  # One file, one decision per line.
  expect_false(dir.exists(file.path(dir, "decisions")))
  expect_true("Lead + Zinc,keep" %in% replay)
  tables <- new.env()
  for (expr in as.list(parse(text = replay))) {
    if (grepl("read_decision_table", deparse(expr)[1], fixed = TRUE)) eval(expr, tables)
  }
  expect_equal(tables$multi_analyte_resolutions, tibble::tibble(name = "Lead + Zinc", action = "keep"))
  expect_equal(tables$review_picks$note, "confirmed against the SDS")
  # A chemical literally named "NA" and awkward text come back as written.
  expect_equal(tables$row_flags, tibble::tibble(name = "NA", flag = "FOLLOW-UP", reason = "a, \"quoted\" reason"))

  rs <- result$state$resolution_state
  expect_equal(rs$review_note, c("confirmed against the SDS", NA, NA))
})

test_that("read_decision_table stops on a casrn a spreadsheet rewrote as a date", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("name,casrn,flag", "Acetone,67-64-1,VERIFIED", "Blank is fine,,VERIFIED", "Odd,0103-02-06,BAD"), path)
  expect_error(read_decision_table(path), "line\\(s\\) 4: 0103-02-06")
  writeLines(c("name,casrn,flag", "Acetone,67-64-1,VERIFIED"), path)
  expect_equal(read_decision_table(path)$casrn, "67-64-1")

  expect_error(read_decision_table(text = "\nname,casrn\nOdd,0103-02-06\n"), "decision table: casrn")

  # A hand-edited value with an unquoted comma stops, with or without a casrn column.
  expect_error(
    read_decision_table(text = "\nname,casrn,action\nAcetone,67-64-1,keep\n1,2-Dichloroethane,107-06-2,keep\n"),
    "line\\(s\\) 3 do not have 3 fields"
  )
  expect_error(read_decision_table(text = "name,flag\n1,2-Dichloroethane,VERIFIED\n"), "line\\(s\\) 2 do not have 2")
  expect_error(read_decision_table(text = "name,flag,reason\nAcetone,VERIFIED\n"), "do not have 3 fields")
  expect_error(read_decision_table(text = "name,flag\n\"Acetone,VERIFIED\nLead,VERIFIED\n"), "do not have 2 fields")
  expect_error(read_decision_table(text = "name,name\nAcetone,VERIFIED\n"), "unique")
  expect_equal(read_decision_table(text = "name,flag\n\"1,2-Dichloroethane\",VERIFIED\n")$name, "1,2-Dichloroethane")

  # A table whose casrn the reader would reject stays an inline literal.
  odd <- tibble::tibble(name = "Odd", casrn = "NOCAS_1", dtxsid = "DTXSID1")
  expect_false(any(grepl("read_decision_table", append_decision_table(character(), "review_picks", odd))))

  # Text that would close the raw string, blanks, and line breaks come back as written.
  awkward <- tibble::tibble(name = c("a )---\" b", "two\nlines", "NA"), casrn = c("67-64-1", NA, NA), note = c(NA, "", "x"))
  block <- append_decision_table(character(), "awkward", awkward)
  expect_true(is_blank_text(eval(parse(text = block))$note[2]))
  expect_equal(eval(parse(text = block))[c("name", "casrn")], awkward[c("name", "casrn")])
})

test_that("curate_iterate reports drifted identity decisions as pending rows instead of stopping (#182)", {
  fx <- iterate_fixture()
  local_mocked_bindings(
    run_curation_pipeline = function(cleaned_data, ...) mock_pipeline_result(cleaned_data),
    postprocess_curation_candidates = mock_postprocess,
    enrich_candidates = mock_enrich,
    validate_manual_dtxsids = mock_validate
  )
  decisions <- file.path(fx$dir, "decisions.R")
  ledger <- function(row, name) {
    list(selector = list(original_row_id = row, chemical_name = name), action = "retain_unresolved",
      scope = "substance", conflict = "none", reason = "Reviewed against an older build",
      evidence_reference = "fixture", evidence_fingerprint = "identity-v2:stale")
  }
  base <- c(
    sprintf("input_path <- %s", deparse(fx$input_path)),
    "tag_map <- list(chemical_name = \"Name\", cas_number = \"CASRN\", result = \"Result\", unit = \"Unit\")",
    "header_row <- 1L",
    "review_picks <- tibble::tibble(name = \"Chromium\", casrn = NA_character_, dtxsid = \"DTXSID1020322\")"
  )
  write_ledger <- function(l) {
    writeLines(c(base, paste("identity_decisions <-", paste(deparse(l), collapse = "\n"))), decisions)
  }
  stale <- list(ledger(1L, "Acetone"), ledger(3L, "Lead"))
  write_ledger(stale)

  out <- curate_iterate(decisions, verbose = FALSE)
  expect_false(out$done)
  expect_equal(out$pending$pending_type, rep("identity_drift", 2))
  expect_equal(out$pending$row_index, c(1L, 3L))
  expect_equal(out$pending$drift_recorded_fingerprint, rep("identity-v2:stale", 2))
  expect_equal(out$identity_drift$current_fingerprint, out$pending$drift_current_fingerprint)
  expect_false("identity_decision_record" %in% names(out$state$resolution_state))
  expect_match(paste(readLines(file.path(fx$dir, "status.md")), collapse = "\n"), "## Drifted decisions")
  expect_equal(readr::read_csv(file.path(fx$dir, "pending.csv"), show_col_types = FALSE)$pending_type,
    rep("identity_drift", 2))

  # Re-confirming with the reported fingerprint clears the row; a malformed decision still stops.
  stale[[1]]$evidence_fingerprint <- out$pending$drift_current_fingerprint[1]
  write_ledger(stale)
  again <- curate_iterate(decisions, verbose = FALSE)
  expect_equal(again$identity_drift$original_row_id, 3L)
  # A retained-unresolved scope stays in the queue as identity_scope; that is not drift.
  expect_equal(again$pending$pending_type, c("identity_scope", "identity_drift"))
  expect_true(again$state$resolution_state$identity_scope_reviewed[1])
  stale[[2]]$action <- "accept"
  write_ledger(stale)
  expect_error(curate_iterate(decisions, verbose = FALSE), "Acceptance requires")
})

test_that("the identity ledger is recorded, drifts, is re-confirmed and withdrawn without project code (#180)", {
  fx <- iterate_fixture()
  local_mocked_bindings(
    run_curation_pipeline = function(cleaned_data, ...) mock_pipeline_result(cleaned_data),
    postprocess_curation_candidates = mock_postprocess,
    enrich_candidates = mock_enrich,
    validate_manual_dtxsids = mock_validate
  )
  decisions <- file.path(fx$dir, "decisions.R")
  ledger <- file.path(fx$dir, "identity_decisions.jsonl")
  writeLines(c(
    sprintf("input_path <- %s", deparse(fx$input_path)),
    "tag_map <- list(chemical_name = \"Name\", cas_number = \"CASRN\", result = \"Result\", unit = \"Unit\")",
    "header_row <- 1L",
    "review_picks <- tibble::tibble(name = \"Chromium\", casrn = NA_character_, dtxsid = \"DTXSID1020322\")",
    "identity_decisions <- \"identity_decisions.jsonl\""
  ), decisions)
  batch <- tibble::tibble(row_index = 3L, action = "retain_unresolved", scope = "aggregate", conflict = "scope",
    reason = "Total lead, not the element", evidence_reference = "owner review")

  expect_error(record_identity_decision(decisions, batch, "owner"), "Run curate_iterate")
  curate_iterate(decisions, verbose = FALSE)
  expect_error(record_identity_decision(decisions, batch, ""), "recorded_by")
  expect_error(record_identity_decision(decisions, transform(batch, row_index = 99L), "owner"), "matches 0 rows")
  expect_error(record_identity_decision(decisions, transform(batch, scope = "nonsense"), "owner"), "Invalid identity")
  expect_false(file.exists(ledger))
  record_identity_decision(decisions, batch, "owner")
  line <- jsonlite::fromJSON(readLines(ledger))
  expect_equal(line$recorded_by, "owner")
  expect_equal(line$evidence$chemical_name, "Lead")

  applied <- curate_iterate(decisions, verbose = FALSE)
  expect_equal(nrow(applied$identity_drift), 0L)
  expect_equal(applied$state$resolution_state$identity_scope[3], "aggregate")
  expect_false(any(grepl("recorded_by|owner review\", evidence = ", readLines(file.path(fx$dir, "replay.R")))))

  # The source row changes under the decision.
  input <- readr::read_csv(fx$input_path, col_types = "cccc")
  input$unit[3] <- "ug/L"
  readr::write_csv(input, fx$input_path)
  drifted <- curate_iterate(decisions, verbose = FALSE)
  drift_row <- drifted$pending[drifted$pending$pending_type == "identity_drift", ]
  expect_equal(drift_row$row_index, 3L)
  expect_equal(drift_row$drift_changed_columns, "unit")

  expect_error(reconfirm_identity_decisions(decisions, "Unit only", expected = 2L, recorded_by = "owner"), "expected 2")
  expect_error(reconfirm_identity_decisions(decisions, "Unit only", 1L, "owner", rows = 1L), "Not drifted")
  expect_length(readLines(ledger), 1L)
  reconfirm_identity_decisions(decisions, "Unit only", expected = 1L, recorded_by = "owner")
  expect_equal(jsonlite::fromJSON(readLines(ledger)[2])$replaces, drift_row$drift_recorded_fingerprint)
  expect_error(reconfirm_identity_decisions(decisions, "Unit only", expected = 1L, recorded_by = "owner"), "0 drifted")

  cleared <- curate_iterate(decisions, verbose = FALSE)
  expect_equal(nrow(cleared$identity_drift), 0L)
  expect_equal(cleared$state$resolution_state$identity_scope[3], "aggregate")

  # A withdrawal needs no current run, so it can remove a line that stops the run.
  unlink(file.path(fx$dir, "cache", "identity_state.rds"))
  record_identity_decision(decisions, tibble::tibble(row_index = 3L, action = "withdraw", reason = "Recorded in error"),
    "owner")
  expect_error(record_identity_decision(decisions, tibble::tibble(row_index = 3L, action = "withdraw", reason = "Again"),
    "owner"), "Nothing to withdraw")
  withdrawn <- curate_iterate(decisions, verbose = FALSE)
  expect_false("identity_decision_record" %in% names(withdrawn$state$resolution_state))
  expect_length(readLines(ledger), 3L)
})

test_that("migrate_identity_ledger moves list-form decisions into a ledger once (#180)", {
  dir <- withr::local_tempdir()
  input <- file.path(dir, "in.csv")
  writeLines("a", input)
  decisions <- file.path(dir, "decisions.R")
  writeLines(c(sprintf("input_path <- %s", deparse(input)), "tag_map <- list(a = \"Name\")",
    "identity_decisions <- list(list(selector = list(original_row_id = 1L, a = \"x\"), action = \"retain_unresolved\"))"),
    decisions)
  path <- suppressMessages(migrate_identity_ledger(decisions))
  expect_equal(read_identity_ledger(path)[[1]]$selector, list(original_row_id = 1L, a = "x"))
  expect_error(migrate_identity_ledger(decisions), "already exists")
})

test_that("curate_iterate writes a run lock and mapping, checks the lock and takes an output path (#183)", {
  fx <- iterate_fixture()
  local_mocked_bindings(
    run_curation_pipeline = function(cleaned_data, ...) mock_pipeline_result(cleaned_data),
    postprocess_curation_candidates = mock_postprocess,
    enrich_candidates = mock_enrich,
    validate_manual_dtxsids = mock_validate
  )
  decisions <- file.path(fx$dir, "decisions.R")
  side <- file.path(fx$dir, "picks.csv")
  writeLines(c("name,casrn,dtxsid", "Chromium,,DTXSID1020322"), side)
  committed <- file.path(fx$dir, "curated.xlsx")
  writeLines(c(
    sprintf("input_path <- %s", deparse(fx$input_path)),
    sprintf("output_path <- %s", deparse(committed)),
    "tag_map <- list(chemical_name = \"Name\", cas_number = \"CASRN\", result = \"Result\", unit = \"Unit\")",
    "header_row <- 1L",
    sprintf("review_picks <- readr::read_csv(%s, col_types = \"ccc\")", deparse(side))
  ), decisions)

  expect_equal(curate_iterate(decisions, check_lock = TRUE)$changed, "run_lock.json")
  result <- curate_iterate(decisions, verbose = FALSE)
  expect_true(result$done)
  lock <- jsonlite::fromJSON(file.path(fx$dir, "run_lock.json"))
  expect_true(lock$done)
  expect_setequal(names(lock$files), c("decisions.R", "inventory.csv", "picks.csv"))
  expect_named(lock$versions, c("concert", "ComptoxR", "dsstox"))
  # The workbook named in decisions.R now exists and must not make the lock stale.
  expect_true(file.exists(committed))
  check <- suppressMessages(curate_iterate(decisions, check_lock = TRUE))
  expect_true(check$current && check$done)

  mapping <- readr::read_csv(file.path(fx$dir, "mapping.csv"), show_col_types = FALSE)
  expect_equal(mapping$original_row_id, 1:3)
  expect_equal(mapping$dtxsid, c("DTXSID8021482", "DTXSID1020322", "DTXSID6024161"))
  expect_equal(mapping$decided_by, c("automatic", "pick", "automatic"))
  expect_equal(mapping$preferred_name[1], "Acetone")
  expect_false(anyNA(mapping$preferred_name))

  # A trial run elsewhere leaves the committed outputs alone.
  trial <- withr::local_tempdir()
  before <- file.mtime(c(committed, file.path(fx$dir, "run_lock.json")))
  curate_iterate(decisions, out_dir = trial, verbose = FALSE, output_path = file.path(trial, "trial.xlsx"))
  expect_true(all(file.exists(file.path(trial, c("trial.xlsx", "mapping.csv", "run_lock.json")))))
  expect_equal(file.mtime(c(committed, file.path(fx$dir, "run_lock.json"))), before)

  writeLines(c("name,casrn,dtxsid", "Chromium,,DTXSID1020322", "Other,,DTXSID8021482"), side)
  expect_equal(suppressMessages(curate_iterate(decisions, check_lock = TRUE))$changed, "files.picks.csv")

  # A failed run leaves no lock and no mapping to mistake for current.
  writeLines("stop('broken')", side)
  writeLines(sub("readr::read_csv\\(", "source(", readLines(decisions)), decisions)
  expect_error(curate_iterate(decisions, verbose = FALSE))
  expect_true(file.exists(file.path(fx$dir, "run_lock.json")))
  writeLines(sub("source\\(.*", "NULL", readLines(decisions)), decisions)
  writeLines("x", fx$input_path)
  expect_error(curate_iterate(decisions, verbose = FALSE))
  expect_false(any(file.exists(file.path(fx$dir, c("run_lock.json", "mapping.csv")))))
})
