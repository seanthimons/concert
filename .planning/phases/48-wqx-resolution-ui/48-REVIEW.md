---
phase: 48-wqx-resolution-ui
reviewed: 2026-05-07T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - R/curation.R
  - R/mod_review_results.R
  - tests/testthat/test-mod-review-helpers.R
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 48: Code Review Report

**Reviewed:** 2026-05-07
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

This review covers the Phase 48 WQX Resolution UI changes: the `wqx_confidence` pipeline column added in `curation.R`, the Review button and WQX Review modal added to `mod_review_results.R`, and the helper-function tests in `test-mod-review-helpers.R`.

The design intent is sound and the implementation largely follows the patterns laid out in PATTERNS.md and UI-SPEC.md. The most significant issue is a data-loss bug: `wqx_confidence` is added to `combined_results` in `curation.R` but is silently dropped by `map_results_to_rows()` because that function only maps five hard-coded columns. The `wqx_confidence` column never reaches `resolution_state`, so the confidence score column in the UI always renders blank. The test suite does not catch this because the `wqx_confidence` tests inline the formula rather than calling the pipeline end-to-end. Three other quality issues are noted below.

---

## Warnings

### WR-01: `wqx_confidence` dropped by `map_results_to_rows` — column never reaches `resolution_state`

**File:** `R/curation.R:543-579`

**Issue:** `run_curation_pipeline` appends `wqx_confidence` to each WQX row in `combined_results` (line 761-765). However, `map_results_to_rows()` pre-allocates exactly five output vectors (`dtxsid_vec`, `pref_vec`, `search_vec`, `rank_vec`, `tier_vec`) and assigns only those five columns to the mapped data frame (lines 566-579). `wqx_confidence` is present in `lookup_deduped` (because `bind_rows` keeps it), but it is never read from `lookup_deduped` and never written to `df`. The column is silently discarded. As a result, `data_store$resolution_state` has no `wqx_confidence` column, the `if ("wqx_confidence" %in% names(df_display))` guard in `renderReactable` (line 767) is always `FALSE`, and the WQX Conf. column never appears in the table.

**Fix:** Add a `wqx_conf_vec` in `map_results_to_rows` alongside the existing five vectors, and write it out as `wqx_confidence`:

```r
# Inside the for (col in tag_cols) loop, add:
wqx_conf_vec <- rep(NA_real_, input_rows)

# Inside the inner for (i in ...) loop, add:
if ("wqx_confidence" %in% names(lookup_deduped)) {
  wqx_conf_vec[ridx] <- lookup_deduped$wqx_confidence[match_pos]
}

# In the single-tag-col branch (line 566), add:
df$wqx_confidence <- wqx_conf_vec

# In the multi-tag-col branch (line 572), add:
df[[paste0("wqx_confidence", suffix)]] <- wqx_conf_vec
```

For the multi-column case, the per-column suffix means multiple `wqx_confidence_*` columns would exist. The `renderReactable` guard checks for `"wqx_confidence"` (no suffix), which would still miss the multi-column scenario. That is a separate concern; the immediate fix is to ensure the single-column path (the typical use case) propagates the value.

---

### WR-02: `needs_review` column written without initialization guard in `wqx_reject_click`

**File:** `R/mod_review_results.R:1937`

**Issue:** The `wqx_reject_click` observer writes `updated_df$needs_review[r] <- TRUE` (line 1937) directly. If `resolution_state` does not have a `needs_review` column at the time of rejection — which is the case when the column is only materialized at export time in `export_helpers.R:43` — this implicitly creates a new logical column initialized to `NA` for all rows except the mutated ones. A subsequent `dplyr::mutate(needs_review = ...)` in the export helper would then overwrite it, rendering the in-state column meaningless. More importantly, if any downstream observer reads `updated_df$needs_review` expecting a fully-initialized logical vector, it will get a mix of `TRUE` and `NA` rather than `TRUE` and `FALSE`.

`init_resolution_state()` does not initialize `needs_review` (it only adds `.pinned` and `.manual_entry`). There is no other initialization site for this column.

**Fix:** Add `needs_review` initialization to `init_resolution_state()` in `R/consensus.R`, or add a guard in the observer before the assignment:

```r
# In the wqx_reject_click observer, before the mutation loop:
if (!"needs_review" %in% names(updated_df)) {
  updated_df$needs_review <- FALSE
}
for (r in group_rows) {
  updated_df$consensus_status[r] <- "unresolvable"
  updated_df$needs_review[r] <- TRUE
}
```

---

### WR-03: `wqx_confidence` test group exercises an inlined formula, not the pipeline — integration gap not surfaced

**File:** `tests/testthat/test-mod-review-helpers.R:118-163`

**Issue:** The four `wqx_confidence` tests (Test Group 4) construct a local `wqx_resolved` tibble and apply the `ifelse(match_tier == "fuzzy", 1 - match_distance, NA_real_)` formula directly. They verify the arithmetic is correct in isolation, which is fine. However, they do not call `run_curation_pipeline()` or even `map_results_to_rows()`, so the bug described in WR-01 (the column is dropped by the mapper) is completely invisible to the test suite. A test that calls the pipeline end-to-end and asserts `"wqx_confidence" %in% names(result$results)` would have caught WR-01 before it shipped.

**Fix:** Add an integration-level test (even with a minimal mock or stubbed API calls) that runs `run_curation_pipeline` with a WQX-matched row and asserts the returned `results` data frame contains a `wqx_confidence` column with the expected value. At minimum, a unit test of `map_results_to_rows` that passes a `lookup_results` tibble containing `wqx_confidence` and asserts the output contains the column would be sufficient.

---

## Info

### IN-01: `review_btn` vector built over all `n` rows but used only for WQX rows

**File:** `R/mod_review_results.R:151-155`

**Issue:** `review_btn` is constructed as a full-length character vector of `n` HTML strings (one per display row) via:

```r
review_btn <- paste0(
  ' <button class="wqx-review-btn btn btn-sm btn-outline-success" data-row="',
  row_indices,
  '">Review</button>'
)
```

Only elements at `wqx_has_pref` and `wqx_mask & !wqx_has_pref` positions are ever used. For tables with many rows and few WQX rows, this allocates and constructs HTML for every row unnecessarily. This matches the existing `compare-btn` pattern (line 135-141) which only constructs HTML for rows where `compare_mask` is TRUE, so the WQX implementation is slightly less efficient than the pattern it was intended to copy.

This is not a correctness issue (the unused strings are never inserted into the DOM), but it is an inconsistency with the established pattern.

**Fix:** Mirror the `compare-btn` pattern and generate button HTML only for the subset of rows that will use it:

```r
wqx_review_html <- function(indices) {
  paste0(
    ' <button class="wqx-review-btn btn btn-sm btn-outline-success" data-row="',
    indices,
    '">Review</button>'
  )
}
result[wqx_has_pref] <- paste0(
  "\u2705 ", htmltools::htmlEscape(effective_wqx_name[wqx_has_pref]),
  " ", wqx_badge, wqx_review_html(row_indices[wqx_has_pref])
)
result[wqx_mask & !wqx_has_pref] <- paste0(
  "\u2705 WQX matched ", wqx_badge,
  wqx_review_html(row_indices[wqx_mask & !wqx_has_pref])
)
```

---

### IN-02: `row$wqx_confidence` access returns a 1-element data frame column, not a scalar

**File:** `R/mod_review_results.R:1788`

**Issue:**

```r
confidence <- if ("wqx_confidence" %in% names(row)) row$wqx_confidence else NA_real_
```

`row` is a single-row data frame produced by `data_store$resolution_state[row_idx, ]`. `row$wqx_confidence` returns a length-1 vector (not a scalar), which is correct in practice — `is.na(confidence)` and `formatC(confidence, ...)` both handle length-1 vectors. However, when `wqx_confidence` is absent from `resolution_state` entirely (as it currently is due to WR-01), the `else NA_real_` branch executes and returns a proper scalar, masking the silent NA as if it were an expected absence rather than a bug. Once WR-01 is fixed this line becomes correct; no change is required here beyond fixing WR-01.

This is noted only for traceability: if WR-01 is not fixed, this line will always take the `else` branch and `confidence` will always be `NA_real_`, so the "Confidence Score" row will never appear in the modal context card even for fuzzy matches.

**Fix:** No change needed here — this is a symptom of WR-01. Fix WR-01 and this resolves automatically.

---

### IN-03: Notification copy for WQX reject diverges from UI spec

**File:** `R/mod_review_results.R:1943`

**Issue:** The `wqx_reject_click` observer shows:

```r
sprintf("WQX match rejected for %d row(s) -- marked unresolvable", length(group_rows))
```

The UI spec (48-UI-SPEC.md, Copywriting Contract) specifies the copy as:

> "WQX match rejected for {N} row(s) — marked unresolvable"

The implementation uses a double hyphen `--` instead of an em-dash `—` (U+2014). All other notifications in this file use Unicode em-dashes directly (e.g., `"\u2014"` at line 79). This is a minor cosmetic inconsistency.

**Fix:**

```r
sprintf(
  "WQX match rejected for %d row(s) \u2014 marked unresolvable",
  length(group_rows)
)
```

---

_Reviewed: 2026-05-07_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
