---
phase: 48-wqx-resolution-ui
reviewed: 2026-05-07T14:30:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - R/curation.R
  - R/mod_review_results.R
  - tests/testthat/test-mod-review-helpers.R
findings:
  critical: 1
  warning: 2
  info: 2
  total: 5
status: issues_found
---

# Phase 48: Code Review Report

**Reviewed:** 2026-05-07T14:30:00Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

This review covers the final state of the Phase 48 WQX Resolution UI changes across six commits (efc1066..f541eac). The phase added: (1) `wqx_confidence` pipeline propagation through `map_results_to_rows()`, (2) a WQX Review modal with accept/override/reject actions, and (3) integration tests for `wqx_confidence`.

The prior review's primary finding (WR-01: `wqx_confidence` dropped by `map_results_to_rows`) was fixed in commit `f6fba84`. The integration test gap (WR-03) was closed in commit `9d738e9` with Test Group 6. However, the fix introduced a new critical bug: the WQX Review modal references `row$searchValue`, a column that does not exist on `resolution_state`, causing an R error ("argument is of length zero") when the Review button is clicked. Two prior warnings remain open (needs_review init guard, multi-tag wqx_confidence naming). Two info-level items are noted for completeness.

---

## Critical Issues

### CR-01: `row$searchValue` references non-existent column -- WQX Review modal crashes on click

**File:** `R/mod_review_results.R:1755`
**Issue:** The `wqx_review_click` observer reads `input_name <- row$searchValue` where `row` is a single-row slice of `data_store$resolution_state`. However, `searchValue` is never propagated to the output data frame by `map_results_to_rows()` -- that function maps `searchName` (the API's match name), not `searchValue` (the user's input query). The `$` accessor on a data.frame for a missing column returns `NULL`.

At line 1796, the code evaluates:
```r
div(class = "col-8", if (!is.na(input_name)) input_name else "(unknown)")
```

Since `input_name` is `NULL`, `is.na(NULL)` returns `logical(0)`, and `if (logical(0))` throws: **"Error in if: argument is of length zero"**. This error propagates to the Shiny observer, preventing the WQX Review modal from opening. The user sees a red error notification instead of the modal.

**Fix:** Read the input name from the tagged column(s) instead. The column names are available via `data_store$column_tags`:

```r
# Replace line 1755:
# input_name <- row$searchValue
# With:
name_cols <- names(data_store$column_tags)[data_store$column_tags == "Name"]
input_name <- NA_character_
for (nc in name_cols) {
  if (nc %in% names(row) && !is.na(row[[nc]])) {
    input_name <- row[[nc]]
    break
  }
}
```

This reads the user's original input value from the tagged Name column, which is the correct semantic for "Input Name" in the modal context card.

---

## Warnings

### WR-01: `needs_review` column written without initialization guard in `wqx_reject_click`

**File:** `R/mod_review_results.R:1937`
**Issue:** The `wqx_reject_click` observer writes `updated_df$needs_review[r] <- TRUE` directly. The `needs_review` column does not exist on `resolution_state` at this point -- it is only materialized at export time by `export_helpers.R:43` via `dplyr::mutate()`. When R assigns to a non-existent column via `$<-`, the column is implicitly created with `NA` for all other rows. This means:

1. Non-rejected rows get `NA` (not `FALSE`) for `needs_review`.
2. If any downstream observer reads `updated_df$needs_review` expecting a fully-initialized logical vector, it gets a mix of `TRUE` and `NA`.
3. The export path in `export_helpers.R` overwrites the column, so there is no user-facing data corruption in exports.

The practical risk is low because the export recalculates, but the in-memory state is inconsistent. No downstream observer currently reads this column, but future code could be surprised by the `NA`/`TRUE` mix.

**Fix:** Add an initialization guard before the mutation loop:

```r
# In the wqx_reject_click observer, before the for loop:
if (!"needs_review" %in% names(updated_df)) {
  updated_df$needs_review <- FALSE
}
for (r in group_rows) {
  updated_df$consensus_status[r] <- "unresolvable"
  updated_df$needs_review[r] <- TRUE
}
```

---

### WR-02: `wqx_confidence` column naming is unsuffixed in multi-tag mode -- confidence lost for most datasets

**File:** `R/mod_review_results.R:767-778,1788` and `R/curation.R:576,584`

**Issue:** `map_results_to_rows()` correctly propagates `wqx_confidence` to the output data frame, but in multi-tag mode (more than one tagged column, which is the common case when both a Name and CASRN column are tagged), it uses a suffixed name: `wqx_confidence_<col>` (e.g., `wqx_confidence_Chemical`). The two consumer sites both check for the unsuffixed name:

- Table colDef (line 767): `if ("wqx_confidence" %in% names(df_display))` -- colDef never applied, raw numeric column appears without formatting.
- Modal (line 1788): `if ("wqx_confidence" %in% names(row))` -- confidence always falls back to `NA_real_`, so "Confidence Score" row never appears in modal.

In single-tag mode (one tagged column), the unsuffixed `wqx_confidence` is used and everything works. But single-tag is the uncommon case.

**Fix:** Use a grep-based lookup consistent with the pattern used for `preferredName_*` and `source_tier_*`:

```r
# Table colDef (around line 767):
wqx_conf_cols <- grep("^wqx_confidence", names(df_display), value = TRUE)
for (wcc in wqx_conf_cols) {
  col_defs[[wcc]] <- reactable::colDef(
    name = "WQX Conf.",
    minWidth = 80,
    align = "right",
    cell = function(value, index) {
      if (is.na(value)) return("")
      formatC(value, digits = 2, format = "f")
    }
  )
}

# Modal (line 1788):
wqx_conf_col <- grep("^wqx_confidence", names(row), value = TRUE)
confidence <- if (length(wqx_conf_col) > 0) row[[wqx_conf_col[1]]] else NA_real_
```

---

## Info

### IN-01: `review_btn` vector built for all `n` rows but used only for WQX subset

**File:** `R/mod_review_results.R:151-155`
**Issue:** `review_btn` is constructed as a full-length character vector across all `n` display rows. Only elements at WQX-masked positions are used. The existing `compare-btn` pattern (lines 134-141) only constructs HTML for the `compare_mask` subset. The WQX implementation is slightly less efficient than the pattern it follows, though correctness is not affected.

**Fix:** Generate button HTML inline at the assignment sites rather than pre-allocating for all rows.

---

### IN-02: Em-dash inconsistency in WQX reject notification

**File:** `R/mod_review_results.R:1943`
**Issue:** The reject notification uses a double hyphen `--`:
```r
sprintf("WQX match rejected for %d row(s) -- marked unresolvable", length(group_rows))
```

All other notifications in this file use Unicode em-dashes (e.g., `"\u2014"` at line 79). Minor cosmetic inconsistency.

**Fix:**
```r
sprintf("WQX match rejected for %d row(s) \u2014 marked unresolvable", length(group_rows))
```

---

_Reviewed: 2026-05-07T14:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
