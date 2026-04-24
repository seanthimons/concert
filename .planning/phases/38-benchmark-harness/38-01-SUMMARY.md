---
phase: 38-benchmark-harness
plan: "01"
subsystem: pipeline-api
tags: [use_dedup, benchmark, package-config, forward-compat]
dependency_graph:
  requires: []
  provides: [use_dedup-parameter-on-run_cleaning_pipeline, use_dedup-parameter-on-harmonize_units, bench-in-suggests, data-benchmark-gitignored]
  affects: [R/cleaning_pipeline.R, R/unit_harmonizer.R, DESCRIPTION, .gitignore]
tech_stack:
  added: []
  patterns: [forward-compatible-parameter, roxygen-documentation]
key_files:
  modified:
    - R/cleaning_pipeline.R
    - R/unit_harmonizer.R
    - DESCRIPTION
    - .gitignore
decisions:
  - "use_dedup = TRUE is forward-compatible: parameter added to both functions but has no behavioral effect until Phase 37 dedup wiring merges"
  - "bench placed in Suggests (not Imports) — benchmark script is dev-only tooling, not required by runtime"
  - "data/benchmark/ gitignored per T-38-02 threat mitigation to prevent accidental commit of regulatory datasets"
metrics:
  duration_minutes: 15
  completed_date: "2026-04-24"
  tasks_completed: 2
  files_modified: 4
---

# Phase 38 Plan 01: Benchmark Harness Infrastructure Summary

**One-liner:** Added `use_dedup = TRUE` toggle to `run_cleaning_pipeline()` and `harmonize_units()` for apples-to-apples benchmark comparison, plus `bench` in Suggests and `data/benchmark/` gitignored.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add use_dedup toggle to run_cleaning_pipeline() and harmonize_units() | ad52f8d | R/cleaning_pipeline.R, R/unit_harmonizer.R |
| 2 | Add bench to DESCRIPTION Suggests and data/benchmark/ to .gitignore | 1626146 | DESCRIPTION, .gitignore |

## What Was Built

**Task 1 — use_dedup parameter:**

Both pipeline entry points now accept a `use_dedup = TRUE` parameter:

- `run_cleaning_pipeline(df, tag_map = NULL, reference_lists = NULL, use_dedup = TRUE)`
- `harmonize_units(values, units, unit_map, media = NULL, dtxsid = NULL, molecular_weight = NULL, use_dedup = TRUE)`

Both include roxygen `@param use_dedup` documentation. The parameter is forward-compatible: since Phase 37's `dedup_step()` wiring has not yet merged into this branch, `use_dedup = TRUE` and `use_dedup = FALSE` currently produce identical behavior. The toggle becomes active when Phase 37 plans 02-04 merge. All existing callers are unaffected (default `TRUE` preserves current behavior).

**Task 2 — Package infrastructure:**

- `bench` added to `DESCRIPTION` Suggests field (alphabetical order, before `testthat`)
- `data/benchmark/` added to `.gitignore` immediately after `data/reference_cache/` to keep data-related ignores grouped

## Verification Results

```
1. run_cleaning_pipeline has use_dedup: TRUE
2. run_cleaning_pipeline default TRUE: TRUE
3. harmonize_units has use_dedup: TRUE
4. harmonize_units default TRUE: TRUE
DESCRIPTION: bench found (line 44)
GITIGNORE: data/benchmark/ found (line 20)
devtools::load_all(): OK
```

Test suite: 3 pre-existing failures in `test-cleaning-reference.R` and `test-reference-provenance.R` (documented acceptable per plan). No new failures introduced.

## Deviations from Plan

None — plan executed exactly as written.

The plan noted that dedup wiring may or may not be present (Phase 37 state-dependent). Current branch confirmed no `dedup_step()` calls in `run_cleaning_pipeline()` body, so the forward-compatible approach (parameter only, no conditional wrapping) was applied as specified.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The `.gitignore` addition directly mitigates T-38-02 (regulatory dataset accidental commit).

## Self-Check: PASSED

- `R/cleaning_pipeline.R` — modified, contains `use_dedup = TRUE` in signature
- `R/unit_harmonizer.R` — modified, contains `use_dedup = TRUE` in signature
- `DESCRIPTION` — modified, contains `bench,` at line 44
- `.gitignore` — modified, contains `data/benchmark/` at line 20
- Commit `ad52f8d` — verified in git log
- Commit `1626146` — verified in git log
