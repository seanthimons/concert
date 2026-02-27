library(testthat)

# Source the consensus functions
source(file.path(here::here(), "R", "consensus.R"))

# ============================================================================
# Test Group 1: find_dtxsid_cols
# ============================================================================

test_that("find_dtxsid_cols detects dtxsid_ prefixed columns", {
  df <- data.frame(
    Chemical = c("Toluene"),
    CAS = c("108-88-3"),
    dtxsid_Chemical = c("DTXSID7021360"),
    dtxsid_CAS = c("DTXSID7021360"),
    preferredName_Chemical = c("Toluene"),
    stringsAsFactors = FALSE
  )

  result <- find_dtxsid_cols(df)
  expect_equal(sort(result), c("dtxsid_CAS", "dtxsid_Chemical"))
})

test_that("find_dtxsid_cols returns empty for no dtxsid columns", {
  df <- data.frame(Chemical = c("Toluene"), stringsAsFactors = FALSE)
  result <- find_dtxsid_cols(df)
  expect_length(result, 0)
})

# ============================================================================
# Test Group 2: classify_consensus - status classification
# ============================================================================

test_that("classify_consensus: all columns agree -> agree status", {
  df <- data.frame(
    Chemical = c("Toluene"),
    CAS = c("108-88-3"),
    dtxsid_Chemical = c("DTXSID7021360"),
    dtxsid_CAS = c("DTXSID7021360"),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")

  result <- classify_consensus(df, dtxsid_cols)

  expect_equal(result$consensus_status[1], "agree")
  expect_equal(result$consensus_dtxsid[1], "DTXSID7021360")
  expect_equal(result$consensus_source[1], "consensus")
})

test_that("classify_consensus: some agree, some NA -> agree_caveat", {
  df <- data.frame(
    Chemical = c("Toluene"),
    CAS = c("108-88-3"),
    Formula = c("C7H8"),
    dtxsid_Chemical = c("DTXSID7021360"),
    dtxsid_CAS = c("DTXSID7021360"),
    dtxsid_Formula = c(NA_character_),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS", "dtxsid_Formula")

  result <- classify_consensus(df, dtxsid_cols)

  expect_equal(result$consensus_status[1], "agree_caveat")
  expect_equal(result$consensus_dtxsid[1], "DTXSID7021360")
  expect_equal(result$consensus_source[1], "consensus")
})

test_that("classify_consensus: different DTXSIDs -> disagree", {
  df <- data.frame(
    Chemical = c("Toluene"),
    CAS = c("67-64-1"),
    dtxsid_Chemical = c("DTXSID7021360"),
    dtxsid_CAS = c("DTXSID1020001"),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")

  result <- classify_consensus(df, dtxsid_cols)

  expect_equal(result$consensus_status[1], "disagree")
  expect_true(is.na(result$consensus_dtxsid[1]))
  expect_true(is.na(result$consensus_source[1]))
})

test_that("classify_consensus: only one column has data -> single", {
  df <- data.frame(
    Chemical = c("Toluene"),
    CAS = c(NA),
    dtxsid_Chemical = c("DTXSID7021360"),
    dtxsid_CAS = c(NA_character_),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")

  result <- classify_consensus(df, dtxsid_cols)

  expect_equal(result$consensus_status[1], "single")
  expect_equal(result$consensus_dtxsid[1], "DTXSID7021360")
  expect_equal(result$consensus_source[1], "Chemical")
})

test_that("classify_consensus: all columns NA -> error", {
  df <- data.frame(
    Chemical = c("Unknown"),
    CAS = c("invalid"),
    dtxsid_Chemical = c(NA_character_),
    dtxsid_CAS = c(NA_character_),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")

  result <- classify_consensus(df, dtxsid_cols)

  expect_equal(result$consensus_status[1], "error")
  expect_true(is.na(result$consensus_dtxsid[1]))
  expect_true(is.na(result$consensus_source[1]))
})

# ============================================================================
# Test Group 3: classify_consensus - mixed rows
# ============================================================================

test_that("classify_consensus: mixed rows classified independently", {
  df <- data.frame(
    Chemical = c("Toluene", "Ethanol", "Unknown", "Acetone"),
    CAS = c("108-88-3", "64-17-5", "invalid", NA),
    dtxsid_Chemical = c("DTXSID7021360", "DTXSID9020584", NA_character_, "DTXSID1020001"),
    dtxsid_CAS = c("DTXSID7021360", "DTXSID1020001", NA_character_, NA_character_),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")

  result <- classify_consensus(df, dtxsid_cols)

  expect_equal(result$consensus_status[1], "agree")     # Both same DTXSID
  expect_equal(result$consensus_status[2], "disagree")   # Different DTXSIDs
  expect_equal(result$consensus_status[3], "error")      # Both NA
  expect_equal(result$consensus_status[4], "single")     # Only Chemical has data
})

# ============================================================================
# Test Group 4: compute_qc_tier
# ============================================================================

test_that("compute_qc_tier: agree gets tier 1", {
  result <- compute_qc_tier("agree", n_matched = 3, n_total = 3)
  expect_equal(result, 1L)
})

test_that("compute_qc_tier: agree_caveat tier scales with missing", {
  # 2 of 3 matched -> tier 2

  result1 <- compute_qc_tier("agree_caveat", n_matched = 2, n_total = 3)
  expect_equal(result1, 2L)

  # 2 of 4 matched -> tier 3
  result2 <- compute_qc_tier("agree_caveat", n_matched = 2, n_total = 4)
  expect_equal(result2, 3L)
})

test_that("compute_qc_tier: disagree is worse than agree_caveat", {
  tier_caveat <- compute_qc_tier("agree_caveat", n_matched = 2, n_total = 3)
  tier_disagree <- compute_qc_tier("disagree", n_matched = 0, n_total = 3)

  expect_true(tier_disagree > tier_caveat)
})

test_that("compute_qc_tier: error is worst tier", {
  tier_disagree <- compute_qc_tier("disagree", n_matched = 0, n_total = 3)
  tier_error <- compute_qc_tier("error", n_matched = 0, n_total = 3)

  expect_true(tier_error > tier_disagree)
})

test_that("compute_qc_tier: tier ordering correct for all statuses", {
  n_total <- 3
  tier_agree <- compute_qc_tier("agree", 3, n_total)
  tier_caveat <- compute_qc_tier("agree_caveat", 2, n_total)
  tier_single <- compute_qc_tier("single", 1, n_total)
  tier_disagree <- compute_qc_tier("disagree", 0, n_total)
  tier_error <- compute_qc_tier("error", 0, n_total)

  expect_true(tier_agree < tier_caveat)
  expect_true(tier_caveat < tier_single)
  expect_true(tier_single < tier_disagree)
  expect_true(tier_disagree < tier_error)
})

# ============================================================================
# Test Group 5: classify_consensus - QC tier integration
# ============================================================================

test_that("classify_consensus assigns correct QC tiers", {
  df <- data.frame(
    Chemical = c("Toluene", "Ethanol", "Unknown"),
    CAS = c("108-88-3", NA, "invalid"),
    dtxsid_Chemical = c("DTXSID7021360", "DTXSID9020584", NA_character_),
    dtxsid_CAS = c("DTXSID7021360", NA_character_, NA_character_),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")

  result <- classify_consensus(df, dtxsid_cols)

  expect_true("qc_tier" %in% names(result))
  # agree -> tier 1, single -> tier K-1=1... for K=2: single=1, but let's check ordering
  expect_equal(result$qc_tier[1], 1L) # agree
  expect_true(result$qc_tier[3] > result$qc_tier[1]) # error > agree
})

# ============================================================================
# Test Group 6: classify_consensus - output columns present
# ============================================================================

test_that("classify_consensus adds all expected columns", {
  df <- data.frame(
    Chemical = c("Toluene"),
    dtxsid_Chemical = c("DTXSID7021360"),
    dtxsid_CAS = c("DTXSID7021360"),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")

  result <- classify_consensus(df, dtxsid_cols)

  expect_true("consensus_status" %in% names(result))
  expect_true("consensus_dtxsid" %in% names(result))
  expect_true("consensus_source" %in% names(result))
  expect_true("qc_tier" %in% names(result))
  # Original columns preserved
  expect_true("Chemical" %in% names(result))
  expect_true("dtxsid_Chemical" %in% names(result))
})

# ============================================================================
# Test Group 7: Edge cases
# ============================================================================

test_that("classify_consensus handles single dtxsid column gracefully", {
  df <- data.frame(
    Chemical = c("Toluene", "Unknown"),
    dtxsid_Chemical = c("DTXSID7021360", NA_character_),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical")

  # With only 1 column, all non-NA are "single", all NA are "error"
  result <- classify_consensus(df, dtxsid_cols)

  expect_equal(result$consensus_status[1], "single")
  expect_equal(result$consensus_status[2], "error")
})

test_that("classify_consensus works with 4 tagged columns", {
  df <- data.frame(
    dtxsid_A = c("DTXSID7021360"),
    dtxsid_B = c("DTXSID7021360"),
    dtxsid_C = c("DTXSID7021360"),
    dtxsid_D = c("DTXSID7021360"),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_A", "dtxsid_B", "dtxsid_C", "dtxsid_D")

  result <- classify_consensus(df, dtxsid_cols)

  expect_equal(result$consensus_status[1], "agree")
  expect_equal(result$qc_tier[1], 1L)
})

# ============================================================================
# Test Group 8: init_resolution_state
# ============================================================================

test_that("init_resolution_state adds .pinned column", {
  df <- data.frame(Chemical = c("Toluene"), stringsAsFactors = FALSE)
  result <- init_resolution_state(df)

  expect_true(".pinned" %in% names(result))
  expect_false(result$.pinned[1])
})

test_that("init_resolution_state preserves existing .pinned", {
  df <- data.frame(Chemical = c("Toluene"), .pinned = TRUE, stringsAsFactors = FALSE)
  result <- init_resolution_state(df)

  expect_true(result$.pinned[1])
})

# ============================================================================
# Test Group 9: get_resolution_options
# ============================================================================

test_that("get_resolution_options returns available columns for disagree row", {
  df <- data.frame(
    Chemical = c("Toluene"),
    CAS = c("67-64-1"),
    dtxsid_Chemical = c("DTXSID7021360"),
    dtxsid_CAS = c("DTXSID1020001"),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")
  df <- classify_consensus(df, dtxsid_cols)

  options <- get_resolution_options(df, 1, dtxsid_cols)

  expect_type(options, "list")
  expect_length(options, 2)
  expect_equal(options[["dtxsid_Chemical"]], "DTXSID7021360")
  expect_equal(options[["dtxsid_CAS"]], "DTXSID1020001")
})

test_that("get_resolution_options returns empty for non-disagree row", {
  df <- data.frame(
    dtxsid_Chemical = c("DTXSID7021360"),
    dtxsid_CAS = c("DTXSID7021360"),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")
  df <- classify_consensus(df, dtxsid_cols)

  options <- get_resolution_options(df, 1, dtxsid_cols)

  expect_length(options, 0)
})

test_that("get_resolution_options excludes NA columns", {
  df <- data.frame(
    dtxsid_Chemical = c("DTXSID7021360"),
    dtxsid_CAS = c("DTXSID1020001"),
    dtxsid_Formula = c(NA_character_),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS", "dtxsid_Formula")
  df <- classify_consensus(df, dtxsid_cols)

  options <- get_resolution_options(df, 1, dtxsid_cols)

  expect_length(options, 2) # Formula excluded (NA)
  expect_null(options[["dtxsid_Formula"]])
})

# ============================================================================
# Test Group 10: resolve_row
# ============================================================================

test_that("resolve_row fills consensus for disagree row", {
  df <- data.frame(
    dtxsid_Chemical = c("DTXSID7021360"),
    dtxsid_CAS = c("DTXSID1020001"),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")
  df <- classify_consensus(df, dtxsid_cols)

  result <- resolve_row(df, 1, "dtxsid_Chemical", dtxsid_cols)

  expect_equal(result$consensus_dtxsid[1], "DTXSID7021360")
  expect_equal(result$consensus_source[1], "Chemical")
  expect_true(result$.pinned[1])
})

test_that("resolve_row errors on non-disagree row", {
  df <- data.frame(
    dtxsid_Chemical = c("DTXSID7021360"),
    dtxsid_CAS = c("DTXSID7021360"),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")
  df <- classify_consensus(df, dtxsid_cols)

  expect_error(resolve_row(df, 1, "dtxsid_Chemical", dtxsid_cols))
})

test_that("resolve_row errors on invalid column", {
  df <- data.frame(
    dtxsid_Chemical = c("DTXSID7021360"),
    dtxsid_CAS = c("DTXSID1020001"),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")
  df <- classify_consensus(df, dtxsid_cols)

  expect_error(resolve_row(df, 1, "dtxsid_Formula", dtxsid_cols))
})

# ============================================================================
# Test Group 11: apply_priority_chain
# ============================================================================

test_that("apply_priority_chain resolves all non-pinned disagree rows", {
  df <- data.frame(
    dtxsid_Chemical = c("DTXSID7021360", "DTXSID9020584"),
    dtxsid_CAS = c("DTXSID1020001", "DTXSID1020002"),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")
  df <- classify_consensus(df, dtxsid_cols)

  priority <- c("dtxsid_CAS", "dtxsid_Chemical")
  result <- apply_priority_chain(df, priority, dtxsid_cols)

  # CAS preferred, so both rows get CAS value
  expect_equal(result$consensus_dtxsid[1], "DTXSID1020001")
  expect_equal(result$consensus_dtxsid[2], "DTXSID1020002")
  expect_equal(result$consensus_source[1], "CAS")
  expect_equal(result$consensus_source[2], "CAS")
})

test_that("apply_priority_chain skips pinned rows", {
  df <- data.frame(
    dtxsid_Chemical = c("DTXSID7021360", "DTXSID9020584"),
    dtxsid_CAS = c("DTXSID1020001", "DTXSID1020002"),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")
  df <- classify_consensus(df, dtxsid_cols)

  # Pin row 1 to Chemical
  df <- resolve_row(df, 1, "dtxsid_Chemical", dtxsid_cols)

  # Now apply priority chain preferring CAS
  priority <- c("dtxsid_CAS", "dtxsid_Chemical")
  result <- apply_priority_chain(df, priority, dtxsid_cols)

  # Row 1: pinned to Chemical, should NOT change
  expect_equal(result$consensus_dtxsid[1], "DTXSID7021360")
  expect_equal(result$consensus_source[1], "Chemical")
  expect_true(result$.pinned[1])

  # Row 2: not pinned, should get CAS
  expect_equal(result$consensus_dtxsid[2], "DTXSID1020002")
  expect_equal(result$consensus_source[2], "CAS")
})

test_that("apply_priority_chain with no disagree rows returns df unchanged", {
  df <- data.frame(
    dtxsid_Chemical = c("DTXSID7021360"),
    dtxsid_CAS = c("DTXSID7021360"),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")
  df <- classify_consensus(df, dtxsid_cols)

  priority <- c("dtxsid_CAS", "dtxsid_Chemical")
  result <- apply_priority_chain(df, priority, dtxsid_cols)

  # agree row unchanged
  expect_equal(result$consensus_dtxsid[1], "DTXSID7021360")
  expect_equal(result$consensus_source[1], "consensus")
})

test_that("apply_priority_chain falls through to next priority column", {
  # Row where first priority column has NA
  df <- data.frame(
    dtxsid_Chemical = c("DTXSID7021360"),
    dtxsid_CAS = c(NA_character_),
    dtxsid_Formula = c("DTXSID1020001"),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS", "dtxsid_Formula")
  df <- classify_consensus(df, dtxsid_cols)

  # This row is disagree (Chemical and Formula differ)
  expect_equal(df$consensus_status[1], "disagree")

  # Priority: CAS first (but it's NA), then Chemical
  priority <- c("dtxsid_CAS", "dtxsid_Chemical", "dtxsid_Formula")
  result <- apply_priority_chain(df, priority, dtxsid_cols)

  # CAS is NA, falls to Chemical
  expect_equal(result$consensus_dtxsid[1], "DTXSID7021360")
  expect_equal(result$consensus_source[1], "Chemical")
})

test_that("re-applying priority chain with different order updates non-pinned rows", {
  df <- data.frame(
    dtxsid_Chemical = c("DTXSID7021360"),
    dtxsid_CAS = c("DTXSID1020001"),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")
  df <- classify_consensus(df, dtxsid_cols)

  # First: prefer CAS
  result1 <- apply_priority_chain(df, c("dtxsid_CAS", "dtxsid_Chemical"), dtxsid_cols)
  expect_equal(result1$consensus_dtxsid[1], "DTXSID1020001")

  # Second: prefer Chemical (re-apply on original classified df)
  result2 <- apply_priority_chain(df, c("dtxsid_Chemical", "dtxsid_CAS"), dtxsid_cols)
  expect_equal(result2$consensus_dtxsid[1], "DTXSID7021360")
})

# ============================================================================
# Test Group 12: End-to-end resolution flow
# ============================================================================

test_that("full flow: classify -> resolve_row -> apply_priority_chain", {
  df <- data.frame(
    Chemical = c("Toluene", "Ethanol", "Acetone"),
    CAS = c("67-64-1", "64-17-5", NA),
    dtxsid_Chemical = c("DTXSID7021360", "DTXSID9020584", "DTXSID1020001"),
    dtxsid_CAS = c("DTXSID1020001", "DTXSID1020002", NA_character_),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")

  # Step 1: Classify
  df <- classify_consensus(df, dtxsid_cols)
  expect_equal(df$consensus_status[1], "disagree")
  expect_equal(df$consensus_status[2], "disagree")
  expect_equal(df$consensus_status[3], "single")

  # Step 2: Manually resolve row 1
  df <- resolve_row(df, 1, "dtxsid_Chemical", dtxsid_cols)
  expect_equal(df$consensus_dtxsid[1], "DTXSID7021360")
  expect_true(df$.pinned[1])

  # Step 3: Apply priority chain (CAS preferred)
  df <- apply_priority_chain(df, c("dtxsid_CAS", "dtxsid_Chemical"), dtxsid_cols)

  # Row 1: pinned, unchanged
  expect_equal(df$consensus_dtxsid[1], "DTXSID7021360")
  expect_equal(df$consensus_source[1], "Chemical")

  # Row 2: not pinned, gets CAS value
  expect_equal(df$consensus_dtxsid[2], "DTXSID1020002")
  expect_equal(df$consensus_source[2], "CAS")

  # Row 3: single, was already resolved during classification
  expect_equal(df$consensus_dtxsid[3], "DTXSID1020001")
})
