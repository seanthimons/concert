---
phase: 39-duration-conversion
plan: "01"
subsystem: unit-harmonization
tags: [duration, unit-conversion, rds-data, tdd, bug-fix]
dependency_graph:
  requires: []
  provides:
    - inst/extdata/unit_conversion.rds (23 duration rows, hr base, exact fractions)
    - inst/extdata/unit_synonyms.rds (34 duration synonyms incl. ambiguous m->min)
    - R/unit_harmonizer.R (category param, ambiguous_unit flag, molarity/m fix)
    - tests/testthat/test-unit-harmonizer.R (sections 16-19, 13 new tests)
  affects:
    - Any caller of harmonize_units() that passes "M" (Molar) — behavior unchanged
    - Pipeline wiring in Plan 02 which will call harmonize_units(category="duration")
tech_stack:
  added: []
  patterns:
    - pre-synonym molarity classification to separate M (Molar) from m (minutes)
    - normalized_pre_synonym vector for molarity scale factor lookup
    - category filter as first operation inside harmonize_units() body
key_files:
  created: []
  modified:
    - inst/extdata/unit_conversion.rds
    - inst/extdata/unit_synonyms.rds
    - R/unit_harmonizer.R
    - tests/testthat/test-unit-harmonizer.R
decisions:
  - Compute molarity_mask pre-synonym to correctly classify M (Molar) vs m (ambiguous)
  - Store normalized_pre_synonym for get_molarity_scale() to avoid post-synonym string corruption
  - is_molarity_unit() made case-sensitive for standalone m/M only; all other units remain case-insensitive
  - ambiguous_unit flag constrained to !molarity_mask & !ppx_mask rows to avoid overwriting molarity flags
metrics:
  duration_minutes: 9
  completed_date: "2026-04-26"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 4
---

# Phase 39 Plan 01: Duration Conversion Foundation Summary

**One-liner:** Duration conversion with hours as base unit — 23 RDS rows, 34 synonyms, category filter and ambiguous_unit flag wired into harmonize_units(), with case-sensitive M/m molarity fix.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add duration rows to RDS files and extend harmonize_units() | c7c351c | unit_conversion.rds, unit_synonyms.rds, unit_harmonizer.R |
| 2 | Add duration test sections 16-19 (TDD) | c51cebf | test-unit-harmonizer.R, unit_harmonizer.R (bug fix) |

## What Was Built

### RDS Data Updates

**unit_conversion.rds:** 23 duration rows appended (151 → 174 total). All rows have `category="duration"`, `to_unit="hr"`, `confidence="HIGH"`, `source="ECOTOX"`. Exact fractions used: `min` → `1/60`, `s` → `1/3600` (not rounded decimals).

**unit_synonyms.rds:** 34 duration synonym rows appended (80 → 114 total). All `is_regex=FALSE` for O(1) hash lookup. Includes the ambiguous `m` → `min` entry with documentation note.

### harmonize_units() Changes

1. **`category` parameter (D-12):** New optional parameter, default `NULL`. When non-NULL, filters `unit_map` to matching category rows before any processing. Inserted as the very first operation in the function body before Step 0.

2. **`ambiguous_unit` flag (D-01):** Post-dedup flag applied to rows where `orig_unit == "m"` (case-insensitive, trimmed). Constrained to `!molarity_mask & !ppx_mask` rows to avoid overwriting molarity flags.

3. **Molarity/m conflict fix (Rule 1 - Bug):** The synonym table maps `"m"` → `"min"` case-insensitively, which also captured `"M"` (Molar). Fixed by:
   - Making `is_molarity_unit()` case-sensitive for standalone `"m"/"M"` — only uppercase `"M"` is Molar
   - Computing `molarity_mask` before synonym application (`normalized_pre_synonym`)
   - Using `normalized_pre_synonym` for `get_molarity_scale()` in both dedup and non-dedup paths
   - Adding NA guard in `is_molarity_unit()` for the case-sensitive `== "M"` check

### Test Coverage (Sections 16-19)

- **Section 16 (3 tests):** Category filter: NULL backward compat, "duration" isolates hr-base rows, unrecognized "dph" passes through as "unmatched"
- **Section 17 (6 tests):** Conversion arithmetic: hr identity, day→hr, min→hr, wk→hr, yr→hr, decimal 1.5 day→36 hr
- **Section 18 (2 tests):** Synonym normalization: "hrs"→hr, "Days"→day
- **Section 19 (2 tests):** Ambiguity flag: "m" maps to min and gets "ambiguous_unit" flag, "min" does NOT get flag

**Total: 214 tests pass (13 new), 0 failures**

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Molarity "M" conflicted with ambiguous "m" synonym**
- **Found during:** Task 2, test run
- **Issue:** `apply_synonyms()` uses case-insensitive lookup (`tolower(input_pattern)`), so the new `"m"` → `"min"` synonym also captured `"M"` (Molar). Additionally, `is_molarity_unit()` used `tolower()`, making it match both `"M"` and `"m"` as molarity. This caused 5 existing molarity tests to fail.
- **Fix:**
  1. Made `is_molarity_unit()` case-sensitive for standalone `"m"/"M"` — only `"M"` (uppercase) is Molar
  2. Moved `molarity_mask` computation to before synonym application (stored as `normalized_pre_synonym`)
  3. Used `normalized_pre_synonym` for `get_molarity_scale()` in both dedup and non-dedup paths
  4. Added `!is.na(unit)` guard in `is_molarity_unit()` for the `== "M"` check (NA propagation edge case)
  5. Constrained `ambiguous_unit` flag to `!molarity_mask & !ppx_mask` rows
- **Files modified:** R/unit_harmonizer.R
- **Commits:** c51cebf

## Self-Check

### Created files exist:
- `inst/extdata/unit_conversion.rds`: FOUND (174 rows, 23 duration)
- `inst/extdata/unit_synonyms.rds`: FOUND (114 rows, m->min present)

### Commits exist:
- c7c351c: FOUND
- c51cebf: FOUND

## Self-Check: PASSED
