---
phase: 41-media-harmonizer-amos-pipeline
reviewed: 2026-04-27T16:42:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - R/media_harmonizer.R
  - R/curate_headless.R
  - R/mod_harmonize.R
  - R/mod_tag_columns.R
  - R/tag_helpers.R
  - scripts/build_amos_media.R
  - tests/testthat/test-media-harmonizer.R
findings:
  critical: 1
  warning: 3
  info: 2
  total: 6
status: issues_found
---

# Phase 41: Code Review Report

**Reviewed:** 2026-04-27T16:42:00Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

The phase introduces an environmental media harmonization engine (`harmonize_media`), an AMOS extraction script for enriching the ENVO vocabulary cache, and wires media harmonization into both the Shiny UI pipeline (`mod_harmonize.R`) and the headless curation pipeline (`curate_headless.R`). Tag infrastructure (`mod_tag_columns.R`, `tag_helpers.R`) is extended to include the "Media" tag type. Tests for the core harmonizer function are thorough and well-structured.

The primary concern is a critical contract mismatch where `harmonize_media()` is passed to `dedup_step()` without an adapter. `dedup_step` expects a function with signature `fn(data_frame, ...) -> list(cleaned_data, audit_trail)`, but `harmonize_media` expects `fn(character_vector, ...) -> tibble`. This will crash at runtime whenever a Media column is tagged and harmonization is executed. A secondary concern is that the headless pipeline runs media harmonization after unit harmonization, preventing per-row media context from influencing ppb/ppm unit routing -- a divergence from the Shiny pipeline where media runs as a pre-stage.

## Critical Issues

### CR-01: Contract mismatch -- harmonize_media passed to dedup_step will crash at runtime

**File:** `R/curate_headless.R:342-346` and `R/mod_harmonize.R:349-353`
**Issue:** Both call sites pass `harmonize_media` directly to `dedup_step()`:
```r
dedup_step(harmonize_media, input_df, dedup_cols = media_cols_pre[1])
```
`dedup_step` (defined in `R/cleaning_pipeline.R:184`) calls `step_fn(df_unique, ...)` where `df_unique` is a data frame row-subset, then accesses `result$cleaned_data` and `result$audit_trail` on the return value. However, `harmonize_media()` has signature `function(raw_media, orig_row_id)` where `raw_media` is a character vector, and it returns a flat tibble (not a list with `$cleaned_data`/`$audit_trail`). This will fail in two ways:
1. `harmonize_media(df_unique)` passes a data frame where a character vector is expected -- `trimws(tolower(raw_media))` on a data frame produces unexpected results or errors.
2. `result$cleaned_data` on the returned tibble yields `NULL`, causing downstream `[key_to_unique_idx, ]` to error.

Additionally, the callers then access `$media_category`, `$media_flag`, and `$orig_row_id` on the `dedup_step` return value, but `dedup_step` returns `list(cleaned_data = ..., audit_trail = ...)` -- not the harmonize_media output schema.

**Fix:** Create an adapter function that wraps `harmonize_media` to conform to the `dedup_step` contract, or call `harmonize_media` directly (bypassing `dedup_step`) since media harmonization does not produce `cleaned_data`/`audit_trail` pairs:
```r
# Option A: Call harmonize_media directly without dedup_step
media_col_values <- as.character(input_df[[media_cols_pre[1]]])
media_tibble <- harmonize_media(
  raw_media = media_col_values,
  orig_row_id = seq_len(nrow(input_df))
)

# Option B: Wrap in an adapter for dedup_step
media_step_fn <- function(df, ...) {
  raw <- as.character(df[[media_cols_pre[1]]])
  result_tbl <- harmonize_media(raw, orig_row_id = seq_len(nrow(df)))
  list(
    cleaned_data = dplyr::bind_cols(df, result_tbl[, c("canonical_media", "media_category", "media_flag")]),
    audit_trail = tibble::tibble(row_id = integer(0), field = character(0),
                                  step = character(0), original_value = character(0),
                                  new_value = character(0), reason = character(0))
  )
}
```

## Warnings

### WR-01: Headless pipeline media harmonization runs after unit harmonization -- per-row media context unavailable for ppb/ppm routing

**File:** `R/curate_headless.R:252-256` and `R/curate_headless.R:337-358`
**Issue:** In `curate_headless.R`, Stage 3 (unit harmonization, line 243) runs before Stage 3d (media harmonization, line 337). The unit harmonization check at line 252 (`"media" %in% names(input_df)`) will always be FALSE because `input_df$media` is not populated until Stage 3d. This means the three-tier cascade described in the comment ("tagged column > manual param > NULL") effectively only has two tiers in the headless pipeline. In contrast, `mod_harmonize.R` correctly runs media as a "Pre-stage" (line 336) before numeric harmonization so that per-row `media_category` is available for ppb/ppm routing.
**Fix:** Move Stage 3d (media harmonization) before Stage 3 (unit harmonization) in `curate_headless.R`, matching the order in `mod_harmonize.R`:
```r
# Stage 3d should run BEFORE Stage 3 in curate_headless.R
# Move the media harmonization block (lines 337-358) to before line 217
```

### WR-02: Unsuppressed warning when lookup_hash is indexed by NA

**File:** `R/media_harmonizer.R:158-160`
**Issue:** Line 158 performs `match_idx <- lookup_hash[normalized]`. When `normalized` contains `NA` values (from `NA` inputs), indexing a named vector by `NA` produces a warning: `"NAs introduced by coercion"` or similar. Line 160 sets the NA positions to `NA_integer_` after the fact, but the warning has already been emitted on line 158. The comment on line 159 claims the warning is "suppress[ed] safely" but no suppression actually occurs.
**Fix:** Wrap the lookup in `suppressWarnings()` or pre-filter NAs:
```r
# Option A: Suppress the specific warning
match_idx <- suppressWarnings(lookup_hash[normalized])
match_idx[is.na(normalized)] <- NA_integer_

# Option B: Pre-filter NAs before lookup
non_na_mask <- !is.na(normalized)
match_idx <- rep(NA_integer_, n)
match_idx[non_na_mask] <- lookup_hash[normalized[non_na_mask]]
```

### WR-03: validate_tag_pairing result is computed but never displayed to the user

**File:** `R/mod_tag_columns.R:137`
**Issue:** `warning_msg <- validate_tag_pairing(col_tag_map)` computes a warning message when Result is tagged without Unit (or vice versa), but the result is assigned to a variable that is never used. The user receives no notification about the pairing issue.
**Fix:** Display the warning message via `showNotification` when non-NULL:
```r
warning_msg <- validate_tag_pairing(col_tag_map)
if (!is.null(warning_msg)) {
  showNotification(warning_msg, type = "warning", duration = 6)
}
```

## Info

### IN-01: Malformed roxygen block -- detect_tag_changes documentation merged into has_required_chemical_tags

**File:** `R/tag_helpers.R:147-212`
**Issue:** The roxygen block starting at line 147 (intended for `detect_tag_changes`) does not end before line 175 where the `has_required_chemical_tags` documentation begins without a new `#'` header separator. The `@export` on line 199 is applied to `has_required_chemical_tags` (line 200), and `detect_tag_changes` (line 213) has only a bare `#' @export` on line 212 with all its detailed documentation lost. `roxygen2::roxygenise()` will produce garbled help pages for both functions.
**Fix:** Close the `detect_tag_changes` roxygen block at line 173, then start a fresh `#'` block for `has_required_chemical_tags`:
```r
#' @export
detect_tag_changes <- function(old_tags, new_tags) {
```
Move the `detect_tag_changes` function definition immediately after its own `@export` tag, and give `has_required_chemical_tags` its own separate roxygen block starting with `#'`.

### IN-02: refresh_amos_cache re-sources the entire build script including top-level side effects

**File:** `scripts/build_amos_media.R:342-368`
**Issue:** `refresh_amos_cache()` at line 366 calls `source("scripts/build_amos_media.R")` -- the same file that defines `refresh_amos_cache()`. This file executes top-level code (API calls, file reads, cache writes) on source, which is the intended behavior for a refresh. However, defining `refresh_amos_cache()` in a file that has side effects on source creates a coupling hazard: anyone who sources the file to get the function also triggers the entire pipeline. The function also redefines itself on each call.
**Fix:** Extract `refresh_amos_cache()` into a separate file (e.g., `R/refresh_amos_cache.R`) that calls the build script, or guard the top-level pipeline code behind an `if (sys.nframe() == 0L)` or `if (!exists(".AMOS_SOURCED"))` check so that sourcing the file for the function definition does not trigger the pipeline.

---

_Reviewed: 2026-04-27T16:42:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
