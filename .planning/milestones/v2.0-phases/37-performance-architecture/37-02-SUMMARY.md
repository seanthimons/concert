---
phase: 37-performance-architecture
plan: "02"
subsystem: pipeline
tags: [pre-check, short-circuit, skip, performance, cleaning-pipeline, SKIP-01, SKIP-02, SKIP-03]

# Dependency graph
requires:
  - phase: 37-01
    provides: dedup_step() and remap_audit_to_parent() in R/cleaning_pipeline.R

provides:
  - build_skip_result() helper in R/cleaning_pipeline.R
  - precheck_unicode_to_ascii() in R/cleaning_pipeline.R
  - precheck_trim_whitespace() in R/cleaning_pipeline.R
  - precheck_normalize_cas() in R/cleaning_pipeline.R
  - precheck_name_cleaning() in R/cleaning_pipeline.R
  - precheck_isotope_shortcodes() in R/cleaning_pipeline.R
  - precheck_multi_analyte() in R/cleaning_pipeline.R
  - precheck_chiral_restore() in R/cleaning_pipeline.R
  - tests/testthat/test-precheck-infrastructure.R with 78 assertions (31 test_that blocks)

affects:
  - 37-03 (orchestrator wires precheck_ calls at each step call site in run_cleaning_pipeline)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "precheck_*(df, ...) -> list(should_run, est_changes): canonical short-circuit predicate signature"
    - "build_skip_result(df, step_name): emits message() log + empty typed 6-col audit tibble (SKIP-02)"
    - "stringi::stri_enc_isascii() vectorized full-column scan for unicode detection (D-05)"
    - "SKIP-03 false-negative companion test pattern: prove should_run=TRUE on every vector the step would transform"

key-files:
  created:
    - tests/testthat/test-precheck-infrastructure.R
  modified:
    - R/cleaning_pipeline.R

key-decisions:
  - "precheck_name_cleaning is intentionally broad (any non-empty name value -> should_run=TRUE): individual name chain steps have too many interdependencies for cell-level prediction; over-counting is safe (D-04)"
  - "precheck_isotope_shortcodes sorts shortcodes by length descending before building regex: greedy matching ensures Pb210 matched before Pb when symbols share a prefix"
  - "precheck_normalize_cas detects two change categories: pure-digit strings (unformatted CAS) and placeholder text patterns; does not call as_cas() to keep pre-check cheap (D-05)"

requirements-completed:
  - SKIP-01
  - SKIP-02
  - SKIP-03

# Metrics
duration: ~12min
completed: "2026-04-24"
---

# Phase 37 Plan 02: Pre-check Predicate Functions Summary

**7 pre-check predicate functions and `build_skip_result()` helper implementing SKIP-01/SKIP-02 short-circuit evaluation, tested with 78 assertions across 31 test_that blocks including SKIP-03 false-negative companions for every predicate**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-04-24T19:07:00Z
- **Completed:** 2026-04-24T19:19:55Z
- **Tasks:** 2
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments

- `build_skip_result(df, step_name)`: emits `message(sprintf("Step %s skipped -- pre-check FALSE", step_name))` and returns pass-through `cleaned_data` + empty typed 6-column audit tibble (SKIP-02)
- `precheck_unicode_to_ascii(df)`: vectorized `stringi::stri_enc_isascii()` scan across all character columns (D-05)
- `precheck_trim_whitespace(df)`: compares `clean_text_field()` output against each character column to detect whitespace/artifact changes
- `precheck_normalize_cas(df, tag_map)`: detects pure-digit unformatted CAS strings and placeholder text patterns in CASRN-tagged columns
- `precheck_name_cleaning(df, name_cols)`: broad non-empty check for the full name chain (Steps 6-pre through 6d3); intentionally over-counts because individual step interdependencies make cell-level prediction impractical
- `precheck_isotope_shortcodes(df, name_cols, isotope_lookup)`: greedy word-boundary match on isotope shortcodes (sorted by length desc); returns FALSE on NULL/empty lookup
- `precheck_multi_analyte(df, name_cols)`: detects whitespace-flanked `and`/`&`/`/` separators; word-boundary guard prevents "sand" / "mandarin" false positives
- `precheck_chiral_restore(df, name_cols)`: checks for `###CHIRAL_` placeholder token; requires underscore suffix so `###CHIRAL` alone does not match
- 78-assertion test suite covering clean (FALSE), dirty (TRUE+est_changes), and SKIP-03 false-negative companion for all 7 predicates

## Task Commits

1. **Task 1: Implement pre-check predicate functions** - `82f5d3f` (feat)
2. **Task 2: Test pre-checks with false-negative companions (SKIP-03)** - `b9145ca` (test)

## Files Created/Modified

- `R/cleaning_pipeline.R` — Phase 37 SKIP-01 section added between `dedup_step()` and `inject_row_lineage()`: 8 new functions (`build_skip_result` + 7 `precheck_*`), 209 lines inserted
- `tests/testthat/test-precheck-infrastructure.R` — 31 `test_that()` blocks, 78 assertions; covers all 7 predicates with (a)/(b)/(c) pattern including SKIP-03 false-negative companions

## Decisions Made

- **`precheck_name_cleaning` is intentionally broad**: All non-empty name values are candidates (`should_run=TRUE` if any exist). Individual name steps (enclosure stripping, adjective removal, chiral protect/restore, etc.) have complex interdependencies — predicting which cells would change requires running the full chain. Over-counting is safe per D-04 (cosmetic only).
- **Isotope shortcodes sorted by length descending**: Greedy matching ensures long symbols (`Pb210`) are matched before shorter prefixes (`Pb`) when building the alternation regex.
- **`precheck_normalize_cas` avoids calling `as_cas()`**: Uses pattern matching (pure-digit regex + placeholder regex) to stay cheap per D-05. Two detected categories: unformatted pure-digit strings and common placeholder text. Does not catch every possible change (e.g., malformed CAS with wrong checksum), but `should_run=TRUE` for the vast majority of real-world dirty data.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Issues Encountered

- Pre-existing test failures in `test-cleaning-reference.R` and `test-reference-provenance.R` (3 failures confirmed pre-existing per Plan 01 SUMMARY — not introduced by this work).

## Self-Check: PASSED

- FOUND: `R/cleaning_pipeline.R` with `precheck_unicode_to_ascii`, `precheck_trim_whitespace`, `precheck_normalize_cas`, `precheck_name_cleaning`, `precheck_isotope_shortcodes`, `precheck_multi_analyte`, `precheck_chiral_restore`, `build_skip_result`
- FOUND: `tests/testthat/test-precheck-infrastructure.R` with 31 test_that blocks and 78 assertions
- FOUND: commit `82f5d3f` (Task 1 — feat)
- FOUND: commit `b9145ca` (Task 2 — test)
- `stringi::stri_enc_isascii` confirmed at lines 291 and 297 of `R/cleaning_pipeline.R`
- `message(sprintf("Step %s skipped -- pre-check FALSE", step_name))` confirmed at line 260
- Empty typed 6-column audit tibble in `build_skip_result` confirmed
- Full suite: 1616 PASS, 3 FAIL (pre-existing), 2 SKIP

---
*Phase: 37-performance-architecture*
*Completed: 2026-04-24*
