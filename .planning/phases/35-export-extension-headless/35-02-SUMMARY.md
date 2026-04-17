---
phase: 35-export-extension-headless
plan: 02
subsystem: headless-pipeline
tags: [headless, harmonize, parquet, toxval, arrow]
dependency_graph:
  requires: [35-01, toxval_mapper, numeric_parser, unit_harmonizer, cleaning_reference]
  provides: [headless-harmonize-pipeline, parquet-export, csv-export]
  affects: [curate_headless]
tech_stack:
  added: []
  patterns: [harmonize-pipeline-reuse, unit-broadcast, format-validation]
key_files:
  created:
    - tests/testthat/test-parquet-roundtrip.R
  modified:
    - R/curate_headless.R
decisions:
  - "apply_corrections defined inline as local function to avoid tight coupling with mod_harmonize.R Shiny-scoped helper"
  - "cache_dir_ref lazily initialized to avoid redundant system.file() calls when user provides both unit_map and corrections"
  - "Format validation runs early (Step 1b) for fail-fast even when harmonize=FALSE"
metrics:
  duration: "271s"
  completed: "2026-04-17"
  tasks: 2
  files: 2
---

# Phase 35 Plan 02: Headless Harmonize Pipeline + Parquet Tests Summary

**One-liner:** curate_headless() extended with corrections/parse/harmonize/toxval pipeline, parquet+CSV export, and 8 round-trip validation tests

## What Was Done

Extended `curate_headless()` to support the full harmonization pipeline when `harmonize=TRUE`. The function now accepts `harmonize`, `format`, `unit_map`, `corrections`, and `media` parameters. When harmonize is enabled, the pipeline runs four stages (corrections, numeric parsing, unit harmonization, ToxVal schema mapping) after curation, writes parquet and/or CSV output alongside the XLSX, and returns the 56-column ToxVal tibble with harmonization audit data. Created comprehensive parquet round-trip validation tests covering column preservation, type fidelity, value matching, zero-row edge cases, file naming conventions, CSV fallback, and format validation.

## Task Completion

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Extend curate_headless() with harmonize pipeline and format export | 37b5098 | R/curate_headless.R |
| 2 | Create parquet round-trip validation tests | a615392 | tests/testthat/test-parquet-roundtrip.R |

## Changes Detail

### R/curate_headless.R
- Updated roxygen: title mentions harmonization + multi-format export, 5 new @param entries, @return documents both harmonize=TRUE/FALSE paths, @importFrom arrow write_parquet
- Extended function signature with harmonize=FALSE, format="parquet", unit_map=NULL, corrections=NULL, media=NULL
- Added Step 1b: format validation against allowlist (parquet, csv, both)
- Added Step 8b: full harmonization pipeline (corrections -> parse_numeric_results -> harmonize_units -> map_to_toxval_schema) with unit broadcast pattern for range-expanded rows
- Updated Step 9: build_export_sheets() call now passes toxval_output=toxval_tibble
- Added Step 9b: writes _toxval.parquet and/or _toxval.csv per format param
- Updated Step 10: return branches on harmonize (TRUE returns data=toxval_tibble + harmonize_audit, FALSE returns data=resolution_state)

### tests/testthat/test-parquet-roundtrip.R (new)
- 8 test_that blocks with 16 total assertions
- Parquet round-trip: 56 columns preserved, types preserved, values match original
- Parquet round-trip: no logical columns after read (guards against bare NA regression)
- Parquet round-trip: zero-row tibble produces valid parquet
- File naming: ToxVal output derives basename from output_path (D-03)
- CSV round-trip: column count preserved
- Format validation: invalid format value raises error

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None. All code paths are fully wired and tested.

## Verification Results

1. `grep "harmonize = FALSE" R/curate_headless.R` -- found (param exists)
2. `grep "arrow::write_parquet" R/curate_headless.R` -- found (parquet export)
3. `grep "parse_numeric_results" R/curate_headless.R` -- found (harmonize pipeline)
4. `grep "map_to_toxval_schema" R/curate_headless.R` -- found (schema mapping)
5. Parquet round-trip tests: 16 pass, 0 fail
6. Export-import tests: 64 pass, 0 fail, 2 pre-existing skips

## Self-Check: PASSED

- FOUND: R/curate_headless.R
- FOUND: tests/testthat/test-parquet-roundtrip.R
- FOUND: commit 37b5098
- FOUND: commit a615392
