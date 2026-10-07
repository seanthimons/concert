review_stage_fixture <- function() {
  raw <- tibble::tibble(name = "Fixture analyte", cas = "1-23-4", source = "fixture-source")
  df <- raw
  df$original_row_id <- 17L
  df$consensus_status <- "unresolvable"
  df$consensus_dtxsid <- NA_character_
  df$consensus_source <- NA_character_
  list(resolution_state = init_resolution_state(df), clean_data = raw,
    merged_chemical_tags = list(name = "Name", cas = "CASRN"),
    merged_tags = list(name = "Name", cas = "CASRN"),
    tag_map = list(name = "Name", cas = "CASRN"), consensus_summary = list())
}
review_stage_flags <- function() {
  tibble::tibble(name = "Fixture analyte", flag = "FOLLOW-UP", reason = "Preserve reviewer wording")
}

test_that("stage reconciliation preserves historical no-hit and distinct completion", {
  state <- stage_review(review_stage_fixture(), row_flags = review_stage_flags())
  expect_equal(state$review_reconciliation$baseline_status, "baseline_missing")
  evidence <- capture_review_state(state, "Fixture analyte", disposition = "no_hit",
    flag = "FOLLOW-UP", reason = "Preserve reviewer wording")
  original <- evidence$decisions[[1]]
  next_state <- review_stage_fixture()
  next_state$resolution_state$consensus_status <- "single"
  next_state$resolution_state$consensus_dtxsid <- "DTXSID123"
  reviewed <- stage_review(next_state, row_flags = review_stage_flags(), review_decision_evidence = evidence)
  expect_equal(reviewed$review_reconciliation$change_category, "no_identity_to_selected")
  expect_identical(reviewed$review_decision_evidence$decisions[[1]], original)
  expect_equal(reviewed$resolution_state$row_flag, "FOLLOW-UP")
  expect_equal(reviewed$resolution_state$row_flag_reason, "Preserve reviewer wording")
  pending <- pending_rows(reviewed)
  completion <- review_completion(reviewed, pending)
  expect_true(completion$queue_complete)
  expect_false(completion$reconciliation_complete)
  expect_false(completion$identity_review_complete)
  expect_equal(completion$accepted_identity_rows, 0)

  cols <- review_scope_columns(reviewed)
  scope <- review_evidence_scope(reviewed$review_automated_state, 1, cols)
  current <- review_evidence_snapshot(reviewed$review_automated_state, reviewed$resolution_state,
    1, reviewed$candidate_validation, "source_dtxsid", cols)
  ack <- acknowledge_review_evidence(evidence, original$decision_id, 1L, scope, current)
  same <- stage_review(next_state, row_flags = review_stage_flags(), review_decision_evidence = ack)
  expect_equal(same$review_reconciliation$baseline_status, "acknowledged")
  expect_true(review_completion(same, pending_rows(same))$reconciliation_complete)
  expect_equal(same$resolution_state$row_flag, "FOLLOW-UP")
  next_state$resolution_state$consensus_dtxsid <- "DTXSID999"
  later <- stage_review(next_state, row_flags = review_stage_flags(), review_decision_evidence = ack)
  expect_true(later$review_reconciliation$actionable)
})

test_that("new unresolved candidate work reaches pending without assigning or clearing flags", {
  original <- stage_review(review_stage_fixture(), row_flags = review_stage_flags())
  evidence <- capture_review_state(original, "Fixture analyte", disposition = "no_hit", flag = "FOLLOW-UP")
  later <- review_stage_fixture()
  later$resolution_state$resolver_dtxsid_candidate <- "DTXSID123"
  later$resolution_state$resolver_lookup_status <- "unverified"
  validation <- data.frame(dtxsid = "DTXSID123", outcome = "unavailable", authority = "fixture", version = "1")
  later <- stage_review(later, row_flags = review_stage_flags(), review_decision_evidence = evidence,
    candidate_validation = validation)
  expect_true(later$candidate_review$actionable)
  expect_match(later$candidate_review$validation_outcomes, "unavailable")
  expect_equal(pending_rows(later)$pending_type, "candidate_validation")
  expect_equal(pending_rows(later)$row_index, 17L)
  expect_false(review_completion(later, pending_rows(later))$queue_complete)
  expect_true(is.na(later$resolution_state$consensus_dtxsid))
  expect_equal(later$resolution_state$row_flag, "FOLLOW-UP")
})

test_that("imported flagged state without decision tables reports missing history", {
  state <- review_stage_fixture()
  state$resolution_state <- set_row_flags(state$resolution_state, 1, "FOLLOW-UP", "arbitrary text")
  state <- stage_review(state)
  expect_equal(state$review_reconciliation$baseline_status, "baseline_missing")
  expect_equal(state$candidate_review$status, "baseline_missing")
  expect_false(state$candidate_review$actionable)
})
