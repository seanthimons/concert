---
phase: 50-auto-resolve-suggest
reviewed: 2026-05-11T20:45:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - R/consensus.R
  - tests/testthat/test-consensus.R
  - R/mod_run_curation.R
  - R/mod_review_results.R
  - R/export_helpers.R
  - R/cleaning_pipeline.R
findings:
  critical: 1
  warning: 2
  info: 3
  total: 6
status: issues_found
---

# Phase 50: Code Review Report

**Reviewed:** 2026-05-11T20:45:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Phase 50 adds auto-resolve and suggest classification for disagree rows based on Jaro-Winkler similarity scoring. The core algorithm in `classify_auto_resolve()` is well-structured with clear threshold logic, proper vectorized pinned-row filtering, and defensive NULL handling for the enrichment cache. The test suite covers the key scenarios (auto-resolve, suggest, disagree, pinned skip, boundary conditions). The UI additions (value boxes, Accept All Suggestions button, modal badges) integrate cleanly with the existing review results module.

One critical bug was found: `isTRUE()` used on a vector in `recalc_consensus_summary()` silently returns `FALSE` for any multi-row data frame, causing the disagree count to always include pinned rows. The same pattern appears in two other locations.

## Critical Issues

### CR-01: `isTRUE()` on vector produces incorrect disagree count

**File:** `R/mod_review_results.R:8`
**Issue:** `isTRUE(df$.pinned)` is a scalar function applied to a vector column. When `df` has more than one row, `isTRUE()` always returns `FALSE` (because the input is a vector, not a scalar). This means `!isTRUE(df$.pinned)` is always `TRUE`, so the `n_disagree` count includes ALL disagree rows regardless of pin status. The "Disagree" value box in the UI will show inflated numbers, and users may think there are unresolved rows when they have already been pinned.

The same anti-pattern appears at two additional locations in the same file:
- Line 1757: `!isTRUE(data_store$resolution_state$.pinned)` in the `apply_priority` before-count
- Line 1774: `!isTRUE(updated_df$.pinned)` in the `apply_priority` after-count

Note: `classify_auto_resolve()` in `R/consensus.R:521` correctly uses vectorized `!is.na(df$.pinned) & df$.pinned` instead of `isTRUE()`. The `isTRUE()` calls inside `for` loops at lines 454 and 652 of consensus.R are correct because they operate on scalar elements (`df$.pinned[i]`).

**Fix:**
```r
# R/mod_review_results.R line 8 -- replace:
n_disagree = sum(df$consensus_status == "disagree" & !isTRUE(df$.pinned), na.rm = TRUE),
# with:
pinned_vec <- !is.na(df$.pinned) & df$.pinned
n_disagree = sum(df$consensus_status == "disagree" & !pinned_vec, na.rm = TRUE),

# R/mod_review_results.R line 1755-1758 -- replace:
before_count <- sum(
  data_store$resolution_state$consensus_status == "disagree" &
    !isTRUE(data_store$resolution_state$.pinned),
  na.rm = TRUE
)
# with:
pinned_before <- !is.na(data_store$resolution_state$.pinned) & data_store$resolution_state$.pinned
before_count <- sum(
  data_store$resolution_state$consensus_status == "disagree" & !pinned_before,
  na.rm = TRUE
)

# R/mod_review_results.R line 1772-1775 -- same pattern:
pinned_after <- !is.na(updated_df$.pinned) & updated_df$.pinned
after_count <- sum(
  updated_df$consensus_status == "disagree" & !pinned_after,
  na.rm = TRUE
)
```

## Warnings

### WR-01: `resolve_row()` does not update `consensus_status` for overridden rows

**File:** `R/consensus.R:406-433`
**Issue:** When a user manually overrides an `auto_resolved` or `suggested` row via `resolve_row()`, the function sets `.pinned = TRUE` and `.resolution_method = "manual"` but leaves `consensus_status` unchanged. The row remains counted as `auto_resolved` or `suggested` in the summary and value boxes, even though the user manually picked a different candidate.

The UI handles this gracefully via the `pinned` flag (accepted suggestions show an "accepted" badge, auto-resolved rows show a "Compare" button), so this does not cause incorrect behavior. However, it means the "Auto-Resolved" and "Suggested" value box counts include rows that were manually overridden, which could be confusing to users.

If this is by design (status tracks origin, `.resolution_method` tracks how it was finalized), document this explicitly. Otherwise, `resolve_row()` should set `consensus_status` to a terminal status like `"manual"` when overriding auto_resolved/suggested rows.

**Fix:** If the intent is to update status on override:
```r
# In resolve_row(), after line 430, add:
if (df$consensus_status[row_idx] %in% c("auto_resolved", "suggested")) {
  df$consensus_status[row_idx] <- "manual"
}
```

### WR-02: Export `left_join` on enrichment cache may produce duplicate rows

**File:** `R/export_helpers.R:54`
**Issue:** The `left_join(enrich_lookup, by = "consensus_dtxsid")` could produce duplicate rows if the enrichment cache contains multiple entries for the same DTXSID. While the enrichment cache is typically deduplicated upstream, this is not enforced here. If a bug or race condition upstream produces duplicates, the exported "Curated Data" sheet would have more rows than the input, silently corrupting the export.

**Fix:** Add deduplication before the join:
```r
enrich_lookup <- enrichment_cache[, c("dtxsid", "casrn", "molecular_formula", "molecular_weight")]
enrich_lookup <- enrich_lookup[!duplicated(enrich_lookup$dtxsid), ]  # defensive dedup
names(enrich_lookup) <- c("consensus_dtxsid", "consensus_casrn", "consensus_formula", "consensus_mw")
```

## Info

### IN-01: Summary sheet uses `sum()` over `resolution_state` directly, duplicating count logic

**File:** `R/export_helpers.R:94-95`
**Issue:** The summary sheet builds auto-resolved and suggested counts via `sum(resolution_state$consensus_status == "auto_resolved", na.rm = TRUE)` rather than using the `consensus_summary` values that are already passed in. While the result is identical, this duplicates the counting logic rather than consuming the single source of truth (`consensus_summary$n_auto_resolved` and `consensus_summary$n_suggested`).

**Fix:**
```r
# Replace lines 94-95 with:
consensus_summary$n_auto_resolved %||% 0,
consensus_summary$n_suggested %||% 0,
```

### IN-02: `.resolution_method` and `.resolution_reason` columns have leading dots in export

**File:** `R/export_helpers.R:63`
**Issue:** The exported "Curated Data" sheet includes columns named `.resolution_method` and `.resolution_reason` (with leading dots). While the other dot-prefixed internal columns (`.pinned`, `.manual_entry`, `.suggested_column`) are explicitly excluded at line 47, these two are intentionally kept. The leading-dot naming convention in R typically signals internal/private columns, which may confuse downstream consumers (Excel users, other tools). Consider renaming them to `resolution_method` and `resolution_reason` in the export sheet.

**Fix:** Add renaming in the export pipeline or document the convention.

### IN-03: `precheck_normalize_cas` change is sound but comment could be clearer

**File:** `R/cleaning_pipeline.R:361-363`
**Issue:** The comment on line 361 says "Always recommend when CASRN columns have data (validation catches check digit errors)" but the actual logic (`has_cas_data`) checks if ANY value in any CASRN column is non-NA. This is correct behavior -- ensuring CAS normalization runs whenever CASRN data exists -- but the comment focuses on "validation catches check digit errors" which is only one of several reasons to run. The primary reason is that even well-formatted CAS numbers benefit from normalization (whitespace trimming, leading-zero handling, etc.).

**Fix:** No code change needed. Consider clarifying the comment.

---

_Reviewed: 2026-05-11T20:45:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
