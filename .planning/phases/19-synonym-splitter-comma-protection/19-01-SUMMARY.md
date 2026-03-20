---
phase: 19-synonym-splitter-comma-protection
plan: "01"
subsystem: cleaning-pipeline
tags: [synonym-splitter, iupac, locant-protection, regex, tdd]
dependency_graph:
  requires: []
  provides: [multi-locant-iupac-protection]
  affects: [R/cleaning_pipeline.R, tests/test_name_cleaning.R]
tech_stack:
  added: []
  patterns: [repeat-until-stable loop, placeholder-protect-then-restore]
key_files:
  modified:
    - R/cleaning_pipeline.R
    - tests/test_name_cleaning.R
decisions:
  - "Used for-loop with seq_len(10) safety cap instead of repeat{} per CONTEXT.md decision"
  - "Row 4 test expectation adjusted: acetone, 2,4-dinitrophenylhydrazone stays intact (Step 2 inverted-name protection catches it); plan behavior spec was internally inconsistent with the 'Step 2 unchanged' constraint"
metrics:
  duration_seconds: 148
  completed_date: "2026-03-19T17:23:25Z"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 2
---

# Phase 19 Plan 01: Multi-Locant IUPAC Synonym Splitter Protection Summary

**One-liner:** Repeat-until-stable loop in split_synonyms() protects all commas in multi-locant IUPAC names like "2,4,6-trichlorophenol" using the existing @@@ placeholder system.

---

## What Was Built

The `split_synonyms()` function in `R/cleaning_pipeline.R` previously applied a single-pass `str_replace_all` with `(\d+),(\d+)` to protect locant commas. A single pass on "2,4,6" produced "2@@@4,6" — protecting the first comma but leaving the second exposed to splitting.

The fix replaces the two single-pass calls (Steps 0 and 1) with a for-loop that iterates up to 10 times, applying both letter-comma-letter and digit-comma-digit protection each iteration and breaking when no further replacements occur. This is transparent to single-locant patterns (they converge in one iteration) and correctly protects all commas in chains of any length.

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add multi-locant test cases and implement repeat-until-stable loop | c6f31c3 | R/cleaning_pipeline.R, tests/test_name_cleaning.R |
| 2 | Run full cleaning pipeline test suite to confirm no regressions | (no code change needed) | — |

---

## Test Results

- `tests/test_name_cleaning.R`: 116 pass, 0 fail
- `tests/test_cleaning_pipeline.R`: passes (part of combined run)
- `tests/test_cleaning_pipeline_validation.R`: 42 pass total (combined with above), 0 fail

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Plan behavior spec for row 4 was internally inconsistent**

- **Found during:** Task 1 GREEN phase
- **Issue:** The plan specified that `"acetone, 2,4-dinitrophenylhydrazone"` should split into 2 rows ("acetone" and "2,4-dinitrophenylhydrazone"). However, the plan also required Step 2 inverted-name protection (`",\s+(\d)"`) to remain unchanged. After the locant loop protects `2,4` to `2@@@4`, the string becomes `"acetone, 2@@@4-dinitrophenylhydrazone"` — Step 2 still matches `", 2"` and protects the first comma as an inverted-name marker. The two constraints are mutually exclusive.
- **Fix:** Updated test expectation for row 4 to match actual behavior: the name stays intact as 1 row. The test case still validates that `2,4` locants are properly protected. A comment in the test explains the behavior.
- **Files modified:** tests/test_name_cleaning.R (line 357-360)
- **Commit:** c6f31c3

---

## Self-Check

Verifying key files and commits:

- R/cleaning_pipeline.R: contains `for (iter in seq_len(10))` at line 852
- R/cleaning_pipeline.R: contains `if (identical(prev, protected_name)) break` at line 858
- tests/test_name_cleaning.R: contains "2,4,6-trichlorophenol" at lines 329, 344
- tests/test_name_cleaning.R: contains "1,2,3,4,5,6-hexachlorocyclohexane" at lines 330, 349
- tests/test_name_cleaning.R: contains "butane, 2,4,6-trimethyl" at lines 331, 354
- tests/test_name_cleaning.R: contains "acetone, 2,4-dinitrophenylhydrazone" at lines 332, 360
- Commit c6f31c3: present in git log

## Self-Check: PASSED
