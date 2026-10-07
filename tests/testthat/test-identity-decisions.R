scope_fixture <- function() {
  tibble::tibble(original_row_id = 27L, name = "Registered combination", cas = "1-23-4",
    consensus_dtxsid = "DTXSID123", consensus_status = "single", consensus_source = "cas",
    dtxsid_cas = "DTXSID123", multi_analyte_resolution = "keep_combined",
    identity_conflict = "source_name_cas")
}
scope_decision <- function(df, action = "accept") {
  list(selector = list(original_row_id = 27L, name = "Registered combination", cas = "1-23-4"),
    action = action, scope = "registered_mixture", conflict = "none", selected_dtxsid = "DTXSID123",
    correspondence = TRUE, reason = "Source composition matches registered entity",
    evidence_reference = "fixture:authoritative-registry-and-source-v1",
    evidence_fingerprint = identity_evidence_fingerprint(df, 1))
}

test_that("registered mixtures need explicit current scoped evidence and separate membership", {
  local_mocked_bindings(validate_manual_dtxsids = function(dtxsids, ...) {
    tibble::tibble(dtxsid = dtxsids, is_valid = TRUE)
  })
  df <- scope_fixture()
  expect_false(identity_review_state(df)$identity_eligible)
  out <- apply_identity_decisions(list(resolution_state = df), list(scope_decision(df)))
  reviewed <- out$resolution_state
  expect_true(identity_review_state(reviewed)$identity_eligible)
  expect_equal(reviewed$name, df$name)
  expect_equal(reviewed$cas, df$cas)
  expect_equal(reviewed$dtxsid_cas, df$dtxsid_cas)
  record <- jsonlite::fromJSON(reviewed$identity_decision_record)
  expect_equal(record$membership, "valid")
  expect_true(record$correspondence)
  expect_equal(record$evidence_fingerprint, identity_evidence_fingerprint(df, 1))
  expect_equal(out$identity_decisions, list(scope_decision(df)))

  # The durable record survives a workbook round trip; booleans are derived.
  path <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(reviewed, path)
  restored <- readxl::read_xlsx(path)
  expect_true(identity_review_state(restored)$identity_eligible)
  restored$identity_decision_current <- TRUE
  restored$cas <- "9-87-6"
  expect_false(identity_review_state(restored)$identity_eligible)
  expect_match(identity_review_state(restored)$identity_blockers, "stale_scope_decision")
  reviewed$dtxsid_cas <- "DTXSID999"
  expect_false(identity_review_state(reviewed)$identity_eligible)
})

test_that("scope decisions reject ambiguity, stale evidence and correspondence shortcuts", {
  local_mocked_bindings(validate_manual_dtxsids = function(dtxsids, ...) {
    tibble::tibble(dtxsid = dtxsids, is_valid = NA)
  })
  df <- scope_fixture()
  decision <- scope_decision(df)
  expect_error(apply_identity_decisions(list(resolution_state = df), list(decision)), "invalid or unavailable")
  decision$correspondence <- FALSE
  expect_error(apply_identity_decisions(list(resolution_state = df), list(decision)), "correspondence")
  decision <- scope_decision(df)
  decision$selector <- list(name = df$name, cas = df$cas)
  expect_error(apply_identity_decisions(list(resolution_state = df), list(decision)), "original_row_id")
  decision <- scope_decision(df)
  expect_error(apply_identity_decisions(list(resolution_state = dplyr::bind_rows(df, df)), list(decision)), "exactly one")
  df$cas <- "9-87-6"
  decision$selector$cas <- df$cas
  expect_error(apply_identity_decisions(list(resolution_state = df), list(decision)), "evidence changed")
})

test_that("retain aggregate and explicit conflicts withstand flags, picks and bulk acceptance", {
  df <- scope_fixture()
  decision <- scope_decision(df, "retain_unresolved")
  decision$scope <- "aggregate"
  decision$conflict <- "scope"
  out <- apply_identity_decisions(list(resolution_state = df), list(decision))$resolution_state
  out$row_flag <- "VERIFIED"
  out$.pinned <- TRUE
  out$consensus_status <- "manual"
  expect_false(identity_review_state(out)$identity_eligible)
  out$row_flag <- NA_character_
  out$.pinned <- FALSE
  out$consensus_status <- "suggested"
  out$.suggested_column <- "dtxsid_cas"
  bulk <- accept_all_suggestions(out, "dtxsid_cas")
  expect_false(bulk$.pinned)
  expect_false(identity_review_state(bulk)$identity_eligible)
})

test_that("unspaced credible lists flag and suggest without treating units or syntax as lists", {
  positive <- c("Febantel/Fenbendazole/Oxfendazole", "Chlortetracycline/Oxytetracycline/Tetracycline")
  negative <- c("mg/L", "w/w", "1.5/1", "endosulfan (alpha/beta)", "cis/trans", "alpha/beta/gamma", "epsilon/delta/omega")
  expect_equal(has_multi_analyte_separator(c(positive, negative)), c(TRUE, TRUE, rep(FALSE, length(negative))))
  expect_equal(suggest_multi_analyte_parts(positive[1]), c("Febantel", "Fenbendazole", "Oxfendazole"))
  expect_equal(precheck_multi_analyte(tibble::tibble(name = positive), "name")$est_changes, 2L)
  flagged <- flag_multi_analyte(tibble::tibble(name = c(positive, negative)), "name")$cleaned_data
  expect_equal(is_multi_analyte_review_row(flagged), c(TRUE, TRUE, rep(FALSE, length(negative))))
})

test_that("splitting preserves CAS evidence and blocks unreviewed component broadcasts", {
  df <- tibble::tibble(original_row_id = 27L, name = "Acetone / Ethanol", cas = "67-64-1",
    cleaning_flag = multi_analyte_warning_label())
  result <- resolve_review_row(df, "name", 1L,
    spec = list(name_action = "split", name_parts = c("Acetone", "Ethanol"), pairing = "broadcast"),
    cas_cols = "cas")$cleaned_data
  expect_equal(result$cas, rep("67-64-1", 2))
  expect_equal(result$multi_analyte_source_cas, rep("67-64-1", 2))
  expect_true(all(result$component_cas_unresolved))
  expect_equal(result$multi_analyte_part_index, 1:2)
  result$consensus_dtxsid <- "DTXSID123"
  result$consensus_status <- "single"
  expect_false(any(identity_review_state(result)$identity_eligible))
})

test_that("row and content scope survives reorder and requires exact component CAS mapping", {
  local_mocked_bindings(validate_manual_dtxsids = function(dtxsids, ...) {
    tibble::tibble(dtxsid = dtxsids, is_valid = TRUE)
  })
  df <- scope_fixture()
  other <- df
  other$original_row_id <- 28L
  reordered <- dplyr::bind_rows(other, df)
  applied <- apply_identity_decisions(list(resolution_state = reordered), list(scope_decision(df)))$resolution_state
  expect_equal(which(identity_review_state(applied)$identity_eligible), 2L)

  split <- tibble::tibble(original_row_id = 27L, name = "Acetone / Ethanol", cas = "67-64-1",
    cleaning_flag = multi_analyte_warning_label())
  spec <- list(name_action = "split", name_parts = c("Acetone", "Ethanol"), pairing = "position",
    cas_parts = "67-64-1")
  repeated <- resolve_review_row(split, "name", 1L, spec, cas_cols = "cas")$cleaned_data
  expect_true(all(repeated$component_cas_unresolved))
  spec$cas_parts <- c("67-64-1", "64-17-5")
  mapped <- resolve_review_row(split, "name", 1L, spec, cas_cols = "cas")$cleaned_data
  expect_false(any(mapped$component_cas_unresolved))
  expect_equal(mapped$cas, spec$cas_parts)
})
