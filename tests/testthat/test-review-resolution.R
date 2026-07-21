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

# --- Fan one decision to all rows sharing the same name + CAS (issue #55) -----

review_dup_fixture <- function() {
  # Three identical GenX rows (duplicate guidance values) + PFBS + a clean row.
  tibble::tibble(
    original_row_id = 1:5,
    analyte = c("GenX", "GenX", "GenX", "PFBS", "acetone"),
    casrn = c("13252-13-6", "13252-13-6", "13252-13-6", "375-73-5", "67-64-1"),
    cas_extract_casrn_2 = c("62037-80-3", "62037-80-3", "62037-80-3", "45187-15-3", NA_character_),
    cleaning_flag = c(
      rep("WARNING: potential multi-analyte", 3),
      NA_character_,
      NA_character_
    ),
    multi_cas = c(TRUE, TRUE, TRUE, TRUE, FALSE),
    multi_cas_count = c(2L, 2L, 2L, 2L, 1L)
  )
}

test_that("review_row_signature matches duplicates and is CAS-order independent", {
  df <- review_dup_fixture()
  name_cols <- "analyte"
  cas_cols <- c("casrn", "cas_extract_casrn_2")

  sig <- function(i) review_row_signature(df, i, name_cols, cas_cols)

  # The three GenX rows share one signature.
  expect_equal(sig(1), sig(2))
  expect_equal(sig(1), sig(3))
  # Different substances differ.
  expect_false(sig(1) == sig(4))
  expect_false(sig(1) == sig(5))

  # Swapping a row's two CAS columns must not change the signature.
  df_swapped <- df
  df_swapped$casrn[2] <- "62037-80-3"
  df_swapped$cas_extract_casrn_2[2] <- "13252-13-6"
  expect_equal(
    review_row_signature(df_swapped, 2, name_cols, cas_cols),
    sig(1)
  )
})

test_that("find_matching_review_rows returns siblings and excludes others", {
  df <- review_dup_fixture()
  matched <- find_matching_review_rows(
    df,
    target_row_index = 1L,
    candidate_row_indices = c(1L, 2L, 3L, 4L),
    name_cols = "analyte",
    cas_cols = c("casrn", "cas_extract_casrn_2")
  )
  expect_equal(matched, c(1L, 2L, 3L))
})

test_that("fanning is CAS-column-order independent (swapped columns match and resolve identically)", {
  # Two GenX rows with the SAME CAS set stored in SWAPPED columns.
  df <- tibble::tibble(
    original_row_id = 1:2,
    analyte = c("GenX", "GenX"),
    casrn = c("13252-13-6", "62037-80-3"),
    cas_extract_casrn_2 = c("62037-80-3", "13252-13-6"),
    cleaning_flag = rep("WARNING: potential multi-analyte", 2),
    multi_cas = c(TRUE, TRUE),
    multi_cas_count = c(2L, 2L)
  )
  cas_cols <- c("casrn", "cas_extract_casrn_2")

  # Swapped storage still matches (signature sorts the CAS set).
  matched <- find_matching_review_rows(df, 1L, c(1L, 2L), "analyte", cas_cols)
  expect_equal(matched, c(1L, 2L))

  # The spec drives assignment, so both siblings resolve to the identical
  # name<->CAS pairing regardless of their original column order.
  spec <- list(
    name_action = "split",
    name_parts = c("GenX Acid", "GenX Ammonium Salt"),
    cas_parts = c("13252-13-6", "62037-80-3"),
    pairing = "position"
  )
  result <- apply_review_resolutions(
    df,
    name_cols = "analyte",
    decisions = list("1" = spec, "2" = spec),
    cas_cols = cas_cols
  )
  cleaned <- result$cleaned_data

  expect_equal(nrow(cleaned), 4)
  # Every "GenX Acid" row got 13252-13-6, every "Ammonium Salt" got 62037-80-3,
  # for BOTH parents -- column order did not leak into the assignment.
  expect_equal(unique(cleaned$casrn[cleaned$analyte == "GenX Acid"]), "13252-13-6")
  expect_equal(unique(cleaned$casrn[cleaned$analyte == "GenX Ammonium Salt"]), "62037-80-3")
  expect_false(any(cleaned$multi_cas))
})

test_that("fanning one spec to all siblings resolves each and preserves lineage", {
  df <- review_dup_fixture()

  spec <- list(
    name_action = "split",
    name_parts = c("GenX Acid", "GenX Ammonium Salt"),
    cas_parts = c("13252-13-6", "62037-80-3"),
    pairing = "position"
  )
  # Simulate the fanned stage observer: same spec staged for each sibling.
  decisions <- list("1" = spec, "2" = spec, "3" = spec)

  result <- apply_review_resolutions(
    df,
    name_cols = "analyte",
    decisions = decisions,
    cas_cols = c("casrn", "cas_extract_casrn_2")
  )
  cleaned <- result$cleaned_data

  # Each GenX parent (original_row_id 1/2/3) split into two rows -> 3 + 3 + PFBS + acetone.
  expect_equal(nrow(cleaned), 8)
  expect_false(any(is_multi_analyte_review_row(cleaned)))
  expect_false(any(cleaned$multi_cas[cleaned$original_row_id %in% 1:3]))
  # Lineage: every split child keeps its parent's original_row_id.
  expect_equal(sort(cleaned$original_row_id[cleaned$analyte == "GenX Acid"]), c(1L, 2L, 3L))
  expect_equal(sort(cleaned$original_row_id[cleaned$analyte == "GenX Ammonium Salt"]), c(1L, 2L, 3L))
})
