---
phase: 45-pipeline-integration
verified: 2026-05-06T18:30:00Z
status: passed
score: 9/9
overrides_applied: 0
---

# Phase 45: Pipeline Integration — Verification Report

**Phase Goal:** WQX matching fires automatically in the curation pipeline for names that failed CompTox
**Verified:** 2026-05-06T18:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | After CompTox curation, names with no DTXSID are automatically passed to the WQX matcher without any user action | VERIFIED | `run_curation_pipeline()` contains Tier 3b block at lines 755-782 of `R/curation.R`: calls `match_wqx(final_missed, wqx_dict, verbose = FALSE)` after the starts-with tier. No user toggle. `curate_headless()` inherits this automatically via existing `run_curation_pipeline()` call (line 176 of `R/curate_headless.R`). |
| 2 | WQX-resolved rows appear in combined_results with `preferredName` set to WQX canonical name and `dtxsid = NA` | VERIFIED | `wqx_rows` tibble at curation.R lines 765-772 sets `dtxsid = NA_character_` and `preferredName = wqx_resolved$wqx_name`. Schema exactly matches `combined_results` schema. Confirmed by Group 3 integration test (10 assertions, all passing). |
| 3 | WQX source_tier values are `wqx_exact`, `wqx_alias`, or `wqx_fuzzy` | VERIFIED | `source_tier = paste0("wqx_", wqx_resolved$match_tier)` at curation.R line 771. Group 5 test explicitly asserts membership in `c("wqx_exact", "wqx_alias", "wqx_fuzzy")`. |
| 4 | `final_missed` is narrowed after WQX matching — only truly unresolved names remain as miss rows | VERIFIED | `final_missed <- setdiff(final_missed, wqx_matched_names)` at curation.R line 777. Group 4 test verifies narrowing: 3 input names → 1 remaining ("TotallyFakeChemical"). |
| 5 | `search_summary` includes `n_wqx` count | VERIFIED | `n_wqx = n_wqx` at curation.R line 910 in the `search_summary` list return value. Confirmed by grep output. |
| 6 | `curate_headless()` includes WQX matching without any new arguments | VERIFIED | `curate_headless()` calls `run_curation_pipeline(cleaning_result$cleaned_data, merged_tags)` at line 176 — same signature as before Phase 45. No new arguments added. WQX tier fires inside the pipeline automatically. |
| 7 | `compute_qc_tier("wqx", 0L, k)` returns `as.integer(k)` — same tier as "single" | VERIFIED | `"wqx" = as.integer(n_total)` at consensus.R line 36. Group 1 test asserts k=1,2,3 return 1L,2L,3L (all pass). |
| 8 | `classify_consensus` assigns `consensus_status = "wqx"` for rows where all DTXSIDs are NA but `source_tier` is `wqx_*` | VERIFIED | WQX guard at consensus.R lines 89-109: checks `n_present == 0`, then `is_wqx_row` via `grepl("^wqx_", row_tiers)`, assigns `"wqx"` status and calls `next`. Groups 2 tests verify `wqx_exact`, `wqx_alias`, `wqx_fuzzy` (all pass). |
| 9 | `classify_consensus` assigns `consensus_status = "error"` for rows where all DTXSIDs are NA and `source_tier` is NOT `wqx_*` | VERIFIED | Guard only fires when `is_wqx_row` is TRUE; rows with `source_tier = "miss"` fall through to the existing `if (n_present == 0) → "error"` branch at line 111. Test confirms "error" for `source_tier_Chemical = "miss"`. |

**Score:** 9/9 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `R/consensus.R` | WQX guard in `classify_consensus` + `wqx` case in `compute_qc_tier` | VERIFIED | Contains `"wqx" = as.integer(n_total)` (line 36), `is_wqx_row <- any(...)` (line 98), `consensus_status[i] <- "wqx"` (line 101), `compute_qc_tier("wqx", 0L, k)` (line 106). Committed in d3caf12. |
| `R/curation.R` | WQX tier insertion in `run_curation_pipeline` | VERIFIED | Contains `match_wqx(final_missed, wqx_dict, verbose = FALSE)` (line 759), `load_wqx_dictionary(cache_dir)` (line 758), `paste0("wqx_", wqx_resolved$match_tier)` (line 771), `n_wqx = n_wqx` (line 910). Committed in a916779. |
| `tests/testthat/test-wqx-pipeline-integration.R` | Unit + integration tests for WQX pipeline | VERIFIED | 186 lines, 10 `test_that` blocks (exceeds min_lines: 120 and min count of 10). All 22 assertions pass. Committed across 52378d1 and 110b0cb. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `R/consensus.R:classify_consensus` | `R/consensus.R:compute_qc_tier` | `compute_qc_tier("wqx", 0L, k)` inside WQX guard | WIRED | Pattern `compute_qc_tier("wqx"` found at consensus.R line 106. |
| `R/curation.R:run_curation_pipeline` | `R/wqx_matching.R:match_wqx` | `match_wqx(final_missed, wqx_dict, verbose = FALSE)` | WIRED | Pattern `match_wqx(final_missed` found at curation.R line 759. |
| `R/curation.R:run_curation_pipeline` | `R/cleaning_reference.R:load_wqx_dictionary` | `load_wqx_dictionary(cache_dir)` | WIRED | Pattern `load_wqx_dictionary(` found at curation.R line 758. |
| `R/curate_headless.R` | `R/curation.R:run_curation_pipeline` | Existing call at line 176 — no changes needed | WIRED | `run_curation_pipeline(cleaning_result$cleaned_data, merged_tags)` confirmed at curate_headless.R line 176. No new arguments required. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `R/curation.R` Tier 3b block | `wqx_dict` | `load_wqx_dictionary(cache_dir)` reads RDS from `inst/extdata/reference_cache/` (built in Phase 43/44) | Yes — lazy-cached dictionary built from EPA CSVs | FLOWING |
| `R/curation.R` Tier 3b block | `wqx_raw` | `match_wqx(final_missed, wqx_dict, verbose = FALSE)` | Yes — real matching logic from Phase 44, verified by 46 passing tests | FLOWING |
| `R/curation.R` Tier 3b block | `wqx_rows` | `wqx_resolved$wqx_name` and `paste0("wqx_", wqx_resolved$match_tier)` | Yes — populated from real match results, not hardcoded empty | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| WQX pipeline integration tests pass | `testthat::test_file("tests/testthat/test-wqx-pipeline-integration.R")` | 22 assertions, 0 failures, 0 skips (API-gated test skipped without key) | PASS |
| Consensus regression tests pass | `testthat::test_file("tests/testthat/test-consensus.R")` | All tests pass, 1 expected warning (pinned rows — pre-existing) | PASS |
| WQX matching regression tests pass | `testthat::test_file("tests/testthat/test-wqx-matching.R")` | 46 assertions, 0 failures | PASS |
| Shiny cold boot | `chemreg::run_app(port=3838, launch.browser=FALSE)` | `Listening on http://127.0.0.1:3838` — no errors | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| INTG-02 | 45-01, 45-02 | WQX match resolves into same output column as curated compound names | SATISFIED | `preferredName = wqx_resolved$wqx_name` in `wqx_rows` (curation.R:768). WQX consensus guard assigns `"wqx"` status, not "error" (consensus.R:101). |
| INTG-03 | 45-02 | Auto-fires for names that failed CompTox curation — no user toggle | SATISFIED | Tier 3b fires unconditionally inside `run_curation_pipeline()` after starts-with tier when `final_missed` is non-empty. No arguments, no toggle. |
| INTG-04 | 45-02 | `curate_headless()` includes WQX matching in its pipeline | SATISFIED | `curate_headless()` calls `run_curation_pipeline()` unchanged at line 176. No new arguments needed. WQX fires automatically. |

All three requirements assigned to Phase 45 in REQUIREMENTS.md are satisfied. No orphaned requirements identified.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | — | — | — |

No TODOs, FIXMEs, placeholder comments, empty return values, or stub patterns found in `R/consensus.R` or `R/curation.R`.

### Human Verification Required

None. All observable behaviors are verifiable programmatically through the test suite and code inspection. The Shiny smoke test confirms the app starts cleanly with the WQX wiring in place.

### Gaps Summary

No gaps. All 9 must-have truths verified. All artifacts exist and are substantive. All key links are wired. All three INTG requirements are satisfied. Test suite passes with zero failures.

---

## Implementation Notes

One deviation from the plan wording is worth documenting (functionally equivalent, not a gap):

The 45-01 PLAN specified the WQX guard should be placed BEFORE the `if (n_present == 0)` branch with the combined condition `if (is_wqx_row && n_present == 0)`. The actual implementation wraps the WQX check inside `if (n_present == 0) { ... if (is_wqx_row) { ... next } }` — this is logically equivalent but avoids computing `row_tiers` for rows that already have DTXSIDs. The summary documented this as an auto-fixed optimization.

TDD gate compliance is confirmed: commit 52378d1 (RED — 6 failing tests) precedes commit d3caf12 (GREEN — all 9 passing), in correct order.

---

_Verified: 2026-05-06T18:30:00Z_
_Verifier: Claude (gsd-verifier)_
