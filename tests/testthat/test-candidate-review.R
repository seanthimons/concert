candidate_fixture <- function() {
  data.frame(name = "Prochloraz-d4", cas = "source-cas", source_file = "inventory", part = "isotope",
    consensus_dtxsid = NA_character_, consensus_status = "unresolvable",
    row_flag = "FOLLOW-UP", row_flag_reason = "Human isotope rejection remains",
    resolver_dtxsid_candidate = NA_character_, resolver_lookup_status = "no_hit",
    pubchem_dtxsid_candidates = NA_character_, pubchem_query = "Prochloraz-d4", source_dtxsid = NA_character_)
}

candidate_capture <- function(df, disposition = "no_hit", validation = NULL) {
  columns <- c("name", "cas", "source_file", "part")
  args <- list(automated = df, validation = validation)
  if ("scope_cols" %in% names(formals(review_evidence_snapshot))) args$scope_cols <- columns
  capture_review_decision(NULL, review_decision_key(df$name, df$cas),
    review_evidence_scope(df, 1, columns), do.call(review_evidence_snapshot, args),
    disposition, df$row_flag, df$row_flag_reason)
}

candidate_report <- function(df, evidence = NULL, ...) {
  build_candidate_review(df, evidence = evidence, name_col = "name", cas_col = "cas",
    scope_cols = c("name", "cas", "source_file", "part"), ...)
}

test_that("captured no-hit becoming candidate is actionable while flags and identity survive", {
  before <- candidate_fixture()
  evidence <- candidate_capture(before)
  df <- before
  df$resolver_dtxsid_candidate <- "DTXSID7043792"
  df$resolver_lookup_status <- "unverified"
  validation <- data.frame(dtxsid = "DTXSID7043792", outcome = "unavailable", authority = "mock", version = "v1")
  report <- candidate_report(df, evidence, validation = validation)
  expect_identical(report$status, "candidate_validation")
  expect_true(report$actionable)
  expect_match(report$validation_outcomes, "unavailable")
  expect_identical(report$flag, "FOLLOW-UP")
  expect_identical(report$reason, before$row_flag_reason)
  expect_true(is.na(df$consensus_dtxsid))
  expect_identical(evidence, unserialize(serialize(evidence, NULL)))
})

test_that("candidate attribution includes CID and conflicts without majority selection", {
  before <- candidate_fixture()
  evidence <- candidate_capture(before)
  df <- before
  df$source_dtxsid <- "DTXSID8023472"
  df$pubchem_dtxsid_candidates <- "99:DTXSID8023472"
  df$resolver_dtxsid_candidate <- "DTXSID101511904"
  report <- candidate_report(df, evidence)
  expect_true(report$actionable)
  expect_match(report$candidates, "pubchem\\|Prochloraz-d4\\|99\\|DTXSID8023472")
  expect_match(report$candidates, "source:source_dtxsid")
  expect_match(report$candidates, "DTXSID101511904")
  expect_true(is.na(df$consensus_dtxsid))
  df$resolver_dtxsid_candidate <- NA_character_
  expect_true(candidate_report(df, evidence)$actionable)
})

test_that("unchanged rejected and deferred candidates do not reopen for order or outages", {
  df <- candidate_fixture()
  df$resolver_dtxsid_candidate <- "DTXSID2;DTXSID1"
  rejected <- data.frame(dtxsid = "DTXSID1", outcome = "rejected", authority = "mock", version = "v1", reason = "Not registered")
  for (disposition in c("rejected", "deferred")) {
    evidence <- candidate_capture(df, disposition, rejected)
    reordered <- df
    reordered$resolver_dtxsid_candidate <- "DTXSID1;DTXSID2;DTXSID1"
    reordered$resolver_lookup_status <- "unverified"
    validation <- data.frame(dtxsid = "DTXSID1", outcome = "unavailable", authority = "mock", version = "v2")
    report <- candidate_report(reordered, evidence, validation = validation)
    expect_false(report$actionable)
    expect_identical(report$status, "already_dispositioned")
    expect_match(report$prior_validation_outcomes, "rejected")
    expect_match(report$reason, "isotope")
    reordered$resolver_dtxsid_candidate <- "DTXSID1;DTXSID2;DTXSID3"
    expect_true(candidate_report(reordered, evidence)$actionable)
  }
})

test_that("legacy reasons do not create baselines and malformed pairs do not create work", {
  df <- candidate_fixture()
  df$pubchem_dtxsid_candidates <- ":;12:;:DTXSID1"
  report <- candidate_report(df)
  expect_identical(report$status, "baseline_missing")
  expect_false(report$actionable)
  expect_true(is.na(report$candidates))
  expect_identical(report$reason, df$row_flag_reason)
  df$resolver_dtxsid_candidate <- "DTXSID1"
  report <- candidate_report(df)
  expect_identical(report$status, "baseline_missing")
  expect_false(report$actionable)
  evidence <- candidate_capture(df, "rejected")
  df$row_flag <- "BAD"
  df$resolver_dtxsid_candidate <- "DTXSID2"
  expect_false(candidate_report(df, evidence)$actionable)
  df$consensus_dtxsid <- "DTXSID1"
  expect_equal(nrow(candidate_report(df, evidence)), 0L)
})

test_that("acknowledgments bind candidate work to decision revision and source content", {
  before <- candidate_fixture()
  evidence <- candidate_capture(before)
  current <- before
  current$resolver_dtxsid_candidate <- "DTXSID1"
  cols <- c("name", "cas", "source_file", "part")
  args <- list(automated = current)
  if ("scope_cols" %in% names(formals(review_evidence_snapshot))) args$scope_cols <- cols
  evidence <- acknowledge_review_evidence(evidence, review_decision_key(before$name, before$cas), 1L,
    review_evidence_scope(current, 1, cols), do.call(review_evidence_snapshot, args))
  expect_false(candidate_report(current, evidence)$actionable)
  expect_identical(candidate_report(current, evidence)$status, "acknowledged")
  current$part <- "other-salt"
  expect_true(candidate_report(current, evidence)$actionable)
  expect_identical(candidate_report(current, evidence)$change_reason, "scope_changed")
  path <- tempfile(fileext = ".R")
  on.exit(unlink(path))
  dput(evidence, path)
  expect_identical(candidate_report(current, dget(path)), candidate_report(current, evidence))
})

test_that("meaningful versioned validation changes reopen but missing data does not", {
  df <- candidate_fixture()
  df$resolver_dtxsid_candidate <- "DTXSID1"
  rejected <- data.frame(dtxsid = "DTXSID1", outcome = "rejected", authority = "mock", version = "v1")
  evidence <- candidate_capture(df, "rejected", rejected)
  expect_false(candidate_report(df, evidence)$actionable)
  valid <- transform(rejected, outcome = "valid", version = "v2")
  expect_true(candidate_report(df, evidence, validation = valid)$actionable)
  expect_identical(candidate_report(df, evidence, validation = valid)$change_reason, "validation_changed")
})

test_that("explicit validators distinguish rejection from outages and cache by authority version", {
  calls <- 0L
  service <- function(id) {
    calls <<- calls + 1L
    if (id == "DTXSID1") return(data.frame(dtxsid = id, outcome = "valid"))
    if (id == "DTXSID2") return(data.frame(dtxsid = id, outcome = "rejected", reason = "No exact record"))
    stop("Authority unavailable")
  }
  result <- validate_review_candidates(c("DTXSID1", "DTXSID2", "DTXSID3", "DTXSID1"), service, "mock", "v1")
  expect_identical(result$validation$outcome, c("valid", "rejected", "unavailable"))
  expect_equal(calls, 3L)
  cached <- validate_review_candidates(c("DTXSID1", "DTXSID2", "DTXSID3"), service, "mock", "v1", result$cache)
  expect_equal(calls, 4L)
  expect_identical(cached$validation, result$validation)
  validate_review_candidates("DTXSID1", service, "mock", "v2", result$cache)
  expect_equal(calls, 5L)
  validate_review_candidates("DTXSID2", service, "mock", "v1", result$cache, refresh = TRUE)
  expect_equal(calls, 6L)
  invalid <- validate_review_candidates(c("bogus", ":"), service, "mock", "v1")
  expect_true(all(invalid$validation$outcome == "invalid"))
  expect_equal(calls, 6L)
  empty <- validate_review_candidates(character(), service, "mock", "v1")
  expect_equal(nrow(empty$validation), 0L)
  mismatch <- validate_review_candidates("DTXSID1", function(id) data.frame(dtxsid = "DTXSID2", outcome = "valid"), "mock", "v1")
  expect_identical(mismatch$validation$outcome, "ambiguous")
  unavailable <- validate_review_candidates("DTXSID1", function(id) NULL, "mock", "v1")
  expect_identical(unavailable$validation$outcome, "unavailable")
  expect_length(unavailable$cache$entries, 0L)
  expect_error(validate_review_candidates("DTXSID1", service, "mock", ""), "version")
})

test_that("candidate swaps across source records require review despite unchanged global set", {
  df <- candidate_fixture()[c(1, 1), ]
  df$source_file <- c("inventory-one", "inventory-two")
  df$resolver_dtxsid_candidate <- c("DTXSID1", "DTXSID2")
  flags <- data.frame(name = df$name[1], flag = "FOLLOW-UP", reason = "Group explicitly reviewed")
  columns <- c("name", "cas", "source_file", "part")
  evidence <- capture_review_decision(NULL, review_decision_key(df$name[1]),
    review_evidence_scope(df, 1:2, columns),
    review_evidence_snapshot(df, scope_cols = columns), "deferred", flags$flag, flags$reason)
  report <- build_candidate_review(df, row_flags = flags, evidence = evidence,
    name_col = "name", cas_col = "cas", scope_cols = columns)
  expect_false(any(report$actionable))
  swapped <- df
  swapped$resolver_dtxsid_candidate <- rev(swapped$resolver_dtxsid_candidate)
  changed <- build_candidate_review(swapped, row_flags = flags, evidence = evidence,
    name_col = "name", cas_col = "cas", scope_cols = columns)
  expect_true(all(changed$actionable))
  expect_true(all(changed$change_reason == "candidate_scope_changed"))
  reordered <- build_candidate_review(df[2:1, ], row_flags = flags, evidence = evidence,
    name_col = "name", cas_col = "cas", scope_cols = columns)
  expect_false(any(reordered$actionable))
})
