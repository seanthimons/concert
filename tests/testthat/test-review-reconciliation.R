reconciliation_fixture <- function() {
  data.frame(name = c("Salt A", "Salt B"), cas = c("1-11-1", "2-22-2"),
    source_file = "inventory", part = c("a", "b"), consensus_dtxsid = NA_character_,
    consensus_status = "unresolvable", consensus_source = NA_character_,
    pubchem_query = c("Salt A", "Salt B"), resolver_dtxsid_candidate = NA_character_,
    pubchem_dtxsid_candidates = NA_character_, source_dtxsid = NA_character_, stringsAsFactors = FALSE)
}

test_that("reconciliation exposes legacy baselines without interpreting prose", {
  df <- reconciliation_fixture()
  df$consensus_dtxsid[1] <- "DTXSID1"
  flags <- data.frame(name = df$name, casrn = df$cas, flag = "FOLLOW-UP", reason = c("no record", "arbitrary wording"))
  report <- build_review_reconciliation(df, row_flags = flags, name_col = "name", cas_col = "cas")
  expect_equal(report$baseline_status, rep("baseline_missing", 2))
  expect_equal(report$change_category, c("legacy_flag_with_selected_identity", "baseline_missing"))
  expect_equal(report$reason, flags$reason)
  expect_true(all(report$actionable))
  expect_equal(names(build_review_reconciliation(df, name_col = "name")), names(report))
})

test_that("selected evidence changes reconcile while retained flags remain intact", {
  df <- reconciliation_fixture()
  flags <- data.frame(name = "Salt A", casrn = "1-11-1", flag = "FOLLOW-UP", reason = "scope requires review")
  columns <- c("name", "cas", "source_file", "part")
  scope <- review_evidence_scope(df, 1, columns)
  original <- review_evidence_snapshot(df, row_indices = 1, scope_cols = columns)
  id <- review_decision_key(flags$name, flags$casrn)
  evidence <- capture_review_decision(NULL, id, scope, original, "no_hit", "FOLLOW-UP", flags$reason)
  df$consensus_dtxsid[1] <- "DTXSID1"
  df$consensus_status[1] <- "single"
  report <- build_review_reconciliation(df, row_flags = flags, evidence = evidence,
    name_col = "name", cas_col = "cas", scope_cols = columns)
  expect_equal(report$change_category, "no_identity_to_selected")
  expect_true(report$actionable)
  expect_equal(report$flag, "FOLLOW-UP")
  expect_equal(report$current_automated_identity, "DTXSID1")
  current <- review_evidence_snapshot(df, row_indices = 1, scope_cols = columns)
  acknowledged <- acknowledge_review_evidence(evidence, id, 1, scope, current)
  report <- build_review_reconciliation(df, row_flags = flags, evidence = acknowledged,
    name_col = "name", cas_col = "cas", scope_cols = columns)
  expect_equal(report$baseline_status, "acknowledged")
  expect_false(report$actionable)
  expect_equal(report$flag, "FOLLOW-UP")
  evidence <- capture_review_decision(evidence, id, scope, current, "scope_conflict", "FOLLOW-UP", flags$reason)
  report <- build_review_reconciliation(df, row_flags = flags, evidence = evidence,
    name_col = "name", cas_col = "cas", scope_cols = columns)
  expect_equal(report$baseline_status, "unchanged")
  expect_false(report$actionable)
})

test_that("manual final state does not conceal changed automated evidence", {
  df <- reconciliation_fixture()
  columns <- c("name", "cas")
  scope <- review_evidence_scope(df, 1, columns)
  final <- df
  final$consensus_dtxsid[1] <- "DTXSID1"
  final$consensus_status[1] <- "manual"
  flags <- data.frame(name = "Salt A", casrn = "1-11-1", flag = "FOLLOW-UP", reason = "scope", decision_id = "explicit")
  evidence <- capture_review_decision(NULL, "explicit", scope,
    review_evidence_snapshot(df, final, 1, scope_cols = columns), "scope_conflict")
  df$resolver_dtxsid_candidate[1] <- "DTXSID2"
  report <- build_review_reconciliation(df, final, flags, evidence, "name", "cas", scope_cols = columns)
  expect_equal(report$change_category, "candidate_evidence_changed")
  expect_equal(report$current_final_identity, "DTXSID1")
  expect_match(report$current_candidates, "DTXSID2")
})

test_that("source scope changes and missing targets remain explicit", {
  df <- reconciliation_fixture()
  flags <- data.frame(name = "Salt A", casrn = "1-11-1", flag = "FOLLOW-UP", decision_id = "explicit")
  columns <- c("name", "cas", "source_file", "part")
  evidence <- capture_review_decision(NULL, "explicit", review_evidence_scope(df, 1, columns),
    review_evidence_snapshot(df, row_indices = 1, scope_cols = columns), "deferred")
  df$part[1] <- "changed"
  report <- build_review_reconciliation(df, row_flags = flags, evidence = evidence,
    name_col = "name", cas_col = "cas", scope_cols = columns)
  expect_equal(report$baseline_status, "scope_changed")
  expect_true(report$actionable)
  report <- build_review_reconciliation(df, row_flags = flags, evidence = evidence, name_col = "name")
  expect_equal(report$baseline_status, "scope_changed")
  expect_true(is.na(report$row_index))
  flags$name <- "missing"
  report <- build_review_reconciliation(df, row_flags = flags, name_col = "name", cas_col = "cas")
  expect_equal(report$baseline_status, "target_missing")
})

test_that("row-bound evidence detects swapped identities within multirow scopes", {
  df <- reconciliation_fixture()
  df$consensus_dtxsid <- c("DTXSID1", "DTXSID2")
  columns <- c("name", "cas", "part")
  first <- review_evidence_snapshot(df, scope_cols = columns)
  reordered <- review_evidence_snapshot(df[2:1, ], scope_cols = columns)
  expect_identical(review_evidence_fingerprint(first), review_evidence_fingerprint(reordered))
  df$consensus_dtxsid <- rev(df$consensus_dtxsid)
  expect_false(identical(review_evidence_fingerprint(first),
    review_evidence_fingerprint(review_evidence_snapshot(df, scope_cols = columns))))
})


test_that("candidate evidence remains bound to source rows under a shared selector", {
  df <- reconciliation_fixture()
  columns <- c("name", "cas", "part")
  df$resolver_dtxsid_candidate <- c("DTXSID1", "DTXSID2")
  df$pubchem_query <- "Shared lookup query"
  first <- review_evidence_snapshot(df, scope_cols = columns)
  expect_identical(review_evidence_fingerprint(first),
    review_evidence_fingerprint(review_evidence_snapshot(df[2:1, ], scope_cols = columns)))
  df$resolver_dtxsid_candidate <- rev(df$resolver_dtxsid_candidate)
  swapped <- review_evidence_snapshot(df, scope_cols = columns)
  expect_identical(first$candidates, swapped$candidates)
  expect_false(identical(review_evidence_fingerprint(first$candidate_scope),
    review_evidence_fingerprint(swapped$candidate_scope)))
  expect_false(identical(review_evidence_fingerprint(first), review_evidence_fingerprint(swapped)))
})
