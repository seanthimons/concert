---
phase: 40-date-parser
reviewed: 2026-04-26T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - R/date_parser.R
  - R/tag_helpers.R
  - R/mod_tag_columns.R
  - R/mod_harmonize.R
  - R/curate_headless.R
  - tests/testthat/test-date-parser.R
  - tests/testthat/test-tag-dispatch.R
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 40: Code Review Report

**Reviewed:** 2026-04-26
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Phase 40 adds the date parsing engine (`parse_dates()`), wires it into the harmonization pipeline in `mod_harmonize.R` and `curate_headless.R`, and extends `tag_helpers.R` with `StudyDate` support. The core parser logic is well-structured — the flag-priority ordering is correct, the empty-input guard is typed correctly, and the train=FALSE rationale is well-documented.

Three warnings were identified:

1. `validate_tag_pairing()` result is computed but never displayed to the user, silently discarding the warning.
2. The `tags_applied` indicator in `mod_tag_columns.R` only checks `column_tags` (chemical), so a StudyDate-only tagging session does not enable downstream navigation.
3. The `apply_corrections` helper is duplicated verbatim between `mod_harmonize.R` and `curate_headless.R` — a shared helper function should be extracted.

Four informational items are noted, including a malformed roxygen block in `tag_helpers.R` that will cause `R CMD check` NOTE/warnings on documentation build.

---

## Warnings

### WR-01: `validate_tag_pairing()` result is silently discarded — user never sees Result/Unit pairing warning

**File:** `R/mod_tag_columns.R:136`
**Issue:** `warning_msg <- validate_tag_pairing(col_tag_map)` is called and assigned, but `warning_msg` is never subsequently read or displayed. The function is documented as returning a warning message for the user (per D-12/D-13), but the notification is never issued. A user who tags a Result column without a Unit will see "Tagged N column(s) successfully!" with no indication of the pairing problem.
**Fix:**
```r
# After line 136, add:
warning_msg <- validate_tag_pairing(col_tag_map)
if (!is.null(warning_msg)) {
  showNotification(warning_msg, type = "warning", duration = 6)
}
```

---

### WR-02: `tags_applied` indicator ignores `study_type_tags` — StudyDate-only sessions leave navigation disabled

**File:** `R/mod_tag_columns.R:198-206`
**Issue:** Both `output$tags_applied` and the returned reactive check only `data_store$column_tags` (chemical tags). When a user tags only a StudyDate column (no chemical Name/CASRN), `column_tags` is an empty list, so `tags_applied` is FALSE. Any downstream navigation gated on `tags_applied` (e.g., the Harmonize tab enable) remains blocked even though the user has applied valid tags that should unlock harmonization.
**Fix:**
```r
output$tags_applied <- reactive({
  has_chemical <- !is.null(data_store$column_tags) && length(data_store$column_tags) > 0
  has_study    <- !is.null(data_store$study_type_tags) && length(data_store$study_type_tags) > 0
  has_numeric  <- !is.null(data_store$numeric_tags) && length(data_store$numeric_tags) > 0
  has_chemical || has_study || has_numeric
})
# Apply the same logic to the returned reactive list on lines 204-208.
```

---

### WR-03: `apply_corrections` helper is duplicated between `mod_harmonize.R` and `curate_headless.R`

**File:** `R/mod_harmonize.R:119-137` and `R/curate_headless.R:216-228`
**Issue:** The `apply_corrections` logic is defined twice: once as a named inner function in `mod_harmonize.R` and once as an anonymous inner function `apply_corrections_headless` inside the `if (harmonize)` block in `curate_headless.R`. The two implementations differ only in their error handler (`warning()` vs `NULL`). Any future change to the gsub loop, pattern application order, or error handling must be made in both places. This is a divergence risk — the headless version silently swallows errors on individual patterns while the Shiny version emits a `warning()`, an inconsistency that will produce different audit trails.
**Fix:** Extract a shared internal function in a utilities file (e.g., `R/utils_corrections.R`) or in `R/date_parser.R`'s sibling helpers:
```r
# Proposed shared helper:
apply_corrections_vec <- function(values, corrections_tbl, warn = TRUE) {
  if (is.null(corrections_tbl) || nrow(corrections_tbl) == 0) return(values)
  result <- values
  for (i in seq_len(nrow(corrections_tbl))) {
    tryCatch(
      result <- gsub(corrections_tbl$pattern[i], corrections_tbl$replacement[i], result),
      error = function(e) {
        if (warn) warning(sprintf("Correction pattern '%s' failed: %s",
                                  corrections_tbl$pattern[i], e$message))
      }
    )
  }
  result
}
```
Then call `apply_corrections_vec(values, corrections_tbl, warn = TRUE)` in both sites.

---

## Info

### IN-01: Malformed roxygen block for `detect_tag_changes` — `has_required_chemical_tags` docstring is embedded inside it

**File:** `R/tag_helpers.R:174-199`
**Issue:** The `@examples` block for `detect_tag_changes` (lines 165-173) ends with `# Changed value - returns TRUE` at line 173, but immediately continues with free text "Check for Required Chemical Tags" at line 175 without a closing blank line or the `#' @` separator needed to start a new roxygen block. The docstring for `has_required_chemical_tags` is actually embedded inside `detect_tag_changes`'s roxygen block. The `@export` tag at line 199 then attaches to `has_required_chemical_tags`, and `detect_tag_changes` itself gets only `#' @export` at line 212 with no title, description, or parameter docs. `R CMD check` will emit a WARNING: "Objects exported but not documented."
**Fix:** Close the `detect_tag_changes` examples block properly and give it its own `@export` before the function definition. Move the `has_required_chemical_tags` docstring to its own unambiguous block immediately before that function:
```r
#' @examples
#' detect_tag_changes(list(col1 = "Name"), list(col1 = "CASRN"))
#'
#' @export
detect_tag_changes <- function(old_tags, new_tags) { ... }

#' Check for Required Chemical Tags
#' ...
#' @export
has_required_chemical_tags <- function(chemical_tags) { ... }
```

---

### IN-02: `detect_tag_changes` is exported but never called in production code

**File:** `R/tag_helpers.R:212`
**Issue:** `detect_tag_changes` is exported (`@export`) and has 6 dedicated test cases in `test-tag-dispatch.R`, but `grep` finds zero call sites in production code (`R/mod_tag_columns.R`, `R/mod_harmonize.R`, `R/curate_headless.R`). The stale-results pattern in `mod_harmonize.R` uses its own `prev_unit_map`/`prev_corrections` reactiveVal approach rather than calling this helper. Either the function is dead code, or it was intended for an observer that was not wired.
**Fix:** Either wire `detect_tag_changes` into the appropriate observer (if cascade-reset logic for tag changes is needed), or remove the export and mark the function as internal documentation (`@keywords internal`) to avoid a growing dead-export surface. Do not delete the tests.

---

### IN-03: `TWO_DIGIT_PAT` regex does not guard against NA input to `grepl()`

**File:** `R/date_parser.R:84`
**Issue:** `is_inferred <- !is_unparseable & grepl(TWO_DIGIT_PAT, raw_dates, perl = TRUE)`. When `raw_dates` contains `NA_character_`, `grepl()` returns `NA`, not `FALSE`. The short-circuit `!is_unparseable` evaluates to `FALSE` for NA rows (because `is.na(parsed_posix)` is TRUE), so `FALSE & NA` collapses to `FALSE` via R's three-valued logic — the guard works correctly in practice. However, the same NA-passthrough issue exists for the `trimws(raw_dates)` calls inside `is_partial` (lines 77-79). `trimws(NA_character_)` returns `NA_character_`, and `grepl("^[0-9]{4}$", NA_character_)` returns `NA`. Again the `!is_unparseable` guard saves the output, but this is implicit and fragile. Adding explicit `& !is.na(raw_dates)` guards to all three `is_partial` grepl calls would make the intent explicit and survive any future reordering of the flag logic.
**Fix:**
```r
is_partial <- !is_unparseable &
  !is.na(raw_dates) &
  (grepl("^[0-9]{4}$", trimws(raw_dates)) |
   grepl("^[0-9]{4}[-/][0-9]{1,2}$", trimws(raw_dates)) |
   grepl("^[A-Za-z]+ [0-9]{4}$", trimws(raw_dates)))
```

---

### IN-04: `curate_headless` hard-stops with `stop()` when `harmonize=TRUE` and no Result column — but a StudyDate-only harmonize run is a valid use case

**File:** `R/curate_headless.R:206-208`
**Issue:** `if (length(result_cols) == 0) stop(...)` prevents calling `curate_headless(..., harmonize = TRUE, tag_map = list(date_col = "StudyDate"))`. In `mod_harmonize.R` the StudyDate-only path is explicitly supported (lines 397-418 build an identity parse/harmonize tibble and proceed to date parsing). The headless interface lacks this same bypass, so a workflow that only needs date parsing output in the parquet/CSV must also include a Result column even though none is needed.
**Fix:** Mirror the Shiny module's StudyDate-only guard:
```r
has_numeric <- length(result_cols) > 0
has_study   <- length(names(tag_map)[tag_map == "StudyDate"]) > 0

if (!has_numeric && !has_study) {
  stop("curate_headless: harmonize=TRUE requires at least one Result or StudyDate column in tag_map.")
}

if (!has_numeric) {
  # StudyDate-only: build identity parse/harmonize tibbles (mirrors mod_harmonize.R lines 397-418)
  n_rows <- nrow(resolution_state)
  harmonize_tibble <- tibble::tibble(
    orig_row_id = seq_len(n_rows), ...
  )
  parse_tibble <- tibble::tibble(...)
  # Skip to date stage
} else {
  # existing numeric pipeline
}
```

---

_Reviewed: 2026-04-26_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
