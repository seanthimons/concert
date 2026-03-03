---
status: complete
phase: 08-error-recovery-workflows
source: [08-01-SUMMARY.md, 08-02-SUMMARY.md, 08-03-SUMMARY.md]
started: 2026-03-03T16:30:00Z
updated: 2026-03-03T18:00:00Z
---

## Current Test

number: complete
name: All tests passed
awaiting: none

## Tests

### 1. Manual DTXSID Entry on Error Row
expected: Click consensus_dtxsid cell on an error row. Inline editor appears. Type a valid DTXSID (e.g., DTXSID7020182). Cell updates with value and shows a "queued" badge.
result: pass

### 2. DTXSID Format Validation
expected: Click consensus_dtxsid cell on an error row and type an invalid string (e.g., "NOTADTXSID" or "hello"). A warning notification should appear saying the format is invalid and expecting DTXSIDxxxxxxx pattern. The value should NOT be queued.
result: pass

### 3. Non-Error Row Edit Rejection
expected: Try to edit the consensus_dtxsid cell on a row that is NOT error/unresolvable (e.g., an "agree" or "single" row). Either the cell should not be editable, or a warning notification should appear saying only error rows can be manually edited.
result: pass

### 4. Validate All Button and Bulk Validation
expected: After entering one or more manual DTXSIDs on error rows, a "Validate All" button should become visible/enabled. Click it. A progress bar should appear showing validation progress. After completion, valid entries should change status to "manual" with a purple badge and show the preferredName. Invalid entries should trigger an error notification listing which entries failed.
result: pass

### 5. Show Errors Filter Toggle
expected: Click "Show Errors" button. The table should filter to show only error and unresolvable rows. The button label should change to "Show All". Click again to return to the full table view.
result: pass

### 6. Error Row Selection and Re-tag Modal
expected: With error filter active, click to select one or more error rows (multi-select). A "Re-tag Selected" button should appear. Click it. A modal should open showing column-to-tag dropdowns pre-populated with current tag assignments (Name, CASRN, Other, or blank).
result: pass

### 7. Re-curate Pipeline Execution
expected: In the re-tag modal, optionally change tag assignments, then click "Apply & Re-curate". A progress indicator should appear. The full curation pipeline runs on the selected subset. After completion, results merge back into the main table. The filter resets to show all rows. A notification shows how many were resolved vs unresolvable.
result: pass

### 8. Pin Preservation During Re-curation
expected: Before re-curating, resolve a disagree row by pinning a selection (so .pinned = TRUE). Then run re-curation on error rows. After merge, the pinned row should remain completely untouched with its original resolution.
result: pass

### 9. Unresolvable Status for Re-failed Rows
expected: After re-curation, any rows that were error before AND still error after retry should show "unresolvable" status with a dark red badge instead of plain "error". This distinguishes first-attempt failures from exhausted retries.
result: pass

### 10. Excel Export with New Statuses
expected: Download the Excel export after some manual and unresolvable resolutions exist. The needs_review column should flag both error AND unresolvable rows as TRUE. The summary sheet should include counts for "Manual" and "Unresolvable" categories.
result: pass

## Summary

total: 10
passed: 10
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
