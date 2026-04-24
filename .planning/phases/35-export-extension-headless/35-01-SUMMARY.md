---
phase: 35-export-extension-headless
plan: 01
subsystem: export
tags: [export, toxval, arrow, excel]
dependency_graph:
  requires: [toxval_mapper, cleaning_reference]
  provides: [8-sheet-export, toxval-output-sheet]
  affects: [mod_review_results, curate_headless]
tech_stack:
  added: [arrow]
  patterns: [null-guard-sheet]
key_files:
  created: []
  modified:
    - DESCRIPTION
    - R/export_helpers.R
    - R/mod_review_results.R
    - tests/testthat/test-export-import.R
decisions:
  - "arrow added to Imports without version constraint (per 35-PATTERNS.md)"
  - "Null-guard pattern matches existing Sheet 4 (Cleaning Audit) pattern"
  - "Sheet 8 placeholder says 'Harmonization not run' when toxval_output is NULL"
metrics:
  duration: "226s"
  completed: "2026-04-17"
  tasks: 2
  files: 4
---

# Phase 35 Plan 01: Export Extension + Sheet 8 Summary

**One-liner:** 8-sheet Excel export with ToxVal Output sheet using null-guard placeholder pattern, arrow added to Imports

## What Was Done

Extended the ChemReg Excel export from 7 sheets to 8 sheets by adding a "ToxVal Output" sheet that displays the 56-column ToxVal schema output when harmonization has been run, or a placeholder note when it has not.

## Task Completion

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add arrow to DESCRIPTION + extend build_export_sheets with Sheet 8 | 7819c11 | DESCRIPTION, R/export_helpers.R |
| 2 | Wire Shiny export + update tests for 8 sheets | 4a49157 | R/mod_review_results.R, tests/testthat/test-export-import.R |

## Changes Detail

### DESCRIPTION
- Added `arrow,` as first Imports entry (alphabetical, before bsicons)

### R/export_helpers.R
- Updated header comment from "7-sheet" to "8-sheet"
- Added `toxval_output = NULL` parameter to `build_export_sheets()`
- Added `@param toxval_output` roxygen documentation
- Updated `@return` to say "Named list of 8 data frames"
- Added Sheet 8 "ToxVal Output" construction with null-guard pattern
- Updated return list to include 8th sheet

### R/mod_review_results.R
- Updated comment from "7 export sheets" to "8 export sheets"
- Added `toxval_output = data_store$toxval_output` to build_export_sheets() call

### tests/testthat/test-export-import.R
- Updated sheet count test from 7 to 8
- Updated expected sheet names to include "ToxVal Output"
- Added test: "Sheet 8 ToxVal Output contains placeholder when toxval_output is NULL"
- Added test: "Sheet 8 ToxVal Output contains data when toxval_output provided"
- All 64 tests pass (0 failures, 2 pre-existing skips)

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None. Sheet 8 correctly shows placeholder when toxval_output is NULL and real data when provided. Both paths are tested.

## Verification Results

1. `grep -c "arrow," DESCRIPTION` returns 1
2. `grep "toxval_output" R/export_helpers.R` shows param and sheet construction (5 matches)
3. `grep "toxval_output" R/mod_review_results.R` shows wiring (1 match)
4. All 64 export tests pass with 0 failures

## Self-Check: PASSED

- FOUND: DESCRIPTION
- FOUND: R/export_helpers.R
- FOUND: R/mod_review_results.R
- FOUND: tests/testthat/test-export-import.R
- FOUND: commit 7819c11
- FOUND: commit 4a49157
