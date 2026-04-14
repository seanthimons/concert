---
phase: 30-numeric-result-parser
plan: "02"
subsystem: numeric-parser
tags: [tdd, parsing, ranges, pre-guard, fortran-exponent, toxval]
dependency_graph:
  requires:
    - phase: 30-01
      provides: parse_numeric_results, normalize_numeric_string, extract_qualifier, detect_narrative
  provides:
    - split_ranges() internal helper with numeric pre-guard
    - range splitting in parse_numeric_results() (3 rows per range: low/mid/high)
    - PARS-03 requirement fulfilled
  affects: [R/numeric_parser.R, tests/testthat/test-numeric-parser.R]
tech_stack:
  added: []
  patterns: [TDD-red-green, pre-normalization-range-detection, fortran-guard-tighter-regex]
key_files:
  created: []
  modified:
    - R/numeric_parser.R
    - tests/testthat/test-numeric-parser.R
key_decisions:
  - "Range detection runs on pre-Fortran-normalized form: normalize_numeric_string Fortran step converts '5-10' -> '5e-10', so ranges must be detected before that step"
  - "Tighter Fortran guard in split_ranges: pattern ^[+-]?[0-9]+\\.[0-9]+[+-][0-9]+$ (decimal mantissa required) correctly excludes '4.56-02' but not '5-10'"
  - "Two-phase normalization in parse_numeric_results: partial norm (unicode/x10^/commas/whitespace) for range detection, full norm for single-value parsing"
patterns_established:
  - "Pre-normalization detection pattern: when a normalization step would destroy distinguishing features needed for detection, run detection before that step"
requirements_completed: [PARS-03]
metrics:
  duration_seconds: 381
  completed_date: "2026-04-14"
  tasks_completed: 1
  files_created: 0
  files_modified: 2
---

# Phase 30 Plan 02: Range Splitting Summary

**Range hyphen splitting with numeric pre-guard: "5-10" -> 3 rows (low/mid/high), with Fortran exponent detection preventing false range matches on "4.56-02".**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-14T22:09:32Z
- **Completed:** 2026-04-14T22:15:53Z
- **Tasks:** 1 (TDD: RED + GREEN)
- **Files modified:** 2

## Accomplishments

- `split_ranges()` internal helper correctly identifies range hyphens vs negative signs, scientific notation, Fortran exponents, and qualified values
- `parse_numeric_results()` expands range values to 3 rows (low/mid/high) with semantic qualifiers (>=, ~, <=) per D-02/D-03
- Numeric pre-guard protects: negative numbers (-5), scientific notation (1e-3, 1.5E-4), Fortran exponents (4.56-02), qualified values (<5, >100)
- Negative-bound ranges work correctly: "-10--5" and "-10-5" both produce 3 rows
- All 55 Plan 01 tests still pass (zero regression)
- Full test suite: 99 tests passing

## Task Commits

Each TDD phase committed atomically:

1. **RED: Failing range tests** - `93d7f76` (test)
2. **GREEN: split_ranges() implementation** - `2a78c4e` (feat)

## Files Created/Modified

- `R/numeric_parser.R` — Added `split_ranges()` helper (lines 110-168); modified `parse_numeric_results()` to use two-phase normalization and range expansion (lines 170-295)
- `tests/testthat/test-numeric-parser.R` — Appended 44 range tests covering detection, pre-guards, negative bounds, mixed vectors, orig_row_id linkage

## Decisions Made

**Range detection before Fortran normalization:** The Fortran exponent normalizer in `normalize_numeric_string` matches `(\\d)([+-])(\\d+)$` which converts `"5-10"` to `"5e-10"`. Range detection must happen on a pre-Fortran form. Solution: two-phase normalization — partial (unicode, x10^, commas, whitespace) for range detection, full (including Fortran) for single-value parsing.

**Tighter Fortran guard regex in split_ranges:** Used `^[+-]?[0-9]+\.[0-9]+[+-][0-9]+$` (requires decimal point in mantissa) to distinguish Fortran exponents from ranges. Key insight: Fortran exponents like `4.56-02` have a decimal mantissa; simple integers like `5` in `5-10` do not. The exponent part is also pure digits (no decimal), while a range's second number can have a decimal (e.g., `0.5-1.0`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fortran normalization converting ranges to scientific notation**
- **Found during:** Task 1 GREEN phase (first test run showed "5-10" returning 1 row instead of 3)
- **Issue:** `normalize_numeric_string` Fortran step converts "5-10" to "5e-10" before `split_ranges` can detect the range hyphen. Root cause: the Fortran guard `(\\d)([+-])(\\d+)$` matches range-like patterns too.
- **Fix:** Moved range detection to run on a pre-Fortran-normalized form (partial normalization: unicode + x10^ + commas + whitespace only). Full normalization (including Fortran) still applied to non-range single values.
- **Files modified:** R/numeric_parser.R
- **Verification:** All 99 tests pass including "5-10" → 3 rows and "4.56-02" → 0.0456 (single row)
- **Committed in:** 2a78c4e

**2. [Rule 1 - Bug] "4.56-02" Fortran exponent falsely detected as range**
- **Found during:** Task 1 GREEN phase, debugging after fix #1
- **Issue:** After moving range detection to pre-Fortran form, "4.56-02" was still being matched as a range (lo=4.56, hi=02) by the range regex, producing 3 rows instead of 1.
- **Fix:** Added tighter Fortran pre-guard in `split_ranges` using regex `^[+-]?[0-9]+\.[0-9]+[+-][0-9]+$` that requires a decimal point in the mantissa — correctly identifies "4.56-02" as Fortran while not blocking "5-10" or "0.5-1.0".
- **Files modified:** R/numeric_parser.R
- **Verification:** "4.56-02" → 1 row, numeric_value=0.0456; "5-10" → 3 rows; "0.5-1.0" → 3 rows
- **Committed in:** 2a78c4e (fixed inline before commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 bugs — normalization order interaction)
**Impact on plan:** Both bugs were caused by the interaction between Fortran exponent normalization and range detection. The fixes maintain backward compatibility with all Plan 01 behavior.

## Issues Encountered

The Fortran exponent normalizer is intentionally broad (matches digit-sign-digits at end) because it was designed for single-value inputs. Range detection requires operating on a form where Fortran normalization has NOT yet run. The two-phase normalization approach cleanly separates concerns without modifying `normalize_numeric_string` itself (preserving Plan 01 behavior).

## Known Stubs

None — all range output columns fully computed. The range_bin values "low", "mid", "high" are correct final values (not stubs).

## Next Phase Readiness

- `parse_numeric_results()` now handles single values (Plan 01) and ranges (Plan 02)
- Ready for Phase 30 Plan 03 if applicable (unit extraction, unit harmonization, etc.)
- Full regression suite (99 tests) protects against future changes

## Self-Check: PASSED

- `R/numeric_parser.R` exists and contains `split_ranges <- function(`
- `tests/testthat/test-numeric-parser.R` contains "range" in test descriptions
- Commits 93d7f76 and 2a78c4e both present in git log
- 99/99 tests pass

---
*Phase: 30-numeric-result-parser*
*Completed: 2026-04-14*
