---
phase: 39-duration-conversion
reviewed: 2026-04-26T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - R/unit_harmonizer.R
  - R/mod_harmonize.R
  - R/curate_headless.R
  - tests/testthat/test-unit-harmonizer.R
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 39: Code Review Report

**Reviewed:** 2026-04-26
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the duration-conversion pipeline: `unit_harmonizer.R` (engine), `mod_harmonize.R` (Shiny module), `curate_headless.R` (headless runner), and the accompanying test file. The core harmonization engine is well-structured, vectorized correctly, and the test coverage is thorough across all major paths.

Two structural bugs exist in the modal edit flows in `mod_harmonize.R`: the hidden-input pattern used to carry the "original from_unit / original pattern" across a modal dialog is not read by Shiny's input system, causing the edit-mode branch to silently fall through to add-mode and produce duplicate rows. This affects both the unit mapping editor and the corrections editor.

A third warning covers incomplete incremental-mode tracking — edited or removed unit mappings are not tracked in `changed_units`, so they can fail to trigger re-harmonization of the right rows after an edit-not-add workflow. This is safe-fallback behavior (it falls through to full mode), but the comment in the code claims it handles "changed" units when it only captures new ones.

Three informational items cover: a dead `isTRUE()` call in `apply_synonyms`, silent error swallowing in `curate_headless`, and a missing test for the `ambiguous_unit` flag interacting with the dedup path.

---

## Warnings

### WR-01: `tags$input(type="hidden")` is not read by Shiny — edit mode always behaves as add mode

**File:** `R/mod_harmonize.R:742-746`, `773-776`
**Issue:** Both modal dialogs that support editing an existing row pass the "original key" value via a raw HTML `tags$input(type="hidden", id=..., value=...)`. Shiny's JavaScript input binding does not register `type="hidden"` elements as reactive inputs. There is no `Shiny.setInputValue()` call and no custom input binding for hidden inputs in this project. As a result, `input$modal_orig_from` (line 895) and `input$modal_corr_orig_pattern` (line 1012) will always be `NULL` inside their respective `observeEvent` handlers. The `if (!is.null(orig_from) && orig_from != "")` guard at line 897 evaluates to `FALSE`, so the edit path is never entered. The handler always appends a new row, silently producing a duplicate entry for the unit being edited.

**Fix:** Replace the hidden `tags$input` with a `shinyjs::hidden(textInput(...))` or use `session$userData` / a `reactiveVal` to store the original key before opening the modal, then read it from there in the save handler. The simplest approach:

```r
# Instead of tags$input(type="hidden", ...)
# Store the original key in a reactiveVal when opening the modal
editing_from_unit <- reactiveVal(NULL)

# In the chip_click observer, before showModal():
editing_from_unit(row$from_unit)

# In save_unit_mapping observer:
orig_from <- editing_from_unit()
editing_from_unit(NULL)  # reset
if (!is.null(orig_from) && orig_from != "") {
  idx <- which(tbl$from_unit == orig_from)
  ...
}
```

The same fix applies to `editing_corr_pattern <- reactiveVal(NULL)` for the corrections modal.

---

### WR-02: `changed_units` tracks only newly added `from_unit` values, not edits or removes

**File:** `R/mod_harmonize.R:1195-1199`
**Issue:** The stale-tracking observer computes `added <- setdiff(new_units, old_units)` — this captures only `from_unit` values that are brand-new additions. If a user edits a multiplier on an existing mapping (unit string unchanged, multiplier changed), `changed_units` stays empty. Because `can_incremental` requires `length(pending_changes) > 0`, the incremental path is not entered and a full re-run is performed — which is correct behavior. However, the comment at line 1195 claims the code tracks "added/changed" units, and a future change to the incremental predicate could silently break that assumption. Additionally, if WR-01 is fixed and edit mode actually works, the edited `from_unit` would be removed and re-added with the same string, so `setdiff` would still return empty (the unit didn't change identity, only its multiplier did), meaning rows with that unit would never enter incremental re-harmonization after a multiplier edit.

**Fix:** Track changes by comparing the full mapping (from_unit + multiplier + to_unit) rather than just the set of `from_unit` keys:

```r
old_map <- prev_unit_map()
new_map <- data_store$unit_map_working

# Units that are new OR whose mapping definition changed
changed <- dplyr::anti_join(
  new_map[, c("from_unit", "to_unit", "multiplier")],
  old_map[, c("from_unit", "to_unit", "multiplier")],
  by = c("from_unit", "to_unit", "multiplier")
)$from_unit

# Units that were removed also need re-harmonization
removed <- setdiff(old_map$from_unit, new_map$from_unit)

data_store$changed_units <- unique(c(
  data_store$changed_units,
  changed,
  removed
))
```

---

### WR-03: `apply_corrections_headless` silently discards correction errors

**File:** `R/curate_headless.R:221-228`
**Issue:** The local `apply_corrections_headless` function swallows regex errors with `error = function(e) NULL` — no message, no warning. If a user-provided correction pattern contains an invalid regex, the failure is invisible and the corrected values pass through uncorrected. The module version in `mod_harmonize.R` (line 127-133) issues a `warning()` with the pattern name and error message, which is more appropriate.

**Fix:** Emit a `warning()` or `message()` in the error handler to surface regex failures to the caller:

```r
tryCatch(
  result <- gsub(
    corrections_tbl$pattern[i],
    corrections_tbl$replacement[i],
    result
  ),
  error = function(e) {
    warning(sprintf(
      "curate_headless: correction pattern '%s' failed: %s",
      corrections_tbl$pattern[i],
      e$message
    ))
  }
)
```

---

## Info

### IN-01: `isTRUE()` applied to a vector in `apply_synonyms` is dead code

**File:** `R/unit_harmonizer.R:66`
**Issue:** `isTRUE(synonyms$is_regex)` is called on a vector. `isTRUE()` is documented to return `TRUE` only for a scalar `TRUE` — it always returns `FALSE` on any vector, including `c(TRUE)`. The full expression is:

```r
isTRUE(synonyms$is_regex) | synonyms$is_regex %in% c(TRUE, "TRUE", "true", 1)
```

The `isTRUE(...)` term contributes `FALSE` to every OR, so it is never operative. The `%in%` clause correctly handles all intended cases (logical `TRUE`, string `"TRUE"`, integer `1`). This is not a runtime bug but it is misleading.

**Fix:** Remove the `isTRUE(...)` term:

```r
is_regex <- if ("is_regex" %in% names(synonyms)) {
  synonyms$is_regex %in% c(TRUE, "TRUE", "true", 1)
} else {
  rep(FALSE, nrow(synonyms))
}
```

---

### IN-02: Duplicate `apply_corrections` implementation between module and headless runner

**File:** `R/curate_headless.R:216-228`, `R/mod_harmonize.R:119-136`
**Issue:** `apply_corrections_headless` in `curate_headless.R` is a local copy of `apply_corrections` from `mod_harmonize.R` with an identical loop body. They will diverge over time (WR-03 illustrates one divergence already). Neither is exported.

**Fix:** Extract `apply_corrections` as a package-internal (unexported) helper in a shared R file, and call it from both `mod_harmonize.R` and `curate_headless.R`. Mark it `@keywords internal`.

---

### IN-03: No test for `ambiguous_unit` flag interaction with dedup path

**File:** `tests/testthat/test-unit-harmonizer.R`
**Issue:** Tests for `ambiguous_unit` (Section 19, lines 1085-1098) run with small inputs that will not trigger the dedup path (`use_dedup_path` requires `n_unique < n/2`). Because the `ambiguous_unit` flag is applied after the dedup/non-dedup branching (lines 619-626 of `unit_harmonizer.R`), it correctly applies in both paths. However, no test verifies the flag is set correctly when dedup fires. If the post-dedup flag application is ever moved inside the branch, a test would catch the regression.

**Fix:** Add a test with high-duplication input to confirm `ambiguous_unit` is set in the dedup code path:

```r
test_that("ambiguous_unit flag applied in dedup path", {
  unit_map <- make_duration_unit_map()
  # 100 rows with 5 unique units including "m" -> dedup fires (5 < 50)
  values <- rep(c(60, 1, 2, 7, 365), 20)
  units <- rep(c("m", "hr", "day", "wk", "yr"), 20)
  result <- harmonize_units(values, units, unit_map,
                            category = "duration", use_dedup = TRUE)
  m_rows <- which(units == "m")
  expect_true(all(result$unit_flag[m_rows] == "ambiguous_unit"))
})
```

---

_Reviewed: 2026-04-26_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
