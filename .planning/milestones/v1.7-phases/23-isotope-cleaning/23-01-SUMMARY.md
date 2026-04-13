---
phase: 23-isotope-cleaning
plan: 01
subsystem: cleaning_pipeline
tags: [ComptoxR, isotope, chiral, multi-analyte, cleaning-pipeline, R, regex, audit-trail]

# Dependency graph
requires:
  - phase: 22-ui-polish
    provides: stable app foundation before adding new pipeline steps
  - phase: 10-cleaning-pipeline
    provides: build_audit_trail() pattern, cleaning_flag column convention, list(cleaned_data, audit_trail) return format

provides:
  - protect_chiral_designations() — chiral marker placeholder protection + WARNING flag
  - expand_isotope_shortcodes() — naked shortcode expansion (u234->Uranium-234) + spelled-out normalization
  - flag_multi_analyte() — naked " + " / " and " multi-analyte detection + WARNING flag
  - CHIRAL_PLACEHOLDER_PREFIX constant
  - 86-test coverage for all three functions

affects: [23-02, run_cleaning_pipeline orchestrator, mod_clean_data, post-curation QC export]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ComptoxR::pt$isotope direct access for isotope lookup (no custom tables)"
    - "Greedy element matching (sort by symbol length desc) for Pb before P"
    - "###CHIRAL_n### placeholder pattern consistent with existing @@@ IUPAC comma protection"
    - "ELEMENT_ALT_NAMES vector for American vs IUPAC name variants (cesium/Caesium)"

key-files:
  created:
    - tests/test_isotope_chiral_multianalyte.R
  modified:
    - R/cleaning_pipeline.R

key-decisions:
  - "ComptoxR uses IUPAC name 'Caesium' not American 'Cesium'; test updated to expect Caesium-137; ELEMENT_ALT_NAMES table added for normalization matching"
  - "Greedy element sort (nchar desc) ensures Pb matched before P in naked shortcode expansion"
  - "d-prefix exclusion done at cell level: if cell starts with [dD]-word, skip entire cell (avoids d-glucose false positive)"
  - "14C-glucose exclusion done at cell level: if cell starts with digit+symbol+hyphen, skip entire cell"
  - "unat handled as special case: flag WARNING unresolvable, do not attempt expansion (D-06)"
  - "flag_multi_analyte uses negative lookahead/lookbehind to distinguish naked ' + ' from '(+)' inside parentheses"

patterns-established:
  - "Chiral protection must run BEFORE strip_terminal_enclosures to prevent (R) removal"
  - "Isotope expansion must run BEFORE detect_bare_formulas to prevent Pb210->BLOCK"
  - "All three new steps are flag/transform-and-flag only — no row deletion"

requirements-completed: [ISOT-01, ISOT-02, ISOT-03, CHIR-01, MANA-01]

# Metrics
duration: 25min
completed: 2026-04-02
---

# Phase 23 Plan 01: Isotope & Chiral Cleaning Functions Summary

**Three new cleaning pipeline functions using ComptoxR isotope lookup: chiral placeholder protection with WARNING flags, naked shortcode expansion (u234->Uranium-234) with spelled-out normalization, and naked multi-analyte flagging — 86 unit tests, all passing.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-02T16:10:00Z
- **Completed:** 2026-04-02T16:36:42Z
- **Tasks:** 2 (TDD: RED + GREEN)
- **Files modified:** 2

## Accomplishments

- `protect_chiral_designations()` replaces chiral markers `(+)`, `(-)`, `(R)`, `(S)`, `(R,S)`, `(dl)` etc. with `###CHIRAL_n###` placeholders and appends `"WARNING: chiral designation"` to `cleaning_flag` — prevents downstream `strip_terminal_enclosures()` from deleting them
- `expand_isotope_shortcodes()` builds a runtime lookup from `ComptoxR::pt$isotope` (3,390 rows), expands naked shortcodes (`u234`→`Uranium-234`, `pb210`→`Lead-210`) with greedy element matching (Pb before P), normalizes spelled-out forms (`radium 226`→`Radium-226`, `cesium-137`→`Caesium-137`), excludes carbon backbone and deuterium d-prefix patterns per ISOT-03, and flags `unat` as unresolvable
- `flag_multi_analyte()` flags rows with naked ` + ` or ` and ` as `"WARNING: potential multi-analyte"` without touching cell values — correctly ignores `(+)-catechin` where `+` is inside parentheses
- 86 tests covering all behaviors, edge cases, NA handling, empty dataframes, and audit trail creation

## Task Commits

Each task was committed atomically (TDD pattern):

1. **Task 1 RED phase: failing tests** - `4bb96bc` (test)
2. **Task 1+2 GREEN phase: all three functions** - `d9532af` (feat)

## Files Created/Modified

- `R/cleaning_pipeline.R` — Three new functions appended (protect_chiral_designations, expand_isotope_shortcodes, flag_multi_analyte) plus CHIRAL_PLACEHOLDER_PREFIX constant (~400 lines added)
- `tests/test_isotope_chiral_multianalyte.R` — 86 unit tests for all three functions (created)

## Decisions Made

- ComptoxR uses IUPAC name `Caesium` not American `Cesium`. Added `ELEMENT_ALT_NAMES` vector with `cesium -> Caesium` mapping for spelled-out normalization. Test expectation updated to `Caesium-137` (the canonical ComptoxR form). This is consistent with D-01 (use ComptoxR data directly) — the alt-names table is for input matching only, not output.
- Greedy element sort ensures `Pb` is matched before `P` in all contexts.
- Cell-level exclusions for d-prefix and 14C-compound patterns (check once per cell, skip entire cell if matched) is simpler and more performant than token-level checks.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Cesium/Caesium spelling mismatch in ComptoxR data**
- **Found during:** Task 1 (expand_isotope_shortcodes implementation + test run)
- **Issue:** Plan test case said `cesium-137` → `Cesium-137`, but ComptoxR uses IUPAC name `Caesium`. The spelled-out normalization pattern `(?i)\bCaesium...\b` does not match input `cesium` because they are different strings (not just different case).
- **Fix:** Added `ELEMENT_ALT_NAMES <- c("cesium" = "Caesium", ...)` vector. The normalization loop now also tries alternate names for each element. Updated test expectation to `Caesium-137` (canonical ComptoxR form).
- **Files modified:** R/cleaning_pipeline.R, tests/test_isotope_chiral_multianalyte.R
- **Verification:** Test passes: `expand_isotope_shortcodes normalizes 'cesium-137' to Caesium-137`
- **Committed in:** d9532af (Task 1+2 feat commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - spelling mismatch bug)
**Impact on plan:** Fix necessary for correctness. No scope creep. Alternate names vector is minimal (3 entries) and documented.

## Issues Encountered

None beyond the Cesium/Caesium spelling deviation above.

## Known Stubs

None — all three functions are fully implemented and tested. No placeholder data flows to UI rendering.

## Next Phase Readiness

- Plan 23-01 complete: three new cleaning functions exist and are tested
- Plan 23-02 can now wire these functions into `run_cleaning_pipeline()` orchestrator between Step 6 (name cleaning) and bare formula detection
- Chiral protection must be inserted BEFORE Step 6a (strip_terminal_enclosures) per D-10
- All 86 tests pass; pre-existing `cleaning_reference` test failure (1 test expecting 3 keys vs 4 returned) is unchanged pre-existing tech debt

## Self-Check: PASSED

- R/cleaning_pipeline.R: FOUND
- tests/test_isotope_chiral_multianalyte.R: FOUND
- .planning/phases/23-isotope-cleaning/23-01-SUMMARY.md: FOUND
- Commit 4bb96bc (test): FOUND
- Commit d9532af (feat): FOUND
- Commit 00e8bf4 (docs): FOUND

---
*Phase: 23-isotope-cleaning*
*Completed: 2026-04-02*
