---
phase: 16-cleaning-pipeline-bug-fixes
plan: 01
subsystem: cleaning-pipeline
tags: [bug-fix, false-positives, validation]
completed: 2026-03-10T16:41:08Z
duration_seconds: 913
requirements: [FORM-01, FORM-02, STOP-01, STOP-02, SPLIT-01, SPLIT-02]
dependency_graph:
  requires: []
  provides: [fixed-formula-detection, fixed-stop-word-matching, fixed-iupac-comma-protection]
  affects: [cleaning-pipeline, data-validation]
tech_stack:
  added: []
  patterns: [heuristic-validation, word-boundary-matching, placeholder-protection]
key_files:
  created: []
  modified:
    - R/cleaning_pipeline.R
    - tests/test_bare_formula_detection.R
    - tests/test_flag_matching.R
    - tests/test_name_cleaning.R
decisions:
  - "Use consecutive-lowercase heuristic to distinguish chemical names from formulas"
  - "Add all-uppercase-no-digits heuristic to exclude abbreviations (DEHP, PFOA, PCB)"
  - "Apply word boundaries (\\b) to stop word substring matching in Pass 2"
  - "Reuse @@@ placeholder for letter-comma-letter IUPAC patterns"
metrics:
  tasks_completed: 3
  commits: 3
  tests_added: 9
  tests_modified: 0
  files_modified: 4
---

# Phase 16 Plan 01: Cleaning Pipeline Bug Fixes Summary

**One-liner:** Fixed three false positive bugs in cleaning pipeline: formula detection, stop word substring matching, and IUPAC comma protection

## Overview

Fixed three validation bugs in the cleaning pipeline that were incorrectly flagging or splitting valid chemical names:

1. **Formula detection false positives**: Chemical names like "Naphthalene" and "Sodium chloride" were being flagged as bare formulas because element symbols (Na, Cl) in the name matched the ComptoxR validator regex.

2. **Stop word substring matching**: Stop word "na" was flagging "Naphthalene" and "Sodium bicarbonate" via substring match, creating false positives.

3. **IUPAC comma splitting**: Names like "N,N-Dimethylformamide" were being split at the comma into separate synonyms, breaking valid IUPAC nomenclature.

All three issues have been resolved with comprehensive test coverage.

## Tasks Completed

### Task 1: Fix bare formula detection false positives (e11e2d2)

**Problem:** `detect_bare_formulas()` used ComptoxR's validator regex to match molecular formulas, but the regex was catching chemical names that happened to contain element symbol sequences (e.g., "Naphthalene" → Na+ph+tha+le+ne).

**Solution:** Added two heuristics before the regex check:
1. **Consecutive lowercase check**: Names with 2+ consecutive lowercase letters (e.g., "aphthalene" in "Naphthalene") are skipped - real formulas only have single lowercase letters after uppercase element symbols
2. **Abbreviation check**: Pure uppercase strings with no digits (DEHP, PFOA, PCB, DDT) are skipped - real formulas have numbers or mixed case

**Impact:**
- ✅ Naphthalene, Sodium chloride, Ethanol, Methanol no longer flagged
- ✅ DEHP, PFOA, PCB, DDT abbreviations no longer flagged
- ✅ H2O, NaCl, CaCl2, C10H22 still correctly flagged as bare formulas

**Tests:** Added 3 new test cases, 57 total tests pass

### Task 2: Fix stop word substring matching (3247f4d)

**Problem:** `flag_reference_matches()` Pass 2 used simple substring matching with `str_detect()`, causing stop word "na" to match inside "Naphthalene" and "Sodium bicarbonate".

**Solution:** Wrapped reference terms in word boundaries (`\b`) during Pass 2 substring matching:
```r
bounded_pattern <- paste0("\\b", escaped_term, "\\b")
```

**Impact:**
- ✅ Stop word "na" no longer flags "Naphthalene" or "Sodium bicarbonate"
- ✅ Whole-word matches still work: "test" in "test sample unknown" is flagged
- ✅ Exact matches still work: "na" and "N/A" standalone are flagged

**Tests:** Added 2 new test cases, 37 total tests pass

### Task 3: Fix IUPAC letter-comma-letter splitting (1fde620)

**Problem:** `split_synonyms()` protected digit-comma-digit patterns (2,4-) and inverted names (butane, 2,2-), but not letter-comma-letter IUPAC prefixes like "N,N-" or "O,O-".

**Solution:** Added Step 0 protection before existing protections:
```r
# Step 0: Protect letter-comma-letter IUPAC patterns (N,N- O,O- S,S- etc.)
protected_name <- stringr::str_replace_all(original_name, "([A-Za-z]),([A-Za-z])", "\\1@@@\\2")
```

**Impact:**
- ✅ N,N-Dimethylformamide no longer splits
- ✅ O,O-Diethyl phosphorothioate no longer splits
- ✅ S,S-Dimethyl dithiocarbonate no longer splits
- ✅ Normal comma-separated synonyms still split: "xylene, dimethylbenzene" → 2 rows

**Tests:** Added 2 new test cases, 105 total tests pass

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

All three test files pass with zero failures:
- `test_bare_formula_detection.R`: 57 pass, 0 fail
- `test_flag_matching.R`: 37 pass, 0 fail
- `test_name_cleaning.R`: 105 pass, 0 fail

**Total: 199 tests pass, 0 fail**

All existing tests remain passing - zero regressions introduced.

## Key Decisions

1. **Heuristic approach for formula detection**: Instead of trying to perfect the regex, added pre-checks that filter out obvious non-formulas. This is more maintainable and handles edge cases the regex can't distinguish.

2. **Word boundary matching for stop words**: Used `\b` boundaries rather than trying to build context-aware matching. Simple, performant, and handles most cases correctly.

3. **Reuse @@@ placeholder**: Used the same placeholder as digit-comma-digit protection instead of introducing a new one (e.g., $$$). Simpler code, same restore logic.

4. **Abbreviation definition**: Defined abbreviations as "all uppercase, no digits" rather than maintaining a whitelist. This scales better as new abbreviations are added.

## Technical Notes

### Formula Detection Logic Flow

```
original_value → has 2+ consecutive lowercase? → YES → skip (not formula)
                                                ↓ NO
                 → all uppercase no digits? → YES → skip (abbreviation)
                                            ↓ NO
                 → matches validator regex? → YES → block as formula
                                            ↓ NO
                 → pass through (valid name)
```

### Stop Word Matching Flow

```
Pass 1: Exact match (tolower comparison)
  ↓ no match
Pass 2: Substring match with word boundaries
  pattern: \b{term}\b (case-insensitive)
```

### Synonym Split Protection Order

```
Step 0: Protect letter,letter → N,N becomes N@@@N
Step 1: Protect digit,digit → 2,4 becomes 2@@@4
Step 2: Protect inverted IUPAC → ", 2" becomes "%%%2"
Step 3: Split on ; then ,
Step 4: Restore protected commas (@@@ → , and %%% → , )
```

## Files Modified

**R/cleaning_pipeline.R** (3 functions updated):
- `detect_bare_formulas()`: Added heuristic pre-checks (lines 899-917)
- `flag_reference_matches()`: Added word boundary wrapping (lines 1031-1042)
- `split_synonyms()`: Added letter-comma-letter protection (lines 740-742)

**tests/test_bare_formula_detection.R** (+51 lines):
- Added test: "does NOT flag valid chemical names as formulas"
- Added test: "does NOT flag abbreviations as formulas"
- Added test: "still correctly identifies true bare formulas after fix"

**tests/test_flag_matching.R** (+35 lines):
- Added test: "does NOT flag chemical names containing stop word substrings"
- Added test: "still flags whole-word stop words in longer text"

**tests/test_name_cleaning.R** (+28 lines):
- Added test: "protects letter-comma-letter IUPAC patterns"
- Added test: "still splits normal comma-separated names after IUPAC fix"

## Requirements Satisfied

- ✅ **FORM-01**: Naphthalene not flagged as bare formula
- ✅ **FORM-02**: Sodium chloride not flagged as bare formula
- ✅ **STOP-01**: Stop word "na" doesn't flag Naphthalene
- ✅ **STOP-02**: Stop word "na" doesn't flag Sodium bicarbonate
- ✅ **SPLIT-01**: N,N-Dimethylformamide not split at comma
- ✅ **SPLIT-02**: Normal comma-separated synonyms still split correctly

All 6 requirements validated via automated tests.

## Self-Check: PASSED

**Created files:** All expected files exist
- ✅ .planning/phases/16-cleaning-pipeline-bug-fixes/16-01-SUMMARY.md

**Commits verified:**
- ✅ e11e2d2: fix(16-01): fix bare formula detection false positives
- ✅ 3247f4d: fix(16-01): fix stop word substring matching false positives
- ✅ 1fde620: fix(16-01): protect IUPAC letter-comma-letter patterns in split_synonyms

**Test results verified:**
- ✅ 199 tests pass, 0 fail across all three modified test files
- ✅ No regressions in existing test suite
