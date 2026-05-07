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
