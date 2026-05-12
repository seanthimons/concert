---
status: complete
phase: 14-multi-sheet-export-re-import
source: [14-01-SUMMARY.md, 14-02-SUMMARY.md]
started: 2026-03-09T16:00:00Z
updated: 2026-03-09T16:00:00Z
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

[testing complete]

## Tests

### 1. Cold Start Smoke Test
expected: Kill any running Shiny app. Start the application from scratch with shiny::runApp(). Server boots without errors and shows "Listening on http://..." message. No missing source() files, no icon errors, no module wiring failures.
result: pass

### 2. 7-Sheet Export Download
expected: Upload a CSV file, run through the curation pipeline, go to Review Results tab, click the download/export button. The downloaded .xlsx file contains exactly 7 sheets: Raw Data, Curated Data, Summary, Cleaning Audit, Reference Lists, Column Tags, Pipeline Config.
result: pass

### 3. Pipeline Config Marker
expected: Open the exported .xlsx file, go to the "Pipeline Config" sheet. It contains a row with concert_export = TRUE and a timestamp.
result: pass

### 4. Config Import Control Visible
expected: In the sidebar, below the main file upload, there is an "Import Configuration" section with a file input that accepts .xlsx files and help text explaining it restores settings from a previous export.
result: pass

### 5. Valid CONCERT Export Import
expected: Upload a previously exported CONCERT .xlsx file via the config import control. A modal dialog appears with checkboxes for "Reference Lists" and "Column Tags", allowing selective import. Clicking confirm applies the selected items.
result: pass

### 6. Non-CONCERT File Rejection
expected: Upload a regular (non-CONCERT) .xlsx file via the config import control. A warning notification appears indicating the file is not a valid CONCERT export. No modal appears.
result: pass

## Summary

total: 6
passed: 6
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
