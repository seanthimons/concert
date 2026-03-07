---
phase: 13-reference-filters-editable-lists
plan: 01
subsystem: data-cleaning-pipeline
tags: [tdd, reference-lists, provenance, formula-detection, flag-matching]
dependencies:
  requires: [12-02]
  provides: [provenance-tracked-references, bare-formula-detection, reference-flag-matching]
  affects: [R/cleaning_reference.R, R/cleaning_pipeline.R]
tech_stack:
  added: []
  patterns: [provenance-tracking, exact-then-substring-matching, soft-delete-via-active-flag]
key_files:
  created:
    - tests/test_reference_provenance.R
    - tests/test_bare_formula_detection.R
    - tests/test_flag_matching.R
  modified:
    - R/cleaning_reference.R
    - R/cleaning_pipeline.R
    - tests/test_cleaning_reference.R
decisions:
  - reference-lists-use-tibble-format-with-provenance
  - bare-formula-detection-uses-comptoxr-validator-regex
  - exact-match-takes-priority-over-substring
  - first-flag-wins-bare-formula-blocks-before-reference-warnings
  - soft-delete-via-active-false-column
metrics:
  duration: 986s
  tasks_completed: 2
  tests_added: 3
  test_assertions: 110
  commits: 3
  completed_date: 2026-03-07T16:00:21Z
---

# Phase 13 Plan 01: Reference Provenance & Formula Detection Summary

**One-liner:** Provenance-tracked reference lists (term, source, active) with bare molecular formula detection via ComptoxR validator and exact-then-substring flag matching.

## What Was Built

Extended the data cleaning pipeline with three key backend capabilities:

1. **Provenance-tracked reference lists** - All reference loaders (`load_stop_words`, `load_block_patterns`, `load_functional_categories`) now return tibbles with `(term, source, active)` columns instead of character vectors. Source tracks origin (`app_default`, `comptoxr`, `user`) and `active` column enables soft delete for UI editors in Plan 02.

2. **Bare molecular formula detection** - New `detect_bare_formulas()` function uses ComptoxR's internal validator regex to identify bare formulas like H2O, NaCl, CuSO4. These are blocked (name set to NA, preserved in `formula_blocked_{col}`) because they lack chemical context. Does NOT match chemical names like "acetone" or mixed text like "CuSO4 pentahydrate".

3. **Reference list flag matching** - New `flag_reference_matches()` function performs two-pass matching (exact first, then substring) against provenance-tracked reference lists. Case-insensitive matching with match type labels `[exact]` or `[substring]`. Only matches `active=TRUE` entries. Records match source and type in audit trail. First flag wins - bare formula blocking takes priority over reference warnings.

## Tasks Completed

### Task 1: Extend reference loaders with provenance + add bare formula detection and flag matching functions
- **Type:** TDD (RED → GREEN → REFACTOR)
- **Files:** R/cleaning_reference.R, R/cleaning_pipeline.R, tests/test_reference_provenance.R, tests/test_bare_formula_detection.R, tests/test_flag_matching.R
- **Commits:**
  - `2067206` - RED: Failing tests for provenance, bare formulas, and flag matching
  - `864fd5f` - GREEN: Implementation complete (all tests pass)
- **Tests:** 110 assertions across 3 new test files
- **Verification:** All tests pass with 0 failures

### Task 2: Run full test suite and verify no regressions
- **Type:** Regression testing
- **Files:** tests/test_cleaning_reference.R
- **Commits:**
  - `ae7f3bd` - Updated existing tests for tibble format
- **Tests:** 28 passes in test_cleaning_reference.R, 40 passes in test_cleaning_pipeline.R
- **Verification:** No regressions - all existing tests pass after format change

## Deviations from Plan

None - plan executed exactly as written. TDD cycle followed precisely (RED → GREEN), all acceptance criteria met, no blocking issues encountered.

## Key Technical Decisions

### 1. Reference lists use tibble format with provenance
**Decision:** Changed reference list loaders from returning character vectors to tibbles with `(term, source, active)` columns.

**Rationale:** Enables UI editors in Plan 02 to show where each entry came from and support soft/hard delete. `active` column allows soft delete without breaking existing references.

**Impact:** Breaking change - existing cache files must be deleted (noted in function docstrings). `load_or_fetch_reference()` is format-agnostic and doesn't need changes.

**Alternatives considered:** Keep character vectors and add separate metadata file. Rejected - tibble approach is cleaner and enables filtering via `dplyr::filter(active == TRUE)`.

### 2. Bare formula detection uses ComptoxR validator regex
**Decision:** Extract validator regex from `ComptoxR:::create_formula_extractor_final()` and apply to name fields after space/dot removal.

**Rationale:** Reuses ComptoxR's battle-tested formula validation logic. Matches entire cleaned string against regex to ensure it's ONLY a formula (no mixed text).

**Impact:** Requires ComptoxR package. Gracefully degrades if unavailable (logs warning, returns data unchanged).

**Alternatives considered:** Write custom regex. Rejected - reinventing the wheel, ComptoxR's regex handles edge cases (charges, groups, etc.).

### 3. Exact match takes priority over substring
**Decision:** Two-pass matching - exact match first (`tolower(name) == tolower(term)`), then substring match only if no exact match found.

**Rationale:** User expectation - "plasticizer" should be labeled `[exact]` not `[substring]`. Avoids ambiguity in audit trail.

**Impact:** Minimal - adds one extra loop per name value. Performance acceptable for reference lists under 10,000 entries.

**Alternatives considered:** Single-pass substring matching. Rejected - loses information about match quality.

### 4. First flag wins - bare formula blocks before reference warnings
**Decision:** `flag_reference_matches()` checks if `cleaning_flag` already set and skips flagging if so.

**Rationale:** Bare formula blocking is higher priority than reference list warnings. Prevents overwriting BLOCK with WARN.

**Impact:** Call order matters - `detect_bare_formulas()` MUST run before `flag_reference_matches()` in pipeline.

**Alternatives considered:** Flag concatenation (e.g., "BLOCK: bare formula; WARN: functional category"). Rejected - UI can't display multiple flags cleanly.

### 5. Soft delete via active=FALSE column
**Decision:** `flag_reference_matches()` only matches entries where `active == TRUE`. Inactive entries are skipped.

**Rationale:** Enables UI editors to soft-delete entries without breaking existing data. User can disable "plasticizer" without removing it from the reference list.

**Impact:** UI must provide toggle UI. Hard delete (row removal) still possible via explicit delete button.

**Alternatives considered:** Physical row deletion. Rejected - can't undo, breaks audit trail.

## Testing Coverage

**New test files:**
- `test_reference_provenance.R` - 40 passes - Verifies tibble structure, column names/types, provenance values
- `test_bare_formula_detection.R` - 39 passes - H2O/NaCl/CuSO4 blocked, acetone/ethanol not blocked, NA handling, multi-column support
- `test_flag_matching.R` - 31 passes - Exact/substring matching, case-insensitive, active-only filtering, match source/type in audit trail

**Updated test files:**
- `test_cleaning_reference.R` - 28 passes - Updated to expect tibbles instead of character vectors

**Regression tests:**
- `test_cleaning_pipeline.R` - 40 passes - No regressions in existing pipeline functions

**Total:** 178 passing assertions, 0 failures

## Files Modified

**R/cleaning_reference.R** (+34, -20 lines)
- `load_stop_words()` - Returns tibble with 15 stop words, all `source="app_default"`, `active=TRUE`
- `load_block_patterns()` - Returns tibble with 7 regex patterns, all `source="app_default"`, `active=TRUE`
- `load_functional_categories()` - Returns tibble from ComptoxR with `source="comptoxr"`, `active=TRUE` (or empty tibble with correct columns if unavailable)
- Added `library(dplyr)` for provenance column operations
- Added cache format change notes in docstrings

**R/cleaning_pipeline.R** (+258, -0 lines)
- `detect_bare_formulas(df, name_cols)` - New function, extracts validator regex from ComptoxR, identifies bare formulas (H2O, NaCl), blocks detected rows, preserves in `formula_blocked_{col}` columns
- `flag_reference_matches(df, name_cols, reference_list, flag_type, flag_label)` - New function, two-pass matching (exact then substring), case-insensitive, only matches `active=TRUE` entries, records match source/type in audit trail

**tests/test_reference_provenance.R** (+129 lines)
- Tests for tibble structure, column names/types
- Tests for provenance values (app_default, comptoxr)
- Tests for empty tibble fallback when ComptoxR unavailable

**tests/test_bare_formula_detection.R** (+152 lines)
- Tests for H2O, NaCl, CuSO4 detection
- Tests for acetone, ethanol, mixed text NOT detected
- Tests for NA handling, empty dataframes, multi-column support

**tests/test_flag_matching.R** (+178 lines)
- Tests for exact/substring matching
- Tests for case-insensitive matching
- Tests for active-only filtering, soft delete support
- Tests for match source/type in audit trail
- Tests for first-flag-wins behavior

**tests/test_cleaning_reference.R** (+20, -18 lines)
- Updated assertions to expect tibbles instead of character vectors
- Changed `result` checks to `result$term` for term column access

## Integration Notes

**For Plan 02 (Reference List Editors):**
- Reference lists are now tibbles with `(term, source, active)` columns
- UI can filter by source (`comptoxr`, `app_default`, `user`)
- UI can toggle `active` for soft delete
- UI can add new entries with `source="user"`, `active=TRUE`

**For Pipeline Integration:**
- Call `detect_bare_formulas()` BEFORE `flag_reference_matches()` (first flag wins)
- Both functions add `cleaning_flag` column if it doesn't exist
- Both functions create audit trail entries with match source/type
- Both functions handle NA values gracefully

**Cache Invalidation:**
- Existing reference list cache files (.rds) must be deleted on first run after upgrade
- `load_or_fetch_reference()` will regenerate with new format automatically
- No user action needed if cache directory is empty

## Performance

**Bare formula detection:** O(n * m) where n = rows, m = name columns. Regex match per value. Acceptable for datasets under 100,000 rows.

**Flag matching:** O(n * m * r) where n = rows, m = name columns, r = reference entries. Two-pass matching per value. Acceptable for reference lists under 10,000 entries.

**Optimization opportunities (if needed):**
- Pre-compile regex patterns for bare formula detection
- Use hash table for exact match lookup (O(1) instead of O(r))
- Parallelize matching across columns with `furrr::future_map()`

## Next Steps

**Immediate (Plan 02):**
- Build Shiny modules for editable reference list tables
- Implement rhandsontable for in-app editing
- Add Add/Delete/Toggle Active buttons
- Wire to cleaning pipeline in mod_clean_data

**Future (Phase 14+):**
- Add user-uploaded reference lists (CSV import)
- Add reference list versioning (track changes over time)
- Add export reference lists (download as CSV)

## Self-Check

**Files created:**
- [X] tests/test_reference_provenance.R exists
- [X] tests/test_bare_formula_detection.R exists
- [X] tests/test_flag_matching.R exists

**Commits exist:**
- [X] 2067206: RED phase commit
- [X] 864fd5f: GREEN phase commit
- [X] ae7f3bd: Regression test update commit

**Tests pass:**
- [X] test_reference_provenance.R: 40 passes
- [X] test_bare_formula_detection.R: 39 passes
- [X] test_flag_matching.R: 31 passes
- [X] test_cleaning_reference.R: 28 passes (updated)
- [X] test_cleaning_pipeline.R: 40 passes (no regressions)

**Functions work:**
- [X] load_stop_words() returns tibble with (term, source, active)
- [X] detect_bare_formulas("H2O") blocks correctly
- [X] detect_bare_formulas("acetone") does NOT block
- [X] flag_reference_matches() performs exact-then-substring matching

## Self-Check: PASSED

All files created, commits exist, tests pass, functions work as specified.
