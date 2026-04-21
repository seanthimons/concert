---
phase: 36-wire-toxval-shiny
reviewed: 2026-04-21T18:42:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - R/mod_harmonize.R
  - inst/app/app.R
findings:
  critical: 1
  warning: 3
  info: 2
  total: 6
status: issues_found
---

# Phase 36: Code Review Report

**Reviewed:** 2026-04-21T18:42:00Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed `R/mod_harmonize.R` (the harmonize module with new ToxVal schema mapping wired into Stage 5) and `inst/app/app.R` (the main Shiny app wiring). The primary concern is a **row count mismatch bug** in the ToxVal mapping call that will crash or corrupt data when input contains range values (which expand 1 row to 3 rows in `parse_numeric_results()`). The incremental harmonization path also silently skips ToxVal re-mapping, leaving `toxval_output` stale without any user-visible indication. The `onclick` XSS mitigation for unmatched unit names only escapes single quotes but not backslashes or other JS-significant characters.

## Critical Issues

### CR-01: Row count mismatch between curated_data and harmonized_data in map_to_toxval_schema call

**File:** `R/mod_harmonize.R:385-389`
**Issue:** `map_to_toxval_schema()` is called with `curated_data = data_store$resolution_state` and `harmonized_data = harmonize_tibble`. The function uses `n_rows <- nrow(curated_data)` (line 55 of toxval_mapper.R) and constructs all 56 columns using `rep(..., n_rows)`, then interleaves values from `harmonized_data$harmonized_value` and `harmonized_data$harmonized_unit` (lines 89-90 of toxval_mapper.R).

When input data contains range values (e.g., "5-10"), `parse_numeric_results()` expands each range to 3 rows (low/mid/high). This means `harmonize_tibble` will have MORE rows than `data_store$resolution_state`. The tibble constructor will fail with a recycling error because `rep(source_name, n_rows)` produces N values but `harmonized_data$harmonized_value` produces N+2k values (where k is the number of ranges).

This is the primary integration point for Phase 36 and will crash on any dataset containing range values.

**Fix:** Before calling `map_to_toxval_schema`, join `harmonized_data` back to `curated_data` via `orig_row_id` to produce a row-aligned pair. Alternatively, expand `curated_data` to match `harmonized_data` rows:
```r
# Option A: Expand curated_data rows to match harmonized rows via orig_row_id
expanded_curated <- data_store$resolution_state[harmonize_tibble$orig_row_id, ]
toxval_tibble <- tryCatch(
  map_to_toxval_schema(
    curated_data = expanded_curated,
    harmonized_data = harmonize_tibble,
    source_name = data_store$file_info$name
  ),
  ...
)
```

## Warnings

### WR-01: Incremental harmonization path skips ToxVal schema mapping

**File:** `R/mod_harmonize.R:238-311`
**Issue:** The incremental mode re-harmonizes affected rows and updates `data_store$harmonize_results` and `data_store$harmonize_audit`, but never re-runs `map_to_toxval_schema()` or updates `data_store$toxval_output`. After an incremental re-run, `toxval_output` retains values from the previous full run (or is NULL if no full run preceded). The stale-results banner (Plan 34-04) is cleared at line 208, so the user sees "Incremental: N rows re-harmonized" but `toxval_output` silently drifts out of sync.

**Fix:** Add a ToxVal mapping step at the end of the incremental path (after line 292), or mark `toxval_output` as stale / set it to NULL to force the user to re-run full mode. Example:
```r
# After incremental merge (line 292), add:
data_store$toxval_output <- tryCatch(
  map_to_toxval_schema(
    curated_data = data_store$resolution_state[new_harmonize$orig_row_id, ],
    harmonized_data = new_harmonize,
    source_name = data_store$file_info$name
  ),
  error = function(e) {
    showNotification(
      paste("ToxVal mapping failed:", conditionMessage(e)),
      type = "warning", duration = 8
    )
    NULL
  }
)
```

### WR-02: Incomplete XSS escaping in onclick handler for unmatched unit names

**File:** `R/mod_harmonize.R:1031-1034`
**Issue:** The `onclick` handler injects `u$orig_unit` into a JavaScript string literal, escaping only single quotes via `gsub("'", "\\\\'", u$orig_unit)`. Unit strings containing backslashes, newlines, or other JS-significant characters (e.g., `mg\L` or a string with `</script>`) could break out of the string literal. The code comment on line 983 acknowledges this as "T-34-06 JS injection" mitigation, but the escaping is incomplete.

While this is user-uploaded data (not third-party attacker-controlled), the defense-in-depth principle applies since uploaded data can contain arbitrary strings.

**Fix:** Use a more robust escaping approach. Escape backslashes first, then single quotes, then other JS-significant characters:
```r
safe_unit <- u$orig_unit
safe_unit <- gsub("\\\\", "\\\\\\\\", safe_unit)  # escape backslashes first
safe_unit <- gsub("'", "\\\\'", safe_unit)          # escape single quotes
safe_unit <- gsub("\n", "\\\\n", safe_unit)          # escape newlines
safe_unit <- gsub("\r", "\\\\r", safe_unit)          # escape carriage returns
safe_unit <- gsub("</", "<\\\\/", safe_unit)         # prevent script tag breakout
```
Or better: use `jsonlite::toJSON(u$orig_unit, auto_unbox = TRUE)` which handles all JS string escaping correctly, then strip the outer quotes and embed in the template.

### WR-03: Stale toxval_output not invalidated by unit_map_working cascade observer

**File:** `R/mod_harmonize.R:1135-1156`
**Issue:** When `unit_map_working` changes, the cascade observer sets `harmonize_results_stale = TRUE` and tracks `changed_units`, but does NOT invalidate `data_store$toxval_output`. The upstream `reset_numeric_downstream()` in `app.R:350-354` does null out `toxval_output` when numeric_tags change, but the within-module stale pattern (editing unit mappings or corrections) leaves `toxval_output` intact and silently outdated.

If the user edits unit mappings, sees the stale banner, then exports via the review tab, the export will include a `toxval_output` that does not reflect the current unit mappings.

**Fix:** Set `data_store$toxval_output <- NULL` alongside the stale flag in both cascade observers (lines 1143 and 1167):
```r
if (!is.null(data_store$harmonize_results)) {
  data_store$harmonize_results_stale <- TRUE
  data_store$toxval_output <- NULL  # Force re-generation on next run
  ...
}
```

## Info

### IN-01: Duplicate logic between has_numeric_tags reactive and enable/disable observer

**File:** `R/mod_harmonize.R:156-169`
**Issue:** The `has_numeric_tags` output (lines 156-159) and the enable/disable observer (lines 163-169) compute the identical condition: `!is.null(data_store$numeric_tags) && length(data_store$numeric_tags) > 0`. This is minor duplication. The observer could consume the output reactive rather than recomputing.

**Fix:** Extract the condition into a shared reactive:
```r
has_tags <- reactive({
  !is.null(data_store$numeric_tags) && length(data_store$numeric_tags) > 0
})
output$has_numeric_tags <- reactive({ has_tags() })
outputOptions(output, "has_numeric_tags", suspendWhenHidden = FALSE)

observe({
  if (has_tags()) shinyjs::enable("run_harmonization")
  else shinyjs::disable("run_harmonization")
})
```

### IN-02: Hidden input elements used for modal state instead of reactiveVal

**File:** `R/mod_harmonize.R:695-698`, `R/mod_harmonize.R:725-729`
**Issue:** The edit modals use hidden `<input>` elements (`modal_orig_from`, `modal_corr_orig_pattern`) to track whether the user is in "add" vs "edit" mode. This is a common Shiny pattern but fragile -- the hidden input persists across modal opens and its value is only set via the HTML `value` attribute at modal creation time, not reactively. If a modal is opened and dismissed without saving, the stale hidden input value could affect a subsequent add/edit flow. In practice this works because each `showModal` call recreates the inputs, but using `reactiveVal` would be more idiomatic and less fragile.

**Fix:** Consider replacing hidden inputs with a `reactiveVal` for edit context:
```r
edit_context <- reactiveVal(list(mode = "add", orig_key = NULL))
```

---

_Reviewed: 2026-04-21T18:42:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
