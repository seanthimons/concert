portable_review_fixture <- function() {
  df <- tibble::tibble(name = "Salt A", cas = "1-11-1", source_file = "inventory",
    consensus_dtxsid = NA_character_, consensus_status = "unresolvable", consensus_source = NA_character_)
  scope <- review_evidence_scope(df, 1, c("name", "cas", "source_file"))
  original <- review_evidence_snapshot(df, scope_cols = scope$columns)
  evidence <- capture_review_decision(NULL, "portable", scope, original, "no_hit", "FOLLOW-UP", "original reason")
  df$resolver_dtxsid_candidate <- "DTXSID1"
  current <- review_evidence_snapshot(df, scope_cols = scope$columns)
  evidence <- acknowledge_review_evidence(evidence, "portable", 1, scope, current)
  list(df = df, scope = scope, current = current, evidence = evidence,
    validation = data.frame(dtxsid = "DTXSID1", outcome = "unavailable", authority = "mock", version = "1"),
    identity = data.frame(name = "Salt A", casrn = "1-11-1", identity_scope = "registered_mixture",
      dtxsid = "DTXSID1", note = "reviewed scope", stringsAsFactors = FALSE))
}

test_that("generated replay reconstructs exact portable decision inputs", {
  fixture <- portable_review_fixture()
  script <- generate_concert_script("input.csv", "output.xlsx", list(name = "Name", cas = "CASRN"), 1,
    review_decision_evidence = fixture$evidence, identity_decisions = fixture$identity,
    candidate_validation = fixture$validation)
  expressions <- parse(text = script)
  env <- new.env(parent = baseenv())
  targets <- c("review_decision_evidence", "identity_decisions", "candidate_validation")
  for (expr in expressions) {
    if (is.call(expr) && identical(expr[[1]], as.name("<-")) && as.character(expr[[2]]) %in% targets) {
      eval(expr, env)
    }
  }
  expect_identical(env$review_decision_evidence, fixture$evidence)
  expect_identical(env$identity_decisions, fixture$identity)
  expect_identical(env$candidate_validation, fixture$validation)
  expect_identical(validate_review_evidence(env$review_decision_evidence), fixture$evidence)
  for (target in targets) expect_match(script, paste0(target, " = ", target), fixed = TRUE)
})

test_that("typed portable session payloads are chunked and integrity checked", {
  fixture <- portable_review_fixture()
  fixture$evidence$decisions[[1]]$reason <- paste(rep("long reviewed evidence", 5000), collapse = "; ")
  fixture$evidence$decisions[[1]]$record_fingerprint <- review_evidence_fingerprint(
    fixture$evidence$decisions[[1]][setdiff(names(fixture$evidence$decisions[[1]]), "record_fingerprint")])
  values <- list(review_decision_evidence = fixture$evidence,
    identity_decisions = fixture$identity, candidate_validation = fixture$validation)
  rows <- serialize_session_inputs(values)
  expect_true(all(nchar(rows$value) <= 30000))
  expect_gt(sum(rows$key == "review_decision_evidence"), 1)
  expect_identical(restore_session_inputs(rows[nrow(rows):1, ]), values)
  invalid <- rows[!(rows$key == "review_decision_evidence" & rows$row_index == 2), ]
  expect_error(restore_session_inputs(invalid), "Missing or duplicate")
  expect_identical(restore_session_inputs(NULL), list())
  corrupted <- fixture$evidence
  corrupted$decisions[[1]]$reason <- "silently changed"
  expect_error(serialize_session_inputs(list(review_decision_evidence = corrupted)), "modified")
})

test_that("workbook export and hydration preserve immutable decisions and acknowledgments", {
  fixture <- portable_review_fixture()
  report <- data.frame(decision_id = "portable", actionable = FALSE)
  sheets <- build_export_sheets(raw = fixture$df, cleaned_data = fixture$df,
    resolution_state = fixture$df, consensus_summary = list(), cleaning_audit = NULL,
    reference_lists = list(), column_tags = list(name = "Name", cas = "CASRN"),
    detection = list(method = "manual", header_row = 1L), file_info = list(name = "input.csv", size = 1),
    review_decision_evidence = fixture$evidence, identity_decisions = fixture$identity,
    candidate_validation = fixture$validation, review_reconciliation = report,
    candidate_review = report, source_identifier_evidence = report, identifier_diagnostics = report)
  path <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(sheets, path)
  parsed <- parse_concert_export(path)
  expect_false(is.null(parsed))
  restored <- hydrate_session_state(parsed)$state
  expect_identical(restored$review_decision_evidence, fixture$evidence)
  expect_identical(restored$identity_decisions, fixture$identity)
  expect_identical(restored$candidate_validation, fixture$validation)
  expect_equal(restored$review_reconciliation$decision_id, "portable")
  expect_equal(restored$candidate_review$decision_id, "portable")
  expect_equal(restored$source_identifier_evidence$decision_id, "portable")
  expect_equal(restored$identifier_diagnostics$decision_id, "portable")
  expect_equal(compare_review_decision(restored$review_decision_evidence, "portable", fixture$scope,
    fixture$current)$status, "acknowledged")
  fixture$df$resolver_dtxsid_candidate <- "DTXSID2"
  changed <- review_evidence_snapshot(fixture$df, scope_cols = fixture$scope$columns)
  expect_equal(compare_review_decision(restored$review_decision_evidence, "portable", fixture$scope, changed)$status, "changed")
  # Older exports lack portable records, and hydration remains compatible.
  parsed$session_state <- parsed$session_state[parsed$session_state$record_type != "portable_input_v1", ]
  legacy <- hydrate_session_state(parsed)$state
  expect_null(legacy$review_decision_evidence)
})
