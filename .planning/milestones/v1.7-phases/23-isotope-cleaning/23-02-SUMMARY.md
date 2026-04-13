---
phase: 23-isotope-cleaning
plan: 02
subsystem: cleaning_pipeline
tags: [isotope, chiral, multi-analyte, cleaning-pipeline, R, Shiny, integration-test, audit-trail]

# Dependency graph
requires:
  - phase: 23-isotope-cleaning/23-01
    provides: protect_chiral_designations, expand_isotope_shortcodes, flag_multi_analyte functions in cleaning_pipeline.R

provides:
  - run_cleaning_pipeline() with chiral protection before Step 6a, isotope expansion after synonym split, multi-analyte flagging after isotopes
  - mod_clean_data.R with identical three new steps at correct positions
  - 4 new integration tests covering full pipeline ordering
  - Shiny smoke test confirmed passing

affects: [mod_tag_columns, post-curation QC export, audit trail consumers, any future pipeline phases]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "protect_chiral_designations wired before strip_terminal_enclosures in both orchestrators"
    - "expand_isotope_shortcodes wired after split_synonyms and before detect_bare_formulas in both orchestrators"
    - "flag_multi_analyte wired after expand_isotope_shortcodes in both orchestrators"
    - "incProgress values trimmed (0.08->0.06) to accommodate 3 new 0.04 progress steps without exceeding 1.0"

key-files:
  created:
    - tests/test_cleaning_pipeline_validation.R (4 new test groups appended)
  modified:
    - R/cleaning_pipeline.R
    - R/modules/mod_clean_data.R

key-decisions:
  - "Pipeline ordering in run_cleaning_pipeline: chiral -> strip_terminal_enclosures -> ... -> split_synonyms -> isotope expansion -> multi-analyte flagging -> (caller: detect_bare_formulas)"
  - "Pipeline ordering in mod_clean_data.R mirrors run_cleaning_pipeline exactly"
  - "incProgress 0.08->0.06 for enclosure stripping and synonym splitting to stay near 1.0 total with 3 new 0.04 steps"

patterns-established:
  - "Both pipeline orchestrators must be updated together when adding new cleaning steps"
  - "Progress steps for new functions use 0.04 increments (small, non-blocking steps)"

requirements-completed: [ISOT-01, ISOT-02, ISOT-03, CHIR-01, MANA-01]

# Metrics
duration: 20min
completed: 2026-04-02
---

# Phase 23 Plan 02: Pipeline Wiring Summary

**Three new cleaning steps (chiral protection, isotope expansion, multi-analyte flagging) wired into both run_cleaning_pipeline() and mod_clean_data.R at correct D-13 positions, with 4 integration tests and confirmed Shiny startup.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-04-02T16:45:00Z
- **Completed:** 2026-04-02T17:05:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- `protect_chiral_designations()` inserted before `strip_terminal_enclosures` in both `run_cleaning_pipeline()` and `mod_clean_data.R` — prevents `(R)`, `(S)`, `(+)` from being stripped as terminal parentheticals
- `expand_isotope_shortcodes()` inserted after `split_synonyms` / row removal and before `detect_bare_formulas` in both orchestrators — ensures `u234 -> Uranium-234` happens before bare formula detection (so `Pb210` is never passed to the formula blocker)
- `flag_multi_analyte()` inserted after isotope expansion in both orchestrators — flags `nitrate + nitrite` without altering values
- 4 integration tests appended to `test_cleaning_pipeline_validation.R` covering all three new steps and formula safety
- Shiny smoke test confirmed: app starts and reaches "Listening on http://127.0.0.1:3838" with no errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire three new steps into run_cleaning_pipeline() and mod_clean_data.R** - `44e9fb7` (feat)
2. **Task 2: Add integration tests and run Shiny smoke test** - `0ae58cb` (test)

## Files Created/Modified

- `R/cleaning_pipeline.R` — Added Steps 6-pre (chiral), 7 (isotope), 8 (multi-analyte) inside `run_cleaning_pipeline()` name cleaning block
- `R/modules/mod_clean_data.R` — Added matching three steps with incProgress calls; reduced two 0.08 incProgress calls to 0.06 to stay near 1.0 total
- `tests/test_cleaning_pipeline_validation.R` — Appended 4 new test groups (Groups 7-10): isotope expansion, chiral protection, multi-analyte flagging, formula survival

## Decisions Made

- Pipeline ordering in `run_cleaning_pipeline`: chiral -> enclosure stripping -> quality adjectives -> salts -> unspecified -> reference terms -> cleanup -> enclosures again -> synonyms -> isotope expansion -> multi-analyte flagging -> (return; caller runs detect_bare_formulas)
- `incProgress` reduced from 0.08 to 0.06 for enclosure stripping and synonym splitting steps to accommodate 3 new 0.04 calls without going significantly over 1.0
- Test expectation uses `Caesium-137` (IUPAC, ComptoxR canonical) not `Cesium-137` (American spelling)

## Deviations from Plan

None - plan executed exactly as written. The Caesium/Cesium adjustment was already documented in Plan 01 SUMMARY and the important context note, and was correctly applied in the test.

## Issues Encountered

None. All tests passed on first run after wiring.

## Known Stubs

None — all three functions are fully wired and tested. No placeholder data flows to UI rendering.

## Next Phase Readiness

- Phase 23 complete: all three new cleaning functions are live in both pipeline orchestrators
- The full pipeline now runs: chiral protection -> name cleaning -> isotope expansion -> multi-analyte flagging -> bare formula detection
- 61 integration tests + 86 unit tests all pass
- Pre-existing tech debt: `test_cleaning_reference.R` 1 failure (expects 3 keys, gets 4 including `strip_terms`) — unchanged, out of scope

## Self-Check: PASSED

- R/cleaning_pipeline.R: FOUND
- R/modules/mod_clean_data.R: FOUND
- tests/test_cleaning_pipeline_validation.R: FOUND
- Commit 44e9fb7 (feat): FOUND
- Commit 0ae58cb (test): FOUND

---
*Phase: 23-isotope-cleaning*
*Completed: 2026-04-02*
