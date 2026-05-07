# ============================================================================
# Tests for mod_review_results.R helper functions with WQX support
# ============================================================================

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
