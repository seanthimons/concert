---
phase: 37-performance-architecture
plan: "04"
subsystem: unit-harmonizer
tags: [performance, dedup, harmonization, PERF-03]
dependency_graph:
  requires: [37-01]
  provides: [unit-key-dedup-in-harmonize-units]
  affects: [R/unit_harmonizer.R]
tech_stack:
  added: []
  patterns: [unit-key-dedup, broadcast-multiply, bypass-threshold]
key_files:
  modified:
    - R/unit_harmonizer.R
    - tests/testthat/test-unit-harmonizer.R
decisions:
  - "Used n_unique < n/2 bypass threshold matching D-03 design decision"
  - "MW pre-fetch kept before dedup key construction since mw_vec is needed in molarity keys (D-07)"
  - "Used anyNA() after jarl lint fix instead of any(is.na()) per T-37-12 defensive check"
  - "Test fixtures use make_test_unit_map() (existing pattern) not load_unit_map() which requires cache_dir"
metrics:
  duration: "~15 minutes"
  completed: "2026-04-24T19:23:18Z"
  tasks_completed: 2
  files_modified: 2
---

# Phase 37 Plan 04: Unit-Key Dedup for harmonize_units() Summary

Unit-key dedup optimization applied to `harmonize_units()` so conversion factors are computed once per distinct unit combination (unit string for standard, unit+media for ppx, unit+mw for molarity), then broadcast-multiplied to all matching rows (PERF-03).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add unit-key dedup to harmonize_units() | b8cf417 | R/unit_harmonizer.R |
| 2 | Add dedup-specific tests | 283a0d1 | tests/testthat/test-unit-harmonizer.R |

## What Was Built

### Task 1: Unit-key dedup in harmonize_units() (b8cf417)

Inserted a dedup layer in `harmonize_units()` after the classification masks and MW pre-fetch, before the three conversion paths. The optimization:

1. **Key construction** — builds `dedup_keys` vector (length n) per row classification:
   - Standard: `normalized[i]` (unit string alone)
   - ppx: `paste0(normalized[i], "||", media_vec[i])`
   - Molarity: `paste0(normalized[i], "||", mw_vec[i])`

2. **Bypass threshold** — `if (n_unique < n / 2)` fires dedup path; otherwise falls through to the existing logic unchanged (D-03)

3. **Unique-subset computation** — the three conversion blocks (molarity, ppx, standard) run on `first_idx` unique subset, writing into `u_harmonized_unit`, `u_conversion_factor`, `u_unit_flag` vectors

4. **Broadcast** — `key_to_unique <- match(dedup_keys, unique_keys)` maps each row back to its unique result; `harmonized_value <- values * conversion_factor` does the actual multiply vectorized over all n rows

5. **Defensive check** — `stopifnot(!anyNA(key_to_unique))` guards against T-37-12 (match returning NA); by construction `unique_keys` is derived from `dedup_keys` so this cannot fail

6. **Output tibble unchanged** — `orig_row_id`, `orig_unit`, `harmonized_value`, `harmonized_unit`, `conversion_factor`, `unit_flag` schema preserved exactly

### Task 2: Dedup-specific tests (283a0d1)

Four new `test_that` blocks added to `tests/testthat/test-unit-harmonizer.R`:

- **dedup: high duplication** — 100 rows with 5 unique units fires dedup path; verifies output schema and consistent conversion factors per unit
- **dedup: ppx with different media** — same ppb unit with aqueous vs. solid media produces distinct `harmonized_unit` values (mg/L vs mg/kg), validating key includes media
- **dedup: all unique units bypasses dedup** — 3 rows, 3 unique units triggers bypass condition; correct conversions still applied
- **dedup: preserves orig_row_id ordering** — 50 rows alternating two units; verifies `orig_row_id` is 1:50 and `orig_unit` matches input

## Test Results

- All 92 existing `test_that` blocks (169 assertions) pass after optimization
- 4 new dedup test blocks added (96 total, 184 assertions all pass)
- Full `devtools::test()` run: FAIL 3 | PASS 1553+ — the 3 failures are pre-existing in `test-reference-provenance.R`, unrelated to this plan

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Adapted load_unit_map() call in test templates**
- **Found during:** Task 2
- **Issue:** Plan's test template called `load_unit_map()` with no arguments, but the function requires a `cache_dir` parameter and reads from a file path
- **Fix:** Used `make_test_unit_map()` (existing test fixture helper) consistent with all 92 prior tests
- **Files modified:** tests/testthat/test-unit-harmonizer.R
- **Commit:** 283a0d1

**2. [Rule 1 - Bug] Stash pop failure reverted test file**
- **Found during:** Task 2
- **Issue:** `git stash` was used to check pre-existing failures; stash pop failed due to xlsx binary conflict, reverting the test file to pre-edit state
- **Fix:** Re-applied the test additions after confirming the issue
- **Files modified:** tests/testthat/test-unit-harmonizer.R
- **Commit:** 283a0d1

**3. [Rule 2 - Lint] anyNA() substitution for any(is.na())**
- **Found during:** Task 1 jarl check
- **Issue:** `any(is.na(key_to_unique))` flagged by jarl (any_is_na rule)
- **Fix:** `jarl check --fix --allow-dirty` replaced with `anyNA(key_to_unique)`
- **Files modified:** R/unit_harmonizer.R
- **Commit:** b8cf417

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- `R/unit_harmonizer.R` exists and contains `dedup_keys <- character(n)`: confirmed
- `tests/testthat/test-unit-harmonizer.R` contains 4 "dedup" test blocks: confirmed (6 "dedup" occurrences)
- Commit b8cf417 exists: confirmed
- Commit 283a0d1 exists: confirmed
- 184 assertions pass: confirmed
