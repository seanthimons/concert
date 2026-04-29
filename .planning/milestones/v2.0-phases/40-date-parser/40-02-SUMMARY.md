---
phase: 40-date-parser
plan: "02"
subsystem: tag-classification
tags: [tag-helpers, mod-tag-columns, study-types, classify-tags]
dependency_graph:
  requires: []
  provides: [classify_tags-4-element-return, study_type_tags-data-store, Study-Contextual-optgroup]
  affects: [R/mod_harmonize.R, R/date_parser.R]
tech_stack:
  added: []
  patterns: [four-element-classify-tags, study_types-membership-vector]
key_files:
  created: []
  modified:
    - R/tag_helpers.R
    - R/mod_tag_columns.R
    - tests/testthat/test-tag-dispatch.R
decisions:
  - "classify_tags() returns 4-element list: chemical_tags, numeric_tags, metadata_tags, study_type_tags per D-13"
  - "study_types membership vector contains only 'StudyDate'; Phase 41 Media tag will be added here"
  - "Optgroup renamed to 'Study / Contextual' per D-14; display label is 'Study Date' (with space), value is 'StudyDate' (camelCase)"
metrics:
  duration: "~10 minutes"
  completed: "2026-04-26"
  tasks_completed: 2
  files_modified: 3
requirements:
  - DATE-04
---

# Phase 40 Plan 02: Tag Classification — study_types Group Summary

classify_tags() extended to 4-element return with study_type_tags slot; StudyDate wired through mod_tag_columns into data_store for Plan 03 consumption.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Extend classify_tags() with study_types group | 41fb903 | R/tag_helpers.R, tests/testthat/test-tag-dispatch.R |
| 2 | Update mod_tag_columns.R optgroup and data_store wiring | d25e52b | R/mod_tag_columns.R |

## What Was Built

### classify_tags() — 4-element return (R/tag_helpers.R)

Added a fourth `study_types` membership vector (`c("StudyDate")`) and corresponding `study_type_tags` slot to `classify_tags()`. The function now returns:

```r
list(
  chemical_tags   = ...,  # Name, CASRN, Other
  numeric_tags    = ...,  # Result, Unit, Qualifier, Duration, DurationUnit
  metadata_tags   = ...,  # Species, ExposureRoute
  study_type_tags = ...   # StudyDate (Phase 40); Media (Phase 41 future)
)
```

Both the empty-input early return and the main return path include `study_type_tags`. The partition pattern follows the existing `metadata_idx`/`metadata_tags` build exactly.

### Tag Dropdown — "Study / Contextual" optgroup (R/mod_tag_columns.R)

The `"Study"` optgroup was renamed to `"Study / Contextual"` and a new entry added:
```r
"Study Date" = "StudyDate"
```
Display label uses a space ("Study Date"); the tag value uses camelCase ("StudyDate") per the UI-SPEC copywriting contract.

### data_store$study_type_tags wiring (R/mod_tag_columns.R)

Added the assignment in `observeEvent(input$apply_tags)` after the existing metadata assignment:
```r
data_store$study_type_tags <- classified$study_type_tags
```
This provides the data flow path that Plan 03 (harmonize module) will consume via `data_store$study_type_tags`.

### Tests (tests/testthat/test-tag-dispatch.R)

- Updated two `expect_named` assertions (lines 9 and 53) to include `"study_type_tags"`
- Added `"classify_tags partitions study_type tags correctly"` test — StudyDate-only input, verifies correct partition and all other slots empty
- Added `"classify_tags handles mixed tags including StudyDate"` test — Name + Result + StudyDate + Species input, verifies each tag routes to its correct slot
- All 47 tests pass (0 failures)

## Verification

```
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 47 ] Done!  ← test-tag-dispatch.R
[ FAIL 3 | WARN 14 | SKIP 2 | PASS 1675 ]     ← full suite (3 pre-existing failures in test-reference-provenance.R, unrelated)
```

The 3 pre-existing failures in `test-reference-provenance.R` were confirmed present on the base commit before any changes.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. `study_type_tags` is populated from a real UI dropdown value and stored in `data_store`. Plan 03 will read it.

## Threat Flags

No new network endpoints, auth paths, file access patterns, or schema changes introduced. `study_type_tags` is stored in session-scoped `reactiveValues` (server-side only). STRIDE threats T-40-04 and T-40-05 remain `accept` disposition as documented in the plan's threat model.

## Self-Check: PASSED

- R/tag_helpers.R exists and contains `study_types <- c("StudyDate")`: FOUND
- R/tag_helpers.R contains `study_type_tags = list()` in empty return: FOUND
- R/tag_helpers.R contains `study_type_idx <- which(tag_values %in% study_types)`: FOUND
- R/tag_helpers.R contains `study_type_tags = study_type_tags` in final return: FOUND
- R/mod_tag_columns.R contains `"Study / Contextual"`: FOUND
- R/mod_tag_columns.R contains `"Study Date" = "StudyDate"`: FOUND
- R/mod_tag_columns.R contains `data_store$study_type_tags <- classified$study_type_tags`: FOUND
- test-tag-dispatch.R line 9 contains `"study_type_tags"` in expect_named: FOUND
- test-tag-dispatch.R line 53 contains `"study_type_tags"` in expect_named: FOUND
- test-tag-dispatch.R contains `"classify_tags partitions study_type tags correctly"`: FOUND
- Commit 41fb903 exists: FOUND
- Commit d25e52b exists: FOUND
