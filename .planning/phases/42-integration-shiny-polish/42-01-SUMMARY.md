---
phase: 42-integration-shiny-polish
plan: "01"
subsystem: backend-services
tags:
  - pre-check
  - harmonization
  - media-map
  - persistence
dependency_graph:
  requires:
    - R/cleaning_pipeline.R (existing pre-check pattern)
    - R/media_harmonizer.R (harmonize_media existing function)
    - R/cleaning_reference.R (load_or_fetch_reference pattern)
    - inst/extdata/reference_cache/amos_media.rds (AMOS media table)
  provides:
    - precheck_harmonize_units
    - precheck_harmonize_duration
    - precheck_harmonize_dates
    - precheck_harmonize_media
    - load_media_map
    - media_map key in load_all_reference_lists
    - harmonize_media(media_map=) optional parameter
  affects:
    - R/mod_harmonize.R (Plan 02: media editor wired via data_store$reference_lists$media_map)
    - R/mod_clean_data.R (Plan 03: pre-flight modal calls the 4 new pre-checks)
tech_stack:
  added: []
  patterns:
    - Pre-check predicate pattern (list(should_run, est_changes)) extended to harmonization steps
    - User-override-with-AMOS-fallback merge for media map
    - Optional parameter with NULL-default backward compatibility
key_files:
  created:
    - tests/testthat/test-harmonize-prechecks.R
    - tests/testthat/test-media-persistence.R
  modified:
    - R/cleaning_pipeline.R
    - R/cleaning_reference.R
    - R/media_harmonizer.R
decisions:
  - Used est_changes = total values (not unmapped count) for units pre-check — all values are processed by harmonize_units regardless of whether they match
  - Added NA parent column backfill in harmonize_media() display-schema translation path — walk_parent() accesses media_tbl$parent unconditionally; backfill prevents length-zero argument error (Rule 1 bug fix)
  - load_media_map returns 7-column merged schema (term, canonical, canonical_term, envo_id, media_category, source, active) rather than 4-column display schema — provides both display and internal lookup columns in one pass
metrics:
  duration_minutes: 50
  completed_date: "2026-04-28"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 5
  tests_added: 99
  tests_passing: 99
---

# Phase 42 Plan 01: Backend Services for Pre-flight Modal and Media Editor Summary

Backend infrastructure for four harmonization pre-check functions, user/AMOS media map persistence, and harmonize_media() API extension. Provides all backend services needed by Plan 02 (media editor) and Plan 03 (pre-flight modal) before any UI work begins.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Four harmonization pre-check functions | 5171246 | R/cleaning_pipeline.R, tests/testthat/test-harmonize-prechecks.R |
| 2 | load_media_map + harmonize_media API extension | 69524a8 | R/cleaning_reference.R, R/media_harmonizer.R, tests/testthat/test-media-persistence.R |

## What Was Built

### Task 1: Four Harmonization Pre-check Functions

Added to `R/cleaning_pipeline.R` immediately after the existing 7 cleaning pre-checks (after line 458). Each function follows the identical `list(should_run = logical(1), est_changes = integer(1))` contract:

- `precheck_harmonize_units(df, unit_cols, unit_map)` — counts all non-NA unit values across Unit-tagged columns; should_run = any values present
- `precheck_harmonize_duration(df, dur_cols, dur_unit_cols, unit_map)` — counts non-NA values across Duration and DurationUnit tagged columns
- `precheck_harmonize_dates(df, date_cols)` — counts non-NA values across StudyDate-tagged columns
- `precheck_harmonize_media(df, media_cols, media_map = NULL)` — counts non-NA values across Media-tagged columns

All four use vectorized `vapply` with `sum(!is.na(...) & nzchar(...))` counting, consistent with the existing pre-check style. All exported.

62 unit tests in `tests/testthat/test-harmonize-prechecks.R` covering: should_run TRUE/FALSE, est_changes counting, empty column guards, all-NA guards, multi-column summing, return type contract.

### Task 2: load_media_map() and harmonize_media() Extension

**`R/cleaning_reference.R`** — Added `load_media_map(cache_dir)` function before `load_all_reference_lists`:
- Reads `user_media_map.rds` from cache_dir if it exists
- Falls back to `get_media_table()` for AMOS data
- Merges so user rows take precedence for the same term (AMOS rows for all non-user terms)
- Returns 7-column tibble: term, canonical, canonical_term, envo_id, media_category, source, active
- Backfills canonical_term/envo_id/media_category from 4-column display schema when user RDS was saved with the shorter schema
- `load_all_reference_lists()` now includes `media_map = load_media_map(cache_dir)` as a tenth key

**`R/media_harmonizer.R`** — Extended `harmonize_media()` signature:
- New `media_map = NULL` parameter (backward-compatible default)
- When media_map provided and non-empty: validates `term` column present, accepts either `canonical_term` (internal schema) or `canonical` (display schema, translated internally)
- Display-schema translation adds `parent = NA_character_` column so `walk_parent()` does not error on missing column
- Falls back to `get_media_table()` when media_map is NULL, empty, or has invalid schema

37 unit tests in `tests/testthat/test-media-persistence.R` covering: AMOS-only path, NULL-AMOS fallback, user RDS merge, user precedence over AMOS, round-trip persistence, canonical backfill, backward compatibility, custom map with canonical_term schema, custom map with canonical schema, invalid schema fallback.

All 62 existing `test-media-harmonizer.R` tests still pass.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] walk_parent() errors on display-schema media_map missing parent column**
- **Found during:** Task 2 test execution
- **Issue:** `harmonize_media()` translates display-schema `canonical` to `canonical_term` but `walk_parent()` unconditionally accesses `media_tbl$parent`. When the display-schema tibble lacks a `parent` column, `$parent` returns a zero-length vector, causing `if (is.na(parent_term))` to error with "argument is of length zero".
- **Fix:** Added `if (!"parent" %in% names(mm)) mm$parent <- NA_character_` in the display-schema translation branch of `harmonize_media()`
- **Files modified:** R/media_harmonizer.R
- **Commit:** 69524a8

**2. [Rule 1 - Bug] expect_type() label parameter fix in test**
- **Found during:** Task 1 test run
- **Issue:** `expect_type(r$should_run, "logical", label = ...)` — `expect_type()` does not accept a `label` argument (unlike `expect_equal()`). All 20 tests in the contract compliance block failed.
- **Fix:** Removed `label =` arguments from `expect_type()` and `expect_length()` calls.
- **Files modified:** tests/testthat/test-harmonize-prechecks.R
- **Commit:** 5171246 (fixed before commit, so commit already contains corrected version)

## Known Stubs

None. All functions are fully implemented with real logic. No placeholders, TODO comments, or hardcoded empty returns in the normal code paths.

## Threat Flags

No new network endpoints, auth paths, file access patterns, or schema changes beyond what the plan's threat model already covers (T-42-01, T-42-02 mitigations applied):
- T-42-01: readRDS only from known `cache_dir` path with `file.exists()` guard — implemented
- T-42-02: media_map column validation with fallback to `get_media_table()` — implemented

## Self-Check

**Created files exist:**
- `R/cleaning_pipeline.R` — precheck_harmonize_units present: FOUND
- `R/cleaning_reference.R` — load_media_map present: FOUND
- `R/media_harmonizer.R` — media_map parameter present: FOUND
- `tests/testthat/test-harmonize-prechecks.R`: FOUND
- `tests/testthat/test-media-persistence.R`: FOUND

**Commits exist:**
- 5171246: FOUND (feat(42-01): add four harmonization pre-check functions)
- 69524a8: FOUND (feat(42-01): add load_media_map and extend harmonize_media API)

## Self-Check: PASSED
