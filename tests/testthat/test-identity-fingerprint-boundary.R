fingerprint_fixture <- function() {
  tibble::tibble(original_row_id = 27L, name = "Registered combination", cas = "1-23-4",
    consensus_dtxsid = "DTXSID123", consensus_status = "single", consensus_source = "cas",
    dtxsid_cas = "DTXSID123", multi_analyte_resolution = "keep_combined",
    identity_conflict = "source_name_cas", source_file = "batch-inventory.csv",
    source_context = "Reviewed composition lot A", source_id = "DTXSID123",
    media = "stormwater", study_date = "2015-03-15", duration = 2, duration_unit = "day")
}

fingerprint_decision <- function(df) {
  list(selector = list(original_row_id = 27L, name = df$name, cas = df$cas),
    action = "accept", scope = "registered_mixture", conflict = "none", selected_dtxsid = "DTXSID123",
    correspondence = TRUE, reason = "Reviewed registered composition and original source context",
    evidence_reference = "mock:registry-and-source", evidence_fingerprint = identity_evidence_fingerprint(df, 1))
}

test_that("scoped registered mixture remains accepted through actual harmonization and workbook", {
  local_mocked_bindings(validate_manual_dtxsids = function(dtxsids, ...) {
    tibble::tibble(dtxsid = dtxsids, is_valid = TRUE)
  })
  before <- fingerprint_fixture()
  reviewed <- apply_identity_decisions(list(resolution_state = before), list(fingerprint_decision(before)))$resolution_state
  expect_true(identity_review_state(reviewed)$identity_eligible)
  units <- tibble::tibble(from_unit = "day", to_unit = "hr", multiplier = 24,
    category = "duration", confidence = "HIGH", source = "test")
  media <- tibble::tibble(term = "stormwater", canonical = "surface water", canonical_term = "surface water",
    envo_id = "ENVO:00002042", parent = NA_character_, media_category = "aqueous", source = "user", active = TRUE)
  runtime <- run_harmonization_runtime(reviewed,
    list(name = "Name", cas = "CASRN", media = "Media", study_date = "StudyDate",
         duration = "Duration", duration_unit = "DurationUnit"), units, media_map = media)
  expect_identical(runtime$data$media, "surface water")
  expect_equal(runtime$data$study_duration_value, 48)
  expect_equal(runtime$data$year, 2015)
  expect_true(identity_review_state(runtime$data)$identity_eligible)
  expect_identical(identity_evidence_fingerprint(runtime$data, 1), identity_evidence_fingerprint(reviewed, 1))
  expect_identical(runtime$data$source_file, before$source_file)
  expect_identical(runtime$data$source_context, before$source_context)
  expect_identical(runtime$data$name, before$name)
  expect_identical(runtime$data$cas, before$cas)
  expect_identical(runtime$data$source_id, before$source_id)
  runtime$data$unrelated_plot_label <- "New display annotation"
  expect_true(identity_review_state(runtime$data)$identity_eligible)
  path <- tempfile(fileext = ".xlsx")
  withr::defer(unlink(path))
  writexl::write_xlsx(runtime$data, path)
  restored <- readxl::read_xlsx(path)
  expect_true(identity_review_state(restored)$identity_eligible)
  record <- jsonlite::fromJSON(restored$identity_decision_record)
  expect_identical(record$version, "2")
  expect_true(all(c("source_context", "source_file", "source_id", "name", "cas") %in% record$evidence_columns))
  expect_false("unrelated_plot_label" %in% record$evidence_columns)
})

test_that("captured source context and new chemical evidence still invalidate decisions", {
  local_mocked_bindings(validate_manual_dtxsids = function(dtxsids, ...) {
    tibble::tibble(dtxsid = dtxsids, is_valid = TRUE)
  })
  before <- fingerprint_fixture()
  reviewed <- apply_identity_decisions(list(resolution_state = before), list(fingerprint_decision(before)))$resolution_state
  changes <- list(cas = "9-87-6", name = "Other entity", source_context = "Different composition lot",
    source_file = "different-inventory.csv", source_id = "DTXSID456", dtxsid_cas = "DTXSID456",
    resolver_dtxsid_candidate = "DTXSID456", pubchem_dtxsid_candidates = "12:DTXSID456",
    source_id_source_validation_status = "unavailable", parent_dtxsid_candidates = "DTXSID456",
    multi_analyte_part_index = 2L, source_cas = "9-87-6")
  for (col in names(changes)) {
    changed <- reviewed
    changed[[col]] <- changes[[col]]
    expect_false(identity_review_state(changed)$identity_eligible, info = col)
    expect_match(identity_review_state(changed)$identity_blockers, "stale_scope_decision", info = col)
  }
  missing_context <- reviewed
  missing_context$source_context <- NULL
  expect_false(identity_review_state(missing_context)$identity_eligible)
})

test_that("old v1 records retain conservative verification without inferred scope migrations", {
  local_mocked_bindings(validate_manual_dtxsids = function(dtxsids, ...) {
    tibble::tibble(dtxsid = dtxsids, is_valid = TRUE)
  })
  before <- fingerprint_fixture()
  reviewed <- apply_identity_decisions(list(resolution_state = before), list(fingerprint_decision(before)))$resolution_state
  record <- jsonlite::fromJSON(reviewed$identity_decision_record)
  record$version <- "1"
  record$evidence_columns <- NULL
  signature <- identity_fingerprint_v1(reviewed, 1)
  record$applied_fingerprint <- signature
  reviewed$identity_decision_fingerprint <- signature
  reviewed$identity_decision_record <- as.character(jsonlite::toJSON(record, auto_unbox = TRUE))
  expect_true(identity_review_state(reviewed)$identity_eligible)
  reviewed$cas <- "9-87-6"
  expect_false(identity_review_state(reviewed)$identity_eligible)
})

test_that("explicit legacy replay decisions require their exact prior evidence and preserve provenance", {
  local_mocked_bindings(validate_manual_dtxsids = function(dtxsids, ...) {
    tibble::tibble(dtxsid = dtxsids, is_valid = TRUE)
  })
  before <- fingerprint_fixture()
  # Replay decisions are applied after init_resolution_state(). Capture the old
  # exact evidence at that same boundary, without rewriting its stored hash.
  initialized <- init_resolution_state(before)
  decision <- fingerprint_decision(initialized)
  decision$evidence_fingerprint <- identity_fingerprint_v1(initialized, 1)
  reviewed <- apply_identity_decisions(list(resolution_state = before), list(decision))$resolution_state
  expect_true(identity_review_state(reviewed)$identity_eligible)
  record <- jsonlite::fromJSON(reviewed$identity_decision_record)
  expect_identical(record$evidence_fingerprint, decision$evidence_fingerprint)
  expect_identical(record$version, "2")
  changed <- before
  changed$source_context <- "Different source composition"
  expect_error(apply_identity_decisions(list(resolution_state = changed), list(decision)), "evidence changed")
})


test_that("malformed persisted identity versions fail closed", {
  df <- tibble::tibble(consensus_dtxsid = "DTXSID123", consensus_status = "manual",
    identity_scope = "registered_mixture", identity_decision_fingerprint = "identity-v2:invalid")
  for (record in c('{}', '{"version":null}', '{"version":["1","2"]}')) {
    df$identity_decision_record <- record
    expect_false(identity_decision_current_rows(df))
    expect_false(identity_review_state(df)$identity_eligible)
  }
})
