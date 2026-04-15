---
phase: 32-toxval-schema-mapper
plan: 01
subsystem: data-transformation
tags: [schema-mapping, toxval, audit-columns]

requires:
  - inst/extdata/reference_cache/toxval_schema.rds (expanded from 7 to 56 columns)
provides:
  - R/toxval_mapper.R
  - tests/testthat/test-toxval-mapper.R
affects:
  - DESCRIPTION (added digest to Imports)
  - NAMESPACE (export map_to_toxval_schema)

tech-stack:
  added: [digest]

patterns:
  - typed-na-enforcement: All unmapped columns use NA_character_ or NA_real_, never bare NA
  - audit-columns: Every harmonized field has *_original counterpart preserving pre-harmonization values
  - deterministic-hashing: SHA256 source_hash per row for audit trail

key-files:
  created:
    - R/toxval_mapper.R
    - tests/testthat/test-toxval-mapper.R
    - man/map_to_toxval_schema.Rd
  modified:
    - inst/extdata/reference_cache/toxval_schema.rds
    - DESCRIPTION
    - NAMESPACE

key-decisions:
  - D-25: digest package added to Imports for SHA256 source_hash generation

requirements-completed: [SCHM-01, SCHM-02]
duration: 12 min
completed: 2026-04-15
---

# Phase 32 Plan 01: ToxVal Schema Mapper Summary

ToxVal schema mapper with 56-column support including typed NAs, source_hash, and 19 audit columns for harmonization tracking.

## Duration

- Started: 2026-04-15T19:30:00Z
- Completed: 2026-04-15T19:42:00Z
- Duration: ~12 minutes

## Tasks Completed

| # | Task | Status | Commit |
|---|------|--------|--------|
| 1 | Expand toxval_schema.rds and create map_to_toxval_schema() | ✅ | 4be24e2 |
| 2 | Roxygen and R CMD check validation | ✅ | a74d97b |

## Implementation Summary

### Schema Expansion
- Expanded `toxval_schema.rds` from 7 to 56 columns matching exact ToxVal database order
- All VARCHAR columns use `NA_character_`, all DOUBLE columns use `NA_real_`
- Zero-row template for type validation

### map_to_toxval_schema()
- Input: curated_data (dtxsid, casrn, name) + harmonized_data (harmonized_value, harmonized_unit)
- Output: 56-column tibble with:
  - Mapped values from inputs
  - `source` defaults to "user_upload" (configurable via source_name)
  - `qc_category` = "user_curated", `qc_status` = "pass"
  - SHA256 `source_hash` per row via digest::digest()
  - 19 audit columns (*_original + original_year)

### Test Coverage
- 112 tests covering:
  - Schema template (column count, names, types)
  - Basic mapping (dtxsid, casrn, name, toxval_numeric, toxval_units)
  - Typed NA enforcement (no logical columns)
  - Audit columns (*_original values)
  - Source hash (deterministic, unique, 64-char hex)
  - Edge cases (zero-row, single-row, missing columns, NA values)

## Files Changed

- `R/toxval_mapper.R` (new, 221 lines)
- `inst/extdata/reference_cache/toxval_schema.rds` (replaced, 56 columns)
- `tests/testthat/test-toxval-mapper.R` (new, 347 lines)
- `DESCRIPTION` (+1 line: digest to Imports)
- `NAMESPACE` (+1 export)
- `man/map_to_toxval_schema.Rd` (new)
- `man/*.Rd` (5 internal helper docs)

## Verification Results

```
testthat::test_file("tests/testthat/test-toxval-mapper.R")
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 112 ]

devtools::check()
0 errors ✔ | 6 warnings ✖ | 5 notes ✖
(warnings/notes are pre-existing, unrelated to this phase)
```

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

Phase 32 complete. Ready for:
- Phase 33: Extended Column Tagging (UI for additional column mapping)
- Phase 34: Harmonize Tab Module (integrate mapper into UI)

---

*Phase: 32-toxval-schema-mapper*
*Plan: 01*
*Completed: 2026-04-15*
