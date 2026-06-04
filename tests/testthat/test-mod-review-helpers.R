# ============================================================================
# Tests for mod_review_results.R helper functions with WQX support
# ============================================================================

untagged_review_test_rows <- function(statuses) {
  n <- length(statuses)
  data.frame(
    Chemical = paste("Chemical", seq_len(n)),
    consensus_status = statuses,
    consensus_dtxsid = rep(NA_character_, n),
    row_flag = rep(NA_character_, n),
    qc_flag = rep(NA_character_, n),
    .pinned = rep(FALSE, n),
    .manual_entry = rep(FALSE, n),
    .resolution_method = rep(NA_character_, n),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

test_that("is_unassigned_untagged_review_row includes unresolved unassigned untagged rows", {
  df <- untagged_review_test_rows(c("disagree", "suggested", "error", "unresolvable"))

  expect_equal(is_unassigned_untagged_review_row(df), rep(TRUE, 4))
})

test_that("is_unassigned_untagged_review_row excludes rows with row flags", {
  df <- untagged_review_test_rows(c("disagree", "error"))
  df$row_flag <- c("BAD", " FOLLOW-UP ")

  expect_equal(is_unassigned_untagged_review_row(df), c(FALSE, FALSE))
})

test_that("is_unassigned_untagged_review_row excludes rows with QC flags", {
  df <- untagged_review_test_rows(c("disagree", "unresolvable"))
  df$qc_flag <- c("WARN: non-ASCII", " WARN: other ")

  expect_equal(is_unassigned_untagged_review_row(df), c(FALSE, FALSE))
})

test_that("is_unassigned_untagged_review_row excludes user action markers", {
  df <- untagged_review_test_rows(rep("disagree", 4))
  df$.pinned[1] <- TRUE
  df$.manual_entry[2] <- TRUE
  df$.resolution_method[3] <- "auto"
  df$.resolution_method[4] <- "suggested-accept"

  expect_equal(is_unassigned_untagged_review_row(df), rep(FALSE, 4))
})

test_that("is_unassigned_untagged_review_row excludes assigned and resolved statuses", {
  df <- untagged_review_test_rows(c("disagree", "agree", "single", "manual", "auto_resolved", "wqx"))
  df$consensus_dtxsid[1] <- "DTXSID7021360"

  expect_equal(is_unassigned_untagged_review_row(df), rep(FALSE, 6))
})

test_that("untagged unresolved filter preserves original indices through deduplication", {
  df <- untagged_review_test_rows(c("agree", "disagree", "disagree", "error"))
  df$Chemical <- c("Resolved", "Duplicate", "Duplicate", "Unique")
  df$consensus_dtxsid[1] <- "DTXSID7021360"

  filtered <- filter_review_rows(df, unassigned_untagged_filter_active = TRUE)
  deduped <- deduplicate_review_rows(
    filtered$df,
    filtered$original_indices,
    group_cols = c("Chemical", "consensus_dtxsid", "consensus_status")
  )

  expect_equal(filtered$original_indices, c(2L, 3L, 4L))
  expect_equal(deduped$display_row_map, c(2L, 4L))
  expect_equal(unname(deduped$dedup_group_map[[1]]), c(2L, 3L))
  expect_equal(deduped$df_display$n_rows, c(2L, 1L))
})

test_that("comptox_dashboard_url builds chemical details URL", {
  result <- comptox_dashboard_url("DTXSID7021360")
  expect_equal(result, "https://comptox.epa.gov/dashboard/chemical/details/DTXSID7021360")
})

test_that("candidate_dtxsid_heading does not link missing or blank DTXSIDs", {
  missing_heading <- as.character(candidate_dtxsid_heading(NA_character_))
  blank_heading <- as.character(candidate_dtxsid_heading("  "))

  expect_no_match(missing_heading, "<a", fixed = TRUE)
  expect_no_match(blank_heading, "<a", fixed = TRUE)
})

test_that("candidate_dtxsid_heading links DTXSID to CompTox Dashboard", {
  result <- as.character(candidate_dtxsid_heading("DTXSID7021360"))

  expect_match(result, "DTXSID7021360", fixed = TRUE)
  expect_match(result, 'href="https://comptox.epa.gov/dashboard/chemical/details/DTXSID7021360"', fixed = TRUE)
  expect_match(result, 'target="_blank"', fixed = TRUE)
  expect_match(result, 'rel="noopener noreferrer"', fixed = TRUE)
  expect_match(result, 'title="Open in CompTox Dashboard"', fixed = TRUE)
})

# ============================================================================
# Test Group 1: recalc_consensus_summary — WQX counting
# ============================================================================

test_that("recalc_consensus_summary counts n_wqx for WQX rows", {
  df <- data.frame(
    consensus_status = c("agree", "wqx", "wqx", "error"),
    consensus_dtxsid = c("DTXSID7021360", NA_character_, NA_character_, NA_character_),
    .pinned = c(FALSE, FALSE, FALSE, FALSE),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  result <- recalc_consensus_summary(df)
  expect_equal(result$n_wqx, 2)
  expect_equal(result$n_agree, 1)
  expect_equal(result$n_error, 1)
})

test_that("recalc_consensus_summary returns 0 for n_wqx when no WQX rows present", {
  df <- data.frame(
    consensus_status = c("agree", "disagree", "error"),
    consensus_dtxsid = c("DTXSID7021360", NA_character_, NA_character_),
    .pinned = c(FALSE, FALSE, FALSE),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  result <- recalc_consensus_summary(df)
  expect_equal(result$n_wqx, 0)
})

# ============================================================================
# Test Group 2: derive_match_type — WQX tier labels
# ============================================================================

test_that("derive_match_type maps wqx_exact to WQX Exact", {
  df <- data.frame(
    source_tier_Chemical = c("wqx_exact"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  result <- derive_match_type(df)
  expect_equal(result, "WQX Exact")
})

test_that("derive_match_type maps wqx_alias to WQX Alias", {
  df <- data.frame(
    source_tier_Chemical = c("wqx_alias"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  result <- derive_match_type(df)
  expect_equal(result, "WQX Alias")
})

test_that("derive_match_type maps wqx_fuzzy to WQX Fuzzy", {
  df <- data.frame(
    source_tier_Chemical = c("wqx_fuzzy"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  result <- derive_match_type(df)
  expect_equal(result, "WQX Fuzzy")
})

test_that("derive_match_type maps built-in isotope dictionary matches", {
  df <- data.frame(
    source_tier_Chemical = c("isotope_match"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  result <- derive_match_type(df)

  expect_equal(result, "Isotope Match")
})

test_that("derive_match_type uses consensus_source instead of first available source_tier", {
  df <- data.frame(
    consensus_status = c("single"),
    consensus_dtxsid = c("DTXSID001"),
    consensus_source = c("CASRN"),
    dtxsid_Chemical = c(NA_character_),
    preferredName_Chemical = c("Benzo(a)anthracene-D12"),
    source_tier_Chemical = c("wqx_fuzzy"),
    dtxsid_CASRN = c("DTXSID001"),
    preferredName_CASRN = c("Benz[a]anthracene"),
    source_tier_CASRN = c("cas"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  result <- derive_match_type(df)

  expect_equal(result, "CAS Lookup")
})

test_that("derive_row_flag_html renders BAD, FOLLOW-UP, VERIFIED, and blank flags", {
  result <- derive_row_flag_html(c("BAD", "FOLLOW-UP", "VERIFIED", NA_character_, ""))

  expect_match(result[1], "BAD")
  expect_match(result[1], "row-flag-chip")
  expect_match(result[1], "#DC3545", fixed = TRUE)
  expect_match(result[2], "FOLLOW-UP")
  expect_match(result[2], "#FFC107", fixed = TRUE)
  expect_match(result[2], "#212529", fixed = TRUE)
  expect_match(result[3], "VERIFIED")
  expect_match(result[3], "#198754", fixed = TRUE)
  expect_equal(result[4], "")
  expect_equal(result[5], "")
})

test_that("row_flag_filter_choices always includes untagged rows", {
  result <- row_flag_filter_choices(c("BAD", NA_character_, ""))

  expect_equal(result[["Untagged"]], "__untagged__")
  expect_equal(result[["BAD"]], "BAD")
  expect_false("FOLLOW-UP" %in% names(result))
})

test_that("row_flag_filter_choices includes untagged even when every row is flagged", {
  result <- row_flag_filter_choices(c("BAD", "VERIFIED"))

  expect_equal(result[["Untagged"]], "__untagged__")
  expect_equal(result[["BAD"]], "BAD")
  expect_equal(result[["VERIFIED"]], "VERIFIED")
})

# ============================================================================
# Test Group 3: derive_resolution_html — WQX resolution rendering
# ============================================================================

test_that("derive_resolution_html produces HTML with WQX canonical name", {
  df <- data.frame(
    consensus_status = c("wqx"),
    consensus_dtxsid = c(NA_character_),
    preferredName_Chemical = c("Dissolved oxygen (DO)"),
    .pinned = c(FALSE),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  result <- derive_resolution_html(df, row_indices = 1L)
  expect_match(result, "Dissolved oxygen \\(DO\\)")
})

test_that("derive_resolution_html includes wqx badge for WQX rows", {
  df <- data.frame(
    consensus_status = c("wqx"),
    consensus_dtxsid = c(NA_character_),
    preferredName_Chemical = c("Dissolved oxygen (DO)"),
    .pinned = c(FALSE),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  result <- derive_resolution_html(df, row_indices = 1L)
  expect_match(result, "wqx</span>")
  expect_match(result, "badge")
})

test_that("derive_resolution_html still works correctly for agree rows (regression)", {
  df <- data.frame(
    consensus_status = c("agree"),
    consensus_dtxsid = c("DTXSID7021360"),
    preferredName_Chemical = c("Toluene"),
    .pinned = c(FALSE),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  result <- derive_resolution_html(df, row_indices = 1L)
  expect_match(result, "DTXSID7021360")
  expect_match(result, "Toluene")
})

test_that("derive_resolution_html uses consensus_source preferredName for single-source rows", {
  df <- data.frame(
    consensus_status = c("single"),
    consensus_dtxsid = c("DTXSID001"),
    consensus_source = c("CASRN"),
    dtxsid_Chemical = c(NA_character_),
    preferredName_Chemical = c("Benzo(a)anthracene-D12"),
    source_tier_Chemical = c("wqx_fuzzy"),
    dtxsid_CASRN = c("DTXSID001"),
    preferredName_CASRN = c("Benz[a]anthracene"),
    source_tier_CASRN = c("cas"),
    .pinned = c(FALSE),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  result <- derive_resolution_html(df, row_indices = 1L)

  expect_match(result, "Benz\\[a\\]anthracene")
  expect_no_match(result, "Benzo\\(a\\)anthracene-D12")
})

test_that("derive_resolution_html exposes expert override for every row status", {
  statuses <- c(
    "single",
    "agree",
    "agree_caveat",
    "suggested",
    "auto_resolved",
    "error",
    "manual",
    "wqx",
    "disagree",
    "unresolvable"
  )
  n <- length(statuses)
  df <- data.frame(
    consensus_status = statuses,
    consensus_dtxsid = c(
      "DTXSID0000001",
      "DTXSID0000002",
      "DTXSID0000003",
      "DTXSID0000004",
      "DTXSID0000005",
      NA_character_,
      "DTXSID0000007",
      NA_character_,
      NA_character_,
      NA_character_
    ),
    consensus_source = rep("Chemical", n),
    preferredName_Chemical = paste("Preferred", seq_len(n)),
    manual_preferredName = c(rep(NA_character_, 6), "Manual Preferred", rep(NA_character_, 3)),
    .pinned = rep(FALSE, n),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  result <- derive_resolution_html(df, row_indices = seq_len(n))

  expect_true(all(grepl("expert-override-btn", result, fixed = TRUE)))
  expect_true(all(grepl("Override", result, fixed = TRUE)))
})

review_override_test_state <- function(statuses) {
  n <- length(statuses)
  old_dtxsid <- paste0("DTXSID9", sprintf("%06d", seq_len(n)))
  old_dtxsid[statuses %in% c("error", "unresolvable", "wqx")] <- NA_character_

  init_resolution_state(data.frame(
    Chemical = paste("Chemical", seq_len(n)),
    consensus_status = statuses,
    consensus_dtxsid = old_dtxsid,
    consensus_source = rep("Chemical", n),
    preferredName_Chemical = paste("Original", seq_len(n)),
    stringsAsFactors = FALSE,
    check.names = FALSE
  ))
}

review_override_validation <- function(dtxsids, valid = TRUE) {
  tibble::tibble(
    searchValue = dtxsids,
    dtxsid = if (valid) dtxsids else NA_character_,
    preferredName = if (valid) paste("Validated", seq_along(dtxsids)) else NA_character_,
    rank = if (valid) rep(1L, length(dtxsids)) else rep(NA_integer_, length(dtxsids)),
    is_valid = rep(valid, length(dtxsids))
  )
}

review_override_wqx_dictionary <- function() {
  tibble::tibble(
    name = c("Canonical WQX", "WQX Alias"),
    canonical_name = c("Canonical WQX", "Canonical WQX"),
    type = c("canonical", "alias")
  )
}

test_that("queued DTXSID overrides apply across review statuses", {
  statuses <- c("single", "agree", "suggested", "auto_resolved", "error", "manual", "wqx")
  df <- review_override_test_state(statuses)
  dtxsids <- paste0("DTXSID7", sprintf("%06d", seq_along(statuses)))
  queue <- list()
  for (i in seq_along(statuses)) {
    queue <- queue_review_override(queue, row = i, group_rows = i, override_type = "dtxsid", value = dtxsids[i])
  }

  result <- apply_queued_review_overrides(
    df,
    queue,
    validation_results = review_override_validation(dtxsids)
  )
  updated <- result$resolution_state

  expect_equal(updated$consensus_status, rep("manual", length(statuses)))
  expect_equal(updated$consensus_dtxsid, dtxsids)
  expect_equal(updated$consensus_source, rep("manual_entry", length(statuses)))
  expect_true(all(updated$.manual_entry))
  expect_true(all(updated$.pinned))
  expect_equal(updated$.resolution_method, rep("manual", length(statuses)))
  expect_equal(updated$manual_preferredName, paste("Validated", seq_along(statuses)))
  expect_equal(result$invalid_entries, 0L)
})

test_that("queued WQX overrides apply across review statuses", {
  statuses <- c("single", "agree", "suggested", "auto_resolved", "error", "manual", "wqx")
  df <- review_override_test_state(statuses)
  queue <- list()
  for (i in seq_along(statuses)) {
    queue <- queue_review_override(queue, row = i, group_rows = i, override_type = "wqx", value = "Canonical WQX")
  }

  result <- apply_queued_review_overrides(
    df,
    queue,
    wqx_dictionary = review_override_wqx_dictionary()
  )
  updated <- result$resolution_state

  expect_equal(updated$consensus_status, rep("wqx", length(statuses)))
  expect_true(all(is.na(updated$consensus_dtxsid)))
  expect_equal(updated$consensus_source, rep("manual_wqx", length(statuses)))
  expect_equal(updated$wqx_override_name, rep("Canonical WQX", length(statuses)))
  expect_true(all(updated$.pinned))
  expect_equal(updated$.resolution_method, rep("manual_wqx", length(statuses)))
  expect_false(any(updated$.manual_entry))
  expect_equal(result$invalid_entries, 0L)
})

test_that("queued overrides propagate across dedup groups", {
  df <- review_override_test_state(c("error", "agree", "wqx", "manual"))
  dtxsid_queue <- queue_review_override(list(), row = 1L, group_rows = c(1L, 3L), override_type = "dtxsid", value = "DTXSID7000001")

  dtxsid_result <- apply_queued_review_overrides(
    df,
    dtxsid_queue,
    validation_results = review_override_validation("DTXSID7000001")
  )$resolution_state

  expect_equal(dtxsid_result$consensus_status[c(1, 3)], c("manual", "manual"))
  expect_equal(dtxsid_result$consensus_dtxsid[c(1, 3)], c("DTXSID7000001", "DTXSID7000001"))
  expect_equal(dtxsid_result$consensus_status[2], "agree")

  wqx_queue <- queue_review_override(list(), row = 2L, group_rows = c(2L, 4L), override_type = "wqx", value = "Canonical WQX")
  wqx_result <- apply_queued_review_overrides(
    df,
    wqx_queue,
    wqx_dictionary = review_override_wqx_dictionary()
  )$resolution_state

  expect_equal(wqx_result$consensus_status[c(2, 4)], c("wqx", "wqx"))
  expect_true(all(is.na(wqx_result$consensus_dtxsid[c(2, 4)])))
  expect_equal(wqx_result$wqx_override_name[c(2, 4)], c("Canonical WQX", "Canonical WQX"))
  expect_equal(wqx_result$consensus_status[1], "error")
})

test_that("newest queued override wins for the same dedup group", {
  queue <- queue_review_override(list(), row = 1L, group_rows = c(1L, 2L), override_type = "dtxsid", value = "DTXSID7000001")
  queue <- queue_review_override(queue, row = 2L, group_rows = c(1L, 2L), override_type = "wqx", value = "Canonical WQX")
  entries <- normalize_review_override_queue(queue)

  expect_length(entries, 1)
  expect_equal(entries[[1]]$override_type, "wqx")
  expect_equal(entries[[1]]$row, 2L)
  expect_equal(entries[[1]]$group_rows, c(1L, 2L))
})

test_that("failed DTXSID validation leaves previously resolved row unchanged", {
  df <- review_override_test_state("agree")
  before <- init_resolution_state(df)
  queue <- queue_review_override(list(), row = 1L, group_rows = 1L, override_type = "dtxsid", value = "DTXSID7000001")

  result <- apply_queued_review_overrides(
    df,
    queue,
    validation_results = review_override_validation("DTXSID7000001", valid = FALSE)
  )

  expect_equal(result$resolution_state, before)
  expect_equal(result$invalid_entries, 1L)
  expect_match(result$invalid_details, "DTXSID7000001", fixed = TRUE)
})

test_that("WQX override converts non-WQX row to WQX name-only resolution", {
  df <- review_override_test_state("agree")
  queue <- queue_review_override(list(), row = 1L, group_rows = 1L, override_type = "wqx", value = "WQX Alias")

  result <- apply_queued_review_overrides(
    df,
    queue,
    wqx_dictionary = review_override_wqx_dictionary()
  )$resolution_state

  expect_equal(result$consensus_status, "wqx")
  expect_true(is.na(result$consensus_dtxsid))
  expect_equal(result$consensus_source, "manual_wqx")
  expect_equal(result$wqx_override_name, "Canonical WQX")
  expect_true(result$.pinned)
  expect_equal(result$.resolution_method, "manual_wqx")
})

test_that("WQX override without dictionary validation leaves row unchanged", {
  df <- review_override_test_state("agree")
  before <- init_resolution_state(df)
  queue <- queue_review_override(list(), row = 1L, group_rows = 1L, override_type = "wqx", value = "Canonical WQX")

  result <- apply_queued_review_overrides(df, queue, wqx_dictionary = NULL)

  expect_equal(result$resolution_state, before)
  expect_equal(result$invalid_entries, 1L)
  expect_match(result$invalid_details, "WQX 'Canonical WQX'", fixed = TRUE)
})

# ============================================================================
# Test Group 4: wqx_confidence computation
# ============================================================================

test_that("wqx_confidence is similarity score for fuzzy rows", {
  wqx_resolved <- tibble::tibble(
    input_name = "dissolved oxygen",
    wqx_name = "Dissolved oxygen (DO)",
    match_tier = "fuzzy",
    match_distance = 0.13,
    alias_type = NA_character_
  )
  wqx_confidence <- ifelse(
    wqx_resolved$match_tier == "fuzzy",
    1 - wqx_resolved$match_distance,
    NA_real_
  )
  expect_equal(wqx_confidence, 0.87)
})

test_that("wqx_confidence is NA for exact match", {
  wqx_resolved <- tibble::tibble(
    input_name = "Dissolved oxygen",
    wqx_name = "Dissolved oxygen (DO)",
    match_tier = "exact",
    match_distance = NA_real_,
    alias_type = NA_character_
  )
  wqx_confidence <- ifelse(
    wqx_resolved$match_tier == "fuzzy",
    1 - wqx_resolved$match_distance,
    NA_real_
  )
  expect_true(is.na(wqx_confidence))
})

test_that("wqx_confidence is NA for alias match", {
  wqx_resolved <- tibble::tibble(
    input_name = "DO",
    wqx_name = "Dissolved oxygen (DO)",
    match_tier = "alias",
    match_distance = NA_real_,
    alias_type = "synonym"
  )
  wqx_confidence <- ifelse(
    wqx_resolved$match_tier == "fuzzy",
    1 - wqx_resolved$match_distance,
    NA_real_
  )
  expect_true(is.na(wqx_confidence))
})

# ============================================================================
# Test Group 5: derive_resolution_html — Review button for WQX rows
# ============================================================================

test_that("derive_resolution_html includes wqx-review-btn for WQX rows", {
  df <- data.frame(
    consensus_status = c("wqx"),
    consensus_dtxsid = c(NA_character_),
    preferredName_Chemical = c("Dissolved oxygen (DO)"),
    .pinned = c(FALSE),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  result <- derive_resolution_html(df, row_indices = 1L)
  expect_match(result, "wqx-review-btn")
  expect_match(result, "expert-override-btn")
  expect_match(result, 'data-row="1"')
})

test_that("derive_resolution_html Review button absent for non-WQX rows", {
  df <- data.frame(
    consensus_status = c("agree"),
    consensus_dtxsid = c("DTXSID7021360"),
    preferredName_Chemical = c("Toluene"),
    .pinned = c(FALSE),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  result <- derive_resolution_html(df, row_indices = 1L)
  expect_no_match(result, "wqx-review-btn")
})

test_that("derive_resolution_html keeps compare actions for reviewable rows", {
  df <- data.frame(
    consensus_status = c("disagree", "suggested", "auto_resolved"),
    consensus_dtxsid = c(NA_character_, "DTXSID7021360", "DTXSID7021360"),
    preferredName_Chemical = c(NA_character_, "Toluene", "Toluene"),
    .pinned = c(FALSE, FALSE, FALSE),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  result <- derive_resolution_html(df, row_indices = 1:3)

  expect_match(result[1], "compare-btn")
  expect_match(result[1], "expert-override-btn")
  expect_match(result[2], "compare-btn")
  expect_match(result[2], "Review Suggestion")
  expect_match(result[2], "expert-override-btn")
  expect_match(result[3], "compare-btn")
  expect_match(result[3], "expert-override-btn")
})

# ============================================================================
# Test Group 6: map_results_to_rows -- wqx_confidence propagation (integration)
# ============================================================================

test_that("map_results_to_rows carries wqx_confidence to output df for WQX fuzzy rows", {
  # Input data frame with one row
  df <- data.frame(
    Chemical = "dissolved oxygen",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  # Dedup key map: row 1 maps to "dissolved oxygen" in column "Chemical"
  dedup_key_map <- tibble::tibble(
    row_idx = 1L,
    column_name = "Chemical",
    dedup_key = "dissolved oxygen"
  )

  # Lookup results: one WQX fuzzy match with wqx_confidence
  lookup_results <- tibble::tibble(
    searchValue = "dissolved oxygen",
    dtxsid = NA_character_,
    preferredName = "Dissolved oxygen (DO)",
    searchName = NA_character_,
    rank = NA_integer_,
    source_tier = "wqx_fuzzy",
    wqx_confidence = 0.87
  )

  result <- map_results_to_rows(df, dedup_key_map, lookup_results)

  expect_true("wqx_confidence" %in% names(result), info = "wqx_confidence column must be present in output")
  expect_equal(result$wqx_confidence[1], 0.87)
})

test_that("map_results_to_rows sets wqx_confidence to NA for non-WQX rows", {
  df <- data.frame(
    Chemical = c("toluene", "dissolved oxygen"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  dedup_key_map <- tibble::tibble(
    row_idx = c(1L, 2L),
    column_name = c("Chemical", "Chemical"),
    dedup_key = c("toluene", "dissolved oxygen")
  )

  # Two results: one CompTox (no wqx_confidence), one WQX fuzzy
  lookup_results <- tibble::tibble(
    searchValue = c("toluene", "dissolved oxygen"),
    dtxsid = c("DTXSID7021360", NA_character_),
    preferredName = c("Toluene", "Dissolved oxygen (DO)"),
    searchName = c("Toluene", NA_character_),
    rank = c(1L, NA_integer_),
    source_tier = c("comptox_exact", "wqx_fuzzy"),
    wqx_confidence = c(NA_real_, 0.87)
  )

  result <- map_results_to_rows(df, dedup_key_map, lookup_results)

  expect_true("wqx_confidence" %in% names(result))
  expect_true(is.na(result$wqx_confidence[1]), info = "CompTox row should have NA wqx_confidence")
  expect_equal(result$wqx_confidence[2], 0.87, info = "WQX fuzzy row should have 0.87 wqx_confidence")
})

test_that("map_results_to_rows handles lookup_results without wqx_confidence column", {
  df <- data.frame(
    Chemical = "toluene",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  dedup_key_map <- tibble::tibble(
    row_idx = 1L,
    column_name = "Chemical",
    dedup_key = "toluene"
  )

  # Lookup results without wqx_confidence column (no WQX matching ran)
  lookup_results <- tibble::tibble(
    searchValue = "toluene",
    dtxsid = "DTXSID7021360",
    preferredName = "Toluene",
    searchName = "Toluene",
    rank = 1L,
    source_tier = "comptox_exact"
  )

  result <- map_results_to_rows(df, dedup_key_map, lookup_results)

  # wqx_confidence column should still be created (all NA) because it is pre-allocated
  expect_true("wqx_confidence" %in% names(result))
  expect_true(is.na(result$wqx_confidence[1]))
})

# ============================================================================
# Test Group 7: Gap closure regression tests (Plan 04 -- CR-01, WR-02)
# ============================================================================

test_that("wqx_confidence grep pattern matches both suffixed and unsuffixed column names", {
  # Single-tag mode: unsuffixed
  single_tag_names <- c("consensus_status", "wqx_confidence", "preferredName_Chemical")
  expect_length(grep("^wqx_confidence", single_tag_names, value = TRUE), 1)
  expect_equal(grep("^wqx_confidence", single_tag_names, value = TRUE), "wqx_confidence")

  # Multi-tag mode: suffixed
  multi_tag_names <- c("consensus_status", "wqx_confidence_Chemical", "preferredName_Chemical")
  expect_length(grep("^wqx_confidence", multi_tag_names, value = TRUE), 1)
  expect_equal(grep("^wqx_confidence", multi_tag_names, value = TRUE), "wqx_confidence_Chemical")

  # Both present (edge case): matches both
  both_names <- c("wqx_confidence", "wqx_confidence_Chemical")
  expect_length(grep("^wqx_confidence", both_names, value = TRUE), 2)

  # No match
  no_match_names <- c("consensus_status", "preferredName_Chemical")
  expect_length(grep("^wqx_confidence", no_match_names, value = TRUE), 0)
})

test_that("grep-based wqx_confidence lookup extracts value from suffixed column", {
  # Simulate a single-row slice of resolution_state with suffixed column (multi-tag mode)
  row <- data.frame(
    consensus_status = "wqx",
    wqx_confidence_Chemical = 0.87,
    stringsAsFactors = FALSE
  )

  wqx_conf_col <- grep("^wqx_confidence", names(row), value = TRUE)
  confidence <- if (length(wqx_conf_col) > 0) row[[wqx_conf_col[1]]] else NA_real_
  expect_equal(confidence, 0.87)

  # Single-tag mode (unsuffixed)
  row2 <- data.frame(
    consensus_status = "wqx",
    wqx_confidence = 0.92,
    stringsAsFactors = FALSE
  )
  wqx_conf_col2 <- grep("^wqx_confidence", names(row2), value = TRUE)
  confidence2 <- if (length(wqx_conf_col2) > 0) row2[[wqx_conf_col2[1]]] else NA_real_
  expect_equal(confidence2, 0.92)

  # No confidence column at all
  row3 <- data.frame(consensus_status = "wqx", stringsAsFactors = FALSE)
  wqx_conf_col3 <- grep("^wqx_confidence", names(row3), value = TRUE)
  confidence3 <- if (length(wqx_conf_col3) > 0) row3[[wqx_conf_col3[1]]] else NA_real_
  expect_true(is.na(confidence3))
})

test_that("input name lookup reads from tagged Name column, not searchValue", {
  # Simulate resolution_state row with tagged Name column
  row <- data.frame(
    Chemical = "Dissolved oxygen",
    consensus_status = "wqx",
    stringsAsFactors = FALSE
  )

  # Simulate column_tags (named character vector mapping column names to tag types)
  column_tags <- c("Chemical" = "Name", "cas_number" = "CASRN")

  name_cols <- names(column_tags)[column_tags == "Name"]
  input_name <- NA_character_
  for (nc in name_cols) {
    if (nc %in% names(row) && !is.na(row[[nc]])) {
      input_name <- row[[nc]]
      break
    }
  }
  expect_equal(input_name, "Dissolved oxygen")

  # Row where the Name column is NA (falls through to NA_character_)
  row2 <- data.frame(
    Chemical = NA_character_,
    consensus_status = "wqx",
    stringsAsFactors = FALSE
  )
  input_name2 <- NA_character_
  for (nc in name_cols) {
    if (nc %in% names(row2) && !is.na(row2[[nc]])) {
      input_name2 <- row2[[nc]]
      break
    }
  }
  expect_true(is.na(input_name2))
})

# ============================================================================
# Test Group 8: GAP closure regression (UAT round 2)
# ============================================================================

test_that("wqx_conf_cols Filter removes all-NA columns in multi-tag mode", {
  # Simulate multi-tag df_display with two wqx_confidence columns:
  # wqx_confidence_Chemical has real data, wqx_confidence_CASRN is all NA
  df <- data.frame(
    wqx_confidence_Chemical = c(0.87, NA_real_, 0.92),
    wqx_confidence_CASRN = c(NA_real_, NA_real_, NA_real_),
    stringsAsFactors = FALSE
  )
  wqx_conf_cols <- grep("^wqx_confidence", names(df), value = TRUE)
  # Before filter: both columns match
  expect_equal(length(wqx_conf_cols), 2)

  # Apply the same Filter logic used in mod_review_results.R
  wqx_conf_cols <- Filter(function(col) any(!is.na(df[[col]])), wqx_conf_cols)
  # After filter: only the Chemical column remains
  expect_equal(length(wqx_conf_cols), 1)
  expect_equal(wqx_conf_cols, "wqx_confidence_Chemical")
})

test_that("wqx_conf_cols Filter preserves single-tag column", {
  # Simulate single-tag df_display with one wqx_confidence column
  df <- data.frame(
    wqx_confidence = c(0.87, NA_real_, 0.92),
    stringsAsFactors = FALSE
  )
  wqx_conf_cols <- grep("^wqx_confidence", names(df), value = TRUE)
  wqx_conf_cols <- Filter(function(col) any(!is.na(df[[col]])), wqx_conf_cols)
  expect_equal(length(wqx_conf_cols), 1)
  expect_equal(wqx_conf_cols, "wqx_confidence")
})

test_that("review column selector exposes upload and curated columns but excludes internals", {
  upload_cols <- c("Chemical", "CASRN", "Sample ID")
  df_names <- c(
    upload_cols,
    "consensus_status",
    "match_type",
    "Resolution",
    "source_tier_Chemical",
    ".pinned"
  )
  internal_hidden <- c("source_tier_Chemical", ".pinned")

  choices <- derive_review_column_choices(upload_cols, df_names, internal_hidden)

  expect_true(all(upload_cols %in% choices))
  expect_true(all(c("consensus_status", "match_type") %in% choices))
  expect_false("Resolution" %in% choices)
  expect_false("source_tier_Chemical" %in% choices)
  expect_false(".pinned" %in% choices)
})

test_that("review column selector preserves condensed default while making untagged uploads available", {
  upload_cols <- c("Chemical", "CASRN", "Sample ID")
  column_tags <- c("Chemical" = "Name", "CASRN" = "CASRN")
  df_names <- c(upload_cols, "consensus_status", "match_type", "Resolution")

  choices <- derive_review_column_choices(upload_cols, df_names)
  default_visible <- derive_default_visible_review_columns(upload_cols, column_tags, df_names)

  expect_true("Sample ID" %in% choices)
  expect_true(all(c("Chemical", "CASRN", "consensus_status", "match_type", "Resolution") %in% default_visible))
  expect_false("Sample ID" %in% default_visible)
})

test_that("hidden review column derivation never hides required Resolution action", {
  upload_cols <- c("Chemical", "CASRN", "Sample ID")
  column_tags <- c("Chemical" = "Name", "CASRN" = "CASRN")
  df_names <- c(upload_cols, "consensus_status", "match_type", "Resolution")

  hidden <- derive_hidden_review_columns(
    selected_cols = c("Chemical"),
    upload_col_names = upload_cols,
    column_tags = column_tags,
    df_names = df_names
  )

  expect_true("CASRN" %in% hidden)
  expect_true("match_type" %in% hidden)
  expect_false("Resolution" %in% hidden)
})

test_that("persisted review columns are honored and reconciled against current choices", {
  upload_cols <- c("Chemical", "CASRN", "Sample ID")
  column_tags <- c("Chemical" = "Name", "CASRN" = "CASRN")
  df_names <- c(upload_cols, "consensus_status", "match_type", "Resolution", "source_tier_Chemical")
  internal_hidden <- c("source_tier_Chemical")

  visible <- reconcile_visible_review_columns(
    selected_cols = c("Sample ID", "Obsolete", "Resolution", "source_tier_Chemical"),
    upload_col_names = upload_cols,
    column_tags = column_tags,
    df_names = df_names,
    internal_hidden_cols = internal_hidden
  )

  expect_equal(visible, c("Sample ID", "Resolution"))
})

test_that("empty persisted review selection still preserves required action columns", {
  upload_cols <- c("Chemical", "CASRN")
  column_tags <- c("Chemical" = "Name", "CASRN" = "CASRN")
  df_names <- c(upload_cols, "consensus_status", "Resolution")

  visible <- reconcile_visible_review_columns(
    selected_cols = character(0),
    upload_col_names = upload_cols,
    column_tags = column_tags,
    df_names = df_names
  )

  expect_equal(visible, "Resolution")
})
