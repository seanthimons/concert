---
status: complete
phase: 05-shiny-integration
source: [05-01-SUMMARY.md, 05-02-SUMMARY.md]
started: 2026-03-01T05:30:00Z
updated: 2026-03-01T05:45:00Z
---

## Current Test

[testing complete]

## Tests

### 1. App starts without errors
expected: Run `shiny::runApp()`. The app launches without errors. All source files load correctly (consensus.R, curation.R). No missing function or package errors in console.
result: pass

### 2. Dedup preview on tag apply
expected: Upload a file (e.g., `data/sample_messy.csv`). Navigate to Tag Columns tab. Tag at least one column as "Name" and/or one as "CASRN". Click Apply Tags. Navigate to Run Curation tab. You should see dedup preview text showing unique counts (e.g., "5 unique names, 3 unique CAS to look up") below the tag summary.
result: pass

### 3. Pipeline progress during curation
expected: On the Run Curation tab, click Start Curation. A progress modal appears with step-by-step updates as each tier runs (dedup, exact match, starts-with, CAS validation, consensus). The Start Curation button is disabled during execution and re-enabled when complete.
result: pass

### 4. Auto-navigate to Review Results
expected: After pipeline completes, the Review Results tab should become visible and either auto-navigate or be ready to click. No errors shown.
result: pass

### 5. Consensus value boxes
expected: On the Review Results tab, 4 value boxes appear at the top: Agree (green), Disagree (red), Needs Review (yellow), Match Rate (blue). Each shows a count or percentage.
result: pass

### 6. Color-coded table rows
expected: The results table shows rows with subtle background colors based on consensus status: green tint for agree rows, red tint for disagree rows, gray for single/error.
result: pass

### 7. Status badges in table
expected: The consensus_status column in the table displays colored badges (not plain text): green for "agree", red for "disagree", yellow/orange for "agree_caveat", gray for "single"/"error".
result: pass

### 8. Condensed table columns
expected: The table shows only original tagged columns + consensus_dtxsid + consensus_status + qc_tier + Resolution column. Internal audit columns (dtxsid_*, preferredName_*, rank_*, source_tier_*) are hidden from view.
result: pass
note: User flagged for future change — wants to revisit column visibility behavior after seeing results on messy data.

### 9. Per-row resolution dropdown
expected: If any disagree rows exist, they show a dropdown in the Resolution column with selectable DTXSID options (one per source column). Selecting an option from the dropdown updates the row — it should show a pin icon and the chosen DTXSID. The value boxes update to reflect the change.
result: pass
note: User flagged for follow-up — dropdown needs richer context (preferredName, rank, EPA QC level) for informed decisions.

### 10. En masse priority controls
expected: Above the results table, a "Column Priority" card shows the dtxsid columns in a numbered list with up/down buttons. Clicking up/down reorders the list. Clicking "Apply Priority" resolves non-pinned disagree rows using the priority order, and a notification shows how many rows were resolved.
result: pass

### 11. Pinned rows survive en masse
expected: If you manually resolved a row (via dropdown in Test 9), then apply en masse priority (Test 10), the manually resolved row should keep its chosen DTXSID (pin icon remains). Only non-pinned disagree rows should be affected by en masse.
result: pass

### 12. Excel export with audit trail
expected: Click the Download button. The exported Excel file has 3 sheets: "Curated Data" (full data with all audit columns including per-column DTXSIDs, consensus, qc_tier), "Summary" (consensus counts and match rate), "Column Tags" (tag mapping).
result: pass

## Summary

total: 12
passed: 12
issues: 0
pending: 0
skipped: 0

## User Feedback (for future work)

- **Test 8 (Column visibility):** User wants to change condensed table behavior after seeing results on messy data
- **Test 9 (Resolution dropdown):** Users need richer context in dropdown — preferredName, rank, EPA QC level — to make informed resolution decisions

## Gaps

[none]
