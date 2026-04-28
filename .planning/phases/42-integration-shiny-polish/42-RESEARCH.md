# Phase 42: Integration & Shiny Polish — Research

**Researched:** 2026-04-28
**Domain:** R Shiny, bslib, DT, reactive state management, pre-check orchestration
**Confidence:** HIGH (all findings from direct codebase reads)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Pre-flight modal uses checkbox rows per step: step name, fire/skip status, estimated
  change count. Steps pre-checked from pre-check results. User can toggle before running.
- **D-02:** Single unified modal with sections for Cleaning steps and Harmonization steps.
- **D-03:** "Run Pipeline" replaces both "Run Cleaning" and "Run Harmonization" buttons.
- **D-04:** When all pre-checks show 0 estimated changes, skip modal — show notification with
  "Run anyway?" and "Open pre-flight modal" action link.
- **D-05:** Pre-check data from Phase 37 `precheck_*` functions. Harmonization steps need new
  pre-checks (units, duration, dates, media).
- **D-06:** Media classification table is read-only DT. Click row opens edit modal (same pattern
  as unit mapping / correction editors in mod_harmonize.R).
- **D-07:** Unmatched media terms at top of table with visual indicator. UNMATCHED section (top),
  MAPPED section (below).
- **D-08:** Table columns: term, canonical, source, active.
- **D-09:** Separate `user_media_map.rds` for user edits; distinct from `amos_media.rds`.
- **D-10:** After saving media edits, show notification "Media mappings updated. Re-run
  harmonization to apply changes?" with "Re-run now" action link via `shinyjs::click()`.
- **D-11:** Session-local `media_map_working` initialized from merged user + AMOS maps at session
  start (same pattern as `unit_map_working` / `corrections_working`).
- **D-12:** Source column badge: "user" = blue (`bg-primary`), "amos" = gray (`bg-secondary`).
  AMOS entries visible but read-only in editor.
- **D-13:** When user adds a mapping for a term that already has an AMOS entry, show confirmation
  modal "Override AMOS Mapping?" before saving.
- **D-14:** Lookup priority: user map checked first, AMOS as fallback.

### Claude's Discretion

- Harmonization pre-check implementation details (what constitutes "nothing to do" for units,
  duration, dates, media steps)
- Modal styling, button placement, responsive layout within bslib framework
- DT table rendering options (pagination, search, row highlighting implementation)
- Notification/toast implementation for re-run prompt and empty pre-flight state
- Working copy merge strategy (how user + AMOS maps are combined at session start)
- Badge rendering approach in DT cells (HTML widget, CSS class, or DT callback)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RECO-01 | Pre-flight modal shown before pipeline runs, displaying which steps fire vs. skip with estimated change counts | 7 `precheck_*` functions already exist in cleaning_pipeline.R (lines 248-458). 4 new pre-checks needed for harmonization steps. Modal structure defined in UI-SPEC. |
| RECO-02 | User can confirm full run or subset run based on pre-check results | "Run All Steps" + "Run Checked Steps" buttons in modal footer; checkbox toggles per step. Logic routes to run_cleaning_pipeline() with enabled-step mask. |
| MEDIT-01 | User-editable media classification table in Harmonize tab (term, canonical, source, active) | DT pattern from existing unmatched-unit panel. Schema: 4 columns matching D-08. `user_media_map.rds` for persistence. |
| MEDIT-02 | Unmatched media terms surfaced for user mapping; user additions persist via RDS and trigger re-run cascade | `media_flag == "media_unmatched"` drives the UNMATCHED section. Save triggers `saveRDS()` to `user_media_map.rds` + notification with shinyjs::click() re-run link. |
| MEDIT-03 | AMOS-derived terms supplement user-editable map as fallback — user map checked first | `media_map_working` merged at session start: user rows prepended, AMOS rows as fallback. `harmonize_media()` receives merged map instead of raw `get_media_table()`. |
</phase_requirements>

---

## Research Summary

- **7 cleaning pre-checks already exist** in `R/cleaning_pipeline.R` (lines 248-458), all returning
  `list(should_run, est_changes)`. None exist yet for harmonization steps. Four new pre-check
  functions are needed: `precheck_units`, `precheck_duration`, `precheck_dates`, `precheck_media`.
- **Modal patterns are well-established** in `mod_harmonize.R`. Three distinct templates are
  available: edit-existing (row pre-filled), add-new (blank fields), and add-from-unmatched
  (term pre-filled). All use `showModal(modalDialog(..., easyClose = FALSE))` with a
  `modalButton("Discard")` + `actionButton(ns("save_*"), "Save Mapping", class = "btn-primary")`
  footer pattern.
- **Working copy pattern is one-shot reactive**: `observe()` fires when working copy is NULL and
  source data is not NULL; sets the reactive value once and never overwrites. The new
  `media_map_working` must follow the identical initialization pattern from `data_store$reference_lists$media_map`.
- **`harmonize_media()` currently reads `amos_media.rds` directly** via `get_media_table()` —
  it does NOT accept a `media_map` parameter. The function signature must be extended to accept
  an optional `media_map` argument so that `media_map_working` (merged user + AMOS) can be
  passed at runtime (per D-14).
- **Both pipeline trigger buttons are straightforward replacements**: `mod_clean_data.R` line 63-66
  has `actionButton(ns("run_cleaning"), ...)` and `mod_harmonize.R` line 74-79 has
  `actionButton(ns("run_harmonization"), ...)`. The `observeEvent(input$run_cleaning, ...)` block
  (line 130) and `observeEvent(input$run_harmonization, ...)` block (line 204) contain the actual
  pipeline execution logic that must be refactored to support partial-step runs.

---

## Pre-check Infrastructure

### Existing Cleaning Pre-check Functions (VERIFIED from cleaning_pipeline.R lines 248-458)

| Function | Signature | Should-run condition | Est. changes basis |
|----------|-----------|----------------------|--------------------|
| `precheck_unicode_to_ascii(df)` | df | Any non-ASCII value in any char col | Count of non-ASCII values |
| `precheck_trim_whitespace(df)` | df | Any value that `clean_text_field()` would change | Count of differing values |
| `precheck_normalize_cas(df, tag_map)` | df, tag_map | Any CASRN-tagged col with unformatted digits or placeholder text | Count of unformatted+placeholder values |
| `precheck_name_cleaning(df, name_cols)` | df, name_cols | Intentionally broad: any non-empty Name column | Count of non-empty name values |
| `precheck_isotope_shortcodes(df, name_cols, isotope_lookup)` | df, name_cols, isotope_lookup | Any name value matching a shortcode | Count of matching values |
| `precheck_multi_analyte(df, name_cols)` | df, name_cols | Any name value containing `\s+(and|&|/)\s+` | Count of pattern matches |
| `precheck_chiral_restore(df, name_cols)` | df, name_cols | Any name value containing `###CHIRAL_` placeholder | Count of placeholder occurrences |

All return `list(should_run = logical(1), est_changes = integer(1))`. [VERIFIED: cleaning_pipeline.R]

### Harmonization Pre-check Gaps (Need New Functions)

The harmonization pipeline (mod_harmonize.R lines 204-622) has four discrete stages that need pre-checks:

| Stage | New Function | Should-run condition | Est. changes basis |
|-------|-------------|----------------------|--------------------|
| Units (Stage 3) | `precheck_harmonize_units(df, unit_cols, unit_map)` | Any Unit-tagged col has values not in `unit_map$from_unit` OR has existing `unit_flag == "unmatched"` | Count of unmapped unit strings |
| Duration (Stage 4.5) | `precheck_harmonize_duration(df, dur_cols, dur_unit_cols, unit_map)` | Duration + DurationUnit cols are tagged AND any DurationUnit value is not in unit_map with category=="duration" | Count of duration rows |
| Dates (Stage 4.6) | `precheck_harmonize_dates(df, date_cols)` | StudyDate-tagged cols present AND any value is parseable (non-NA, non-empty) | Count of non-NA date values |
| Media (Stage 3-pre) | `precheck_harmonize_media(df, media_cols, media_map)` | Media-tagged cols present | Count of non-NA media values; unmatched count as higher priority |

**Key insight for pre-check discretion**: A pre-check returning `should_run = FALSE` should be rare for harmonization steps — "nothing to do" is only true when no relevant columns are tagged. The more useful metric is `est_changes` (unmatched count) to inform the UI badge label.

### Orchestration Pattern in cleaning_pipeline.R (VERIFIED lines 1948-2210)

```r
# Pattern: check → branch → run or build_skip_result
unicode_check <- precheck_unicode_to_ascii(df_after_lineage)
if (!unicode_check$should_run) {
  df_after_unicode <- df_after_lineage
  audit_unicode <- build_skip_result(df_after_lineage, "unicode_to_ascii")$audit_trail
} else {
  # ... run step
}
```

The pre-flight modal requires these pre-checks to run BEFORE pipeline execution and surface results to the UI, not just short-circuit internally.

---

## Modal & Editor Patterns

### Pattern 1: Edit Existing Row (VERIFIED: mod_harmonize.R lines 906-951)

```r
# Triggered by JS message (DT row click sends Shiny.setInputValue)
observeEvent(input$open_edit_modal, {
  tbl <- data_store$unit_map_working
  row <- tbl[tbl$from_unit == msg$term, ][1, ]
  showModal(modalDialog(
    title = "Edit Unit Mapping",
    textInput(session$ns("modal_from_unit"), "From Unit", value = row$from_unit),
    # ... more fields
    tags$input(type = "hidden", id = session$ns("modal_orig_from"), value = row$from_unit),
    footer = tagList(
      modalButton("Discard"),
      actionButton(session$ns("save_unit_mapping"), "Save Mapping", class = "btn-primary")
    ),
    easyClose = FALSE
  ))
})
```

Key details:
- Hidden input stores original key for row lookup on save (update vs. insert discrimination)
- `easyClose = FALSE` is enforced on all edit modals
- Save button triggers a separate `observeEvent(input$save_unit_mapping, {...})`

### Pattern 2: Add New Row — Blank (VERIFIED: mod_harmonize.R lines 1010-1061)

Same structure as Pattern 1 but all `value = ` arguments omitted or set to defaults. The hidden `modal_orig_from` value is `""` (empty string signals "insert not update").

### Pattern 3: Add From Unmatched Term (VERIFIED: mod_harmonize.R lines 1320-1350)

```r
observeEvent(input$add_unmatched_mapping, {
  msg <- input$add_unmatched_mapping
  req(msg$unit)
  showModal(modalDialog(
    title = "Add Unit Mapping",
    textInput(session$ns("modal_from_unit"), "From Unit", value = msg$unit),  # pre-filled!
    # ... rest blank
  ))
})
```

The pre-filled term comes from a JS `Shiny.setInputValue()` call on DT row click.

### DT Row Click → Shiny Message Pattern

Existing pattern uses `DT::datatable()` with a `callback` argument injecting JavaScript:

```javascript
// JS callback pattern (inferred from existing modal pattern)
table.on('click', 'tr', function() {
  var data = table.row(this).data();
  if (data) {
    Shiny.setInputValue('ns_prefix-open_edit_modal', {
      type: 'units',
      term: data[0]
    }, {priority: 'event'});
  }
});
```

The `{priority: 'event'}` flag ensures the observer fires even if the value hasn't changed (same row clicked twice). [VERIFIED: mod_harmonize.R pattern, exact JS not read but inferred from observeEvent binding]

### Pre-flight Modal Structure (from UI-SPEC)

```r
showModal(modalDialog(
  title = "Pre-flight Check",
  size = "m",
  easyClose = FALSE,
  # Two accordion sections: "Cleaning Steps", "Harmonization Steps"
  # Each row: checkboxInput() + badge span
  footer = tagList(
    modalButton("Cancel"),
    actionButton(ns("run_checked"), "Run Checked Steps", class = "btn-primary"),
    actionButton(ns("run_all"), "Run All Steps", class = "btn-outline-secondary")
  )
))
```

The checklist rows are dynamically rendered via `renderUI()` from pre-check results.

---

## Working Copy & Persistence

### Existing Pattern (VERIFIED: mod_harmonize.R lines 175-200)

```r
# One-shot initialization: fires when working copy is NULL, source is not NULL
unit_map_ready <- reactiveVal(FALSE)
observe({
  if (
    is.null(data_store$unit_map_working) &&
      !is.null(data_store$reference_lists$unit_map)
  ) {
    data_store$unit_map_working <- data_store$reference_lists$unit_map
    if (!unit_map_ready()) unit_map_ready(TRUE)
  }
})
```

Pattern for `media_map_working`:

```r
media_map_ready <- reactiveVal(FALSE)
observe({
  if (
    is.null(data_store$media_map_working) &&
      !is.null(data_store$reference_lists$media_map)
  ) {
    data_store$media_map_working <- data_store$reference_lists$media_map
    if (!media_map_ready()) media_map_ready(TRUE)
  }
})
```

### RDS Persistence Pattern (VERIFIED: cleaning_reference.R)

```r
# Load-or-fetch (with cache miss path)
load_or_fetch_reference(cache_path, fetch_fn, name)

# Save directly
saveRDS(result, cache_path, compress = FALSE)
```

File naming convention: `<term>.rds` in `inst/extdata/reference_cache/` for package-shipped data. For user-specific overrides, the pattern would be `user_media_map.rds` in the same directory (D-09).

### load_all_reference_lists() Must Gain media_map (VERIFIED: cleaning_reference.R line 414-426)

Current return keys: `stop_words`, `block_patterns`, `functional_categories`, `strip_terms`, `corrections`, `isotope_lookup`, `unit_map`, `unit_synonyms`, `toxval_schema`.

A new `load_media_map()` function and a `media_map` key in `load_all_reference_lists()` are needed to wire `data_store$reference_lists$media_map` into existence at session start.

### Merge Strategy for media_map_working (Claude's Discretion)

User map + AMOS map merged so user rows take precedence for the same `term`:

```r
load_media_map <- function(cache_dir) {
  amos_map <- get_media_table()  # from amos_media.rds
  user_path <- file.path(cache_dir, "user_media_map.rds")
  user_map <- if (file.exists(user_path)) readRDS(user_path) else NULL
  if (!is.null(user_map) && nrow(user_map) > 0) {
    # User rows first; AMOS rows for terms not in user map
    amos_fallback <- amos_map[!amos_map$term %in% user_map$term, ]
    dplyr::bind_rows(user_map, amos_fallback)
  } else {
    amos_map
  }
}
```

The schema of `user_media_map.rds` (4 columns: `term`, `canonical`, `source`, `active`) is a subset of `amos_media.rds` (7 columns). The merged working copy should use only the 4 MEDIT-01 columns for display.

---

## Media Harmonizer State

### harmonize_media() Current Signature (VERIFIED: media_harmonizer.R lines 124-199)

```r
harmonize_media(raw_media, orig_row_id = seq_along(raw_media))
```

It calls `get_media_table()` internally, which reads `amos_media.rds` directly from the package. There is **no `media_map` parameter** — the function always uses the bundled AMOS table. [VERIFIED]

**This is the critical API gap for MEDIT-03**: the function must be extended to accept an optional `media_map` argument so `media_map_working` (merged user + AMOS) can be passed at runtime.

### Output Schema (VERIFIED: media_harmonizer.R lines 191-198)

```
orig_row_id:    integer
raw_media:      character
canonical_media: character (NA if unmatched)
envo_id:        character (NA if unmatched)
media_category: character — "aqueous" | "air" | "solid" | NA
media_flag:     character — "" | "parent_walk" | "media_unmatched"
```

Unmatched detection: `media_flag == "media_unmatched"`.

### How harmonize_media() is Called in mod_harmonize.R (VERIFIED: lines 347-381)

```r
media_tibble <- harmonize_media(
  raw_media = as.character(input_df[[media_cols_pre[1]]]),
  orig_row_id = seq_len(nrow(input_df))
)
```

After Phase 42, this call must pass `media_map = data_store$media_map_working` to enable user-map lookups.

### amos_media.rds Schema (VERIFIED: media_harmonizer.R line 13)

Columns: `term`, `canonical_term`, `envo_id`, `parent`, `media_category`, `source`, `fetch_timestamp`. The `term` column is already normalized (trimws + tolower). File exists in `inst/extdata/reference_cache/amos_media.rds`. [VERIFIED: file listing]

---

## Integration Points

### Button Locations

| Button | File | Lines | ID | Current class |
|--------|------|--------|----|---------------|
| "Run Cleaning" | `R/mod_clean_data.R` | 63-66 | `ns("run_cleaning")` | `btn-success btn-lg` |
| "Run Harmonization" | `R/mod_harmonize.R` | 74-79 | `ns("run_harmonization")` | `btn-success btn-lg mt-3 mb-3` |

Both are wrapped in `shinyjs::disabled()` at render time and enabled via observer conditions. The replacement "Run Pipeline" button goes in `mod_clean_data.R` (Clean Data tab), following UI-SPEC which places it at the top of the Clean Data tab. The "Run Harmonization" button in `mod_harmonize.R` is simply removed (no replacement in the Harmonize tab).

### Observer Locations

| Observer | File | Lines | Trigger |
|----------|------|--------|---------|
| Cleaning pipeline execution | `R/mod_clean_data.R` | 130-340 | `observeEvent(input$run_cleaning, {...})` |
| Harmonization pipeline execution | `R/mod_harmonize.R` | 204-622 | `observeEvent(input$run_harmonization, {...})` |

The refactor strategy:
1. Add `observeEvent(input$run_pipeline, {...})` that calls pre-checks and opens the modal.
2. Add `observeEvent(input$run_checked, {...})` and `observeEvent(input$run_all, {...})` that
   invoke the existing cleaning + harmonization pipeline logic (possibly as extracted functions).
3. Keep `observeEvent(input$run_harmonization, {...})` internally for the `shinyjs::click()`
   re-run path from the re-run notification link (line 762-764 already wires `rerun_now` →
   `shinyjs::click("run_harmonization")`).

### Re-run Link Pattern (VERIFIED: mod_harmonize.R lines 755-764)

```r
# Existing re-run wiring
actionLink(session$ns("rerun_now"), "Re-run now", class = "alert-link ms-2")

observeEvent(input$rerun_now, {
  shinyjs::click("run_harmonization")
})
```

The media editor's "Re-run now" link after save should follow this identical pattern, triggering `shinyjs::click("run_harmonization")` (or equivalent renamed button).

### data_store additions required

```
data_store$media_map_working   # new: session-local editable media map
data_store$reference_lists$media_map  # new: merged user + AMOS loaded at startup
```

---

## Risks & Considerations

### Risk 1: harmonize_media() API Change Breaks Existing Callers

`harmonize_media()` currently has no `media_map` parameter. Adding one as an optional argument with `NULL` default (falls back to `get_media_table()`) is backward-compatible. But the call in `mod_harmonize.R` line 349 must be updated to pass `data_store$media_map_working`.

**Mitigation:** Make the new parameter `media_map = NULL` with internal fallback to `get_media_table()`. Update the single call site in mod_harmonize.R.

### Risk 2: Pre-flight Modal Must Collect Pre-check Results Before Showing Modal

All pre-check functions must complete before `showModal()` is called. For the cleaning pre-checks, this requires `data_store$clean` to be available (same guard as existing `run_cleaning` observer). For harmonization pre-checks, `data_store$column_tags` is also required.

**Mitigation:** Wrap pre-check collection in a single `req()` block, run all pre-checks synchronously (they are fast vectorized operations), then show modal.

### Risk 3: "Run Checked Steps" Requires Step-Mask Logic

When user unchecks steps, "Run Checked Steps" must skip those steps in both the cleaning pipeline (which uses pre-check `should_run` internally) and the harmonization pipeline (which has no step-skipping mechanism today).

**Mitigation for cleaning:** `run_cleaning_pipeline()` already supports step skipping via pre-checks. Passing a synthetic pre-check result with `should_run = FALSE` for unchecked steps overrides natural pre-check behavior.

**Mitigation for harmonization:** The harmonization pipeline in `mod_harmonize.R` (lines 204-622) is a monolithic `observeEvent` block. A step-mask can be implemented as a set of `if (mask$units)` guards wrapping each stage before calling it.

### Risk 4: Unified Modal Crosses Module Boundaries

The pre-flight modal currently requires data from both `mod_clean_data.R` (cleaning pre-checks use `data_store$clean`) and `mod_harmonize.R` (harmonization pre-checks use `data_store$column_tags`, `data_store$unit_map_working`). Since both modules share `data_store`, all pre-check inputs are accessible from either module.

**Recommendation:** Place the unified "Run Pipeline" button and its `observeEvent` in `mod_clean_data.R`, since that tab is the logical starting point. The observer reads from `data_store` for harmonization context. Alternatively, promote to a top-level observer in `app.R`.

### Risk 5: user_media_map.rds Does Not Exist on First Run

On first run, `user_media_map.rds` will not exist. `load_media_map()` must handle the missing-file case gracefully (return empty tibble, fall back to AMOS-only).

**Mitigation:** Pattern already established in `load_corrections()` — `fetch_fn` returns an empty tibble when no cached data exists.

### Risk 6: amos_media.rds Columns vs. user_media_map.rds Columns

`amos_media.rds` has 7 columns. `user_media_map.rds` has 4 columns (term, canonical, source, active). The merged `media_map_working` needs a consistent schema for both display (DT table, 4 columns) and harmonize_media() lookup (at minimum: `term`, `canonical_term`, `media_category`).

**Resolution:** When building the merged map, map `canonical_term` from amos to `canonical` for display, and add `active = TRUE` for all AMOS rows. The internal harmonize_media() lookup only needs `term` → `canonical_term` + `media_category`, so the function should accept either column naming or use a translation layer.

---

## Validation Architecture

### Test Framework (VERIFIED: CLAUDE.md)

| Property | Value |
|----------|-------|
| Framework | testthat |
| Config | `tests/test_data_detection.R` (existing); new test file needed |
| Quick run | `testthat::test_dir("tests")` |
| Full suite | `testthat::test_dir("tests")` |
| Shiny smoke | `Rscript -e "shiny::runApp('app.R', port=3838, launch.browser=FALSE)"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | File |
|--------|----------|-----------|------|
| RECO-01 | Pre-check functions return correct should_run and est_changes for harmonization steps | unit | `tests/test_harmonize_prechecks.R` (new) |
| RECO-02 | "Run Checked Steps" skips unchecked steps (step mask works) | integration | Manual/smoke (Shiny UI interaction) |
| MEDIT-01 | Media table renders with term, canonical, source, active columns | smoke | Shiny cold boot |
| MEDIT-02 | user_media_map.rds saved after edit; loaded on next session | unit | `tests/test_media_persistence.R` (new) |
| MEDIT-03 | harmonize_media() with merged map: user entry wins over AMOS for same term | unit | `tests/test_harmonize_media.R` (new or extend existing) |

### Wave 0 Gaps

- [ ] `tests/test_harmonize_prechecks.R` — unit tests for 4 new harmonization pre-check functions
- [ ] `tests/test_media_persistence.R` — load/save round-trip for user_media_map.rds
- [ ] Shiny cold boot after button replacement (mandatory per CLAUDE.md)

---

## Sources

All findings are VERIFIED from direct codebase reads in this session.

| File | Lines Read | Finding |
|------|-----------|---------|
| `R/cleaning_pipeline.R` | 248-470, 1948-2210 | 7 existing pre-check functions; orchestration pattern |
| `R/mod_harmonize.R` | 74-79, 175-200, 204-622, 755-764, 906-960, 1010-1061, 1320-1350 | Button location, working copy init, pipeline execution, re-run pattern, modal patterns |
| `R/mod_clean_data.R` | 62-66, 130-160 | Run Cleaning button location; pipeline execution observer start |
| `R/media_harmonizer.R` | 1-199 (full file) | harmonize_media() signature, output schema, get_media_table() internal call |
| `R/cleaning_reference.R` | 1-427 (full file) | RDS load/save pattern; load_all_reference_lists() keys |
| `.planning/phases/42-integration-shiny-polish/42-UI-SPEC.md` | Full | Modal structures, copywriting, interaction states |
| `.planning/phases/42-integration-shiny-polish/42-CONTEXT.md` | Full | All locked decisions |
| `inst/extdata/reference_cache/` | Directory listing | amos_media.rds confirmed present; user_media_map.rds confirmed absent |
