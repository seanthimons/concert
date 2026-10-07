evidence_fixture <- function() {
  data.frame(name = c("Salt A", "Salt B"), cas = c("1-11-1", "2-22-2"),
    source_file = "inventory", part = c("a", "b"), consensus_dtxsid = NA_character_,
    consensus_status = "unresolvable", consensus_source = NA_character_,
    pubchem_query = c("Salt A", "Salt B"), resolver_dtxsid_candidate = NA_character_,
    pubchem_dtxsid_candidates = NA_character_, source_dtxsid = NA_character_,
    stringsAsFactors = FALSE)
}

test_that("candidate evidence preserves attribution and rejects incomplete pairs", {
  df <- evidence_fixture()
  df$pubchem_dtxsid_candidates[1] <- " :; 12:DTXSID123;12:DTXSID123; :DTXSID5;12:;0:DTXSID4;NA:DTXSID5"
  df$resolver_dtxsid_candidate[1] <- "DTXSID123; DTXSID456;bogus;DTXSID123"
  df$source_dtxsid[1] <- "DTXSID123"
  out <- normalize_review_candidates(df, 1)
  expect_equal(nrow(out), 4L)
  expect_equal(out$cid[out$source == "pubchem"], "12")
  expect_equal(out$dtxsid[out$source == "resolver"], c("DTXSID123", "DTXSID456"))
  expect_equal(out$role[out$source == "source:source_dtxsid"], "source_metadata")
  df$pubchem_dtxsid_candidates <- c(":", NA_character_)
  df$resolver_dtxsid_candidate <- df$source_dtxsid <- NA_character_
  expect_equal(nrow(normalize_review_candidates(df)), 0L)
})

test_that("scope and evidence survive row reordering but not content changes", {
  df <- evidence_fixture()
  columns <- c("name", "cas", "source_file", "part")
  scope <- review_evidence_scope(df, 1:2, columns)
  snapshot <- review_evidence_snapshot(df)
  expect_identical(review_evidence_fingerprint(scope),
    review_evidence_fingerprint(review_evidence_scope(df[2:1, ], 1:2, rev(columns))))
  expect_identical(review_evidence_fingerprint(snapshot),
    review_evidence_fingerprint(review_evidence_snapshot(df[2:1, ])))
  changed <- df
  changed$cas[1] <- "new"
  expect_false(identical(review_evidence_fingerprint(scope),
    review_evidence_fingerprint(review_evidence_scope(changed, 1:2, columns))))
  expect_error(review_evidence_scope(df, 1, "missing"), "existing source/content")
  ambiguous <- review_evidence_scope(df[c(1, 1), ], 1:2, columns)
  expect_true(ambiguous$ambiguous)
  expect_error(capture_review_decision(NULL, "a", ambiguous, snapshot, "deferred"), "unambiguous")
})

test_that("explicit snapshots remain immutable and acknowledgments are narrowly bound", {
  df <- evidence_fixture()
  scope <- review_evidence_scope(df, 1, c("name", "cas", "source_file", "part"))
  original <- review_evidence_snapshot(df, row_indices = 1)
  expect_equal(compare_review_decision(NULL, "a", scope, original)$status, "baseline_missing")
  decisions <- capture_review_decision(NULL, "a", scope, original, "no_hit", "FOLLOW-UP", "Human wording")
  expect_equal(compare_review_decision(decisions, "a", scope, original)$status, "unchanged")
  df$resolver_dtxsid_candidate[1] <- "DTXSID123"
  current <- review_evidence_snapshot(df, row_indices = 1)
  expect_equal(compare_review_decision(decisions, "a", scope, current)$status, "changed")
  acknowledged <- acknowledge_review_evidence(decisions, "a", 1, scope, current)
  expect_identical(acknowledged$decisions, decisions$decisions)
  expect_equal(compare_review_decision(acknowledged, "a", scope, current)$status, "acknowledged")
  expect_equal(acknowledged$decisions[[1]]$flag, "FOLLOW-UP")
  df$resolver_dtxsid_candidate[1] <- "DTXSID456"
  expect_equal(compare_review_decision(acknowledged, "a", scope,
    review_evidence_snapshot(df, row_indices = 1))$status, "changed")
  df$name[1] <- "different source identity"
  changed_scope <- review_evidence_scope(df, 1, scope$columns)
  expect_equal(compare_review_decision(acknowledged, "a", changed_scope, current)$status, "scope_changed")
  expect_error(acknowledge_review_evidence(decisions, "a", 2, scope, current), "exact decision")
  expect_error(acknowledge_review_evidence(decisions, "a", 1, changed_scope, current), "exact decision")
  revised <- capture_review_decision(acknowledged, "a", scope, current, "deferred")
  expect_length(revised$decisions, 2)
  expect_identical(revised$decisions[[1]], decisions$decisions[[1]])
  expect_false(compare_review_decision(revised, "a", scope, current)$acknowledged)
  expect_error(capture_review_decision(revised, "a", scope, current, "deferred", revision = 1), "next decision")
  corrupted <- revised
  corrupted$decisions[[1]]$reason <- "silently rewritten"
  expect_error(validate_review_evidence(corrupted), "modified")
})

test_that("normalization ignores order and timestamps, and distinguishes validation outcomes", {
  df <- evidence_fixture()[1, ]
  df$resolver_dtxsid_candidate <- "DTXSID2; DTXSID1"
  first <- review_evidence_snapshot(df)
  df$resolver_dtxsid_candidate <- "DTXSID1; DTXSID2; DTXSID1"
  df$lookup_time <- Sys.time()
  expect_identical(review_evidence_fingerprint(first), review_evidence_fingerprint(review_evidence_snapshot(df)))
  unavailable <- review_evidence_snapshot(df, validation = data.frame(dtxsid = "DTXSID1", outcome = "unavailable"))
  rejected <- review_evidence_snapshot(df, validation = data.frame(dtxsid = "DTXSID1", outcome = "rejected"))
  expect_false(identical(review_evidence_fingerprint(unavailable), review_evidence_fingerprint(rejected)))
  expect_error(normalize_review_validation(data.frame(dtxsid = "DTXSID1", outcome = "timeout")), "Unsupported")
  final <- df
  final$consensus_dtxsid <- "DTXSID1"
  final$consensus_status <- "manual"
  snapshot <- review_evidence_snapshot(df, final)
  expect_false(identical(snapshot$automated, snapshot$final))
})

test_that("portable contract round trips through replay and RDS without rebasing", {
  df <- evidence_fixture()
  scope <- review_evidence_scope(df, 1, c("name", "cas", "source_file", "part"))
  current <- review_evidence_snapshot(df, row_indices = 1)
  original <- capture_review_decision(NULL, "portable", scope, current, "rejected", reason = "Reviewed explicitly")
  path <- tempfile(fileext = ".R")
  dput(original, path)
  replayed <- dget(path)
  expect_identical(validate_review_evidence(replayed), original)
  path <- tempfile(fileext = ".rds")
  saveRDS(original, path)
  expect_identical(validate_review_evidence(readRDS(path)), original)
})

test_that("unrelated candidate validation cannot change another decision snapshot", {
  df <- evidence_fixture()
  df$resolver_dtxsid_candidate[1] <- "DTXSID123"
  validation <- data.frame(dtxsid = c("DTXSID123", "DTXSID999"), outcome = "valid")
  before <- review_evidence_snapshot(df, row_indices = 1, validation = validation)
  validation$outcome[2] <- "rejected"
  expect_identical(review_evidence_fingerprint(before),
    review_evidence_fingerprint(review_evidence_snapshot(df, row_indices = 1, validation = validation)))
})

test_that("snapshots observe current source validation and ignore audit timestamps", {
  df <- evidence_fixture()[1, ]
  df$source_dtxsid <- " dtxsid123 "
  df$source_id_source_dtxsid_source_candidate_id <- "DTXSID123"
  df$source_id_source_dtxsid_validation_status <- "validated"
  df$source_id_source_dtxsid_validation_reason <- "fixture"
  df$source_id_source_dtxsid_authority <- "fixture-authority"
  df$source_id_source_dtxsid_authority_version <- "1"
  df$source_id_source_dtxsid_checked_at <- "yesterday"
  original <- review_evidence_snapshot(df)
  expect_equal(original$candidates$dtxsid, "DTXSID123")
  expect_equal(original$validation$outcome, "valid")
  df$source_id_source_dtxsid_checked_at <- "today"
  expect_identical(review_evidence_fingerprint(original), review_evidence_fingerprint(review_evidence_snapshot(df)))
  df$source_id_source_dtxsid_validation_status <- "unavailable"
  now <- review_evidence_snapshot(df, validation = original$validation)
  expect_equal(now$validation$outcome, "unavailable")
  expect_false(identical(review_evidence_fingerprint(original), review_evidence_fingerprint(now)))
})
