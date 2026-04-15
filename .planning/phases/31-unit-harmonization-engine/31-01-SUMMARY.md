---
phase: 31-unit-harmonization-engine
plan: 01
subsystem: data-processing
tags: [unit-conversion, harmonization, tdd]
dependency_graph:
  requires:
    - 29-static-data-foundations (load_unit_map)
    - 30-numeric-result-parser (orig_row_id pattern)
  provides:
    - harmonize_units() function
    - normalize_unit_string() helper
  affects:
    - Phase 32 ToxVal Schema Mapper (consumes harmonized output)
    - Phase 34 Harmonize Tab (UI wiring)
tech_stack:
  added: []
  patterns:
    - case-sensitive lookup with case-insensitive fallback
    - tibble audit trail with orig_row_id linkage
    - micro symbol normalization (U+00B5, U+03BC)
key_files:
  created:
    - R/unit_harmonizer.R
    - tests/testthat/test-unit-harmonizer.R
    - man/harmonize_units.Rd
    - man/normalize_unit_string.Rd
  modified:
    - NAMESPACE
decisions:
  - Used match() for O(n*m) lookup; acceptable for typical unit_map sizes (~150 rows)
  - normalize_unit_string() is internal (not exported) per plan specification
  - Empty string "" for exact match unit_flag instead of NA (per D-07, keeps downstream joins clean)
metrics:
  duration_seconds: 303
  completed: 2026-04-15T18:04:59Z
  tasks_completed: 2
  tasks_total: 2
  tests_passing: 71
  files_created: 4
  files_modified: 1
---

# Phase 31 Plan 01: Unit Harmonization Engine Summary

Table-driven unit harmonization with micro symbol normalization, case-safe lookup, and conversion arithmetic returning audit tibble.

## Completed Tasks

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | TDD - Tests and implementation for harmonize_units() | d18f8fb, 334c13a | R/unit_harmonizer.R, tests/testthat/test-unit-harmonizer.R |
| 2 | Wire exports and verify integration | c099eac | NAMESPACE, man/harmonize_units.Rd |

## Implementation Details

### normalize_unit_string() (internal)

Applies normalization chain per D-02:
1. `trimws()` - remove leading/trailing whitespace
2. Micro symbol replacement: U+00B5 and U+03BC to ASCII "u"
3. Collapse spaces around "/": `gsub("\\s*/\\s*", "/", x)`

### harmonize_units() (exported)

Lookup strategy per D-03, D-04, D-05:
1. Normalize input unit strings
2. Case-sensitive exact match -> `unit_flag = ""`
3. Case-insensitive fallback -> `unit_flag = "case_fallback"`
4. No match -> pass-through with `unit_flag = "unmatched"`, `conversion_factor = 1`

Output tibble columns (per D-07):
- `orig_row_id` (int) - links back to input position
- `orig_unit` (chr) - original unit before normalization
- `harmonized_value` (dbl) - value * multiplier
- `harmonized_unit` (chr) - target unit from table or original if unmatched
- `conversion_factor` (dbl) - multiplier applied
- `unit_flag` (chr) - "", "case_fallback", or "unmatched"

### Test Coverage

71 test cases covering:
- Normalization: whitespace, micro symbols (both U+00B5 and U+03BC), spaces around /
- Case-sensitive lookup: exact matches for mg/L, ug/L, ppb
- Case-insensitive fallback: MG/L, Mg/L, UG/L, PPB with flag
- Unmatched pass-through: NTU, CFU/100mL, xyz_unknown
- Conversion arithmetic: 5 ug/L * 0.001 = 0.005 mg/L
- Output shape: 6 columns, correct types, empty string for success flag
- Vector input: multiple rows, orig_row_id linkage, orig_unit preservation
- Compound units: mg/kg bw/day table-driven (no special parsing)

## TDD Gate Compliance

- RED gate: d18f8fb - test(31-01): add failing tests for harmonize_units()
- GREEN gate: 334c13a - feat(31-01): implement harmonize_units()
- REFACTOR gate: Not needed - implementation was clean on first pass

## Verification Results

```
testthat::test_file('tests/testthat/test-unit-harmonizer.R')
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 71 ] Done!

devtools::check(error_on = 'error')
0 errors | 6 warnings | 5 notes
```

Warnings and notes are pre-existing package issues unrelated to unit_harmonizer.

## Integration Smoke Test

```r
unit_map <- load_unit_map("inst/extdata/reference_cache")
result <- harmonize_units(
  values = c(5, 10, 100),
  units = c("ug/L", "MG/L", "NTU"),
  unit_map = unit_map
)
# Row 1: ug/L -> 0.005 mg/L, unit_flag = ""
# Row 2: MG/L -> 10 mg/L, unit_flag = "case_fallback"
# Row 3: NTU -> 100 NTU, unit_flag = "unmatched"
```

## Requirements Coverage

- UNIT-01: Case-safe unit lookup - case-sensitive first, case-insensitive fallback with flag
- UNIT-02: Unit string normalization - micro symbols, whitespace, spacing around /
- UNIT-03: Compound unit decomposition - explicit enumeration in table, no parsing
- UNIT-04: Unit conversion arithmetic - value * multiplier
- UNIT-05: Harmonization result tibble structure - 6 columns with audit trail

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

- [x] R/unit_harmonizer.R exists and contains harmonize_units and normalize_unit_string
- [x] tests/testthat/test-unit-harmonizer.R exists with 44 test_that blocks (exceeds 20 minimum)
- [x] NAMESPACE contains export(harmonize_units)
- [x] Commit d18f8fb exists (test)
- [x] Commit 334c13a exists (feat)
- [x] Commit c099eac exists (docs)
- [x] All 71 tests pass
