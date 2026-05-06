---
phase: 45-pipeline-integration
plan: "02"
subsystem: curation
tags: [wqx, pipeline, integration, match_wqx, run_curation_pipeline, testthat]
dependency_graph:
  requires:
    - phase: 45-01
      provides: WQX-consensus-guard in consensus.R (wqx status classification)
    - phase: 44
      provides: match_wqx function and load_wqx_dictionary in wqx_matching.R / cleaning_reference.R
  provides:
    - WQX matching tier wired into run_curation_pipeline (Tier 3b after starts-with)
    - n_wqx counter in search_summary return value
    - Integration tests for WQX pipeline wiring (Groups 3-6)
  affects:
    - R/curation.R
    - tests/testthat/test-wqx-pipeline-integration.R
tech-stack:
  added: []
  patterns:
    - "WQX tier slots between starts-with and miss-row construction -- consumes final_missed, narrows it before n_miss is set"
    - "Dictionary loaded via load_wqx_dictionary(cache_dir) lazy cache pattern inside the tier block"
    - "wqx_rows tibble uses preferredName=wqx_name, dtxsid=NA_character_, source_tier=paste0('wqx_', match_tier)"
key-files:
  created: []
  modified:
    - R/curation.R
    - tests/testthat/test-wqx-pipeline-integration.R
key-decisions:
  - "D-01 honored: WQX tier fires inside run_curation_pipeline after starts-with, before miss-row construction"
  - "D-02 honored: Dictionary loaded via load_wqx_dictionary() lazy cache -- not passed as argument"
  - "D-03 honored: preferredName = wqx_name (WQX canonical), dtxsid = NA_character_"
  - "D-05 honored: source_tier = paste0('wqx_', match_tier) producing wqx_exact/wqx_alias/wqx_fuzzy"
  - "D-06 honored: No new arguments to run_curation_pipeline -- curate_headless() works unchanged"
patterns-established:
  - "Tier 3b pattern: load dictionary, call matcher, filter resolved rows, build combined_results-schema tibble, narrow final_missed, report progress"
  - "Counter pattern: n_wqx initialized as 0L alongside other tier counters, exposed in search_summary"
requirements-completed: [INTG-02, INTG-03, INTG-04]
duration: 12min
completed: "2026-05-06"
---

# Phase 45 Plan 02: WQX Pipeline Integration Summary

**WQX Tier 3b wired into run_curation_pipeline: names failing all CompTox tiers are automatically passed to match_wqx(), with canonical WQX names surfaced in preferredName and wqx_* source_tier values narrowing final_missed before miss rows are built.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-05-06T17:45:00Z
- **Completed:** 2026-05-06T17:57:00Z
- **Tasks:** 3 (2 code, 1 verification-only)
- **Files modified:** 2

## Accomplishments

- Added Tier 3b WQX matching block into `run_curation_pipeline()` between the starts-with tier and miss-row construction -- per locked decision D-01
- `n_wqx` counter initialized alongside other tier counters and exposed in `search_summary` return value
- 4 new test groups appended to `test-wqx-pipeline-integration.R` (22 total assertions, 0 failures)
- Shiny cold boot passes -- app starts on `http://127.0.0.1:3838` with no errors
- All 127 consensus tests, 46 WQX matching tests, and 22 pipeline integration tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire WQX tier into run_curation_pipeline()** - `a916779` (feat)
2. **Task 2: Add integration tests for WQX pipeline wiring** - `110b0cb` (test)
3. **Task 3: Shiny smoke test** - no commit (verification-only per plan)

## Files Created/Modified

- `R/curation.R` - Three modifications: n_wqx counter init, Tier 3b WQX block, n_wqx in search_summary
- `tests/testthat/test-wqx-pipeline-integration.R` - Groups 3-6 appended (4 new test_that blocks, 16 new assertions)

## Decisions Made

All locked decisions (D-01 through D-06) were applied exactly as specified. No new decisions were required.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. The advisory complexity warnings from the pre-commit hook (O(n^2) potential in `%in%` inside loops) all reference pre-existing code in `cas_from_names` and `cas_results` sections, not the WQX block added in this plan. The WQX tier uses no loop-internal `%in%` calls — it does a single vectorized filter (`wqx_raw$match_tier != "none"`) and a single `setdiff()`.

## User Setup Required

None - no external service configuration required. WQX dictionary is loaded from the existing reference cache via `load_wqx_dictionary()` (built in Phase 44).

## Next Phase Readiness

- `run_curation_pipeline()` now fully wired: CompTox exact → CAS → starts-with → WQX → miss
- `curate_headless()` inherits WQX matching automatically (no changes needed, per INTG-04)
- `search_summary$n_wqx` is available for UI display if desired in a future phase
- `consensus.R` WQX guard (from Plan 45-01) and `curation.R` WQX tier (this plan) are both in place -- the full INTG-02/03/04 chain is complete

## Known Stubs

None. The WQX tier is fully wired end-to-end.

## Threat Flags

No new threat surface introduced beyond the plan's threat model (T-45-03, T-45-04, T-45-05 were all accepted at plan authoring time).

## Self-Check: PASSED

- R/curation.R: FOUND
- tests/testthat/test-wqx-pipeline-integration.R: FOUND
- .planning/phases/45-pipeline-integration/45-02-SUMMARY.md: FOUND (this file)
- commit a916779 (Task 1 feat): FOUND
- commit 110b0cb (Task 2 test): FOUND
- String checks:
  - `n_wqx <- 0L`: FOUND at line 677
  - `match_wqx(final_missed, wqx_dict, verbose = FALSE)`: FOUND at line 759
  - `load_wqx_dictionary(cache_dir)`: FOUND at line 758
  - `paste0("wqx_", wqx_resolved$match_tier)`: FOUND at line 771
  - `n_wqx = n_wqx`: FOUND at line 910
  - `progress_callback("wqx"`: FOUND at line 780
- Shiny smoke test: PASSED (Listening on http://127.0.0.1:3838)
- test-consensus.R: 127 PASS, 0 FAIL
- test-wqx-matching.R: 46 PASS, 0 FAIL
- test-wqx-pipeline-integration.R: 22 PASS, 0 FAIL

---
*Phase: 45-pipeline-integration*
*Completed: 2026-05-06*
