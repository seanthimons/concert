# Test file for WQX pipeline integration (Phase 45)
# Tests INTG-02, INTG-03, INTG-04

# ============================================================================
# Group 1: compute_qc_tier handles wqx status
# ============================================================================

test_that("compute_qc_tier returns n_total for wqx status", {
  # WQX gets same tier as "single" (resolved but no multi-source agreement)
  expect_equal(compute_qc_tier("wqx", 0L, 1L), 1L)
  expect_equal(compute_qc_tier("wqx", 0L, 2L), 2L)
  expect_equal(compute_qc_tier("wqx", 0L, 3L), 3L)
})

# ============================================================================
# Group 2: classify_consensus assigns wqx for WQX-resolved rows
# ============================================================================

test_that("classify_consensus assigns wqx status for wqx_exact source tier", {
  df <- data.frame(
    Chemical = "Arsenic",
    dtxsid_Chemical = NA_character_,
    preferredName_Chemical = "Arsenic",
    source_tier_Chemical = "wqx_exact",
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- "dtxsid_Chemical"
  result <- classify_consensus(df, dtxsid_cols)

  expect_equal(result$consensus_status[1], "wqx")
  expect_true(is.na(result$consensus_dtxsid[1]))
})

test_that("classify_consensus assigns wqx status for wqx_alias source tier", {
  df <- data.frame(
    Chemical = "Arsenic",
    dtxsid_Chemical = NA_character_,
    preferredName_Chemical = "Arsenic",
    source_tier_Chemical = "wqx_alias",
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- "dtxsid_Chemical"
  result <- classify_consensus(df, dtxsid_cols)

  expect_equal(result$consensus_status[1], "wqx")
})

test_that("classify_consensus assigns wqx status for wqx_fuzzy source tier", {
  df <- data.frame(
    Chemical = "Arsenic",
    dtxsid_Chemical = NA_character_,
    preferredName_Chemical = "Arsenic",
    source_tier_Chemical = "wqx_fuzzy",
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- "dtxsid_Chemical"
  result <- classify_consensus(df, dtxsid_cols)

  expect_equal(result$consensus_status[1], "wqx")
})

test_that("classify_consensus still assigns error for non-wqx NA-DTXSID rows", {
  df <- data.frame(
    Chemical = "Unknown",
    dtxsid_Chemical = NA_character_,
    source_tier_Chemical = "miss",
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- "dtxsid_Chemical"
  result <- classify_consensus(df, dtxsid_cols)

  expect_equal(result$consensus_status[1], "error")
})

test_that("classify_consensus assigns single (not wqx) when DTXSID is present alongside wqx", {
  # One col: NA dtxsid + wqx_exact tier; Other col: real DTXSID + exact tier
  # n_present > 0, so WQX guard should NOT fire
  df <- data.frame(
    Chemical = "Arsenic",
    dtxsid_Chemical = NA_character_,
    source_tier_Chemical = "wqx_exact",
    dtxsid_Other = "DTXSID123",
    source_tier_Other = "exact",
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_Other")
  result <- classify_consensus(df, dtxsid_cols)

  # n_present == 1 (only dtxsid_Other has a real DTXSID), so "single"
  expect_equal(result$consensus_status[1], "single")
})
