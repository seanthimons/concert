---
status: partial
phase: 51-row-flagging
source:
  - 51-02-SUMMARY.md
started: 2026-05-18
updated: 2026-05-18
---

# Phase 51 Human UAT

## Current Test

number: 2
name: Batch Selected Visible Rows
expected: |
  Selected visible Review Results rows can be batch flagged or cleared.
awaiting: user response

## Tests

### 1. Modal Row Flagging
expected: Existing row review modal can set BAD, FOLLOW-UP, VERIFIED, and Unset.
result: pass

### 2. Batch Selected Visible Rows
expected: Selected visible Review Results rows can be batch flagged or cleared.
result: issue
reported: "Some sort of filter against the curated results table is locking me into a state where I can't apply bulk flags. We probably need a clear filter button."
severity: major

### 3. Filtered Selection Scope
expected: When the table is filtered or searched, batch flagging changes only selected visible rows.
result: pending

### 4. Session Persistence
expected: Flags remain after navigating away from Review Results and back during the same session.
result: pending

### 5. Export Persistence
expected: Downloaded Excel Curated Data contains `row_flag`.
result: pending

### 6. needs_review Independence
expected: A resolved row marked BAD still has `needs_review = FALSE`.
result: pending

## Summary

total: 6
passed: 1
issues: 1
pending: 4
skipped: 0
blocked: 0

## Gaps

- truth: "Selected visible Review Results rows can be batch flagged or cleared."
  status: failed
  reason: "User reported: Some sort of filter against the curated results table is locking me into a state where I can't apply bulk flags. We probably need a clear filter button."
  severity: major
  test: 2
  artifacts:
    - path: "R/mod_review_results.R"
      issue: "Bulk row flagging depends on reactable selection state, but selection is only enabled when the server-side error filter is active and client-side filters have no explicit reset control."
  missing:
    - "Enable row selection for the curated results table outside error-filter mode."
    - "Add a Clear Filters action that clears reactable column filters and resets the server-side error filter state."
