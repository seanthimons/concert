---
status: partial
phase: 39-duration-conversion
source: [39-VERIFICATION.md]
started: 2026-04-26T00:00:00Z
updated: 2026-04-26T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Duration harmonization end-to-end in Shiny UI
expected: Upload a file with duration columns, tag one as Duration (numeric) and another as DurationUnit (string) in the Harmonize tab, run harmonization, and verify the exported ToxVal CSV has populated `study_duration_value` (hour-converted numeric) and `study_duration_units` ("hr") fields with correct values. E.g., "14 days" → study_duration_value=336, study_duration_units="hr".
result: [pending]

## Summary

total: 1
passed: 0
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps
