wqx_review_fixture <- function() {
  df <- tibble::tibble(original_row_id = 1:3,
    chemical_name = c("Cyhalothrin", "Methadone-d9", "TETRACYCLINES"),
    dtxsid = NA_character_, preferredName = c("Cyhalothrin", "Methadone-d9", "Tetracycline"),
    source_tier = c("wqx_exact", "wqx_exact", "wqx_fuzzy"),
    lookup_evidence_columns = "dtxsid", consensus_status = "wqx", consensus_dtxsid = NA_character_,
    consensus_source = NA_character_, consensus_name = preferredName,
    wqx_name = preferredName, wqx_cas = c("68085-85-8", NA, "60-54-8"),
    wqx_cas_status = c("valid", "missing", "valid"),
    wqx_cas_provenance = paste0("canonical:", tolower(preferredName)),
    wqx_cas_dtxsid_candidates = c("DTXSID111|DTXSID222", NA, "DTXSID333"),
    wqx_cas_lookup_status = c("candidate", "missing", "candidate"))
  init_resolution_state(df)
}

test_that("unreviewed WQX rows remain pending with attributed candidates", {
  df <- wqx_review_fixture()
  state <- list(resolution_state = df, merged_chemical_tags = list(chemical_name = "Name"))
  pending <- pending_rows(state)
  expect_equal(pending$row_index, 1:3)
  expect_equal(pending$pending_type, rep("wqx", 3))
  expect_match(pending$candidates[1], "DTXSID111")
  expect_equal(pending$wqx_cas_lookup_status[2], "missing")
  expect_equal(names(pending), names(empty_pending()))
  expect_false(review_completion(state, pending)$queue_complete)
  expect_false(review_completion(state, pending)$identity_review_complete)
  expect_true(all(is.na(df$consensus_dtxsid)))
})

test_that("explicit dispositions and reviewed WQX names retain their semantics", {
  df <- wqx_review_fixture()
  df <- set_row_flags(df, 1L, "VERIFIED", "Vocabulary is sufficient for this source")
  df <- set_row_flags(df, 2L, "FOLLOW-UP", "Need registry evidence")
  df <- set_row_flags(df, 3L, "BAD", "Excluded source record")
  state <- list(resolution_state = df, merged_chemical_tags = list(chemical_name = "Name"))
  expect_equal(nrow(pending_rows(state)), 0)
  expect_true(review_completion(state, pending_rows(state))$queue_complete)
  expect_false(review_completion(state, pending_rows(state))$identity_review_complete)
  expect_equal(df$row_flag_reason, c("Vocabulary is sufficient for this source", "Need registry evidence", "Excluded source record"))
  expect_false(any(identity_review_state(df)$identity_eligible))
  df$row_flag[] <- NA_character_
  df$consensus_source[] <- "manual_wqx"
  state$resolution_state <- df
  expect_equal(nrow(pending_rows(state)), 0)
  expect_true(review_completion(state, pending_rows(state))$identity_review_complete)
  expect_equal(review_completion(state, pending_rows(state))$accepted_identity_rows, 0)
})

test_that("manual WQX candidate selection cannot bypass source correspondence", {
  df <- wqx_review_fixture()[1, ]
  df$consensus_dtxsid <- "DTXSID111"
  df$consensus_status <- "manual"
  df$.pinned <- TRUE
  df$.resolution_method <- "manual"
  expect_false(identity_review_state(df)$identity_eligible)
  expect_match(identity_review_state(df)$identity_blockers, "wqx_correspondence_unconfirmed")
  state <- list(resolution_state = df, merged_chemical_tags = list(chemical_name = "Name"))
  expect_equal(pending_rows(state)$pending_type, "identity_scope")
  testthat::local_mocked_bindings(validate_manual_dtxsids = function(ids) {
    tibble::tibble(searchValue = ids, dtxsid = ids, preferredName = "Candidate", is_valid = TRUE)
  })
  decision <- list(selector = list(original_row_id = 1L, chemical_name = "Cyhalothrin"),
    action = "accept", scope = "substance", conflict = "none", reason = "Reviewed exact source scope",
    evidence_reference = "Mock authoritative record and source specification",
    selected_dtxsid = "DTXSID111", correspondence = TRUE,
    evidence_fingerprint = identity_evidence_fingerprint(df, 1L))
  accepted <- apply_identity_decisions(state, list(decision))
  expect_true(identity_review_state(accepted$resolution_state)$identity_eligible)
  expect_equal(accepted$resolution_state$wqx_cas_dtxsid_candidates, "DTXSID111|DTXSID222")
  changed <- accepted$resolution_state
  changed$wqx_cas_dtxsid_candidates <- "DTXSID444"
  expect_false(identity_review_state(changed)$identity_eligible)
})

test_that("WQX evidence snapshots retain normalization and detect changed provenance", {
  df <- wqx_review_fixture()[1, ]
  candidates <- normalize_review_candidates(df)
  expect_equal(candidates$dtxsid, c("DTXSID111", "DTXSID222"))
  expect_equal(candidates$query, rep("68085-85-8", 2))
  expect_equal(candidates$role, rep("vocabulary_cas_candidate", 2))
  before <- review_evidence_snapshot(df)
  df$wqx_cas_provenance <- "canonical:changed"
  after <- review_evidence_snapshot(df)
  expect_false(identical(review_evidence_fingerprint(before), review_evidence_fingerprint(after)))
  df$wqx_cas_dtxsid_candidates <- "DTXSID222|DTXSID111|DTXSID111"
  expect_identical(normalize_review_candidates(df), candidates)
})

test_that("WQX evidence reaches source review controls without raw metadata promotion", {
  df <- wqx_review_fixture()[1, ]
  panel <- as.character(source_identifier_review_panel(df, 1L, list(chemical_name = "Name")))
  expect_match(panel, "68085-85-8", fixed = TRUE)
  expect_match(panel, "DTXSID111", fixed = TRUE)
  expect_match(panel, "review evidence", fixed = TRUE)
  df$lookup_evidence_columns <- "dtxsid_lookup_chemical_name"
  df$dtxsid_lookup_chemical_name <- NA_character_
  expect_equal(nrow(normalize_review_candidates(df)), 0)
})

test_that("query records remain selectable without expanding default review rows", {
  fields <- c("name", "wqx_cas", "resolver_query_details", "pubchem_query_details", "Resolution")
  visible <- derive_default_visible_review_columns("name", c(name = "Name"), fields)
  expect_false(any(c("resolver_query_details", "pubchem_query_details") %in% visible))
  expect_true(all(c("name", "wqx_cas", "Resolution") %in% visible))
  expect_true(all(c("resolver_query_details", "pubchem_query_details") %in%
    derive_review_column_choices("name", fields)))
})
