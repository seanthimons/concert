review_export <- function(state) {
  build_export_sheets(
    raw = state["name"],
    resolution_state = state,
    consensus_summary = list(),
    cleaning_audit = NULL,
    reference_lists = list(),
    column_tags = list(name = "Name"),
    detection = list(),
    file_info = list()
  )[["Curated Data"]]
}

test_that("unreviewed WQX fuzzy candidates require review in exports", {
  state <- tibble::tibble(
    name = "carbomycin",
    consensus_dtxsid = NA_character_,
    consensus_status = "wqx",
    consensus_source = "Name",
    source_tier = "wqx_fuzzy",
    preferredName = "Carbon"
  )

  expect_true(review_export(state)$needs_review)
})

test_that("exact and alias WQX evidence does not complete identity review", {
  state <- tibble::tibble(
    name = c("Carbon", "Carbon alias"),
    consensus_dtxsid = NA_character_,
    consensus_status = "wqx",
    consensus_source = "Name",
    source_tier = c("wqx_exact", "wqx_alias")
  )

  expect_equal(review_export(state)$needs_review, c(TRUE, TRUE))
})

test_that("explicit WQX acceptance and verification resolve review, but FOLLOW-UP persists", {
  state <- tibble::tibble(
    name = c("accepted", "verified", "followup", "accepted followup", "identifier followup"),
    consensus_dtxsid = c(rep(NA_character_, 4), "DTXSID7020182"),
    consensus_status = c(rep("wqx", 4), "agree"),
    consensus_source = "Name"
  )
  # The same overrides are used by headless review and replay of interactive edits.
  state <- apply_review_overrides(
    state,
    tibble::tibble(
      row = c(1L, 4L),
      column = "consensus_source",
      value = "manual_wqx"
    )
  )
  state <- set_row_flag(state, 2L, "VERIFIED")
  state <- set_row_flags(state, 3:5, "FOLLOW-UP")

  expect_equal(review_export(state)$needs_review, c(FALSE, FALSE, TRUE, TRUE, TRUE))
})

test_that("exports retain incoming review requirements and unresolved errors", {
  state <- tibble::tibble(
    name = c("incoming", "clear", "missing flag", "error", "unresolvable", "bad", "verified"),
    consensus_dtxsid = c(rep("DTXSID7020182", 3), NA_character_, NA_character_, "DTXSID7020182", "DTXSID7020182"),
    consensus_status = c(rep("agree", 3), "error", "unresolvable", "agree", "agree"),
    row_flag = c(rep(NA_character_, 3), "VERIFIED", NA_character_, "BAD", "VERIFIED"),
    needs_review = c(TRUE, FALSE, NA, FALSE, FALSE, FALSE, FALSE)
  )

  expect_equal(review_export(state)$needs_review, c(TRUE, FALSE, FALSE, TRUE, TRUE, FALSE, FALSE))
})

test_that("headless workbook exports use the same review rules as interactive exports", {
  state <- tibble::tibble(
    name = c("fuzzy", "exact", "alias", "accepted", "verified", "followup", "error"),
    consensus_dtxsid = NA_character_,
    consensus_status = c(rep("wqx", 6), "error"),
    consensus_source = c(rep("Name", 3), "manual_wqx", rep("Name", 3)),
    source_tier = c("wqx_fuzzy", "wqx_exact", "wqx_alias", rep("wqx_exact", 3), "miss")
  )
  reviewed <- stage_review(
    list(resolution_state = state, merged_chemical_tags = list(name = "Name")),
    row_flags = tibble::tibble(name = c("verified", "followup"), flag = c("VERIFIED", "FOLLOW-UP"))
  )
  output_path <- tempfile(fileext = ".xlsx")
  withr::defer(unlink(output_path))
  stage_export(
    list(
      raw_df = state["name"],
      resolution_state = reviewed$resolution_state,
      consensus_summary = reviewed$consensus_summary,
      reference_lists = list(),
      merged_tags = list(name = "Name"),
      detection = list(),
      file_info = list()
    ),
    output_path = output_path
  )
  exported <- readxl::read_xlsx(output_path, sheet = "Curated Data")

  expect_equal(exported$needs_review, c(TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, TRUE))
  expect_equal(exported$needs_review, review_export(reviewed$resolution_state)$needs_review)
})
