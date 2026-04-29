---
phase: 38-benchmark-harness
reviewed: 2026-04-26T01:01:24Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - R/cleaning_pipeline.R
  - R/unit_harmonizer.R
  - tests/testthat/test-dedup-infrastructure.R
  - tests/testthat/test-unit-harmonizer.R
findings:
  critical: 0
  warning: 1
  info: 3
  total: 4
status: issues_found
---

# Phase 38: Code Review Report (Re-review)

**Reviewed:** 2026-04-26T01:01:24Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the Phase 38 `use_dedup` toggle bypass logic across two source files and two test files. The review focused specifically on the 5 `dedup_step` gating sites in `run_cleaning_pipeline()` (lines 1959, 1983, 2007, 2100, 2179) and the `use_dedup_path` variable in `harmonize_units()` (lines 372-385).

**Structural assessment:** All 5 gating sites in `run_cleaning_pipeline()` correctly branch on `use_dedup`, passing the right arguments in both the `dedup_step()` and direct-call branches. Pre-check predicates remain independent of the toggle (correct design -- they gate whether a step runs at all, not how it runs). The `harmonize_units()` toggle correctly gates dedup key construction and falls through to the existing direct path when `use_dedup=FALSE`.

**Test coverage:** Phase 38 adds 4 new toggle tests: 2 in `test-dedup-infrastructure.R` (BENCH-01) and 2 in `test-unit-harmonizer.R` (BENCH-02). The tests compare `cleaned_data` and harmonized output columns between the two paths. One behavioral edge case is not covered (see WR-01).

One warning-level behavioral inconsistency was found in the `harmonize_units()` dedup path for unmatched units with differing pre-normalization forms. Three info-level items were found (dead code, misleading `isTRUE` usage, and a test coverage gap).

## Warnings

### WR-01: Dedup path returns wrong harmonized_unit for unmatched units with different pre-normalization forms

**File:** `R/unit_harmonizer.R:402`
**Issue:** In the dedup path, `u_harmonized_unit` is initialized from `orig_unit[first_idx]` (line 402). For **unmatched** standard units, this value is never overwritten -- matched units get overwritten at line 473, ppx at line 440, molarity at line 414. When the broadcast on line 484 maps `u_harmonized_unit` back to all rows sharing a dedup key, rows that had different `orig_unit` values but normalized to the same key will all receive the first occurrence's `orig_unit` as their `harmonized_unit`.

Example: if row 1 has `orig_unit = "  XYZ  "` and row 5 has `orig_unit = "XYZ"`, both normalize to key `"XYZ"`. In the dedup path, row 5's `harmonized_unit` would be `"  XYZ  "` (from the first occurrence), while in the non-dedup path (line 312 initializes `harmonized_unit <- orig_unit`), row 5 would correctly get `"XYZ"`. This is a behavioral difference between the two paths.

In practice, this only affects unmatched units with whitespace or micro-symbol differences that normalize to the same string. The existing tests do not trigger this path because all test units are either exact matches, ppx, or molarity (never unmatched with variant whitespace). But the test on line 925 explicitly states dedup is "performance-only, not behavioral," so this violates that contract.

**Fix:** After broadcasting, restore per-row `orig_unit` for unmatched rows:
```r
# After line 486 (unit_flag broadcast), add:
unmatched_rows <- unit_flag == "unmatched"
harmonized_unit[unmatched_rows] <- orig_unit[unmatched_rows]
```

## Info

### IN-01: Dead code -- unused variable `unique_values_dummy`

**File:** `R/unit_harmonizer.R:395`
**Issue:** `unique_values_dummy <- rep(1.0, n_unique)` is assigned but never referenced anywhere in the function. The comment says "dummy values; factors computed separately" confirming the variable was superseded by the factor-only approach but the allocation was left behind.
**Fix:** Remove line 395 entirely.

### IN-02: Misleading isTRUE() on vector in apply_synonyms (pre-existing)

**File:** `R/unit_harmonizer.R:66`
**Issue:** `isTRUE(synonyms$is_regex)` always returns `FALSE` when `synonyms` has more than 1 row, because `isTRUE()` requires `length(x) == 1L`. The left side of the `|` operator is effectively dead code. The behavior is still correct because the right side (`synonyms$is_regex %in% c(TRUE, "TRUE", "true", 1)`) covers all intended cases. This is a pre-existing issue, not introduced in Phase 38.
**Fix:** Remove the `isTRUE()` call:
```r
is_regex <- if ("is_regex" %in% names(synonyms)) {
  synonyms$is_regex %in% c(TRUE, "TRUE", "true", 1)
} else {
  rep(FALSE, nrow(synonyms))
}
```

### IN-03: Phase 38 toggle tests do not compare audit_trail between dedup and non-dedup paths

**File:** `tests/testthat/test-dedup-infrastructure.R:266-315`
**Issue:** Both `use_dedup=FALSE` tests (BENCH-01) compare `cleaned_data` columns but skip audit trail comparison entirely. The comment explains that `original_row_id` differs due to dedup remapping, but the audit trail (which tracks row-level change lineage) is not validated at all. If a future change breaks audit trail generation in one path but not the other, these tests would not catch it. The `harmonize_units` toggle tests (BENCH-02) similarly compare only output columns, not the full tibble.
**Fix:** Add audit trail row-count comparison as a basic consistency check:
```r
# After the cleaned_data comparison in each test:
expect_equal(nrow(result_dedup$audit_trail), nrow(result_no_dedup$audit_trail))
```

---

_Reviewed: 2026-04-26T01:01:24Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
