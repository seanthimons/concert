---
phase: 15-post-curation-qc
plan: 01
subsystem: data-cleaning
tags: [unicode, qc, comptoxr, chemistry]
dependency_graph:
  requires: [cleaning-pipeline, comptoxr]
  provides: [chemistry-unicode-cleaning, post-curation-qc-detection]
  affects: [unicode-handling, greek-letters, qc-reporting]
tech_stack:
  added: []
  patterns: [chemistry-dot-notation, read-only-qc, codepoint-reporting]
key_files:
  created:
    - tests/test_unicode_qc.R
    - tests/test_unicode_comptoxr.R
  modified:
    - R/cleaning_pipeline.R
    - R/modules/mod_clean_data.R
    - tests/test_cleaning_pipeline.R
decisions:
  - "Replaced custom clean_unicode_field with ComptoxR::clean_unicode for 157 chemistry-specific mappings"
  - "Greek letters convert to dot-notation (.alpha., .beta.) following chemistry conventions"
  - "perform_unicode_qc is read-only - detects issues without modifying data"
  - "Unicode detection uses non-ASCII byte scanning (grepl pattern) not ComptoxR internals"
metrics:
  duration: 627
  tasks_completed: 2
  files_modified: 5
  tests_added: 41
  commits: 4
completed: 2026-03-09T20:32:40Z
---

# Phase 15 Plan 01: Replace Unicode Cleaning with ComptoxR Summary

**One-liner:** Replaced generic stringi transliteration with ComptoxR's 157 chemistry-specific unicode mappings (Greek letters to dot-notation) and added post-curation QC detection function.

## Tasks Completed

### Task 1: Replace clean_unicode_field with ComptoxR::clean_unicode
**Status:** Complete
**Commits:** 51dc548, (implementation in 51dc548)
**Files:** R/cleaning_pipeline.R, R/modules/mod_clean_data.R, tests/test_cleaning_pipeline.R, tests/test_unicode_comptoxr.R

**Changes:**
- Deleted `clean_unicode_field()` function completely from R/cleaning_pipeline.R
- Replaced all calls to `clean_unicode_field` with `ComptoxR::clean_unicode`
- Updated in both run_cleaning_pipeline and mod_clean_data module
- Updated test expectations: Greek alpha (\u03B1) now produces ".alpha.-tocopherol" not "a-tocopherol"
- Added test_unicode_comptoxr.R with chemistry-specific unicode test cases

**Verification:** All 40 cleaning_pipeline tests pass with new expectations.

### Task 2: Create perform_unicode_qc() function
**Status:** Complete
**Commits:** a8b0b64, 272f66d
**Files:** R/cleaning_pipeline.R, tests/test_unicode_qc.R

**Changes:**
- Added `perform_unicode_qc(df)` function for post-curation Unicode detection
- Added `detect_non_ascii_chars(x)` helper for codepoint extraction and counting
- Function scans dataframe for non-ASCII characters without modification (read-only QC)
- Returns: rows_with_non_ascii count, row_indices vector, unhandled_chars list with codepoints
- Added test_unicode_qc.R with 8 comprehensive test cases

**Verification:** All 33 QC tests pass, covering clean data, Greek letters, NA handling, empty dataframes, and read-only behavior.

## Deviations from Plan

None - plan executed exactly as written.

## Key Technical Details

**ComptoxR Unicode Behavior:**
- Chemistry-focused: 157 mapped entries including Greek letters
- Greek alpha → ".alpha." (dot-notation, not "a")
- Greek beta → ".beta." (dot-notation, not "b")
- Unhandled unicode passes through unchanged with warning
- NOT a general-purpose unicode cleaner (cafe\u0301 → unchanged)

**perform_unicode_qc Detection:**
- Uses `grepl("[^\x01-\x7F]", x)` for non-ASCII detection (byte-level scanning)
- Does NOT call ComptoxR internals (avoided :::check_unhandled dependency)
- Codepoint extraction via `utf8ToInt()` and sprintf formatting ("U+%04X")
- Accumulates counts across all character columns
- Read-only guarantee - input dataframe never modified

**Test Coverage:**
- 41 new test cases total (8 QC + 33 updated/new)
- Chemistry unicode (Greek letters) verified end-to-end
- NA handling, empty dataframes, numeric-only dataframes
- Input immutability verified with before/after comparison
- Codepoint reporting accuracy (U+03B1, U+03B2) verified

## Integration Points

**Upstream Dependencies:**
- ComptoxR package (clean_unicode function)
- Existing cleaning_pipeline structure (run_cleaning_pipeline, mod_clean_data)

**Downstream Impact:**
- All unicode cleaning now uses chemistry-specific mappings
- Greek letters in chemical names render as dot-notation in cleaned data
- Post-curation QC can detect remaining unicode issues without modification

## Next Steps

Plan 15-02 will likely integrate perform_unicode_qc into the UI for post-curation reporting.

## Self-Check: PASSED

**Files Created:**
- tests/test_unicode_qc.R: FOUND
- tests/test_unicode_comptoxr.R: FOUND

**Files Modified:**
- R/cleaning_pipeline.R: FOUND (perform_unicode_qc and detect_non_ascii_chars present)
- R/modules/mod_clean_data.R: FOUND (ComptoxR::clean_unicode call present)
- tests/test_cleaning_pipeline.R: FOUND (updated expectations present)

**Commits:**
- 51dc548: FOUND
- a8b0b64: FOUND
- 272f66d: FOUND

**Function Removal:**
- clean_unicode_field: NOT FOUND in R/ or tests/ (0 references)

All claims verified.
