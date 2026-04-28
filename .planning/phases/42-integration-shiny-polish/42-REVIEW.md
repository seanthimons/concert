---
phase: 42-integration-shiny-polish
reviewed: 2026-04-28T18:45:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - R/cleaning_pipeline.R
  - R/cleaning_reference.R
  - R/media_harmonizer.R
  - R/mod_clean_data.R
  - R/mod_harmonize.R
  - tests/testthat/test-harmonize-prechecks.R
  - tests/testthat/test-media-persistence.R
findings:
  critical: 2
  warning: 2
  info: 2
  total: 6
status: issues_found
---

# Phase 42: Code Review Report

**Reviewed:** 2026-04-28T18:45:00Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Reviewed 7 files comprising the Phase 42 integration work: harmonization pre-check functions added to `cleaning_pipeline.R`, media harmonization persistence in `cleaning_reference.R` and `media_harmonizer.R`, pre-flight modal wiring in `mod_clean_data.R`, media editor and harmonization pipeline dispatch in `mod_harmonize.R`, and two new test files.

The harmonization pre-check functions are well-designed with consistent contracts. The media harmonizer has solid defensive coding (empty-input guards, schema translation, parent-walk fallback). Test coverage for the new pre-checks and media persistence is thorough.

Two critical issues were found: (1) tag extraction in the pre-flight checks uses the wrong data stores, causing unit/duration pre-checks to always report zero changes; (2) bare `ns()` calls in a server-side `renderUI` will crash at runtime. Two warnings flag a missed NA-transition detection path in the audit trail builder and a silent fallback in `harmonize_media` that may mask configuration errors.

## Critical Issues

### CR-01: Pre-flight checks extract Unit/Duration tags from wrong data stores

**File:** `R/mod_clean_data.R:157,163-164`
**Issue:** The pre-flight check section extracts `unit_cols` from `data_store$column_tags` (line 157) and `dur_cols`/`dur_unit_cols` from `data_store$study_type_tags` (lines 163-164). However, per `classify_tags()` in `R/tag_helpers.R` (line 39), "Unit", "Duration", and "DurationUnit" are classified as `numeric_types` and stored in `data_store$numeric_tags` -- not in `column_tags` (which holds chemical tags: Name, CASRN, Other) or `study_type_tags` (which holds StudyDate, Media). As a result, `precheck_harmonize_units()` and `precheck_harmonize_duration()` always receive empty column vectors, always returning `should_run = FALSE` and `est_changes = 0L`. The pre-flight modal will never show estimated changes for unit or duration harmonization, and both steps will always appear with a "skip" badge.

Note: The actual pipeline execution in `mod_harmonize.R` (lines 476-477) correctly extracts Duration/DurationUnit from `numeric_tags`, so the harmonization itself works. Only the pre-flight estimates are wrong.

**Fix:**
```r
# Line 155-157: Also extract from numeric_tags for Unit, Duration, DurationUnit
tag_map <- data_store$column_tags
name_cols <- names(tag_map)[tag_map == "Name"]

# Unit, Duration, DurationUnit are in numeric_tags, not column_tags
if (!is.null(data_store$numeric_tags)) {
  ntv <- unlist(data_store$numeric_tags)
  unit_cols <- names(ntv)[ntv == "Unit"]
  dur_cols <- names(ntv)[ntv == "Duration"]
  dur_unit_cols <- names(ntv)[ntv == "DurationUnit"]
} else {
  unit_cols <- character(0)
  dur_cols <- character(0)
  dur_unit_cols <- character(0)
}

# Lines 160-165: study_type_tags only holds StudyDate and Media
if (!is.null(data_store$study_type_tags)) {
  stv <- unlist(data_store$study_type_tags)
  date_cols <- names(stv)[stv == "StudyDate"]
  media_cols <- names(stv)[stv == "Media"]
} else {
  date_cols <- character(0)
  media_cols <- character(0)
}
```

### CR-02: Bare `ns()` in server-side renderUI will error at runtime

**File:** `R/mod_clean_data.R:1206,1208,1283`
**Issue:** Inside `output$multi_cas_section` (a `renderUI` in the module server), three calls use bare `ns()` instead of `session$ns()`. The `ns` variable is only defined in the UI function scope (line 11: `ns <- NS(id)`) and inside the `render_chip_editor` helper (line 846: `ns <- session$ns`). Neither is in scope for the `multi_cas_section` renderUI block. When a user views the multi-CAS section, R will fail with `Error: could not find function "ns"`, crashing the UI output.

**Fix:**
```r
# Line 1206: Change ns() to session$ns()
reactable::reactableOutput(session$ns("multi_cas_table")),

# Line 1208: Change ns() to session$ns()
session$ns("split_row"),

# Line 1283: Change ns() to session$ns()
actionButton(session$ns("confirm_split"), "Confirm Split", class = "btn-warning")
```

## Warnings

### WR-01: build_audit_trail silently skips NA-to-value and value-to-NA transitions

**File:** `R/cleaning_pipeline.R:67`
**Issue:** The generic `build_audit_trail()` function uses `which(original_vals != cleaned_vals)` to detect changes. In R, `NA != "something"` evaluates to `NA` (not `TRUE`), and `which(NA)` skips the index. This means transitions from NA to a non-NA value (or vice versa) are never recorded in the audit trail when using this generic function. While `normalize_cas_fields()` handles this separately with `mapply(identical, ...)`, any step that relies on the generic `build_audit_trail()` -- such as unicode-to-ASCII (line 340) and trim-whitespace (line 352) -- will silently miss NA-related transitions. This could cause audit trail gaps for rows where cleaning introduces or removes values.

**Fix:**
```r
# Replace line 67 with NA-aware comparison:
differs <- !mapply(identical, original_vals, cleaned_vals, USE.NAMES = FALSE)
changed_idx <- which(differs)
```

### WR-02: harmonize_media silently falls back to AMOS when media_map lacks required columns

**File:** `R/media_harmonizer.R:147-169`
**Issue:** When `harmonize_media()` receives a `media_map` that has rows but is missing the `term` column (line 147), or has `term` but lacks both `canonical_term` and `canonical` (lines 149-168), the function silently falls back to `get_media_table()`. This is a graceful degradation, but it makes misconfiguration hard to diagnose -- the caller may believe their custom map is being used when it is not. A warning would help surface map schema issues during development.

**Fix:**
```r
# After line 147:
if (!"term" %in% names(media_map)) {
  warning("media_map missing required 'term' column; falling back to bundled AMOS table")
  get_media_table()
}
# After line 167 (the else branch):
else {
  warning("media_map missing both 'canonical_term' and 'canonical' columns; falling back to AMOS table")
  get_media_table()
}
```

## Info

### IN-01: Duplicated CSS and JS chip editor blocks across modules

**File:** `R/mod_clean_data.R:16-24`, `R/mod_harmonize.R:31-39`
**Issue:** The chip editor CSS block (`.ref-chip`, `.ref-chip-remove`, etc.) is duplicated verbatim between `mod_clean_data_ui` and `mod_harmonize_ui`. The comment at `mod_harmonize.R:31` even acknowledges this: "verbatim from mod_clean_data.R lines 15-22". If either copy diverges, the styling becomes inconsistent. Consider extracting to a shared utility function or a single CSS file included once.

**Fix:** Extract the shared CSS into a helper function (e.g., `chip_editor_css()`) in a shared module, or move it to `www/chip-editor.css` and include via `tags$link()` in the app's UI.

### IN-02: `media_pending_save` reactiveVal not cleared on modal cancel

**File:** `R/mod_harmonize.R:1447`
**Issue:** When the AMOS override confirmation dialog is shown (line 1472), a pending save is staged in `media_pending_save(new_row)` (line 1471). If the user clicks "Cancel" (via `modalButton("Cancel")`), `media_pending_save` retains the stale value. This is harmless because `confirm_amos_override` requires `req(pending)` and uses `media_pending_save(NULL)` on confirm, but a stale value could cause confusion if debugging reactive dependencies. Consider adding a cancel observer that clears the pending state, or using `isolate()` defensively.

**Fix:** No functional change needed; this is a minor hygiene item. Optionally add:
```r
# Clear pending on modal dismiss (if desired for cleanliness)
observeEvent(input$cancel_amos_override, { media_pending_save(NULL) }, ignoreInit = TRUE)
```

---

_Reviewed: 2026-04-28T18:45:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
