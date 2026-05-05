---
phase: 44-matching-engine-prototype
reviewed: 2026-05-05T12:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - R/wqx_matching.R
  - tests/testthat/test-wqx-matching.R
  - scripts/prototype_wqx_matching.R
  - DESCRIPTION
  - NAMESPACE
findings:
  critical: 0
  warning: 1
  info: 2
  total: 3
status: issues_found
---

# Phase 44: Code Review Report

**Reviewed:** 2026-05-05
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Phase 44 introduces `match_wqx()`, a three-tier WQX Characteristic Name matcher (exact canonical, alias crosswalk, Jaro-Winkler fuzzy). The implementation is well-structured: pre-allocated result vectors, O(1) named-vector hash maps for tiers 1 and 2, vectorized distance matrix for tier 3, and a clean empty-input guard. Test coverage hits all tiers including edge cases (NA, empty string, multi-name batch). The prototype script is a clean standalone harness.

One correctness bug was found: the ampersand normalization (`&` to `and`) is applied to input names but not to hash table keys, causing 172 canonical names containing `&` to be unmatchable via tier 1 or tier 2 when users supply the exact canonical spelling. This will silently fall through to the fuzzy tier (where it may still resolve, but at unnecessary cost and with a non-zero distance score).

DESCRIPTION and NAMESPACE are consistent -- `stringdist` is declared in `Imports` and `match_wqx` is exported.

## Warnings

### WR-01: Ampersand normalization asymmetry between input and hash table keys

**File:** `R/wqx_matching.R:47,67-68`
**Issue:** Line 47 normalizes input names with `gsub("\\s*&\\s*", " and ", names_clean)`, converting `&` to `and`. However, the tier 1 hash table keys (line 67) and tier 2 hash table keys (line 61-68) are built from the dictionary using only `tolower(trimws(...))` without the same ampersand swap. This creates an asymmetry: if the WQX canonical name is `"Nitrogen & Phosphorus"` and the user types exactly that, the input becomes `"nitrogen and phosphorus"` but the key remains `"nitrogen & phosphorus"` -- tier 1 misses. The same asymmetry applies to tier 2 alias keys. There are 172 canonical names in the live WQX dictionary that contain `&`, all of which are affected.

The match will fall through to tier 3 fuzzy and likely still resolve, but with a non-zero distance and the wrong tier label (`fuzzy` instead of `exact`), which degrades match quality reporting and adds unnecessary fuzzy computation cost.

**Fix:** Apply the same ampersand normalization when building hash table keys:
```r
# Helper to normalize consistently
normalize_name <- function(x) {
  x <- tolower(trimws(x))
  gsub("\\s*&\\s*", " and ", x)
}

# Use in input normalization (line 46-47)
names_clean <- normalize_name(names)

# Use in tier 1 map keys (line 67)
tier1_map <- stats::setNames(canonical_rows$name, normalize_name(canonical_rows$name))

# Use in tier 2 dedup and map keys (line 61)
alias_rows <- dplyr::distinct(
  dplyr::mutate(alias_rows, .lower_name = normalize_name(alias_rows$name)),
  .lower_name,
  .keep_all = TRUE
)
```

## Info

### IN-01: Verbose test uses weak assertion (gte instead of gt)

**File:** `tests/testthat/test-wqx-matching.R:140`
**Issue:** The test asserts `expect_gte(length(msgs_verbose), length(msgs_quiet))` (greater than or equal), which would pass even if verbose mode produced the same number of messages as quiet mode. The intent is to verify verbose=TRUE produces additional per-name messages beyond the summary, which calls for `expect_gt` (strictly greater than).

**Fix:** Change to `expect_gt`:
```r
expect_gt(length(msgs_verbose), length(msgs_quiet))
```

### IN-02: Prototype script has no guard against missing `analyte` column or empty data

**File:** `scripts/prototype_wqx_matching.R:58,95`
**Issue:** Line 58 accesses `train$analyte` without checking the column exists. If the CSV lacks an `analyte` column, `train$analyte` returns `NULL`, which flows through to `match_wqx()` (returning a zero-row tibble), and line 95 divides by `nrow(results)` which would be 0, producing `NaN`. This is a minor concern for a standalone prototype script but worth hardening.

**Fix:** Add a column existence check after loading training data:
```r
stopifnot(
  "'analyte' column not found in training CSV" = "analyte" %in% names(train),
  "Training CSV has zero rows" = nrow(train) > 0
)
```

---

_Reviewed: 2026-05-05_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
