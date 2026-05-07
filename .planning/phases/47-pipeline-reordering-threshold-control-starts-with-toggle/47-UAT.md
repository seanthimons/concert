---
status: complete
phase: 47-pipeline-reordering-threshold-control-starts-with-toggle
source: 47-01-SUMMARY.md, 47-02-SUMMARY.md
started: 2026-05-07T00:00:00-04:00
updated: 2026-05-07T00:15:00-04:00
---

## Current Test

[testing complete]

## Tests

### 1. Cold Start Smoke Test
expected: Kill any running app. Start fresh with `chemreg::run_app()`. App boots without errors and reaches "Listening on" with no warnings about missing inputs or modules.
result: pass

### 2. Search Settings Accordion Visible in Pre-Flight Modal
expected: Upload a file, tag columns, and open the pre-flight cleaning modal. A third accordion panel labeled "Search Settings" appears. It contains a WQX fuzzy threshold slider (range 0.50-1.00, default 0.85), a synced numeric input beside it, and a CompTox starts-with checkbox (default unchecked/OFF).
result: pass

### 3. WQX Threshold Slider-Numeric Sync
expected: Move the WQX threshold slider to a new value (e.g. 0.70). The numeric input updates to match. Type a value into the numeric input (e.g. 0.90). The slider moves to match. Both stay in lockstep.
result: pass

### 4. Starts-With Toggle Default OFF
expected: When the pre-flight modal opens, the CompTox starts-with checkbox is unchecked by default. The curation can run without enabling it.
result: pass

### 5. Curation Runs with Default Settings
expected: With threshold at 0.85 and starts-with OFF, click Start Curation. Pipeline completes. The notification string includes a WQX match count (e.g. "X CAS, Y WQX, Z starts-with" or similar). Starts-with count should be 0 since the toggle is off.
result: pass

### 6. Curation Runs with Starts-With Enabled
expected: Set starts-with checkbox ON, then run curation again. The notification now shows a non-zero starts-with count (if matching data exists). WQX matches still appear.
result: pass

### 7. WQX Threshold Affects Match Count
expected: Run curation with threshold at 0.85, note WQX match count. Then re-run with threshold lowered to 0.60. The WQX match count increases with the lower threshold (more lenient matching finds more matches).
result: pass

## Summary

total: 7
passed: 7
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none yet]
