---
phase: 46-wqx-ui-display-fixes
reviewed: 2026-05-06T12:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - R/mod_review_results.R
  - tests/testthat/test-mod-review-helpers.R
findings:
  critical: 1
  warning: 2
  info: 1
  total: 4
status: issues_found
---

# Phase 46: Code Review Report

**Reviewed:** 2026-05-06T12:00:00Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed the WQX UI display fixes in `R/mod_review_results.R` and the new test file `tests/testthat/test-mod-review-helpers.R`. The primary changes add `unname()` calls to named-vector lookups (lines 41, 785, 786, 827, 925), which correctly prevent named vectors from propagating names into HTML/CSS output. These fixes are sound.

However, the review uncovered a pre-existing bug (`isTRUE()` misuse on vectors) that affects disagree-row counting accuracy, a logic error in the Excel download error handler that allows export to proceed after validation failure, and a gap in test coverage for the pinned-row exclusion logic.

## Critical Issues

### CR-01: `isTRUE()` applied to vector always returns scalar FALSE -- pinned rows never excluded from disagree count

**File:** `R/mod_review_results.R:8`
**Issue:** `isTRUE(df$.pinned)` is called on a vector column, but `isTRUE()` is not vectorized. When the vector has more than one element, `isTRUE()` returns `FALSE` regardless of content. This means `!isTRUE(df$.pinned)` always evaluates to the scalar `TRUE`, and the `&` with the status check short-circuits to include ALL disagree rows, even pinned ones. The same bug appears at lines 1438 and 1455 in the priority-application counting logic. The disagree count displayed in the UI value box and the resolved-count notification after applying priority are both incorrect when any rows are pinned.

Confirmed with R 4.5.1: `isTRUE(c(TRUE, FALSE, TRUE))` returns `FALSE`.

**Fix:**
```r
# Line 8: replace !isTRUE(df$.pinned) with element-wise check
n_disagree = sum(
  df$consensus_status == "disagree" & !isTRUE(df$.pinned),  # BUG
  na.rm = TRUE
),

# Should be:
n_disagree = sum(
  df$consensus_status == "disagree" & !(df$.pinned %in% TRUE),
  na.rm = TRUE
),

# Same fix at lines 1437-1438:
data_store$resolution_state$consensus_status == "disagree" &
  !(data_store$resolution_state$.pinned %in% TRUE),

# And lines 1454-1455:
updated_df$consensus_status == "disagree" &
  !(updated_df$.pinned %in% TRUE),
```

Using `%in% TRUE` is NA-safe (returns `FALSE` for `NA`) and vectorized, matching the original intent.

## Warnings

### WR-01: Download handler continues after validation failure due to `return()` scoping

**File:** `R/mod_review_results.R:1493-1505`
**Issue:** Inside the `downloadHandler`'s `content` function, `validate_excel_size` is wrapped in `tryCatch`. When validation fails, the error handler calls `return()`, but this returns from the anonymous error-handler function, not from the outer `content` function. Execution then falls through to `build_export_sheets` and `write_xlsx`, meaning the export proceeds even when validation should have blocked it.

**Fix:**
```r
content = function(file) {
  req(data_store$resolution_state, data_store$consensus_summary)

  # Validate curated data size before export
  size_ok <- tryCatch(
    {
      validate_excel_size(data_store$resolution_state, "Curated Data")
      TRUE
    },
    error = function(e) {
      showNotification(
        paste("Export blocked:", conditionMessage(e)),
        type = "error",
        duration = NULL
      )
      FALSE
    }
  )

  if (!size_ok) return()

  # Build all 8 export sheets
  sheets <- build_export_sheets(
    ...
  )
  writexl::write_xlsx(sheets, path = file)
}
```

### WR-02: No test coverage for pinned-row exclusion in `recalc_consensus_summary`

**File:** `tests/testthat/test-mod-review-helpers.R`
**Issue:** All test data frames set `.pinned = FALSE` for every row. There is no test that verifies pinned disagree rows are excluded from `n_disagree`. This allowed the `isTRUE()` vector bug (CR-01) to go undetected. Without a test covering the pinned case, a future fix could regress silently.

**Fix:** Add a test case with `.pinned = TRUE` on a disagree row:
```r
test_that("recalc_consensus_summary excludes pinned disagree rows from n_disagree", {
  df <- data.frame(
    consensus_status = c("disagree", "disagree", "agree"),
    consensus_dtxsid = c("DTXSID1", "DTXSID2", "DTXSID3"),
    .pinned = c(TRUE, FALSE, FALSE),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  result <- recalc_consensus_summary(df)
  expect_equal(result$n_disagree, 1)  # Only the non-pinned disagree row
})
```

## Info

### IN-01: `get_group_rows` rebuilds full reverse map on every call

**File:** `R/mod_review_results.R:177`
**Issue:** `get_group_rows()` calls `build_group_reverse_map()` on every invocation, rebuilding the entire O(n) map to perform a single O(1) lookup. This is called in several event handlers (lines 1055, 1086, 1268, 1297, 1546) and could be cached. Not a correctness issue, but worth noting for future optimization.

**Fix:** Cache the reverse map in `data_store` alongside `dedup_group_map`, or pass a pre-built reverse map as a parameter.

---

_Reviewed: 2026-05-06T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
