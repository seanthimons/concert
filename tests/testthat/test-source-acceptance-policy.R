source_policy_fixture <- function(validation = "validated", correspondence = "identity_unconfirmed") {
  tibble::tibble(original_row_id = 7L, name = "Source substance", cas = "source-cas",
    consensus_dtxsid = "DTXSID123", consensus_status = "agree", consensus_source = "Name/CAS",
    dtxsid_name = "DTXSID123", dtxsid_cas = "DTXSID123", source_id = "DTXSID123",
    source_id_source_id_source_raw_id = "DTXSID123",
    source_id_source_id_source_candidate_id = "DTXSID123",
    source_id_source_id_validation_status = validation,
    source_id_source_id_identity_status = correspondence,
    source_id_source_id_validation_reason = "Retained authority result",
    source_id_source_id_authority = "Mock authority v1")
}

source_policy_decision <- function(df, selected_id = "DTXSID123") {
  list(selector = list(original_row_id = 7L, name = "Source substance", cas = "source-cas"),
    action = "accept", scope = "substance", conflict = "none", selected_dtxsid = selected_id,
    correspondence = TRUE, reason = "Reviewed source correspondence and retained conflicting metadata",
    evidence_reference = "mock:registry-and-source-v1", evidence_fingerprint = identity_evidence_fingerprint(df, 1))
}

test_that("source invalid unavailable and ambiguity block acceptance despite lookup agreement", {
  for (status in c("invalid_format", "not_found", "returned_id_mismatch", "unavailable", "ambiguous")) {
    df <- source_policy_fixture(status)
    out <- identity_review_state(df)
    expect_false(out$identity_eligible, info = status)
    expect_true(is.na(out$accepted_dtxsid), info = status)
    expect_match(out$identity_blockers, "source_identifier", info = status)
    df$row_flag <- "VERIFIED"
    df$.pinned <- TRUE
    expect_false(identity_review_state(df)$identity_eligible, info = status)
    expect_equal(nrow(accepted_identity_view(df)), 0L)
    expect_identical(df$source_id, "DTXSID123")
  }
})

test_that("validated unconfirmed source preserves legitimate Name/CAS compatibility", {
  df <- source_policy_fixture()
  expect_true(identity_review_state(df)$identity_eligible)
  df$source_id_source_id_source_raw_id <- NA_character_
  df$source_id_source_id_source_candidate_id <- NA_character_
  df$source_id_source_id_validation_status <- "invalid_format"
  expect_true(identity_review_state(df)$identity_eligible)
})

test_that("structured source identity conflicts and scope require current explicit decisions", {
  local_mocked_bindings(validate_manual_dtxsids = function(dtxsids, ...) {
    tibble::tibble(dtxsid = dtxsids, is_valid = TRUE)
  })
  for (conflict in c("identity_conflict", "scope_review")) {
    df <- source_policy_fixture(correspondence = conflict)
    expect_false(identity_review_state(df)$identity_eligible)
    out <- apply_identity_decisions(list(resolution_state = df), list(source_policy_decision(df)))$resolution_state
    expect_true(identity_review_state(out)$identity_eligible)
    expect_identical(out$source_id_source_id_identity_status, conflict)
    expect_identical(out$source_id_source_id_validation_reason, df$source_id_source_id_validation_reason)
    expect_identical(out$cas, df$cas)
    expect_identical(out$name, df$name)
    out$source_id_source_id_source_raw_id <- "DTXSID456"
    expect_false(identity_review_state(out)$identity_eligible)
  }
})

test_that("promoting matching source IDs requires source validation plus correspondence and membership", {
  membership_calls <- 0L
  local_mocked_bindings(validate_manual_dtxsids = function(dtxsids, ...) {
    membership_calls <<- membership_calls + 1L
    tibble::tibble(dtxsid = dtxsids, is_valid = TRUE)
  })
  for (status in c("unavailable", "not_found", "ambiguous", "invalid_format", "returned_id_mismatch")) {
    df <- source_policy_fixture(status)
    expect_error(apply_identity_decisions(list(resolution_state = df), list(source_policy_decision(df))), "Source-ID promotion")
  }
  expect_equal(membership_calls, 0L)
  df <- source_policy_fixture()
  decision <- source_policy_decision(df)
  decision$correspondence <- FALSE
  expect_error(apply_identity_decisions(list(resolution_state = df), list(decision)), "correspondence")
  out <- apply_identity_decisions(list(resolution_state = df), list(source_policy_decision(df)))$resolution_state
  expect_true(identity_review_state(out)$identity_eligible)
  expect_equal(membership_calls, 1L)

  # A different independently validated selection may resolve conflicting source
  # metadata through an explicit scoped decision without rewriting that metadata.
  df <- source_policy_fixture("not_found", "identity_conflict")
  out <- apply_identity_decisions(list(resolution_state = df), list(source_policy_decision(df, "DTXSID456")))$resolution_state
  expect_true(identity_review_state(out)$identity_eligible)
  expect_identical(out$source_id, "DTXSID123")
  expect_identical(out$source_id_source_id_validation_status, "not_found")
  expect_identical(out$consensus_dtxsid, "DTXSID456")
})

test_that("current source correspondence decisions survive workbook and reject changed evidence", {
  local_mocked_bindings(validate_manual_dtxsids = function(dtxsids, ...) {
    tibble::tibble(dtxsid = dtxsids, is_valid = TRUE)
  })
  df <- source_policy_fixture(correspondence = "identity_conflict")
  out <- apply_identity_decisions(list(resolution_state = df), list(source_policy_decision(df)))$resolution_state
  path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(path))
  writexl::write_xlsx(out, path)
  restored <- readxl::read_xlsx(path)
  expect_true(identity_review_state(restored)$identity_eligible)
  restored$source_id_source_id_validation_status <- "unavailable"
  restored$identity_decision_current <- TRUE
  expect_false(identity_review_state(restored)$identity_eligible)
  expect_match(identity_review_state(restored)$identity_blockers, "source_identifier_unavailable")
})

test_that("generic manual source-ID recovery cannot replace scoped correspondence review", {
  local_mocked_bindings(validate_manual_dtxsids = function(dtxsids, ...) {
    tibble::tibble(dtxsid = dtxsids, is_valid = TRUE)
  })
  df <- source_policy_fixture()
  df$dtxsid_name <- df$dtxsid_cas <- NA_character_
  df$lookup_evidence_columns <- "dtxsid_name;dtxsid_cas"
  df$consensus_status <- "manual"
  df$consensus_source <- "manual_entry"
  df$.manual_entry <- TRUE
  df$.pinned <- TRUE
  df$.resolution_method <- "manual"
  expect_false(identity_review_state(df)$identity_eligible)
  expect_match(identity_review_state(df)$identity_blockers, "source_correspondence_unconfirmed")
  expect_identical(df$source_id_source_id_validation_status, "validated")
  expect_identical(df$consensus_dtxsid, "DTXSID123")

  # A user-entered raw column with the reserved ID prefix is not an owned lookup.
  df$dtxsid_source_metadata <- "DTXSID123"
  expect_false(identity_review_state(df)$identity_eligible)
  unregistered <- df
  unregistered$lookup_evidence_columns <- NULL
  expect_false(identity_review_state(unregistered)$identity_eligible)
  df$row_flag <- "VERIFIED"
  expect_false(identity_review_state(df)$identity_eligible)
  spoofed <- df
  spoofed$source_id_source_id_identity_status <- "identity_confirmed"
  expect_false(identity_review_state(spoofed)$identity_eligible)

  resolved <- apply_identity_decisions(list(resolution_state = df), list(source_policy_decision(df)))$resolution_state
  expect_true(identity_review_state(resolved)$identity_eligible)
  expect_identical(resolved$source_id, df$source_id)
  expect_identical(resolved$source_id_source_id_identity_status, "identity_unconfirmed")
})

test_that("manual selection preserves independent registered lookup support and provenance", {
  df <- source_policy_fixture()
  df$lookup_evidence_columns <- "dtxsid_name;dtxsid_cas"
  df$consensus_status <- "manual"
  df$consensus_source <- "manual_entry"
  df$.manual_entry <- TRUE
  expect_true(identity_review_state(df)$identity_eligible)
  expect_identical(df$source_id_source_id_identity_status, "identity_unconfirmed")
  df$source_tier_name <- df$source_tier_cas <- "manual_entry"
  expect_false(identity_review_state(df)$identity_eligible)
})
