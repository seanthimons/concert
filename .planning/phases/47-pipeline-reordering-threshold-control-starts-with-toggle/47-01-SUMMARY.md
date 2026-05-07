---
phase: 47-pipeline-reordering-threshold-control-starts-with-toggle
plan: 01
status: complete
started: 2026-05-06T21:30:00-04:00
completed: 2026-05-06T22:00:00-04:00
---

## What was built

Reordered the curation pipeline so WQX dictionary matching runs as Tier 3 (before CompTox starts-with), added `wqx_threshold` and `starts_with` parameters to `run_curation_pipeline()` and `curate_headless()`, and gated starts-with execution on the boolean flag.

## Key changes

- **R/curation.R**: Signature now includes `wqx_threshold = 0.85` and `starts_with = FALSE`. WQX tier receives `still_missed` directly and passes user-configured threshold to `match_wqx()`. Starts-with is nested inside the WQX block, gated by `if (starts_with && ...)`, and receives only post-WQX misses.
- **R/curate_headless.R**: Signature extended with `wqx_threshold = 0.85` and `starts_with = FALSE`, both threaded to `run_curation_pipeline()`.
- **tests/testthat/test-pipeline-reorder-toggle.R**: 5 test cases using namespace-level mocking to verify tier ordering (ORD-01), name exclusion (ORD-02), threshold passthrough (CONF-02), and toggle gating (TOG-02).

## Key files

### Created
- `tests/testthat/test-pipeline-reorder-toggle.R`

### Modified
- `R/curation.R`
- `R/curate_headless.R`

## Self-Check: PASSED

All 5 test_that blocks pass (7 expectations). TDD RED-GREEN cycle complete.

## Deviations

- Tests use `unlockBinding`/`assign` namespace-level mocking instead of `local_mocked_bindings` because `devtools::load_all()` locks the namespace, preventing `local_mocked_bindings` from intercepting calls within the package.
- Tag value corrected from `"Chemical Name"` to `"Name"` to match what `deduplicate_tagged_columns()` expects.
