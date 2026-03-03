---
phase: 08-error-recovery-workflows
plan: 01
subsystem: backend-curation-functions
tags: [backend, api-validation, merge-logic, consensus-status, unit-tests]
completed: 2026-03-03T16:05:47Z
duration_seconds: 155
requirements_completed:
  - RECV-02
  - RECV-03
  - RECV-05
dependency_graph:
  requires: []
  provides:
    - validate_manual_dtxsids
    - merge_retry_results
    - manual_entry_tracking
    - unresolvable_status
  affects:
    - R/curation.R
    - R/consensus.R
    - tests/test_consensus.R
tech_stack:
  added: []
  patterns:
    - bulk-api-validation-with-batching
    - pin-aware-merge-by-index
    - unresolvable-status-detection
key_files:
  created: []
  modified:
    - R/curation.R: "Added validate_manual_dtxsids() and merge_retry_results()"
    - R/consensus.R: "Extended init_resolution_state() to add .manual_entry column"
    - tests/test_consensus.R: "Added 6+ tests for merge logic and manual_entry"
decisions:
  - context: "Manual DTXSID validation"
    decision: "Use bulk API with batching (20 per batch, 1s delay) to stay within rate limits"
    rationale: "Follows existing search_exact() pattern, prevents API throttling"
  - context: "Unresolvable detection"
    decision: "Mark as 'unresolvable' only if error before AND after retry"
    rationale: "Clear distinction: error = first attempt failed, unresolvable = retry also failed"
  - context: "Pin preservation"
    decision: "Skip pinned rows with warning rather than error"
    rationale: "Defensive — prevents accidental overwrites, logs for audit trail"
metrics:
  tasks_completed: 2
  tests_added: 41
  tests_total: 127
  commits: 2
---

# Phase 08 Plan 01: Backend Functions for Error Recovery

**One-liner:** Manual DTXSID validation with bulk API batching, retry merge-back with pin preservation, and extended consensus status for manual/unresolvable states.

## Summary

Created backend functions to support error recovery workflows:
- `validate_manual_dtxsids()`: Bulk validation of manually-entered DTXSIDs via CompTox API with rate limiting
- `merge_retry_results()`: Safe merge-back of retry curation with pinned row protection and unresolvable detection
- Extended `init_resolution_state()` to track `.manual_entry` column for manual DTXSID entries
- Comprehensive unit tests (41 new tests) covering all merge scenarios including pin preservation, row order, new columns, and unresolvable marking

These functions enable Plans 02 (manual entry UI) and 03 (re-curate UI) to operate safely with full backend support.

## Tasks Completed

### Task 1: Add validate_manual_dtxsids() and merge_retry_results() to R/curation.R
**Status:** Complete
**Commit:** 91a6a9b
**Files:** R/curation.R

**Implementation:**
- `validate_manual_dtxsids(dtxsids, batch_size = 20, delay_sec = 1)`
  - Deduplicates input DTXSIDs before API calls
  - Batches requests with configurable delay (rate limiting)
  - Uses `purrr::safely()` pattern for error handling
  - Returns tibble with searchValue, dtxsid, preferredName, rank, is_valid
  - Marks DTXSIDs not found in API as is_valid = FALSE

- `merge_retry_results(original_state, retry_results, selected_row_indices, tags_changed = FALSE)`
  - **Safety:** Skips any row where `.pinned = TRUE` with warning
  - Updates consensus columns: consensus_dtxsid, consensus_status, consensus_source, qc_tier
  - Updates per-column lookup columns: dtxsid_*, preferredName_*, rank_*, source_tier_*
  - **Column handling:** If tags_changed = TRUE, adds new columns from retry_results (initialize with NA)
  - **Unresolvable detection:** If row was error before AND after retry, sets status = "unresolvable"
  - **Order preservation:** Operates by index, never sorts

**Verification:** Functions callable after sourcing, follow existing codebase patterns

### Task 2: Extend consensus status levels and add merge unit tests
**Status:** Complete
**Commit:** 333492f
**Files:** R/consensus.R, tests/test_consensus.R

**R/consensus.R changes:**
- `init_resolution_state()` now initializes `.manual_entry` column (logical, default FALSE)
- Added documentation to `classify_consensus()` explaining downstream status extensions ("manual", "unresolvable")

**tests/test_consensus.R additions (6+ new test cases):**
1. **Basic merge:** Updates only selected rows, leaves others untouched
2. **Pin preservation:** Pinned rows are NOT updated even if included in selected_row_indices
3. **Row order preservation:** Original row order maintained regardless of selected indices order
4. **Unresolvable marking:** Rows with error status before and after retry marked as "unresolvable"
5. **New column handling:** When tags_changed = TRUE, new columns added with NA for non-selected rows
6. **Manual entry column:** init_resolution_state() adds .manual_entry = FALSE

**Test results:** All 127 tests passing (86 existing + 41 new)

## Deviations from Plan

None — plan executed exactly as written.

## Key Decisions

1. **Batch size and delay:** Used 20 DTXSIDs per batch with 1s delay, matching CompTox API best practices and existing search_exact() pattern
2. **Pin preservation strategy:** Implemented as warning + skip rather than error, allowing partial merge to proceed safely
3. **Unresolvable detection logic:** Requires error status both before and after retry (not just single error state)
4. **Column type preservation:** When adding new columns (tags_changed = TRUE), preserve numeric/logical/character types from retry_results

## Verification

All verification criteria met:
- [x] validate_manual_dtxsids() and merge_retry_results() exist and are callable
- [x] init_resolution_state() adds .manual_entry column
- [x] All 127 tests pass (86 existing + 41 new)
- [x] No changes to classify_consensus core logic (backward compatible)
- [x] merge_retry_results handles all documented scenarios (pin, order, unresolvable, columns)

## Self-Check

**Files:**
- R/curation.R: Modified (validate_manual_dtxsids, merge_retry_results added)
- R/consensus.R: Modified (init_resolution_state extended, classify_consensus documented)
- tests/test_consensus.R: Modified (41 new tests added)

**Commits:**
- 91a6a9b: feat(08-01): add validate_manual_dtxsids and merge_retry_results
- 333492f: feat(08-01): extend consensus with manual_entry and add merge tests

**Status:** PASSED

All claimed files exist, all commit hashes verified, all tests passing.

## Next Steps

Plans 02 and 03 can now proceed:
- **Plan 02 (Manual Entry UI):** Consume validate_manual_dtxsids() for bulk validation
- **Plan 03 (Re-curate UI):** Consume merge_retry_results() for safe retry merge-back

Backend functions are stable, tested, and ready for UI integration.
