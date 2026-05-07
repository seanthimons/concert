---
phase: 48-wqx-resolution-ui
reviewed: 2026-05-07T21:07:45Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - R/curation.R
  - R/mod_review_results.R
  - tests/testthat/test-mod-review-helpers.R
findings:
  critical: 1
  warning: 2
  info: 1
  total: 4
status: issues_found
---

# Phase 48: Code Review Report

**Reviewed:** 2026-05-07T21:07:45Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

This review covers the final state of the Phase 48 WQX Resolution UI changes: (1) `wqx_confidence` pipeline propagation through `map_results_to_rows()`, (2) a WQX Review modal with accept/override/reject actions, (3) WQX override rendering in `derive_resolution_html`, and (4) integration tests for `wqx_confidence` and gap closure regressions.

All findings from the prior review (CR-01: `searchValue` crash, WR-01: `needs_review` init guard, WR-02: unsuffixed `wqx_confidence` lookup, IN-02: em-dash inconsistency) have been fixed. The WQX modal flow is well structured -- lifecycle is clean, group propagation is consistent, `htmltools::htmlEscape` is correctly applied to all user-derived values, and the new grep-based column lookups correctly handle both single-tag and multi-tag naming modes.

However, a pre-existing vectorization bug in `recalc_consensus_summary` silently miscounts pinned disagree rows. This bug is in code that was not changed by Phase 48, but it directly impacts the disagree count displayed in the value boxes and the "Apply Priority" notification -- both of which are exercised by the new WQX reject flow (which can change rows to `unresolvable`, affecting the disagree count). Two additional warnings relate to missing defensive guards.

## Critical Issues

### CR-01: `isTRUE()` on vector silently disables pinned-row filter in disagree count

**File:** `R/mod_review_results.R:8`
**Issue:** `isTRUE(df$.pinned)` is a scalar function -- when called on a vector (the `.pinned` column of a data frame), it always returns `FALSE` per R documentation: "isTRUE returns TRUE if its argument value is identical to TRUE." For a vector of length > 1, `identical(vec, TRUE)` is always FALSE. Therefore `!isTRUE(df$.pinned)` is always `TRUE`, and the `& !isTRUE(df$.pinned)` filter in the `n_disagree` calculation has no effect. Pinned disagree rows are always counted toward `n_disagree`, contradicting the apparent intent to exclude them.

The same bug appears at two additional call sites within the `apply_priority` observer:
- Line 1476: `!isTRUE(data_store$resolution_state$.pinned)` in the before-count
- Line 1493: `!isTRUE(updated_df$.pinned)` in the after-count

Consequences:
1. The "Disagree" value box always overstates the actionable disagree count by including pinned (already-resolved) rows.
2. The "N rows resolved" notification after Apply Priority reports incorrect numbers since both before and after counts include pinned rows, masking the actual effect.
3. After a user pins a disagree row via the Compare modal or WQX reject flow, the disagree count does not decrease, which is confusing UX.

**Fix:**

Replace `!isTRUE(df$.pinned)` with a vectorized equivalent. For line 8:
```r
# Before (broken):
n_disagree = sum(df$consensus_status == "disagree" & !isTRUE(df$.pinned), na.rm = TRUE),

# After (fixed):
n_disagree = sum(
  df$consensus_status == "disagree" & !(df$.pinned %in% TRUE),
  na.rm = TRUE
),
```

The `%in% TRUE` idiom correctly handles vectors and treats `NA` as not-TRUE. Apply the same fix at lines 1476 and 1493:
```r
# Line 1476:
!isTRUE(data_store$resolution_state$.pinned)
# becomes:
!(data_store$resolution_state$.pinned %in% TRUE)

# Line 1493:
!isTRUE(updated_df$.pinned)
# becomes:
!(updated_df$.pinned %in% TRUE)
```

## Warnings

### WR-01: Missing `req()` guard on `data_store$column_tags` in `wqx_review_click` handler

**File:** `R/mod_review_results.R:1746-1758`
**Issue:** The WQX review modal handler reads `names(data_store$column_tags)[data_store$column_tags == "Name"]` at line 1758 without a `req()` or null check on `data_store$column_tags`. While `column_tags` is expected to be set by the time curation completes, the compare modal handler at line 1187 defensively wraps similar access in `if (!is.null(data_store$column_tags) && length(data_store$column_tags) > 0)`. The WQX handler lacks this guard, which would cause an error on `names(NULL)` if `column_tags` were not yet set.

**Fix:**

Add `data_store$column_tags` to the existing `req()` call:
```r
observeEvent(input$wqx_review_click, {
  req(data_store$resolution_state, data_store$column_tags)
  # ... rest of handler
})
```

### WR-02: WQX reject handler silently returns without closing modal on NULL row index

**File:** `R/mod_review_results.R:1938-1940`
**Issue:** The `wqx_reject_click` handler returns early on line 1940 if `data_store$wqx_modal_row_idx` is NULL. However, it does not call `removeModal()` before returning. The modal was opened with `easyClose = TRUE` (line 1877), so the user can dismiss it by clicking outside, but the early return path leaves the modal open with no explicit dismissal. This could occur in a double-click race condition: the first click processes the reject and sets `wqx_modal_row_idx` to NULL (line 1963), then the second click fires `wqx_reject_click` again and hits the NULL guard.

The same pattern exists in the `wqx_modal_confirm` handler (line 1905), but that path shows a notification ("Please select a candidate first") which at least communicates state to the user. The reject path silently does nothing.

**Fix:**

Add `removeModal()` before the early return:
```r
observeEvent(input$wqx_reject_click, {
  row_idx <- data_store$wqx_modal_row_idx
  if (is.null(row_idx)) {
    removeModal()
    return()
  }
  # ... rest of handler
})
```

## Info

### IN-01: Test Group 7 tests grep patterns inline rather than through actual functions

**File:** `tests/testthat/test-mod-review-helpers.R:298-382`
**Issue:** Tests in Group 7 (gap closure regression tests) duplicate the grep pattern logic and column-lookup loop from `mod_review_results.R` inline rather than calling the actual functions. This means the tests verify that `grep("^wqx_confidence", ...)` works in isolation, but if the pattern in the source code were accidentally changed, the tests would still pass. This is a known trade-off for testing server-side observer logic (which requires a full Shiny test harness), and the inline approach is reasonable for gap closure. Pairing these with `shinytest2`-based integration tests would provide stronger end-to-end coverage.

**Fix:** Consider adding `shinytest2` tests that exercise the WQX review modal flow end-to-end to supplement the unit-level pattern tests. Low priority.

---

_Reviewed: 2026-05-07T21:07:45Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
