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
  expect_true(identity_review_state(df)$identity_eligible)
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
