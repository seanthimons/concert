---
phase: 36-wire-toxval-shiny
fixed_at: 2026-04-21T21:20:54Z
review_path: .planning/phases/36-wire-toxval-shiny/36-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 36: Code Review Fix Report

**Fixed at:** 2026-04-21T21:20:54Z
**Source review:** .planning/phases/36-wire-toxval-shiny/36-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4
- Fixed: 4
- Skipped: 0

## Fixed Issues

### CR-01: Row count mismatch between curated_data and harmonized_data in map_to_toxval_schema call

**Files modified:** `R/mod_harmonize.R`
**Commit:** 59a16b5
**Applied fix:** Added row expansion of `data_store$resolution_state` via `harmonize_tibble$orig_row_id` before passing to `map_to_toxval_schema()`. When `parse_numeric_results()` expands range values (e.g., "5-10" becomes 3 rows: low/mid/high), the curated data now correctly expands to match the harmonized row count, preventing tibble recycling errors.

### WR-01: Incremental harmonization path skips ToxVal schema mapping

**Files modified:** `R/mod_harmonize.R`
**Commit:** b0c2a0d
**Applied fix:** Added `data_store$toxval_output <- NULL` after the incremental merge (after `harmonize_audit` assignment, before the success notification). This invalidates the stale ToxVal output so it does not silently drift out of sync with updated harmonization results. The next full-mode run will regenerate it with correct data.

### WR-02: Incomplete XSS escaping in onclick handler for unmatched unit names

**Files modified:** `R/mod_harmonize.R`, `DESCRIPTION`
**Commit:** e32f491
**Applied fix:** Replaced the manual `gsub("'", "\\\\'", ...)` single-quote escaping with `jsonlite::toJSON(u$orig_unit, auto_unbox = TRUE)` which produces a properly double-quoted and escaped JSON/JS string literal. This handles all JS-significant characters (backslashes, quotes, newlines, carriage returns, script tags) correctly. Also added `jsonlite` to DESCRIPTION Imports since it was not previously declared as a package dependency.

### WR-03: Stale toxval_output not invalidated by unit_map_working cascade observer

**Files modified:** `R/mod_harmonize.R`
**Commit:** 33d0244
**Applied fix:** Added `data_store$toxval_output <- NULL` in both cascade observers (unit_map_working and corrections_working) alongside the existing `harmonize_results_stale <- TRUE` flag. This ensures that when the user edits unit mappings or corrections, the ToxVal output is immediately invalidated rather than silently retained with stale values. Prevents export of outdated data via the review tab.

## Skipped Issues

None -- all findings were fixed.

---

_Fixed: 2026-04-21T21:20:54Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
