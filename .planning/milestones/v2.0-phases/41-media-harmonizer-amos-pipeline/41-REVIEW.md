---
phase: 41-media-harmonizer-amos-pipeline
reviewed: 2026-04-27T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - R/curate_headless.R
  - R/media_harmonizer.R
  - R/mod_harmonize.R
  - R/mod_tag_columns.R
  - R/tag_helpers.R
  - scripts/build_amos_media.R
  - tests/testthat/test-media-harmonizer.R
  - tests/testthat/test-media-pipeline-wiring.R
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 41: Code Review Report

**Reviewed:** 2026-04-27
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

This is a post-gap-closure review of the media harmonization engine (`harmonize_media()`), the AMOS extraction script (`scripts/build_amos_media.R`), Shiny module wiring (`mod_harmonize.R`), and headless pipeline wiring (`curate_headless.R`). Plan 41-04 closed dedup_step contract mismatch, stage-ordering inversion, NA warnings, and validation display gaps.

Reading the current source confirms the gap-closure is applied: `harmonize_media()` is called directly (not via `dedup_step`), media harmonization runs as a pre-stage in both code paths before unit harmonization, and the NA-safety guard is in place. The core engine in `media_harmonizer.R` and the test coverage in `test-media-harmonizer.R` are solid.

Three warnings remain. The first is a silent error-swallowing divergence between the headless and Shiny correction handlers. The second is a fragile positional indexing pattern in the duration expansion merge. The third is a `NULL` return from the Media-only harmonize path that callers may not tolerate. Three info items cover a malformed roxygen block, a build-script coupling hazard, and a missing test for tier-2 of the media cascade.

## Warnings

### WR-01: `apply_corrections_headless` silently swallows errors -- correction state is silently discarded on bad pattern

**File:** `R/curate_headless.R:252-255`
**Issue:** The `tryCatch` error handler for a correction pattern failure returns `NULL` and discards the exception without any warning or message. When `gsub()` throws (e.g., an invalid regex in `corrections_tbl$pattern[i]`), the assignment `result <- gsub(...)` does not execute, so `result` retains the value from the previous iteration. The failed pattern is silently skipped and the caller has no indication that corrections were partially applied.

The Shiny-side equivalent in `mod_harmonize.R:125-134` correctly emits a `warning()` on error. The headless handler is inconsistent and harder to debug in scripted batch usage where there is no notification UI.

**Fix:**
```r
apply_corrections_headless <- function(values, corrections_tbl) {
  if (is.null(corrections_tbl) || nrow(corrections_tbl) == 0) {
    return(values)
  }
  result <- values
  for (i in seq_len(nrow(corrections_tbl))) {
    tryCatch(
      result <- gsub(corrections_tbl$pattern[i], corrections_tbl$replacement[i], result),
      error = function(e) {
        warning(sprintf(
          "curate_headless: correction pattern '%s' failed: %s",
          corrections_tbl$pattern[i],
          e$message
        ))
      }
    )
  }
  result
}
```

---

### WR-02: `dur_for_merge` positional indexing in `mod_harmonize.R` depends on an undocumented invariant

**File:** `R/mod_harmonize.R:570-571`
**Issue:** The duration expansion merge reads:
```r
dur_values_expanded <- dur_for_merge$study_duration_value[harmonize_tibble$orig_row_id]
dur_units_expanded <- dur_for_merge$study_duration_units[harmonize_tibble$orig_row_id]
```
This uses the _values_ of `harmonize_tibble$orig_row_id` as positional row indices into `dur_for_merge`. This works only because `harmonize_units()` for durations (line 477) processes the full unfiltered `input_df` column and returns `orig_row_id = 1:nrow(input_df)` in sequential order, making row position and `orig_row_id` value identical.

The comment at lines 566-569 acknowledges the range-expansion complexity but describes the index as mapping through `orig_row_id` — which implies a `match()`-based join — while the code actually does positional indexing. If `input_df` is ever pre-filtered or if `harmonize_units()` returns non-sequential IDs, this silently misaligns duration values to the wrong expanded rows.

The media merge at line 584 correctly uses positional indexing because `media_results$orig_row_id` is guaranteed 1:N and position = ID. But that reasoning is not shared by duration. The correct defensive pattern is `match()`:

**Fix:**
```r
matched_dur_idx <- match(harmonize_tibble$orig_row_id, dur_for_merge$orig_row_id)
dur_values_expanded <- dur_for_merge$study_duration_value[matched_dur_idx]
dur_units_expanded <- dur_for_merge$study_duration_units[matched_dur_idx]
```

---

### WR-03: `harmonize_audit_tibble` is `NULL` for Media-only/StudyDate-only paths -- callers expecting a tibble will fail

**File:** `R/curate_headless.R:322`
**Issue:** When the pipeline takes the "no Result column" branch (StudyDate-only or Media-only, lines 310-323), `harmonize_audit_tibble` is set to `NULL`. The return value at line 421 therefore carries `harmonize_audit = NULL`. Any caller that applies `nrow()`, `dplyr::bind_rows()`, `writexl::write_xlsx()`, or a downstream sheet builder on `result$harmonize_audit` will encounter an error because those functions do not accept `NULL` as a tibble.

The `harmonize_tibble` produced in this same branch (lines 314-320) is correctly a zero-or-N-row typed tibble. `harmonize_audit_tibble` should follow the same convention.

**Fix:** Replace the `NULL` assignment at line 322 with a typed zero-row tibble:
```r
harmonize_audit_tibble <- tibble::tibble(
  orig_row_id       = integer(0),
  raw_value         = character(0),
  numeric_value     = numeric(0),
  value_flag        = character(0),
  orig_unit         = character(0),
  harmonized_value  = numeric(0),
  harmonized_unit   = character(0),
  conversion_factor = numeric(0),
  unit_flag         = character(0)
)
```

---

## Info

### IN-01: `detect_tag_changes` has a malformed roxygen block -- documentation merged with `has_required_chemical_tags`

**File:** `R/tag_helpers.R:147-213`
**Issue:** The roxygen block beginning at line 147 (intended for `detect_tag_changes`) does not close before the `has_required_chemical_tags` documentation begins at line 175. The `@export` on line 199 applies to `has_required_chemical_tags`, and `detect_tag_changes` at line 213 has only a bare `#' @export` with all its detailed `@param`, `@return`, `@details`, and `@examples` documentation orphaned in the preceding function's block. `roxygen2::roxygenise()` will generate garbled help pages and `R CMD check` will warn about undocumented arguments.

**Fix:** Close the `detect_tag_changes` roxygen block at line 173, start a fresh block for `has_required_chemical_tags`, and move `@export` for `detect_tag_changes` into its own block directly above the function at line 213.

---

### IN-02: `refresh_amos_cache` re-sources the build script, executing all top-level side effects

**File:** `scripts/build_amos_media.R:366`
**Issue:** `refresh_amos_cache()` calls `source(file.path(root, "scripts", "build_amos_media.R"))`. The build script runs `stopifnot()`, API calls, file reads, and cache writes at the top level. Sourcing the file to obtain the function also triggers the entire pipeline. The function redefines itself on each invocation. Anyone sourcing the file in interactive use to inspect `refresh_amos_cache()` silently kicks off an API call.

**Fix:** Extract `refresh_amos_cache()` into `R/refresh_amos_cache.R` (or a package function) that calls the build pipeline as a callable, and guard the top-level script code with `if (sys.nframe() == 0L)` so that sourcing the file for the function definition does not trigger the pipeline.

---

### IN-03: No test covers tier-2 of the three-tier media cascade (dataset-wide `media` parameter)

**File:** `tests/testthat/test-media-pipeline-wiring.R`
**Issue:** The three-tier media cascade is documented in `curate_headless.R:275-279` and `mod_harmonize.R:408-413`: tagged column > dataset-wide `media` param > NULL/aqueous default. The test suite covers tier 1 (tagged Media column, API-gated) and tier 3 (implicit aqueous default via the direct-wiring test). Tier 2 -- passing `media = "aqueous"` as the dataset-wide scalar with no Media column in `tag_map` -- is untested. A direct-wiring test for this can be written without an API key.

**Fix:** Add to Section 3 of `test-media-pipeline-wiring.R`:
```r
test_that("harmonize_units respects scalar media= parameter for ppb routing (tier-2 cascade)", {
  unit_map <- concert:::load_unit_map(
    system.file("extdata", "reference_cache", package = "concert")
  )
  result <- harmonize_units(
    values  = c(1000, 500),
    units   = c("ppb", "ppb"),
    unit_map = unit_map,
    media   = "aqueous"
  )
  expect_true(all(result$harmonized_unit == "mg/L"))
})
```

---

_Reviewed: 2026-04-27_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
