---
status: complete
phase: 16-cleaning-pipeline-bug-fixes
source: [16-01-SUMMARY.md, 16-02-SUMMARY.md]
started: 2026-03-10T17:15:00Z
updated: 2026-03-10T17:20:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Formula detection does not flag valid chemical names
expected: Upload or process data containing "Naphthalene" and "Sodium chloride" as chemical names through the cleaning pipeline. Neither should be flagged as a bare formula. They should pass through cleanly without warnings or removal.
result: pass

### 2. Formula detection still catches actual bare formulas
expected: Process data containing bare formulas like "C10H22", "NaCl", or "CaCl2" (without accompanying chemical names). These should be flagged/blocked as bare formulas by the pipeline.
result: pass

### 3. Stop word "na" does not flag chemical names containing "na"
expected: Process data with chemical names like "Naphthalene" or "Sodium bicarbonate". The stop word "na" should NOT trigger a warning on these names, even though "na" appears as a substring within them.
result: pass

### 4. IUPAC comma patterns preserved during synonym splitting
expected: Process a chemical name like "N,N-Dimethylformamide" through the cleaning pipeline. The comma between the two N letters should NOT cause the name to be split into separate synonyms. The full name should remain intact as a single entry.
result: pass

### 5. Normal comma-separated synonyms still split correctly
expected: Process an entry like "xylene, dimethylbenzene" through the cleaning pipeline. The comma should correctly split this into two separate synonym rows (xylene and dimethylbenzene).
result: pass

## Summary

total: 5
passed: 5
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
