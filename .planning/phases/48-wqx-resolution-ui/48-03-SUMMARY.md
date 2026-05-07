---
phase: 48-wqx-resolution-ui
plan: 03
subsystem: curation-pipeline
tags: [bug-fix, wqx, confidence-propagation, gap-closure]
dependency_graph:
  requires: [48-01, 48-02]
  provides: [wqx_confidence in map_results_to_rows output]
  affects: [R/mod_review_results.R (resolution_state), Review Results table, WQX Review modal]
tech_stack:
  added: []
  patterns: [pre-allocation vector pattern extended to 6th vector]
key_files:
  created: []
  modified:
    - R/curation.R
    - tests/testthat/test-mod-review-helpers.R
decisions:
  - "Guard wqx_confidence fill with column presence check to handle non-WQX-enabled curation runs gracefully"
  - "Pre-allocate wqx_conf_vec with NA_real_ so column always exists in output regardless of WQX state"
metrics:
  duration: 182s
  completed: 2026-05-07T20:16:11Z
  tasks: 2/2
  files_modified: 2
---

# Phase 48 Plan 03: wqx_confidence Propagation Fix Summary

**One-liner:** Fixed BLOCKER gap where wqx_confidence was computed in wqx_rows but silently dropped by map_results_to_rows() due to missing 6th pre-allocation vector.

## What Changed

The `map_results_to_rows()` function in `R/curation.R` pre-allocates result vectors for each column it maps back to the original data frame. It had 5 vectors (dtxsid, preferredName, searchName, rank, source_tier) but `wqx_confidence` -- added by Plan 01's `wqx_rows` tibble -- was never included. This caused the column to be silently dropped during the mapping step, so `resolution_state` never had `wqx_confidence`, and the "WQX Conf." reactable column and modal confidence display always showed NA.

### Fix (Task 1)

Three changes inside the `for (col in tag_cols)` loop of `map_results_to_rows()`:

1. **Pre-allocation:** Added `wqx_conf_vec <- rep(NA_real_, input_rows)` as the 6th vector
2. **Guarded fill:** Added `if ("wqx_confidence" %in% names(lookup_deduped)) { wqx_conf_vec[ridx] <- lookup_deduped$wqx_confidence[match_pos] }` in the inner loop
3. **Assignment:** Added `df$wqx_confidence <- wqx_conf_vec` in the single-tag branch and `df[[paste0("wqx_confidence", suffix)]] <- wqx_conf_vec` in the multi-tag branch

The guard handles the case where curation runs without WQX matching enabled (no `wqx_confidence` column in `lookup_results` at all).

### Integration Tests (Task 2)

Added Test Group 6 with 3 new integration tests that call `map_results_to_rows()` directly:

1. WQX fuzzy row gets correct confidence score (0.87)
2. Mixed rows: CompTox row gets NA, WQX fuzzy row gets 0.87
3. Graceful handling when `lookup_results` lacks `wqx_confidence` column entirely (column still created with all NA)

## Task Log

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Fix map_results_to_rows wqx_confidence propagation | f6fba84 | R/curation.R |
| 2 | Add integration tests for wqx_confidence propagation | 9d738e9 | tests/testthat/test-mod-review-helpers.R |

## Verification Results

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| `grep -c "wqx_conf_vec" R/curation.R` | >= 4 | 4 | PASS |
| `grep -c "map_results_to_rows" tests/testthat/test-mod-review-helpers.R` | >= 3 | 7 | PASS |
| All tests pass | 0 failures | 0 failures, 25 pass | PASS |

## Deviations from Plan

None -- plan executed exactly as written.

**Test count note:** The plan predicted 21 total tests (18 existing + 3 new). The actual count is 25 (22 existing + 3 new). The plan's baseline count of 18 was outdated; the file already had 22 tests from prior wave work. This is not a deviation -- all tests pass.

## Known Stubs

None. The fix wires real data through the existing pipeline with no placeholder values.

## Self-Check: PASSED

All files found (R/curation.R, tests/testthat/test-mod-review-helpers.R, 48-03-SUMMARY.md). All commits found (f6fba84, 9d738e9).
