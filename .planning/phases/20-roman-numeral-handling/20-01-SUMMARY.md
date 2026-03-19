---
phase: 20-roman-numeral-handling
plan: "01"
subsystem: cleaning
tags: [R, stringr, regex, chemical-names, oxidation-states, strip_terminal_enclosures]

# Dependency graph
requires:
  - phase: 19-synonym-splitter-comma-protection
    provides: multi-locant synonym protection in split_synonyms()
provides:
  - Roman numeral oxidation state protection in strip_terminal_enclosures()
  - ROMAN_NUMERAL_PATTERN module-level constant in cleaning_pipeline.R
  - Unit tests covering terminal, lowercase, bracket, and regression cases
  - Validation CSV rows tagged roman_numeral_oxidation
affects: [any phase that modifies strip_terminal_enclosures or formula_extract logic]

# Tech tracking
tech-stack:
  added: []
  patterns: [content-based should_strip gating with has_roman check (same pattern as has_yl, has_percentage)]

key-files:
  created: []
  modified:
    - R/cleaning_pipeline.R
    - tests/test_name_cleaning.R
    - data/chemical_validation_test.csv

key-decisions:
  - "ROMAN_NUMERAL_PATTERN defined as module-level constant after library() calls — single definition used by both paren and bracket paths"
  - "has_roman added to should_strip as third condition: && !has_roman — minimal intrusion, parallel with existing has_yl and has_percentage guards"
  - "Regex uses anchored full-content match (^ and $) so only purely roman numeral content is protected — mixed content like (Fe2O3, III) still strips"
  - "Case-insensitive via (?i) flag — protects both (III) and (iii) forms confirmed in production data"
  - "Element+symbol prefix [A-Z][a-z]? heuristic used (not full periodic table list) — sufficient for defense-in-depth on edge cases"

patterns-established:
  - "content-based strip gating: add has_X flag before should_strip, include && !has_X in conditional — applied identically to both paren and bracket code paths"

requirements-completed: [ROMAN-01, ROMAN-02]

# Metrics
duration: 45min
completed: 2026-03-19
---

# Phase 20 Plan 01: Roman Numeral Handling Summary

**Roman numeral oxidation state protection added to strip_terminal_enclosures() using anchored regex constant, blocking (III)/(iii)/[III] from being stripped or misrouted to formula_extract**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-03-19T19:30:00Z
- **Completed:** 2026-03-19T20:15:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Added `ROMAN_NUMERAL_PATTERN` module-level constant covering I through XII, case-insensitive, with optional element symbol prefix
- Modified both parenthetical and bracket paths in `strip_terminal_enclosures()` to detect roman numeral content and skip stripping
- Added 4 roman numeral unit test cases (terminal uppercase/lowercase, brackets, element+numeral, regression) — all 42 name_cleaning tests pass
- Appended 6 rows to `chemical_validation_test.csv` with `issue_type = roman_numeral_oxidation` covering all key forms
- Shiny smoke test passed (app starts without crash)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add roman numeral protection + unit tests (TDD)** - `e7adc24` (feat)
2. **Task 2: Add validation CSV rows + smoke test** - `35d1464` (feat)

**Plan metadata:** to be committed with SUMMARY.md

_Note: Task 1 followed TDD: RED (failing tests written first), GREEN (code fix applied), 129 tests pass_

## Files Created/Modified
- `R/cleaning_pipeline.R` - Added ROMAN_NUMERAL_PATTERN constant (line 17); added has_roman to paren path (line 390) and bracket path (line 420); modified should_strip in both paths
- `tests/test_name_cleaning.R` - Added 4 new test_that blocks for ROMAN-01/ROMAN-02 coverage (42 total tests, 0 failures)
- `data/chemical_validation_test.csv` - Appended 6 rows: chromium (III), chromium (iii), Iron(III) chloride, Copper(II) sulfate, Antimony(III) ethoxide, Manganese(VII) oxide

## Decisions Made
- ROMAN_NUMERAL_PATTERN defined as module-level constant — single authoritative source used by both code paths
- Full-content anchor (^ and $) in regex ensures only purely roman numeral parentheticals are protected — mixed content like "(Fe2O3)" continues to be stripped
- Element symbol heuristic [A-Z][a-z]? rather than full periodic table whitelist — simpler and sufficient
- Pre-existing failures in test_cleaning_pipeline.R (ComptoxR::clean_unicode) and test_cleaning_reference.R are out of scope — not caused by this phase's changes

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Port 3838 was already in use during smoke test (from prior test runner background processes). Used port 3841 instead — "Listening on http://127.0.0.1:3841" confirmed the app starts without crash.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Roman numeral protection is complete and tested
- Phase 20 is fully complete (1 plan)
- The pre-existing ComptoxR test failures in test_cleaning_pipeline.R were present before this phase — they are candidates for Phase 21 (UNIC-01/UNIC-02) if ComptoxR mapping table verification is needed

## Self-Check: PASSED

- R/cleaning_pipeline.R: FOUND
- tests/test_name_cleaning.R: FOUND
- data/chemical_validation_test.csv: FOUND
- 20-01-SUMMARY.md: FOUND
- Commit e7adc24: FOUND
- Commit 35d1464: FOUND

---
*Phase: 20-roman-numeral-handling*
*Completed: 2026-03-19*
