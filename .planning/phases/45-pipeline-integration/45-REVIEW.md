---
phase: 45-pipeline-integration
reviewed: 2026-05-06T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - R/consensus.R
  - R/curation.R
  - tests/testthat/test-wqx-pipeline-integration.R
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 45: Code Review Report

**Reviewed:** 2026-05-06
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

This phase wires WQX dictionary matching as a fourth search tier in `run_curation_pipeline()`, adds a `"wqx"` consensus status to `classify_consensus()`, and adds a `compute_qc_tier()` case for that status. The logic is structurally sound. The main concerns are: (1) `resolve_row()` leaves `consensus_status` as `"disagree"` after resolution, which means downstream checks on the status are inconsistent with the pinned state; (2) `apply_priority_chain()` never updates `consensus_status`, silently leaving resolved rows still classified as `"disagree"`; (3) the integration test uses a named character vector instead of the required named list for `column_tags`, which will cause a runtime type error in the full-pipeline test; and (4) `%||%` is used throughout `curation.R` but is not declared in `NAMESPACE`, which will trigger `R CMD check` warnings and can cause `NOTE`-level failures in CI.

---

## Warnings

### WR-01: `resolve_row()` does not update `consensus_status` after resolution

**File:** `R/consensus.R:293-295`
**Issue:** `resolve_row()` fills `consensus_dtxsid` and sets `.pinned = TRUE` but never changes `consensus_status` from `"disagree"` to something like `"manual"`. Downstream code that reads `consensus_status` to determine row state will see `"disagree"` for a pinned row. The module UI and `merge_retry_results()` both check `consensus_status` directly. The docstring in `classify_consensus()` (line 51) explicitly says `"manual"` is a downstream-added status, implying `resolve_row()` should set it.

**Fix:**
```r
# After setting consensus_dtxsid and consensus_source:
df$consensus_dtxsid[row_idx] <- val
df$consensus_source[row_idx] <- sub("^dtxsid_", "", chosen_column)
df$consensus_status[row_idx] <- "manual"   # add this line
df$.pinned[row_idx] <- TRUE
```

---

### WR-02: `apply_priority_chain()` never updates `consensus_status`

**File:** `R/consensus.R:327-329`
**Issue:** When `apply_priority_chain()` resolves a `"disagree"` row by filling `consensus_dtxsid` and `consensus_source`, it does not change `consensus_status`. The row remains `"disagree"` in all downstream consumers that key off `consensus_status`. This means the consensus summary counts, module display logic, and export sheets all misreport these rows as unresolved after a bulk priority resolution.

**Fix:**
```r
for (col in priority_order) {
  val <- df[[col]][i]
  if (!is.na(val)) {
    df$consensus_dtxsid[i] <- val
    df$consensus_source[i] <- sub("^dtxsid_", "", col)
    df$consensus_status[i] <- "manual"   # add this line
    break
  }
}
```

---

### WR-03: Integration test passes named character vector where named list is required

**File:** `tests/testthat/test-wqx-pipeline-integration.R:177`
**Issue:** The full-pipeline test constructs `column_tags` as a named character vector (`c(Chemical = "Chemical Name")`), but `run_curation_pipeline()` passes it directly to `deduplicate_tagged_columns()` as `tag_map`, which calls `names(tag_map)[tag_map == "Name"]` and `tag_map[[col_name]]`. These operations behave differently on a character vector vs a list: `tag_map[[col_name]]` on a named vector returns the scalar correctly, but the intended contract in the docstring is `Named list (col_name -> "Name"|"CASRN"|"Other")`. More critically, the value `"Chemical Name"` does not match any of the expected tag types (`"Name"`, `"CASRN"`, `"Other"`), so `name_cols` and `cas_cols` will both be empty, and the pipeline will find zero unique names to search — the test will likely pass vacuously (empty results), not actually exercising WQX matching.

**Fix:**
```r
# Correct type and correct tag value:
column_tags <- list(Chemical = "Name")
```

---

### WR-04: `%||%` operator used in `curation.R` without `importFrom` in NAMESPACE

**File:** `R/curation.R:953, 959, 990`
**Issue:** `%||%` is used at three call sites in `enrich_candidates()` (e.g., `existing_cache %||% empty_cache`) but is not declared via `importFrom(rlang, "%||%")` in NAMESPACE, and is not defined anywhere in the package's own R sources. `rlang` is in `Imports:` so the operator is available at runtime via the package search path, but `R CMD check --as-cran` will flag the missing `importFrom` as a NOTE or WARNING for undefined global symbol. The operator should be explicitly imported.

**Fix:**
Add to any roxygen-documented function in the package (or a dedicated `utils.R`):
```r
#' @importFrom rlang %||%
NULL
```
Then re-run `devtools::document()` to regenerate NAMESPACE.

---

## Info

### IN-01: `consensus_summary` omits `n_wqx` count

**File:** `R/curation.R:913-919`
**Issue:** `search_summary` correctly includes `n_wqx` (line 910), but `consensus_summary` counts `n_agree`, `n_disagree`, `n_agree_caveat`, `n_single`, and `n_error` — it does not count rows with `consensus_status == "wqx"`. Any downstream consumer (module UI, export helpers) that iterates `consensus_summary` will not account for WQX-resolved rows, making totals not add up to `nrow(results)`.

**Fix:**
```r
n_wqx_status <- sum(classified_df$consensus_status == "wqx", na.rm = TRUE)
# ...
consensus_summary = list(
  n_agree = n_agree,
  n_disagree = n_disagree,
  n_agree_caveat = n_agree_caveat,
  n_single = n_single,
  n_wqx = n_wqx_status,   # add this
  n_error = n_error
)
```

---

### IN-02: WQX tier path exists only in `run_curation_pipeline`, not in `run_tiered_search`

**File:** `R/curation.R:370-495` vs `R/curation.R:625-921`
**Issue:** `run_tiered_search()` is an exported function that duplicates much of the tier-1/2/3 logic from `run_curation_pipeline()`. The WQX matching tier (Tier 3b) was added only in `run_curation_pipeline()` (line 755), not in the parallel implementation in `run_tiered_search()`. Any caller using `run_tiered_search()` directly — including future test code or headless callers — will not get WQX fallback. This is dead/inconsistent code rather than a bug, but it will cause confusion.

**Fix:** Either add the WQX tier to `run_tiered_search()` to mirror the pipeline, or deprecate `run_tiered_search()` if it is not called externally.

---

### IN-03: Missing test for `resolve_row()` and `apply_priority_chain()` with WQX rows

**File:** `tests/testthat/test-wqx-pipeline-integration.R`
**Issue:** The test file covers `classify_consensus()` WQX assignment and `compute_qc_tier()` for the `"wqx"` status, but has no tests for `resolve_row()` or `apply_priority_chain()` operating on rows that have `consensus_status == "wqx"`. Given that `resolve_row()` validates `status == "disagree"` and stops otherwise (line 275), it is undefined behavior to call it on a `"wqx"` row. Whether that is intentional (WQX rows should never be manually resolved) is not documented.

**Fix:** Add a test that verifies `resolve_row()` on a `"wqx"` row throws an informative error, or — if WQX rows should be resolvable — change the guard condition.

---

_Reviewed: 2026-05-06_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
