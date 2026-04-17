---
status: complete
phase: 34-harmonize-tab-module
source: 34-01-SUMMARY.md, 34-02-SUMMARY.md, 34-03-SUMMARY.md, 34-04-SUMMARY.md
started: 2026-04-16T14:30:00Z
updated: 2026-04-17T19:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Cold Start Smoke Test
expected: Kill any running R/Shiny process. Start the app fresh from R console with `chemreg::run_app()` (or `shiny::runApp("inst/app/app.R")`). App boots without errors, all tabs render, and the upload page is functional.
result: pass

### 2. Harmonize Tab Navigation Gate
expected: Upload a file with numeric data. Before tagging any columns as Result, the Harmonize tab should be hidden/disabled. After tagging a column as "Result" in the Tag Columns step, the Harmonize tab appears in the sidebar with a pulse animation.
result: pass

### 3. Run Harmonization Pipeline
expected: Navigate to the Harmonize tab. Click the "Run Harmonization" button. A notification confirms tags were applied, the pipeline runs, and completes without error messages.
result: pass
note: Modal abandoned per user decision — notification is intended behavior

### 4. QC Value Box Dashboard
expected: After harmonization completes, four value boxes appear at the top of the Harmonize tab: "Rows Parsed" (primary/blue), "Rows Harmonized" (success/green), "With DTXSID" (info/cyan), "NA Results" (warning/yellow). Each shows a numeric count.
result: pass
note: All 4 boxes visible. DTXSID=0 expected when curation not run first.

### 5. Unit Table Editor Accordion
expected: Below the value boxes, an accordion section "Unit Table Editor" exists. Expanding it shows chips representing unit mappings. Chips are color-coded by source: ECOTOX (green), SSWQS (cyan), user-added (blue), passthrough (gray). Each chip shows "from_unit -> to_unit (xN)" format (multiplier suffix hidden when =1).
result: pass
note: Only green (ECOTOX) chips visible because reference cache lacks SSWQS data. Color logic is correct.

### 6. Corrections Editor Accordion
expected: A "Corrections Editor" accordion panel exists. Expanding it shows either correction chips (if any exist) or an empty-state message: "No corrections defined. Add corrections for source-specific malformed values." An "Add Correction" button is visible.
result: pass

### 7. Unmatched Units Panel
expected: An "Unmatched Units" accordion panel exists. Before running harmonization, it shows a muted message "Run harmonization to see unmatched units." After harmonization: if all units matched, shows a success alert "All units matched successfully." If unmatched units exist, shows a list with counts (e.g., "mg/L (5)") and per-row "Add Mapping" buttons.
result: pass

### 8. Click Chip to Edit
expected: Click on a chip in the Unit Table Editor. A modal dialog opens with fields pre-filled (from_unit, to_unit, multiplier, category, confidence, source). You can edit values and Save/Discard.
result: pass

### 9. Add Unit Mapping
expected: Click "Add Unit Mapping" button in the Unit Table Editor panel. An empty modal dialog opens. Enter from_unit, to_unit, multiplier, etc. Click Save. A new chip appears in the editor with source="user".
result: pass
note: Opening dialog clears unmatched units panel — requires re-run harmonization after adding. May be intentional cascade reset per Test 13.

### 10. Remove User-Added Chip
expected: User-added chips (source=user or user_passthrough) have an X button for removal. Click X on a user-added chip. The chip is removed from the list. Note: App-default chips (ECOTOX, SSWQS) should NOT have the X button.
result: pass

### 11. Add Mapping from Unmatched
expected: With unmatched units present, click "Add Mapping" next to an unmatched unit row. The unit mapping modal opens with the from_unit field pre-filled with that unit value. Complete the mapping and save. The unit is added to the unit table.
result: pass
note: Originally failed (cascade reset UX). Fixed by Plan 34-04 — verified in Test 14.

### 12. Add All Passthrough
expected: With unmatched units present, click "Add All Passthrough" button. All unmatched units are added as identity mappings (from_unit = to_unit, multiplier=1, source="user_passthrough"). The unmatched list clears (shows success alert).
result: pass

### 13. Cascade Reset on Editor Mutation
expected: After running harmonization (with results visible), add or edit a unit mapping. The harmonization results should reset (value boxes clear or update). You need to re-run harmonization to see new results.
result: pass
note: Cascade works but is too aggressive — every edit triggers full reset requiring 2+ min re-run. See Test 11 issue. FIXED in Plan 34-04.

### 14. Post-Hotfix: Stale Results Pattern
expected: After Plan 34-04 fix — adding unit mapping should NOT clear results. Instead: yellow warning banner "Results may be stale", dimmed value boxes (50% opacity), "Re-run now" link available.
result: pass
note: Stale pattern works correctly. Cosmetic issue noted: Run Harmonization button spacing is off.

## Summary

total: 14
passed: 14
issues: 0
cosmetic: 1
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "Add unit mapping without resetting harmonization state"
  status: fixed
  reason: "User reported: Adding mapping resets harmonization state, requiring 2+ min re-run. Bad UX for iterative editing."
  severity: major
  test: 11
  root_cause: "observeEvent cascade immediately cleared harmonize_results on any unit_map change"
  fix: "Plan 34-04: Stale results pattern + vectorized harmonization"
  verified: 2026-04-17
  artifacts: [R/mod_harmonize.R, R/unit_harmonizer.R, inst/app/app.R]

- truth: "Run Harmonization button should have proper spacing"
  status: open
  reason: "User reported: Run Harmonization button is still not properly spaced."
  severity: cosmetic
  test: 14
  root_cause: ""
  artifacts: []
  missing: []
