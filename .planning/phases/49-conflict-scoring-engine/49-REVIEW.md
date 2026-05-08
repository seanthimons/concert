---
phase: 49-conflict-scoring-engine
reviewed: 2026-05-08T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - R/consensus.R
  - R/curation.R
  - R/export_helpers.R
  - R/mod_review_results.R
  - R/mod_run_curation.R
  - tests/testthat/test-consensus.R
  - tests/testthat/test-enrichment.R
findings:
  critical: 1
  warning: 6
  info: 6
  total: 13
status: issues_found
---

# Phase 49: Code Review Report

**Reviewed:** 2026-05-08
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

This phase delivers the conflict-scoring engine: `compute_similarity_scores`, `score_one_candidate`,
WQX source-tier awareness, enrichment/synonym caching, and the resolution modal with per-candidate
similarity badges. The core scoring logic in `R/consensus.R` is well-structured and the test suite
covers the happy-path and boundary cases for scoring thoroughly.

One critical bug was found in `R/curation.R`: the single-tag column naming scheme in
`map_results_to_rows` produces columns that `find_dtxsid_cols` cannot detect, causing every row
to be classified as `"error"` when only one column is tagged. Six warnings cover a silent
`validate_and_lookup_cas` crash path, dead code in `run_tiered_search`, a misleading version
string in exports, and missing QC tier handling for newer status values. Six info items cover
dead code, missing exports, and test gaps.

---

## Critical Issues

### CR-01: Single-tag pipeline produces `dtxsid` column that `find_dtxsid_cols` cannot find

**File:** `R/curation.R:570-584`

**Issue:** `map_results_to_rows` has a branch for `length(tag_cols) == 1` that writes results to
columns named `dtxsid`, `preferredName`, `source_tier`, etc. (no suffix). The downstream call
`find_dtxsid_cols(mapped_df)` at `R/curation.R:891` uses `grep("^dtxsid_", names(df), ...)`, which
requires the `dtxsid_` prefix. When only one column is tagged, `find_dtxsid_cols` returns
`character(0)`, `classify_consensus` is called with an empty `dtxsid_cols` vector, and every row
receives `consensus_status = "error"` with `qc_tier = n_total + 2L` (where `n_total = 0`, yielding
`2L`). This silently produces a pipeline that appears to complete but resolves nothing.

**Fix:**
```r
# In map_results_to_rows, remove the special-case branch for single tag cols.
# Always use the suffixed naming scheme regardless of tag count.
# Replace lines ~570-585:

suffix <- paste0("_", col)
df[[paste0("dtxsid", suffix)]] <- dtxsid_vec
df[[paste0("preferredName", suffix)]] <- pref_vec
df[[paste0("searchName", suffix)]] <- search_vec
df[[paste0("rank", suffix)]] <- rank_vec
df[[paste0("source_tier", suffix)]] <- tier_vec
df[[paste0("wqx_confidence", suffix)]] <- wqx_conf_vec

# Remove the `if (length(tag_cols) == 1) { ... } else { ... }` wrapper entirely.
```

---

## Warnings

### WR-01: `validate_and_lookup_cas` has no outer error guard — crashes the pipeline

**File:** `R/curation.R:282-363`

**Issue:** The function calls `ComptoxR::as_cas(unique_cas)` and `ComptoxR::is_cas(validated)` at
lines 299-300 with no `tryCatch`. If either function throws (e.g., on unexpected input types or
an API change), the exception propagates uncaught through `run_tiered_search` / `run_curation_pipeline`
and terminates the curation run. The inner block at lines 319-359 does have a `tryCatch` for the
DTXSID lookup, but the normalization step before it does not.

**Fix:**
```r
validate_and_lookup_cas <- function(unique_cas) {
  # ... existing empty_result definition ...

  tryCatch({
    validated <- ComptoxR::as_cas(unique_cas)
    valid_flags <- ComptoxR::is_cas(validated)
    valid_flags[is.na(unique_cas)] <- NA
  }, error = function(e) {
    message(sprintf("  Warning: CAS normalization failed: %s", e$message))
    return(empty_result)   # early exit on normalization failure
  })

  # ... rest of function ...
}
```

### WR-02: `run_tiered_search` is dead code — diverged from `run_curation_pipeline`

**File:** `R/curation.R:373-495`

**Issue:** `run_tiered_search` was the original orchestration function. `run_curation_pipeline`
now inlines the entire tier logic (lines 697-815) with additional stages (WQX, progress callbacks,
`starts_with` flag). `run_tiered_search` is never called at runtime. Any bug fix applied to the
inline logic in `run_curation_pipeline` is not mirrored here. It also lacks the WQX tier entirely.
If a future caller invokes `run_tiered_search` directly they get incorrect, outdated behavior.

**Fix:** Either delete `run_tiered_search` or replace its body with a single call to the inline
logic block and a deprecation notice. Leaving it in place as unreachable code creates maintenance
debt.

### WR-03: `compute_qc_tier` returns `NA_integer_` for `"manual"` and `"unresolvable"` statuses

**File:** `R/consensus.R:30-42`

**Issue:** The `switch` statement handles `agree`, `agree_caveat`, `single`, `wqx`, `disagree`,
and `error`. The function comment at `classify_consensus` (line 51) explicitly acknowledges that
downstream code adds `"manual"` and `"unresolvable"`. Both statuses return `NA_integer_` from
`compute_qc_tier`. Downstream consumers that sort or compare `qc_tier` get `NA` for manual and
unresolvable rows, which compares as larger than any integer in R (`NA > 5L` is `NA`, not `TRUE`).
The `recalc_consensus_summary` in the review module correctly counts these statuses, but any
`qc_tier`-based sorting or filtering silently treats them as missing.

**Fix:**
```r
compute_qc_tier <- function(status, n_matched, n_total) {
  tier <- switch(
    status,
    "agree"         = 1L,
    "agree_caveat"  = 1L + as.integer(n_total - n_matched),
    "single"        = as.integer(n_total),
    "wqx"           = as.integer(n_total),
    "disagree"      = as.integer(n_total + 1L),
    "manual"        = as.integer(n_total),        # same tier as single
    "error"         = as.integer(n_total + 2L),
    "unresolvable"  = as.integer(n_total + 2L),   # same tier as error
    NA_integer_
  )
  tier
}
```

### WR-04: `validate_excel_size` boundary is off by one — header row not accounted for

**File:** `R/export_helpers.R:187-210`

**Issue:** Excel's row limit is 1,048,576 rows *including* the header. `validate_excel_size` blocks
at `n_rows >= max_rows` (i.e., `nrow(df) >= 1048576`). A data frame with exactly 1,048,575 rows
passes the check but will produce an Excel file with 1,048,576 rows (header + 1,048,575 data rows),
which hits Excel's hard limit exactly. `writexl` will either silently truncate or error at write
time.

**Fix:**
```r
max_rows <- 1048575L  # Reserve one row for the header
```

### WR-05: `curation_report$cas_invalid` can go negative

**File:** `R/mod_run_curation.R:185-186`

**Issue:**
```r
cas_invalid = pipeline_result$dedup_summary$n_cas - pipeline_result$search_summary$n_cas_valid
```
`n_cas` counts unique CAS values from CASRN-tagged columns only. `n_cas_valid` is `n_cas_from_columns + n_cas_from_names` — the sum of resolved CAS across both the CASRN-column path and the name-column CAS-fallback path. If a CAS string appears in both a Name column and a CASRN column, it is counted once in `n_cas` but twice in `n_cas_valid`. The subtraction produces a negative value. While the field only feeds a backward-compat report, negative counts will confuse any consumer of `data_store$curation_report`.

**Fix:**
```r
cas_invalid = max(0L,
  pipeline_result$dedup_summary$n_cas -
  pipeline_result$search_summary$n_cas_valid
)
```
Or preferably compute `cas_invalid` directly from the `cas_results` count inside the pipeline rather than deriving it by subtraction.

### WR-06: `get_resolution_options` WQX tiers missing from `tier_labels` — display shows "Unknown"

**File:** `R/consensus.R:196-203`

**Issue:** The `tier_labels` lookup at lines 196-203 does not include `"wqx_exact"`, `"wqx_alias"`,
or `"wqx_fuzzy"`. A disagree row where one candidate was matched via WQX will show `"Unknown"` as
the source tier in the resolution modal instead of a meaningful label. The `derive_match_type`
function in the review module *does* include these labels (lines 27-33), so there is an
inconsistency between modal display and table badge display for WQX-originated candidates.

**Fix:**
```r
tier_labels <- c(
  "exact"       = "Exact match",
  "cas"         = "CAS lookup",
  "starts_with" = "Starts-with",
  "wqx_exact"   = "WQX Exact",
  "wqx_alias"   = "WQX Alias",
  "wqx_fuzzy"   = "WQX Fuzzy",
  "miss"        = "No match",
  "cas_no_match"   = "No match",
  "cas_invalid"    = "No match"
)
```

---

## Info

### IN-01: `app_version` in export config sheet always reports base R version, not chemreg version

**File:** `R/export_helpers.R:137`

**Issue:** `as.character(packageVersion("base"))` is used as a placeholder with an inline comment
`# Placeholder for ChemReg version`. Every exported Excel file's `Pipeline Config` sheet will show
the base R version (e.g., `"4.5.1"`) as the app version. This is silently wrong data in a
permanent export artifact.

**Fix:**
```r
# If chemreg has a DESCRIPTION version:
tryCatch(as.character(packageVersion("chemreg")), error = function(e) "unknown")
```
Or define a package-level constant `CHEMREG_VERSION <- "0.x.y"` and reference it here.

### IN-02: `deduplicate_tagged_columns` is not exported

**File:** `R/curation.R:19`

**Issue:** `deduplicate_tagged_columns` lacks an `@export` roxygen tag. It is part of the public
pipeline contract (called by `run_curation_pipeline` and `get_dedup_preview`) and would be useful
for testing or scripted use outside the Shiny app. The function is reachable only via `chemreg:::`.

**Fix:** Add `#' @export` to the roxygen block above `deduplicate_tagged_columns`.

### IN-03: `compare_row_click` observer has no bounds check on `row_idx`

**File:** `R/mod_review_results.R:1185-1343`

**Issue:** The WQX review path at line 1811 has an explicit bounds check:
```r
if (is.null(row_idx) || row_idx < 1 || row_idx > nrow(data_store$resolution_state))
```
The `compare_row_click` path at line 1185 does not. A stale click event (e.g., from a
re-rendered table after re-curation that reduced row count) will cause `get_resolution_options`
to attempt `df[[col]][row_idx]` with an out-of-bounds index. R will return `NA` silently for
vector indexing but will error for list indexing; the net effect depends on the data frame
type. A guard should be added for consistency.

**Fix:**
```r
observeEvent(input$compare_row_click, {
  req(data_store$resolution_state, data_store$dtxsid_cols)
  row_idx <- input$compare_row_click$row
  if (is.null(row_idx) || row_idx < 1 || row_idx > nrow(data_store$resolution_state)) {
    return()
  }
  # ... rest of handler ...
})
```

### IN-04: `compute_qc_tier` and `classify_consensus` not tested for `"wqx"` status

**File:** `tests/testthat/test-consensus.R:142-183`

**Issue:** The `compute_qc_tier` ordering test at line 172 covers five statuses. `"wqx"` is not
tested even though `classify_consensus` emits it (lines 101-108 of `consensus.R`). There is also
no test that verifies `classify_consensus` correctly sets `consensus_status = "wqx"` when all
DTXSID columns are NA but a `source_tier_*` column has a `wqx_*` value.

**Fix:** Add test cases:
```r
test_that("compute_qc_tier: wqx tier equals single tier", {
  expect_equal(compute_qc_tier("wqx", 0, 3), compute_qc_tier("single", 1, 3))
})

test_that("classify_consensus: all-NA dtxsid with wqx source_tier -> wqx status", {
  df <- data.frame(
    dtxsid_Chemical = NA_character_,
    source_tier_Chemical = "wqx_exact",
    stringsAsFactors = FALSE
  )
  result <- classify_consensus(df, "dtxsid_Chemical")
  expect_equal(result$consensus_status[1], "wqx")
})
```

### IN-05: `enrich_candidates` incremental-cache test does not assert single API call

**File:** `tests/testthat/test-enrichment.R:42-78`

**Issue:** The test at line 42 verifies the result cache contents are correct but does not assert
that `call_count == 1` — the optimization that skips re-fetching cached DTXSIDs. If the
incremental caching logic regressed (fetching all DTXSIDs every time), the cache content would
still be correct (the result would just be re-fetched) and the test would still pass.

**Fix:**
```r
# After result <- enrich_candidates(...):
expect_equal(call_count, 1L)
```

### IN-06: `score_one_candidate` uses namespace-free `stringdist::stringdist` call

**File:** `R/consensus.R:289`

**Issue:** The call is written as `stringdist::stringdist(...)`, which is correct and explicit.
No issue — noted for completeness. No change needed.

---

_Reviewed: 2026-05-08_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
