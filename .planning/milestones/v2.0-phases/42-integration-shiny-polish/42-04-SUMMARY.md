---
phase: 42-integration-shiny-polish
plan: "04"
subsystem: mod_harmonize
tags: [bug-fix, ux, media-editor, dt-table, shinyjs]
dependency_graph:
  requires: []
  provides: [media-editor-row-click, add-media-mapping-button, rerun-links, media-guidance-text, pipeline-wording]
  affects: [R/mod_harmonize.R]
tech_stack:
  added: []
  patterns: [DT selection=none for custom JS callbacks, hidden actionButton DOM target for shinyjs::click, ignoreInit=TRUE for dynamic UI observers]
key_files:
  created: []
  modified:
    - R/mod_harmonize.R
decisions:
  - "DT selection=none chosen over JS workaround — simplest fix, no side effects on existing callback"
  - "Hidden actionButton placed in mod_harmonize_ui() tagList before conditionalPanel so it is always in DOM regardless of tab state"
  - "ignoreInit=TRUE on add_media_mapping observer prevents false-fire on module initialization"
metrics:
  duration: "~12 minutes"
  completed: "2026-04-28"
  tasks_completed: 1
  files_modified: 1
---

# Phase 42 Plan 04: Media Editor Bug Fixes and UX Polish Summary

Five UAT gaps in the Harmonize tab media editor closed in a single pass through `R/mod_harmonize.R`: DT row click now opens the edit modal, Add Media Mapping button fires its observer, rerun action links work via a hidden DOM button, unmatched terms show guidance text, and all stale "run harmonization" strings updated to reference "the pipeline".

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Fix critical bugs and UX gaps in mod_harmonize.R | 7f3d155 | R/mod_harmonize.R |

## What Was Built

### Fix A — Gap 4: DT row click broken (CRITICAL)
Changed `selection = "single"` to `selection = "none"` in the `output$media_table` DT::datatable call. DT's single-selection mode was consuming click events before the custom JS `callback` could fire `Shiny.setInputValue('open_media_edit_modal', ...)`. With `selection = "none"` DT no longer intercepts clicks and the callback fires normally.

### Fix B — Gap 5: Add Media Mapping button broken (CRITICAL)
Added `ignoreInit = TRUE` to the `observeEvent(input$add_media_mapping, {...})` observer. The button lives inside a dynamically rendered `renderUI` accordion panel; `ignoreInit = TRUE` prevents a false-fire on module initialization and ensures the observer correctly handles the dynamic input lifecycle.

### Fix C — Hidden run_harmonization button (rerun links prerequisite)
Added a hidden `actionButton(ns("run_harmonization"), "Run Harmonization")` wrapped in `tags$div(style = "display: none;")` inside `mod_harmonize_ui()`, placed before the `conditionalPanel`. This restores the DOM target required by `shinyjs::click("run_harmonization")` at two call sites (rerun_now and media_rerun_now action links) and the cascade trigger in mod_clean_data.R.

### Fix D — Gap 2: Unmatched guidance text
Added `output$media_guidance <- renderUI({...})` that renders a Bootstrap `alert-info` banner showing the count of unmatched terms and instructions to click a row or use Add Media Mapping. Wired `uiOutput(session$ns("media_guidance"))` above the DT in the media_editor accordion panel.

### Fix E — Gap 6: Stale "run harmonization" wording
Updated all four user-facing strings that referenced "run harmonization" or "Re-run harmonization":
- Empty state `conditionalPanel` paragraph → "run the pipeline from the Clean Data tab"
- Empty DT table `emptyTable` message → "Run the pipeline with a Media-tagged column..."
- Media save notification → "Re-run the pipeline to apply changes?"
- Add-all-passthrough notification → "Re-run the pipeline to apply."

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Two additional stale-wording strings beyond the three listed in plan**
- **Found during:** Task 1 verification
- **Issue:** Plan listed 3 strings to update (lines ~91, ~1512, ~1585); grep found 2 additional user-facing instances: the empty DT table `emptyTable` message and the media save notification
- **Fix:** Updated all instances for consistency
- **Files modified:** R/mod_harmonize.R
- **Commit:** 7f3d155

## Verification Results

```
Fix A: selection = "none" at lines 1297 and 1331 (empty path also corrected)
Fix B: ignoreInit = TRUE at line 1438
Fix C: display: none div at line 73; actionButton(ns("run_harmonization")) at line 74
Fix D: output$media_guidance at line 862; uiOutput(media_guidance) at line 816
Fix E: zero remaining user-facing "run harmonization" strings (comment-only hit at line 1532)
air format: clean (no output)
Shiny cold boot: "Listening on http://127.0.0.1:3844" — PASS
```

## Known Stubs

None — all fixes wire to existing reactive infrastructure. No placeholder values introduced.

## Threat Flags

None — changes are UI-layer fixes within existing module scope. No new trust boundaries.

## Self-Check: PASSED

- `/R/mod_harmonize.R` — FOUND (modified)
- Commit `7f3d155` — FOUND in git log
- Cold boot — PASSED (Listening on http://127.0.0.1:3844)
