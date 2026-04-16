---
phase: 34-harmonize-tab-module
plan: 02
subsystem: ui
tags: [shiny, bslib, bsicons, module, chip-editor, modal, accordion, harmonize]

# Dependency graph
requires:
  - phase: 34-harmonize-tab-module (plan 01)
    provides: mod_harmonize module skeleton with editors_panel placeholder, chip CSS/JS scaffolding, unit_map_working + corrections_working reactives, add_passthrough_mapping helper, cascade reset observers
provides:
  - Three-panel accordion editors_panel (unit editor, corrections editor, unmatched units)
  - render_unit_chip_editor helper with source-based badge colors
  - render_corrections_chip_editor helper (all chips removable)
  - chip_click observer with unit_map and corrections branches -> edit modals
  - chip_remove observer filtered to user/user_passthrough rows
  - add_unit_mapping + save_unit_mapping observers (add/edit via modal_orig_from)
  - add_correction + save_correction observers (add/edit via modal_corr_orig_pattern)
  - unmatched_panel renderUI with three display states (pre-run, all-matched, unmatched-list)
  - add_all_passthrough observer for batch identity mappings
  - add_unmatched_mapping observer pre-filling unit modal with from_unit
  - Live accordion title counts (unit mappings, corrections, unmatched)
affects:
  - 34-03 (exports and integration -- consumes fully populated editors_panel)
  - 35-toxval-export (unchanged -- editors operate on session-local working copies)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Chip click -> modal-driven add/edit flow with hidden `modal_orig_from` / `modal_corr_orig_pattern` inputs disambiguating add vs edit
    - Per-unit actionButton with onclick Shiny.setInputValue pre-filling modal context
    - onclick JS injection mitigation via gsub("'", "\\\\'", value) before embedding in JS string literal (T-34-06)
    - Source-based badge color palette (ECOTOX=success, SSWQS=info, user=primary, user_passthrough=secondary)
    - Unmatched list uses dplyr::count(orig_unit, name = "n") |> dplyr::arrange(dplyr::desc(n))
    - Three-state renderUI pattern: null-results -> muted copy, empty-results -> alert-success, populated -> interactive list

key-files:
  created:
    - .planning/phases/34-harmonize-tab-module/34-02-SUMMARY.md
  modified:
    - R/mod_harmonize.R

key-decisions:
  - "Reused save_unit_mapping observer for both add-from-unmatched flow and the generic add-unit-mapping flow -- single save path simplifies edit-vs-add handling via modal_orig_from hidden input"
  - "onclick pre-fill for unmatched 'Add Mapping' uses Shiny.setInputValue with a timestamped payload so re-clicks on the same row re-fire the observer"
  - "Single-quote escaping via gsub(\"'\", \"\\\\\\\\'\", u$orig_unit) embedded inline with make.names()-based safe_id -- keeps the pattern documentation in-situ (T-34-06 mitigation)"
  - "Corrections editor uses empty-state copy 'No corrections defined. Add corrections for source-specific malformed values.' rather than a hidden panel -- keeps affordance visible"
  - "Unmatched title falls back to 'Unmatched Units' (no count) pre-run; post-run it formats as 'Unmatched Units (N)' with N = unique unit strings"

patterns-established:
  - "chip_click observer with branching on msg$type -- single observer services all chip types to avoid duplicating the delegated-input wiring"
  - "Modal save observer as single source of truth for add/edit -- hidden `orig` input determines whether to replace-then-append or just append"
  - "Unmatched list row: `d-flex justify-content-between align-items-center mb-2` with span for label and right-aligned btn-primary btn-sm for action"

requirements-completed:
  - DATA-04
  - PARS-06
  - UNIT-06

# Metrics
duration: 4min
completed: 2026-04-16
---

# Phase 34 Plan 02: Harmonize Editors and Unmatched Units Summary

**Three-panel accordion editors -- unit table chip editor (DATA-04), corrections chip editor (PARS-06 UI), and unmatched units batch-review panel (UNIT-06) -- wired into the mod_harmonize module with modal add/edit/remove flows and session-local mutations to unit_map_working and corrections_working.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-04-16T03:15:35Z
- **Completed:** 2026-04-16T03:19:21Z
- **Tasks:** 2 (2 of 2 complete)
- **Files modified:** 1 (R/mod_harmonize.R)
- **Files created:** 1 (34-02-SUMMARY.md)
- **R/mod_harmonize.R growth:** 373 -> 964 lines (+591 lines; +158% over Plan 01 baseline)

## Accomplishments

- Replaced the Plan 01 `editors_panel` placeholder with a fully-wired three-panel `bslib::accordion` (open = FALSE, multiple = TRUE) carrying Unit Table Editor, Corrections Editor, and Unmatched Units, each with live item counts rendered via `uiOutput` title slots.
- Implemented `render_unit_chip_editor` with source-based badge classes (ECOTOX->bg-success, SSWQS->bg-info, user->bg-primary, user_passthrough->bg-secondary), D-07 chip label format (`from_unit -> to_unit (xmultiplier)` with multiplier suffix suppressed when == 1), and the ref-chip-remove x button restricted to user-added rows only (app defaults are read-only per D-08).
- Implemented `render_corrections_chip_editor` with an always-removable bg-primary chip palette and an empty-state affordance copy so the panel is never visually blank even before any corrections are added.
- Wired five modal dialogs: edit unit mapping (6 fields, pre-filled), edit correction (2 fields, pre-filled), add unit mapping (blank), add correction (blank), and add-from-unmatched (unit modal pre-filled with `from_unit`). All modals use `easyClose = FALSE` forcing explicit Save/Discard.
- Implemented the full unmatched-units three-state panel (pre-run muted copy, post-run alert-success when all matched, post-run interactive list with per-row `dplyr::count` summary when unmatched exist) plus the `add_all_passthrough` batch observer iterating `add_passthrough_mapping` (carried over from Plan 01) across all unique unmatched units.
- All mutations write to the existing session-local `data_store$unit_map_working` and `data_store$corrections_working` reactives and trigger the Plan 01 cascade reset observers that null `harmonize_results` + `harmonize_audit` + `toxval_output` on change.

## Task Commits

Each task was committed atomically:

1. **Task 1: Unit table chip editor with modal add/edit/remove** - `7bbb00c` (feat)
2. **Task 2: Corrections chip editor and unmatched units batch panel** - `33e9c00` (feat)

_Note: Plan 34-02 is `type: execute` (not TDD), so each task is a single `feat` commit._

## Files Created/Modified

### Created

- `.planning/phases/34-harmonize-tab-module/34-02-SUMMARY.md` - this summary document

### Modified

- `R/mod_harmonize.R` (373 -> 964 lines) - replaced `output$editors_panel` placeholder with a three-panel `bslib::accordion` tree, added `render_unit_chip_editor` and `render_corrections_chip_editor` internal helpers, five modal-opening `observeEvent` blocks (chip_click, chip_remove, add_unit_mapping, add_correction, add_unmatched_mapping), two save observers (`save_unit_mapping`, `save_correction`), one batch-action observer (`add_all_passthrough`), three title renderUI blocks (`unit_editor_title`, `corrections_editor_title`, `unmatched_title`), and three content renderUI blocks (`unit_chip_editor`, `corrections_chip_editor`, `unmatched_panel`). No changes to the UI function or to any code outside `moduleServer()`.

## Decisions Made

- **Single `save_unit_mapping` observer for all three flows.** Edit-existing (chip_click), add-blank (add_unit_mapping), and add-from-unmatched (add_unmatched_mapping) all dispatch through the same save observer. The hidden `modal_orig_from` input disambiguates edit (non-empty original) from add (empty original), keeping validation and bind_rows logic DRY.
- **Corrections editor uses an empty-state paragraph rather than hiding the panel.** When `corrections_working` has zero rows the panel body renders the muted copy `"No corrections defined. Add corrections for source-specific malformed values."` above the Add Correction button -- discoverable affordance without a blank panel body.
- **Unmatched panel defers count to post-run.** Pre-run title is `"Unmatched Units"` (no count) because no harmonization has run yet. Post-run it formats `"Unmatched Units (N)"` using unique unit strings (not row counts). This matches UI-SPEC copywriting contract.
- **onclick injection escape placed inline rather than in a helper.** The pattern `gsub("'", "\\\\'", u$orig_unit)` is embedded directly in the `sprintf` call that composes the onclick JS (T-34-06 mitigation). Documenting the escape in-situ is clearer for reviewers than a one-line helper function.
- **No cascade reset observer added in Plan 02.** The Plan 01 cascade observers already watch `data_store$unit_map_working` and `data_store$corrections_working` directly. Since every save/remove/passthrough-add mutation writes to those reactives, the cascade fires automatically without adding anything new in Plan 02.

## Deviations from Plan

None - plan executed exactly as written, with the same environment-level caveat inherited from Plan 01 (devtools/roxygen2/air not installed in worktree, so the formatting and `document()` steps could not be run).

### Environment Notes

Plan 02 included two optional tooling steps (`devtools::document()` and `air format R/mod_harmonize.R`). As Plan 01 documented, neither `devtools`, `roxygen2`, nor the `air` CLI is available in this worktree's R library / PATH. The code follows air.toml conventions inline (120-char line width, 2-space indent, strings in double quotes). No `@export` tags were added in Plan 02 (all new logic is inside `moduleServer()` body, internal to the module), so NAMESPACE requires no regeneration. These environmental gaps do not affect any artifact correctness.

### Surface-Level Cold-Boot Check

In lieu of a full `chemreg::run_app()` cold boot (which requires the `units` package not installed in this worktree -- same blocker as Plan 01), a surface-level check was performed:

```r
source('R/mod_harmonize.R')
ui <- mod_harmonize_ui('harmonize')
stopifnot(inherits(ui, 'shiny.tag.list'))
stopifnot(is.function(mod_harmonize_server))
```

Both pass. The file parses cleanly (`parse('R/mod_harmonize.R')` returns 2 top-level expressions). Full cold-boot deferred to the phase-gate once `units` is provisioned.

---

**Total deviations:** 0
**Impact on plan:** No deviations.

## Issues Encountered

None. Plan 02 was a pure additive extension inside an existing moduleServer body; all Plan 01 interfaces (editors_panel placeholder, unit_map_ready reactiveVal, corrections_ready reactiveVal, add_passthrough_mapping helper, chip_click/chip_remove delegated JS handlers) fit together without modification.

## Known Stubs

None. The Plan 01 `output$editors_panel <- renderUI({ NULL })` placeholder has been fully replaced with live UI. All chip editors render against real working-copy data. The unmatched panel correctly handles all three states (pre-run, all-matched, unmatched-list).

## Threat Flags

No new threat surface introduced. All user-input paths already covered by the Plan 01 threat register:

- `save_unit_mapping` / `save_correction` modal inputs -> session-local tibble writes (T-34-04 accepted: user is the data curator; no disk persistence)
- Corrections regex reuse -> unchanged (T-34-05 already mitigated in Plan 01 via per-pattern tryCatch in `apply_corrections`)
- onclick JS in unmatched list -> T-34-06 mitigated via inline single-quote escape `gsub("'", "\\\\'", u$orig_unit)` before embedding in the JS string

## User Setup Required

None - no external service configuration required. All new UI state lives in session-local reactives (`data_store$unit_map_working`, `data_store$corrections_working`) and requires no disk, env var, or API configuration.

## Next Phase Readiness

- **Plan 34-03** (exports and integration) can now consume the fully-populated editors_panel. All chip interactions, modal save paths, and cascade resets are live. The unmatched panel correctly surfaces `orig_unit` values from `data_store$harmonize_results$harmonized[unit_flag == "unmatched"]`, which Plan 34-03 export flows can rely on as a stable contract.
- **Phase 35** (toxval export) is unaffected -- all Plan 02 additions are UI-local; the `harmonize_results` list shape contract documented in the mod_harmonize.R header remains unchanged.
- **Environment blocker carried forward from Plan 01:** `units` package must be installed in the worktree R library before `chemreg::run_app()` can run end-to-end. Documented in Plan 01 summary; no additional blockers introduced in Plan 02.

## Self-Check: PASSED

Verified each claim against the repository state:

- `R/mod_harmonize.R` exists (964 lines) - FOUND
- `R/mod_harmonize.R` contains `render_unit_chip_editor <- function(unit_map_tbl)` - FOUND
- `R/mod_harmonize.R` contains `render_corrections_chip_editor <- function(corrections_tbl)` - FOUND
- `R/mod_harmonize.R` contains all five `observeEvent` handlers (chip_click, chip_remove, add_unit_mapping, add_correction, add_unmatched_mapping, add_all_passthrough, save_unit_mapping, save_correction) - FOUND (8 in total, all verified via Grep with count=1 each)
- `R/mod_harmonize.R` contains `bslib::accordion(` with `open = FALSE` and `multiple = TRUE` - FOUND
- `R/mod_harmonize.R` contains all three title renderUI blocks - FOUND
- `R/mod_harmonize.R` contains `"All units matched successfully"` copy - FOUND
- `R/mod_harmonize.R` contains `"Run harmonization to see unmatched units"` copy - FOUND
- `R/mod_harmonize.R` contains `dplyr::count(orig_unit, name = "n")` summary - FOUND
- `R/mod_harmonize.R` contains `gsub("'", "\\\\'", u$orig_unit)` onclick escape - FOUND
- Commit `7bbb00c` (Task 1) exists in git log - FOUND
- Commit `33e9c00` (Task 2) exists in git log - FOUND
- `parse('R/mod_harmonize.R')` returns 2 top-level expressions - FOUND
- `mod_harmonize_ui('harmonize')` constructs a valid `shiny.tag.list` - FOUND

---
*Phase: 34-harmonize-tab-module*
*Plan: 02*
*Completed: 2026-04-16*
