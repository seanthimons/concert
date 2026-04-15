---
phase: 33-extended-column-tagging
plan: 01
subsystem: shiny-ui
tags: [tag-dispatch, cascade-reset, harmonization]
dependency_graph:
  requires: []
  provides: [classify_tags, validate_tag_pairing, detect_tag_changes, optgroup-ui, granular-reset]
  affects: [mod_tag_columns.R, app.R]
tech_stack:
  added: []
  patterns: [tag-dispatch, cascade-reset-per-type]
key_files:
  created:
    - R/tag_helpers.R
    - tests/testthat/test-tag-dispatch.R
    - man/classify_tags.Rd
    - man/validate_tag_pairing.Rd
    - man/detect_tag_changes.Rd
  modified:
    - R/mod_tag_columns.R
    - inst/app/app.R
    - NAMESPACE
decisions:
  - D-03: Tag dispatch helpers as single source of truth for type membership
  - D-04: column_tags contains ONLY chemical tags for backwards compatibility
  - D-09: Granular cascade resets per tag type
metrics:
  duration: 6m
  completed: 2026-04-15T20:26:18Z
  tasks: 2
  files: 7
---

# Phase 33 Plan 01: Extended Column Tagging Summary

Tag dispatch helpers with optgroup UI and granular cascade resets for independent chemical/numeric pipeline invalidation.

## Commits

| Hash | Type | Message |
|------|------|---------|
| b7ba668 | test | add failing tests for tag dispatch helpers |
| 021dcef | feat | add tag dispatch helpers with classify/validate/detect |
| f6fce63 | feat | extend tag module UI with optgroups and dispatch wiring |

## What Was Built

### Task 1: Tag Dispatch Helpers (TDD)

Created `R/tag_helpers.R` with three exported functions:

1. **classify_tags(tags)** - Partitions named tag list into:
   - `chemical_tags`: Name, CASRN, Other (per D-06)
   - `numeric_tags`: Result, Unit, Qualifier, Duration, DurationUnit (per D-07)
   - `metadata_tags`: Species, ExposureRoute (per D-08)

2. **validate_tag_pairing(tags)** - Warns on unpaired Result/Unit (per D-12/D-13)
   - Returns warning message string or NULL
   - Non-blocking warning only

3. **detect_tag_changes(old_tags, new_tags)** - Change detection for cascade resets
   - Handles NULL old_tags (first apply)
   - Compares names and values

Test coverage: 17 test cases, 38 assertions pass.

### Task 2: UI and Dispatch Wiring

**mod_tag_columns.R:**
- Updated dropdown to use optgroups: Chemical, Numeric, Study
- All 10 tag types accessible (3 chemical + 5 numeric + 2 metadata)
- Integrated classify_tags() in Apply Tags observer
- Added validate_tag_pairing() warning notification
- column_tags now contains ONLY chemical tags (backwards compatible)

**inst/app/app.R:**
- Added 7 new data_store fields: numeric_tags, metadata_tags, harmonize_results, harmonize_audit, toxval_output, prev_chemical_tags, prev_numeric_tags
- Added reset_chemical_downstream() - nulls curation pipeline state
- Added reset_numeric_downstream() - nulls harmonization pipeline state
- Added cascade reset observers for column_tags and numeric_tags changes
- Extended reset_all_downstream() to include new fields

## Verification

- All 38 tag dispatch tests pass
- Full test suite: 1421 pass, 2 pre-existing failures (unrelated reference list structure tests)
- Smoke test: App starts successfully ("Listening on http://127.0.0.1:3838")

## Requirements Satisfied

| ID | Description | Status |
|----|-------------|--------|
| UITG-01 | Optgroup-categorized tag dropdown | Complete |
| UITG-02 | Apply Tags partitions into chemical_tags, numeric_tags, metadata_tags | Complete |
| UITG-03 | Independent cascade resets per tag type | Complete |

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

- [x] R/tag_helpers.R exists
- [x] tests/testthat/test-tag-dispatch.R exists
- [x] Commits b7ba668, 021dcef, f6fce63 exist
- [x] All files modified as specified in plan
