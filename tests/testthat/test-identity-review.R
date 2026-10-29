test_that("accepted identity policy blocks unresolved scope and dispositions", {
  df <- tibble::tibble(
    consensus_dtxsid = rep("DTXSID123", 8),
    consensus_status = c("single", "agree", "manual", "single", "suggested", "error", "single", "mystery"),
    row_flag = c(NA, "FOLLOW-UP", "BAD", NA, NA, "VERIFIED", NA, NA),
    identity_conflict = c(NA, NA, NA, "source_name_cas", NA, NA, NA, NA),
    needs_review = c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE)
  )
  out <- identity_review_state(df)
  expect_identical(out$identity_eligible, c(TRUE, rep(FALSE, 7)))
  expect_identical(out$accepted_dtxsid, c("DTXSID123", rep(NA_character_, 7)))
  expect_equal(nrow(accepted_identity_view(df)), 1)
  expect_equal(df$consensus_dtxsid, rep("DTXSID123", 8))
  expect_match(out$identity_blockers[4], "source_conflict")
})

test_that("blank and name-only evidence never manufacture accepted IDs", {
  df <- tibble::tibble(consensus_dtxsid = c(NA, "", " ", "junk"), consensus_status = "wqx")
  expect_false(any(identity_review_state(df)$identity_eligible))
  expect_equal(nrow(identity_review_state(df[0, ])), 0)
  expect_false(identity_review_state(tibble::tibble(x = 1))$identity_eligible)
})

test_that("registered mixtures require a current explicit scope decision", {
  df <- tibble::tibble(consensus_dtxsid = "DTXSID123", consensus_status = "manual",
    multi_analyte_resolution = "keep_combined", identity_scope = "registered_mixture",
    identity_scope_reviewed = TRUE, identity_decision_current = FALSE)
  expect_false(identity_review_state(df)$identity_eligible)
  df$identity_decision_current <- TRUE
  expect_false(identity_review_state(df)$identity_eligible)
  df$identity_scope <- "aggregate"
  expect_false(identity_review_state(df)$identity_eligible)
})

test_that("accepted ToxVal mapping preserves rows and blocks raw ID fallback", {
  df <- tibble::tibble(consensus_dtxsid = c("DTXSID123", NA), dtxsid = "DTXSID456",
    consensus_status = c("single", "error"), row_flag = c("FOLLOW-UP", NA))
  h <- tibble::tibble(orig_row_id = 1:2, orig_unit = "mg/L", harmonized_value = c(1, 2),
    harmonized_unit = "mg/L", conversion_factor = 1, unit_flag = "")
  out <- map_to_toxval_schema(df, h, identity_mode = "accepted")
  expect_identical(out$dtxsid, c(NA_character_, NA_character_))
  expect_equal(out$toxval_numeric, c(1, 2))
  expect_equal(map_to_toxval_schema(df, h)$dtxsid, c("DTXSID123", "DTXSID456"))
})

test_that("headless accepted ToxVal mode keeps measurements and replays explicit compatibility choice", {
  df <- tibble::tibble(original_row_id = 1:2, consensus_dtxsid = "DTXSID123",
    consensus_status = "single", row_flag = c("FOLLOW-UP", NA), result = c("1", "2"), unit = "mg/L")
  refs <- resolve_harmonization_references()
  runtime <- run_harmonization_runtime(df, list(result = "Result", unit = "Unit"),
    unit_map = refs$unit_map, corrections = refs$corrections, media_map = refs$media_map,
    toxval_identity_mode = "accepted")
  expect_identical(runtime$toxval_output$dtxsid, c(NA_character_, "DTXSID123"))
  expect_equal(runtime$toxval_output$toxval_numeric, c(1, 2))
  script <- generate_concert_script("input.csv", "output.xlsx", list(result = "Result", unit = "Unit"), 1L,
    harmonize = TRUE, toxval_identity_mode = "accepted")
  expect_match(script, 'toxval_identity_mode = "accepted"', fixed = TRUE)
})

test_that("a fraction qualifier on a bare-nutrient identity blocks it, whatever the status (#129)", {
  df <- tibble::tibble(
    consensus_dtxsid = c("DTXSID4036304", "DTXSID4036304", "DTXSID7039672", "DTXSID7039672", "DTXSID1020000"),
    consensus_status = "single",
    cleaning_flag = c(
      "WARNING: measurement qualifier [total, as N]", NA,
      "WARNING: measurement qualifier [as PO4]", "WARNING: measurement qualifier [total, as PO4]",
      "WARNING: measurement qualifier [total]"
    )
  )
  # Nitrogen, total (as N) | Nitrogen | Phosphate, ortho (as PO4) | Phosphate, total | Aluminum, total
  out <- identity_review_state(df)
  expect_identical(out$identity_eligible, c(FALSE, TRUE, TRUE, FALSE, TRUE))
  expect_match(out$identity_blockers[1], "unresolved_scope")

  local_mocked_bindings(validate_manual_dtxsids = function(dtxsids, ...) {
    tibble::tibble(dtxsid = dtxsids, is_valid = TRUE)
  })
  row <- tibble::tibble(original_row_id = 1L, name = "Nitrogen, total", consensus_dtxsid = "DTXSID4036304",
    consensus_status = "single", consensus_source = "name", dtxsid_name = "DTXSID4036304",
    cleaning_flag = "WARNING: measurement qualifier [total]")
  decision <- list(selector = list(original_row_id = 1L, name = "Nitrogen, total"),
    action = "accept", scope = "substance", conflict = "none", selected_dtxsid = "DTXSID4036304",
    correspondence = TRUE, reason = "Reviewer confirms N2", evidence_reference = "fixture",
    evidence_fingerprint = identity_evidence_fingerprint(row, 1))
  reviewed <- apply_identity_decisions(list(resolution_state = row), list(decision))$resolution_state
  expect_true(identity_review_state(reviewed)$identity_eligible)
})

test_that("the measurement-qualifier warning does not change identity fingerprints (#129)", {
  row <- tibble::tibble(original_row_id = 1L, name = "Copper, dissolved", consensus_dtxsid = "DTXSID1020000",
    cleaning_flag = c(NA, "WARNING: potential multi-analyte"))
  flagged <- row
  flagged$cleaning_flag <- c("WARNING: measurement qualifier [dissolved]",
    "WARNING: potential multi-analyte; WARNING: measurement qualifier [dissolved, as N]")
  for (i in 1:2) {
    expect_identical(identity_fingerprint_v2(flagged, i), identity_fingerprint_v2(row, i))
    expect_identical(identity_fingerprint_v1(flagged, i), identity_fingerprint_v1(row, i))
  }
})
