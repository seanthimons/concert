---
phase: 11-cas-pipeline
plan: 01
subsystem: data-cleaning
tags: [cas-numbers, comptoxr, data-validation, audit-trail, tdd]

# Dependency graph
requires:
  - phase: 10-cleaning-infrastructure
    provides: "Basic cleaning pipeline with unicode and text normalization"
provides:
  - "CAS-RN normalization and validation using ComptoxR"
  - "CAS extraction from text columns with auto-tagging"
  - "Multi-CAS detection and flagging"
  - "Row lineage tracking via original_row_id"
  - "Tag map support in cleaning pipeline"
affects: [11-02-cas-ui, 12-synonym-splitting, 13-flagging-system]

# Tech tracking
tech-stack:
  added: [ComptoxR]
  patterns:
    - "Tag map pattern for column type tracking (CASRN/Name/Other)"
    - "TDD with RED-GREEN-REFACTOR cycle for data pipeline functions"
    - "Audit trail generation for CAS transformations"

key-files:
  created: [tests/test_cas_pipeline.R]
  modified: [R/cleaning_pipeline.R, tests/test_cleaning_pipeline.R]

key-decisions:
  - "Use ComptoxR directly for CAS operations (as_cas, extract_cas) per user decision"
  - "WIDE data shape for multi-CAS (new columns, not new rows) validated against EPA scripts"
  - "Auto-tag rescued CAS columns as CASRN for downstream multi-CAS detection"
  - "Manual audit trail building for normalize_cas_fields to handle NA transitions correctly"

patterns-established:
  - "Tag map pattern: Named list mapping column names to types (CASRN, Name, Other)"
  - "CAS pipeline functions return list(cleaned_data, audit_trail, new_tags) for composability"
  - "Backward compatibility: tag_map=NULL skips CAS steps, preserves Phase 10 behavior"

requirements-completed: [CAS-01, CAS-02, CAS-03, CAS-04]

# Metrics
duration: 8.6min
completed: 2026-03-06
---

# Phase 11 Plan 01: CAS Pipeline Core Functions

**CAS-RN normalization, validation, extraction from text, and multi-CAS detection using ComptoxR with full audit trail**

## Performance

- **Duration:** 8.6 min (514s)
- **Started:** 2026-03-06T15:06:15Z
- **Completed:** 2026-03-06T15:14:49Z
- **Tasks:** 2 (TDD: RED + GREEN)
- **Files modified:** 3

## Accomplishments

- Implemented 4 CAS pipeline functions: inject_row_lineage, normalize_cas_fields, rescue_cas_from_text, detect_multi_cas
- Extended run_cleaning_pipeline with tag_map parameter for CAS processing
- Comprehensive test suite with 65 passing tests covering all CAS requirements
- Maintained backward compatibility (tag_map=NULL preserves Phase 10 behavior)
- Zero regressions in existing test suite (40 tests)

## Task Commits

Each task was committed atomically following TDD protocol:

1. **Task 1: Write CAS pipeline tests (RED phase)** - `6c2aa36` (test)
2. **Task 2: Implement CAS pipeline functions (GREEN phase)** - `5299003` (feat)

_TDD workflow: Tests written first (RED), implementation followed (GREEN), no refactoring needed_

## Files Created/Modified

- `tests/test_cas_pipeline.R` - 65 comprehensive tests for CAS requirements (CAS-01 through CAS-04)
- `R/cleaning_pipeline.R` - Added 4 CAS functions + updated run_cleaning_pipeline with tag_map support
- `tests/test_cleaning_pipeline.R` - Updated to reflect new original_row_id column in pipeline output

## Decisions Made

**Use manual audit trail building for normalize_cas_fields:**
- ComptoxR::as_cas() converts invalid CAS and placeholders to NA
- Standard build_audit_trail() treats NA-to-NA as "no change"
- Need to track "no cas" → NA transitions for audit completeness
- Solution: Custom audit logic in normalize_cas_fields that detects non-NA → NA conversions

**Auto-tag rescued CAS columns:**
- rescue_cas_from_text creates cas_extract_{source} columns
- Returns new_tags list mapping these columns to "CASRN"
- Tag map updated before detect_multi_cas so rescued CAS counted correctly
- Enables downstream UI to display rescued columns as CAS fields

**Backward compatibility design:**
- tag_map parameter defaults to NULL in run_cleaning_pipeline
- When NULL: only basic cleaning (unicode, trim) - identical to Phase 10
- When provided: runs full CAS pipeline after basic cleaning
- Preserves existing calls without breaking changes

## Deviations from Plan

None - plan executed exactly as written. All functions implemented as specified, all tests pass, no auto-fixes needed.

## Issues Encountered

**ComptoxR namespace warning:**
- Warning: "replacing previous import 'jsonlite::flatten' by 'purrr::flatten' when loading 'ComptoxR'"
- Non-blocking: Tests pass, functions work correctly
- Impact: Informational only, no functional issues
- Resolution: Accepted as known ComptoxR package behavior

**Test file structure:**
- Plan specified tests/test_cas_pipeline.R for CAS tests
- Existing tests in tests/test_cleaning_pipeline.R updated for row lineage
- Both test suites maintained separately for clarity
- Total: 105 tests pass (65 CAS + 40 existing)

## User Setup Required

None - no external service configuration required. ComptoxR is an R package installed via standard R package management.

## Next Phase Readiness

**Ready for Phase 11 Plan 02 (CAS UI Module):**
- All CAS pipeline functions tested and working
- Tag map structure defined and validated
- New columns (cas_extract_*, multi_cas, multi_cas_count) ready for UI display
- Audit trail captures all CAS transformations for user review

**Provides for downstream phases:**
- normalize_cas_fields: CAS validation and format standardization
- rescue_cas_from_text: Recovers CAS from name/description columns
- detect_multi_cas: Flags rows needing user decision
- Tag map pattern: Column type tracking for UI configuration

**No blockers.** CAS pipeline core complete, ready for UI integration.

---
*Phase: 11-cas-pipeline*
*Completed: 2026-03-06*
