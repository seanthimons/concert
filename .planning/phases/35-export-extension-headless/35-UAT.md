---
status: testing
phase: 35-export-extension-headless
source: 35-01-SUMMARY.md, 35-02-SUMMARY.md
started: 2026-04-17T12:00:00Z
updated: 2026-04-21T12:00:00Z
---

## Current Test

number: 4
name: Headless Curation with Harmonize Pipeline
expected: |
  Running curate_headless() with harmonize=TRUE, providing unit_map and corrections, executes the full pipeline: corrections -> numeric parsing -> unit harmonization -> ToxVal schema mapping. The function returns a list with data containing the 56-column ToxVal tibble and a harmonize_audit entry.
awaiting: user response

## Tests

### 1. Cold Start Smoke Test
expected: Kill any running Shiny app. Start chemreg from a fresh R session. The app boots without errors and reaches "Listening on" without crashes. This catches missing imports (e.g., arrow), broken module wiring, or load-order issues introduced by the export changes.
result: pass

### 2. Excel Export Produces 8 Sheets
expected: Upload a chemical inventory file in the Shiny app, run curation, and download the Excel export. The exported XLSX should contain 8 sheets (up from 7), with the 8th sheet named "ToxVal Output".
result: issue
reported: "CSV and excel button do not work. Curated results do not show."
severity: blocker

### 3. Sheet 8 Placeholder When No Harmonization
expected: When exporting without running harmonization first, Sheet 8 "ToxVal Output" should contain a single-row placeholder message saying "Harmonization not run" rather than being empty or causing an error.
result: issue
reported: "Curated results do not show, CSV and Excel button are disabled as before. CSV button is also misaligned."
severity: blocker

### 4. Headless Curation with Harmonize Pipeline
expected: Running curate_headless() with harmonize=TRUE, providing unit_map and corrections, executes the full pipeline: corrections -> numeric parsing -> unit harmonization -> ToxVal schema mapping. The function returns a list with data containing the 56-column ToxVal tibble and a harmonize_audit entry.
result: [pending]

### 5. Parquet Export from Headless Pipeline
expected: When curate_headless() runs with harmonize=TRUE and format="parquet", a _toxval.parquet file is written alongside the XLSX output. The parquet file preserves all 56 columns with correct types and values matching the in-memory tibble.
result: [pending]

### 6. CSV Export Fallback
expected: When curate_headless() runs with harmonize=TRUE and format="csv", a _toxval.csv file is written instead of parquet. When format="both", both parquet and CSV files are produced.
result: [pending]

### 7. Format Validation
expected: Calling curate_headless() with an invalid format value (e.g., format="json") raises an error immediately (fail-fast), before any processing begins.
result: [pending]

### 8. Headless Return Without Harmonize
expected: When curate_headless() runs with harmonize=FALSE (the default), the function returns data containing the resolution_state (cleaned data) as before, with no harmonization artifacts or parquet/csv files produced. Backward compatibility is preserved.
result: [pending]

## Summary

total: 8
passed: 1
issues: 2
pending: 5
skipped: 0
blocked: 0

## Gaps

- truth: "Excel export produces 8 sheets with 8th named ToxVal Output"
  status: failed
  reason: "User reported: CSV and excel button do not work. Curated results do not show."
  severity: blocker
  test: 2
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "Sheet 8 placeholder when no harmonization run"
  status: failed
  reason: "User reported: Curated results do not show, CSV and Excel button are disabled as before. CSV button is also misaligned."
  severity: blocker
  test: 3
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""
