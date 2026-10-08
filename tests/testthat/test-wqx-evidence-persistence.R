# Exercise the portable boundaries with actual WQX projections and attributed
# query records. All registry and PubChem responses are deterministic fixtures.
wqx_portable_fixture <- function(raw = NULL, candidates = TRUE) {
  if (is.null(raw)) {
    raw <- tibble::tibble(
      name = c("Arsenick", "DO"), cas = c("7440-38-2", "7782-44-7"),
      source_file = c("inventory-a", "inventory-b"), original_row_id = c("11", "22"),
      # Input metadata that happens to resemble an evidence field stays raw.
      wqx_cas_dtxsid_candidates = c("DTXSID999", "DTXSID998")
    )
  }
  dict <- tibble::tibble(
    name = c("Arsenic", "Dissolved oxygen", "DO"),
    canonical_name = c("Arsenic", "Dissolved oxygen", "Dissolved oxygen"),
    type = c("canonical", "canonical", "synonym"),
    cas_number = c("7440-38-2", "7782-44-7", NA_character_)
  )
  matches <- match_wqx(raw$name, dict)
  evidence <- wqx_dictionary_candidates(matches, lookup_fn = function(cas) {
    if (!candidates) {
      return(tibble::tibble(original_cas = cas, dtxsid = NA_character_,
        preferredName = NA_character_, lookup_status = "not_found"))
    }
    tibble::tibble(original_cas = c(cas[1], cas[1], cas[2]),
      dtxsid = c("DTXSID101", "DTXSID102", "DTXSID103"),
      preferredName = c("Candidate A", "Candidate B", "Candidate C"), lookup_status = "hit")
  })
  lookup <- dplyr::bind_cols(tibble::tibble(searchValue = raw$name,
    dtxsid = NA_character_, preferredName = matches$wqx_name,
    searchName = raw$name, rank = 0L, source_tier = paste0("wqx_", matches$match_tier)), evidence)
  keys <- tibble::tibble(row_idx = seq_len(nrow(raw)), column_name = "name", dedup_key = raw$name)
  df <- map_results_to_rows(raw, keys, lookup)
  df$consensus_status <- "wqx"
  df$consensus_dtxsid <- NA_character_
  df$consensus_source <- "Name"
  df$consensus_name <- matches$wqx_name
  df <- add_pubchem_candidates(df, "name", original_data = raw,
    search_fn = function(query, type) {
      tibble::tibble(cid = if (candidates && query == "Arsenic") 12L else integer())
    }, synonyms_fn = function(cid, tidy) tibble::tibble(cid = cid, synonym = "DTXSID104"))
  df <- add_resolver_candidates(df, "name", original_data = raw,
    lookup_fn = function(queries, tidy) lapply(queries, function(query) {
      if (candidates && query %in% c("Arsenick", "Arsenic")) {
        list(query = query, result = "FOUND", resolvedBy = "Name",
          chemical = list(sid = if (query == "Arsenick") "DTXSID105" else "DTXSID106",
            name = "Resolver candidate"))
      } else list(query = query, result = "NOT_FOUND")
    }), public_fn = function(ids) ids)
  list(raw = raw, df = init_resolution_state(df), tags = list(name = "Name", cas = "CASRN"))
}

wqx_portable_workbook <- function(fixture, evidence = NULL) {
  sheets <- build_export_sheets(raw = fixture$raw, cleaned_data = fixture$raw,
    resolution_state = fixture$df, consensus_summary = list(), cleaning_audit = NULL,
    reference_lists = list(), column_tags = fixture$tags,
    detection = list(method = "manual", header_row = 1L), file_info = list(name = "input.csv", size = 1),
    review_decision_evidence = evidence)
  path <- tempfile(fileext = ".xlsx")
  withr::defer(unlink(path), envir = parent.frame())
  writexl::write_xlsx(sheets, path)
  hydrate_session_state(parse_concert_export(path))$state
}

test_that("WQX evidence and query attribution survive a real workbook hydration", {
  fixture <- wqx_portable_fixture()
  restored <- wqx_portable_workbook(fixture)
  fields <- c(wqx_review_columns(fixture$df), "lookup_evidence_columns",
    "pubchem_query", "pubchem_query_details", "pubchem_dtxsid_candidates",
    "resolver_query", "resolver_query_details", "resolver_dtxsid_candidate")
  for (field in fields) expect_equal(restored$resolution_state[[field]], fixture$df[[field]])
  expect_equal(restored$resolution_state[ names(fixture$raw) ], fixture$raw)
  expect_equal(restored$raw[ names(fixture$raw) ], fixture$raw)
  expect_equal(restored$resolution_state$original_row_id, c("11", "22"))
  expect_equal(find_dtxsid_cols(restored$resolution_state), "dtxsid_lookup_name")
  before <- normalize_review_candidates(fixture$df)
  after <- normalize_review_candidates(restored$resolution_state)
  expect_identical(after, before)
  expect_false(any(after$dtxsid %in% c("DTXSID999", "DTXSID998")))
  expect_equal(after$dtxsid[after$role == "vocabulary_cas_candidate"],
    c("DTXSID101", "DTXSID102", "DTXSID103"))
  expect_equal(after$query[after$source == "pubchem"], "Arsenic")
  expect_equal(after$role[after$source == "pubchem"], "vocabulary_name_candidate")
  expect_equal(after$query[after$source == "resolver"], c("Arsenic", "Arsenick"))
  expect_equal(after$role[after$source == "resolver"], c("vocabulary_name_candidate", "candidate"))
  details <- jsonlite::fromJSON(restored$resolution_state$pubchem_query_details[1])
  expect_equal(details$query, c("Arsenick", "Arsenic"))
  expect_equal(details$role, c("original", "wqx_canonical"))
  expect_equal(details$original_row_id, c("11", "11"))
  expect_true(all(is.na(restored$resolution_state$consensus_dtxsid)))
})

test_that("imported no-hit decisions and acknowledgments do not cover changed WQX evidence", {
  fixture <- wqx_portable_fixture(candidates = FALSE)
  cols <- c("name", "cas", "source_file", "original_row_id")
  scope <- review_evidence_scope(fixture$df, 1L, cols)
  baseline <- review_evidence_snapshot(fixture$df, row_indices = 1L, scope_cols = cols)
  evidence <- capture_review_decision(NULL, "wqx-portable", scope, baseline,
    "no_hit", "FOLLOW-UP", "No registry candidates in the reviewed fixture")
  restored <- wqx_portable_workbook(fixture, evidence)
  imported <- restored$resolution_state
  current <- review_evidence_snapshot(imported, row_indices = 1L, scope_cols = cols)
  expect_identical(restored$review_decision_evidence, evidence)
  expect_equal(compare_review_decision(evidence, "wqx-portable", scope, current)$status, "unchanged")
  imported$wqx_cas_dtxsid_candidates_lookup_name[1] <- "DTXSID101|DTXSID102"
  imported$wqx_cas_lookup_status_lookup_name[1] <- "candidate"
  changed <- review_evidence_snapshot(imported, row_indices = 1L, scope_cols = cols)
  expect_equal(compare_review_decision(evidence, "wqx-portable", scope, changed)$status, "changed")
  acknowledged <- acknowledge_review_evidence(evidence, "wqx-portable", 1L, scope, changed)
  expect_identical(acknowledged$decisions, evidence$decisions)
  expect_equal(compare_review_decision(acknowledged, "wqx-portable", scope, changed)$status, "acknowledged")
  query_changed <- imported
  details <- jsonlite::fromJSON(query_changed$pubchem_query_details[1], simplifyVector = FALSE)
  details[[2]]$role <- "original"
  query_changed$pubchem_query_details[1] <- as.character(jsonlite::toJSON(details, auto_unbox = TRUE))
  expect_equal(compare_review_decision(acknowledged, "wqx-portable", scope,
    review_evidence_snapshot(query_changed, row_indices = 1L, scope_cols = cols))$status, "changed")
  unavailable <- imported
  unavailable$wqx_cas_lookup_status_lookup_name[1] <- "unavailable"
  expect_equal(compare_review_decision(acknowledged, "wqx-portable", scope,
    review_evidence_snapshot(unavailable, row_indices = 1L, scope_cols = cols))$status, "changed")
  fixture$df <- imported
  roundtrip <- wqx_portable_workbook(fixture, acknowledged)
  imported <- roundtrip$resolution_state
  expect_identical(roundtrip$review_decision_evidence, acknowledged)
  imported$wqx_cas_provenance_lookup_name[1] <- "canonical:another reviewed entry"
  revised <- review_evidence_snapshot(imported, row_indices = 1L, scope_cols = cols)
  expect_equal(compare_review_decision(roundtrip$review_decision_evidence,
    "wqx-portable", scope, revised)$status, "changed")
  imported$wqx_cas_dtxsid_candidates_lookup_name[1] <- "DTXSID105"
  expect_equal(compare_review_decision(acknowledged, "wqx-portable", scope,
    review_evidence_snapshot(imported, row_indices = 1L, scope_cols = cols))$status, "changed")
})

test_that("generated replay keeps WQX evidence, source lineage and deferred baselines", {
  fixture <- wqx_portable_fixture()
  scope <- review_evidence_scope(fixture$df, 1L, c("name", "cas", "source_file"))
  current <- review_evidence_snapshot(fixture$df, row_indices = 1L, scope_cols = scope$columns)
  evidence <- capture_review_decision(NULL, "wqx-replay", scope, current,
    "deferred", "FOLLOW-UP", "Review canonical vocabulary correspondence")
  local_mocked_bindings(
    run_curation_pipeline = function(clean_data, ...) {
      replay <- wqx_portable_fixture(clean_data)
      list(results = replay$df, consensus_summary = recalc_consensus_summary(replay$df))
    },
    postprocess_curation_candidates = function(resolution_state, ...) {
      empty_postprocess_result(resolution_state, NULL, character())
    }
  )
  dir <- withr::local_tempdir()
  input <- file.path(dir, "source.csv")
  output <- file.path(dir, "curated.xlsx")
  readr::write_csv(fixture$raw, input)
  mask <- lapply(default_cleaning_step_mask(), function(x) FALSE)
  script <- generate_concert_script(input, output, fixture$tags, 1L,
    cleaning_steps = mask, review_decision_evidence = evidence)
  path <- file.path(dir, "replay.R")
  writeLines(script, path)
  result <- source(path, local = new.env(parent = globalenv()))$value
  fields <- c(names(fixture$raw), wqx_review_columns(fixture$df),
    "lookup_evidence_columns", "pubchem_query", "pubchem_query_details",
    "resolver_query", "resolver_query_details")
  for (field in fields) expect_equal(result$data[[field]], fixture$df[[field]])
  restored <- hydrate_session_state(parse_concert_export(output))$state
  expect_identical(restored$review_decision_evidence, evidence)
  replayed <- review_evidence_snapshot(restored$resolution_state, row_indices = 1L,
    scope_cols = scope$columns)
  expect_equal(compare_review_decision(restored$review_decision_evidence,
    "wqx-replay", scope, replayed)$status, "unchanged")
  expect_identical(normalize_review_candidates(restored$resolution_state), normalize_review_candidates(fixture$df))
  expect_true(all(is.na(result$data$consensus_dtxsid)))
})
