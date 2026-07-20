review_fixture <- function() {
  # Two flagged rows plus a clean row, with a primary + secondary CAS column.
  tibble::tibble(
    original_row_id = 1:3,
    analyte = c(
      "HFPO Dimer Acid and HFPO Dimer Acid Ammonium Salt",
      "Perfluorobutane sulfonate (PFBS)",
      "acetone"
    ),
    casrn = c("13252-13-6", "375-73-5", "67-64-1"),
    cas_extract_casrn_2 = c("62037-80-3", "45187-15-3", NA_character_),
    cleaning_flag = c("WARNING: potential multi-analyte", NA_character_, NA_character_),
    multi_cas = c(TRUE, TRUE, FALSE),
    multi_cas_count = c(2L, 2L, 1L)
  )
}

test_that("position pairing splits name and CAS one-to-one (GenX case)", {
  df <- review_fixture()

  result <- resolve_review_row(
    df,
    name_cols = "analyte",
    row_index = 1L,
    spec = list(
      name_action = "split",
      name_parts = c("HFPO Dimer Acid", "HFPO Dimer Acid Ammonium Salt"),
      cas_parts = c("13252-13-6", "62037-80-3"),
      pairing = "position"
    ),
    cas_cols = c("casrn", "cas_extract_casrn_2")
  )
  cleaned <- result$cleaned_data

  expect_equal(nrow(cleaned), 4)
  expect_equal(cleaned$analyte[1:2], c("HFPO Dimer Acid", "HFPO Dimer Acid Ammonium Salt"))
  expect_equal(cleaned$casrn[1:2], c("13252-13-6", "62037-80-3"))
  # Secondary CAS column emptied so each child carries exactly one CAS.
  expect_true(all(is.na(cleaned$cas_extract_casrn_2[1:2])))
  expect_false(any(cleaned$multi_cas[1:2]))
  expect_false(any(is_multi_analyte_review_row(cleaned)[1:2]))
})

test_that("position pairing keeps a single name and splits CAS into rows (PFBS case)", {
  df <- review_fixture()

  result <- resolve_review_row(
    df,
    name_cols = "analyte",
    row_index = 2L,
    spec = list(
      name_action = "keep",
      cas_parts = c("375-73-5", "45187-15-3", "29420-49-3"),
      pairing = "position"
    ),
    cas_cols = c("casrn", "cas_extract_casrn_2")
  )
  cleaned <- result$cleaned_data

  # One kept name expands to three CAS-bearing rows.
  expect_equal(sum(cleaned$analyte == "Perfluorobutane sulfonate (PFBS)"), 3L)
  pfbs_rows <- which(cleaned$analyte == "Perfluorobutane sulfonate (PFBS)")
  expect_equal(cleaned$casrn[pfbs_rows], c("375-73-5", "45187-15-3", "29420-49-3"))
  expect_false(any(cleaned$multi_cas[pfbs_rows]))
  expect_equal(result$audit_trail$new_value, c("375-73-5", "45187-15-3", "29420-49-3"))
})

test_that("broadcast leaves CAS columns intact and clears the multi-CAS flag", {
  df <- review_fixture()

  result <- resolve_review_row(
    df,
    name_cols = "analyte",
    row_index = 2L,
    spec = list(name_action = "keep", pairing = "broadcast"),
    cas_cols = c("casrn", "cas_extract_casrn_2")
  )
  cleaned <- result$cleaned_data

  expect_equal(nrow(cleaned), 3)
  expect_equal(cleaned$casrn[2], "375-73-5")
  expect_equal(cleaned$cas_extract_casrn_2[2], "45187-15-3")
  expect_false(cleaned$multi_cas[2])
})

test_that("position pairing rejects mismatched name and CAS counts", {
  df <- review_fixture()

  expect_error(
    resolve_review_row(
      df,
      name_cols = "analyte",
      row_index = 1L,
      spec = list(
        name_action = "split",
        name_parts = c("a", "b"),
        cas_parts = c("1", "2", "3"),
        pairing = "position"
      ),
      cas_cols = c("casrn", "cas_extract_casrn_2")
    ),
    "position pairing requires"
  )
})

test_that("apply_review_resolutions applies staged decisions in descending row order", {
  df <- review_fixture()

  decisions <- list(
    "1" = list(
      name_action = "split",
      name_parts = c("HFPO Dimer Acid", "HFPO Dimer Acid Ammonium Salt"),
      cas_parts = c("13252-13-6", "62037-80-3"),
      pairing = "position"
    ),
    "2" = list(name_action = "keep", pairing = "broadcast")
  )

  result <- apply_review_resolutions(
    df,
    name_cols = "analyte",
    decisions = decisions,
    cas_cols = c("casrn", "cas_extract_casrn_2")
  )
  cleaned <- result$cleaned_data

  expect_equal(nrow(cleaned), 4)
  expect_equal(cleaned$analyte[1:2], c("HFPO Dimer Acid", "HFPO Dimer Acid Ammonium Salt"))
  expect_equal(cleaned$analyte[3], "Perfluorobutane sulfonate (PFBS)")
  expect_false(any(cleaned$multi_cas))
  expect_false(any(is_multi_analyte_review_row(cleaned)))
})
