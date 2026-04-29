---
phase: 42-integration-shiny-polish
plan: "03"
subsystem: ui
tags:
  - shiny
  - pre-flight-modal
  - pipeline
  - button
dependency_graph:
  requires:
    - phase: 42-01
      provides: precheck_harmonize_units, precheck_harmonize_duration, precheck_harmonize_dates, precheck_harmonize_media
    - phase: 42-02
      provides: media_map_working, harmonize_media(media_map=) parameter
  provides:
    - run_pipeline button replacing both run_cleaning and run_harmonization
    - pre-flight modal with Cleaning Steps + Harmonization Steps accordion
    - step-mask pipeline execution via data_store$harmonize_step_mask
    - zero-change notification with open-modal action link
  affects:
    - R/mod_clean_data.R (button + modal + execution)
    - R/mod_harmonize.R (button removed from UI, h_mask reader added)
tech_stack:
  added: []
  patterns:
    - preflight_checks reactiveVal shared between run_pipeline observer and open_preflight_anyway observer
    - execute_pipeline() local function called by both run_all and run_checked observers
    - harmonize_step_mask passed via data_store from mod_clean_data to mod_harmonize
    - h_mask guards wrapping media/units/duration/dates stages in run_harmonization observer
key_files:
  created: []
  modified:
    - R/mod_clean_data.R
    - R/mod_harmonize.R
decisions:
  - "execute_pipeline() is a plain local function (not an observer) that closes over session/data_store — keeps pipeline logic shared between run_all and run_checked without duplicating reactive machinery"
  - "harmonize_step_mask passed through data_store rather than function arguments — avoids cross-module function call complexity while remaining consistent with existing working-copy pattern"
  - "h_mask defaults all-TRUE when NULL — preserves backward compatibility for rerun_now and media_rerun_now paths that trigger run_harmonization without setting a mask"
  - "Zero-change notification uses duration=0 (persistent) per UI-SPEC D-04 so user can see and act on it"
metrics:
  duration_minutes: 20
  completed_date: "2026-04-28"
  tasks_completed: 1
  tasks_total: 2
  files_modified: 2
---

# Phase 42 Plan 03: Run Pipeline Button and Pre-flight Modal Summary

**Single Run Pipeline button replaces both Run Cleaning and Run Harmonization buttons, with a pre-flight modal showing all 11 steps fire/skip across two accordion sections (Cleaning Steps, Harmonization Steps)**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-04-28
- **Tasks:** 1 of 2 (Task 2 is checkpoint:human-verify)
- **Files modified:** 2

## Accomplishments

### Task 1: Replace buttons and build pre-flight modal with step-mask execution

**mod_clean_data.R:**

- Replaced `actionButton(ns("run_cleaning"), "Run Cleaning", ...)` with `shinyjs::disabled(actionButton(ns("run_pipeline"), "Run Pipeline", class = "btn-success btn-lg mt-3 mb-3", icon = icon("play")))`
- Added `observe()` that enables/disables `run_pipeline` based on `has_required_chemical_tags()`
- Added `preflight_checks <- reactiveVal(NULL)` shared between two observers
- Added `observeEvent(input$run_pipeline)` that:
  - Extracts tag_map, name_cols, unit_cols from column_tags
  - Extracts study_type tags (date_cols, dur_cols, dur_unit_cols, media_cols) with NULL-safe extraction
  - Runs all 11 pre-check functions synchronously building a named `checks` list
  - Stores checks in `preflight_checks` reactiveVal
  - On zero total_changes: shows persistent notification with `actionLink(open_preflight_anyway)`
  - Otherwise: shows pre-flight `modalDialog` with `uiOutput(preflight_checklist)` and Cancel/Run All/Run Checked footer
- Added `observeEvent(input$open_preflight_anyway)` that forces modal open using stored checks
- Added `output$preflight_checklist <- renderUI()` with `make_row()` helper building checkbox+label+badge rows, grouped into two `bslib::accordion_panel` sections: "Cleaning Steps" (7 steps) and "Harmonization Steps" (4 steps)
- Added `build_mask_from_inputs()` helper reading all 11 `input$step_*` checkboxes
- Added `execute_pipeline(mask)` local function containing the full cleaning pipeline with per-step mask guards, then storing `harmonize_step_mask` and calling `shinyjs::click("run_harmonization")` if any harmonization steps are checked
- Added `observeEvent(input$run_all)` building all-TRUE mask, calling `execute_pipeline()`
- Added `observeEvent(input$run_checked)` building mask from checkbox inputs, calling `execute_pipeline()`

**mod_harmonize.R:**

- Removed `shinyjs::disabled(actionButton(ns("run_harmonization"), ...))` block from `mod_harmonize_ui`
- Removed button enable/disable `observe()` block (button no longer in UI)
- Added `h_mask <- data_store$harmonize_step_mask` reader at top of `observeEvent(input$run_harmonization)` with NULL default (all TRUE) preserving backward compatibility for `rerun_now` and `media_rerun_now` paths
- Wrapped media pre-stage with `h_mask$media &&` guard
- Wrapped units Stage 3 with `h_mask$units &&` guard
- Wrapped duration Stage 4.5 with `h_mask$duration &&` guard
- Wrapped dates Stage 4.6 with `h_mask$dates &&` guard

**Verification:** `air format` ran cleanly. `jarl check` shows only pre-existing warnings (sprintf on CSS block, redundant_equals on multi_cas, implicit_assignment in apply_corrections). Shiny cold boot: `Listening on http://127.0.0.1:3840`, HTTP 200.

## Task Commits

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Replace buttons and build pre-flight modal | 16a36e9 | R/mod_clean_data.R, R/mod_harmonize.R |

## Checkpoint Pending

**Task 2** is `type="checkpoint:human-verify"` — awaiting human end-to-end verification of the full Phase 42 feature set.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. All code paths are fully wired. The pre-flight modal renders dynamically from real pre-check results.

## Threat Flags

No new threat surface beyond the plan's threat model (T-42-09 through T-42-11 accepted):
- T-42-09: harmonize_step_mask booleans from checkboxInput — worst case user skips a step they chose to skip (intended behavior)
- T-42-10: 11 pre-checks run synchronously — same cost as existing 7 cleaning pre-checks
- T-42-11: shinyjs::click cross-module trigger — standard Shiny pattern, session-scoped

## Self-Check

**Created files exist:**
- `R/mod_clean_data.R` — run_pipeline button present: FOUND (line 75)
- `R/mod_clean_data.R` — preflight_checks reactiveVal present: FOUND (line 147)
- `R/mod_clean_data.R` — output$preflight_checklist renderUI present: FOUND (line 235)
- `R/mod_clean_data.R` — observeEvent(input$run_checked) present: FOUND (line 585)
- `R/mod_clean_data.R` — observeEvent(input$run_all) present: FOUND (line 567)
- `R/mod_harmonize.R` — NO run_harmonization actionButton in UI: CONFIRMED
- `R/mod_harmonize.R` — observeEvent(input$run_harmonization) still in server: FOUND (line 194)
- `R/mod_harmonize.R` — h_mask reader present: FOUND (line 197)

**Commits exist:**
- 16a36e9: FOUND (feat(42-03): replace Run Cleaning/Harmonization with unified Run Pipeline button)

## Self-Check: PASSED
