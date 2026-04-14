---
status: partial
phase: 27-headless-pipeline
source: [27-VERIFICATION.md]
started: 2026-04-13T00:00:00Z
updated: 2026-04-13T00:00:00Z
---

# Human Verification: Phase 27 Headless Pipeline

## Current Test

[awaiting human testing]

## Tests

### 1. End-to-End Pipeline Run (HDL-02, HDL-03, HDL-04)

**Test:** In a fresh R session with `ctx_api_key` set:
```r
devtools::install()
library(chemreg)
result <- curate_headless(
  input_path = "uncurated_sswqs.csv",
  output_path = "test_headless_output.xlsx",
  tag_map = list(chemical_name = "Name", cas_number = "CASRN")
)
readxl::excel_sheets("test_headless_output.xlsx")  # should return 7 names
str(result)  # should show $data tibble and $audit_trail tibble
```

expected: Function completes without error; XLSX file exists; excel_sheets() returns 7 sheet names; str(result) shows $data and $audit_trail tibbles
result: [pending]

### 2. Verbose Suppression (verbose=FALSE)

**Test:**
```r
curate_headless("uncurated_sswqs.csv", "test2.xlsx",
  tag_map = list(chemical_name = "Name", cas_number = "CASRN"),
  verbose = FALSE
)
```

expected: No [headless] progress lines appear on console
result: [pending]

### 3. Help Page Discoverability (HDL-01)

**Test:**
```r
devtools::install()
library(chemreg)
?curate_headless
```

expected: R help pane opens with title, description, all 7 param docs, and return value section
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps

(None identified yet)
