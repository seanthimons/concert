# Phase 35: Export Extension + Headless - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend the export system with parquet/CSV output for ToxVal-schema data, add Sheet 8 "ToxVal Output" to the existing Excel export, and extend `curate_headless()` to support the full harmonization pipeline.

**Scope:**
1. Parquet export via `arrow::write_parquet()` with explicit schema assertion (SCHM-03)
2. CSV export as user-selectable alternative (SCHM-04 — revised: arrow is hard dependency, CSV is a format choice not a fallback)
3. `curate_headless()` extension with `harmonize=TRUE` param and format selection (SCHM-05)
4. Sheet 8 "ToxVal Output" in existing Excel export (UITG-06)

**Not in scope:**
- ToxVal schema mapper function (completed in Phase 32)
- Harmonize tab UI (Phase 34)
- Extended column tagging (Phase 33)

</domain>

<decisions>
## Implementation Decisions

### Export Format Selection
- **D-01:** User chooses format — add `format` parameter accepting "parquet", "csv", or "both" to `curate_headless()` and a radio button in the Shiny UI export section
- **D-02:** `arrow` is a hard dependency (Imports in DESCRIPTION), not Suggests — parquet is always available, no `requireNamespace()` guard needed. This overrides SCHM-04's original "CSV fallback when arrow unavailable" design.
- **D-03:** File naming follows input basename: `{input_basename}_toxval.parquet` and/or `{input_basename}_toxval.csv` (e.g., `sswqs_data_toxval.parquet`)

### Headless Pipeline Extension
- **D-04:** Extend existing `tag_map` values — add "Result", "Unit", "Qualifier", "Duration", "DurationUnit", "Species", "ExposureRoute" as valid tag values alongside existing "Name"/"CASRN"/"Other". Same parameter, richer vocabulary.
- **D-05:** When `harmonize=TRUE`, `$data` in the return value becomes the 56-column ToxVal tibble (from `map_to_toxval_schema()`) instead of the resolution_state. When `harmonize=FALSE` (default), `$data` remains the resolution_state for backward compatibility.
- **D-06:** Add `$harmonize_audit` to the return list when `harmonize=TRUE` (harmonization audit trail tibble)
- **D-07:** Headless mode writes both the 8-sheet XLSX and a separate ToxVal parquet/CSV file (per format param) when `harmonize=TRUE`
- **D-08:** New `curate_headless()` parameters: `harmonize = FALSE`, `format = "parquet"`, plus any needed for harmonization context (unit_map, corrections, media — Claude's discretion on exact param names)

### Sheet 8 Integration
- **D-09:** Sheet 8 "ToxVal Output" is always present in Excel export, even when harmonization has not been run
- **D-10:** When harmonization has not run, Sheet 8 contains a note row (e.g., "Harmonization not run — run harmonization to populate this sheet")
- **D-11:** When harmonization has run, Sheet 8 contains the full 56-column ToxVal tibble from `map_to_toxval_schema()`

### Read-back Validation
- **D-12:** Parquet round-trip validation is test-only — testthat test writes a known tibble to parquet, reads it back, and asserts column types + values match. No runtime validation check at export time.

### Claude's Discretion
- Internal helper function organization for export logic
- Exact parameter names for harmonization context in headless mode (unit_map, corrections, media defaults)
- Test case selection beyond the round-trip requirement
- Radio button placement and label text in UI export section
- Error message wording for invalid format values

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Upstream Phase Context
- `.planning/phases/32-toxval-schema-mapper/32-CONTEXT.md` — `map_to_toxval_schema()` signature and 56-column schema
- `.planning/phases/34-harmonize-tab-module/34-CONTEXT.md` — `data_store$harmonize_results` and `data_store$harmonize_audit` structure
- `.planning/phases/27-headless-pipeline/27-CONTEXT.md` — Current `curate_headless()` signature and return value
- `.planning/phases/31.5-units-package-assimilation/31.5-CONTEXT.md` — `harmonize_units()` function signature
- `.planning/phases/30-numeric-result-parser/30-CONTEXT.md` — `parse_numeric_results()` output structure

### Key Source Files
- `R/curate_headless.R` �� Current headless pipeline (extend with harmonize param)
- `R/export_helpers.R` — `build_export_sheets()` (add Sheet 8)
- `R/toxval_mapper.R` — `map_to_toxval_schema()` (produces 56-col tibble)
- `DESCRIPTION` — Add `arrow` to Imports

### Requirements
- `.planning/REQUIREMENTS.md` — SCHM-03, SCHM-04, SCHM-05, UITG-06 definitions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `map_to_toxval_schema(curated_data, harmonized_data, source_name)` in `R/toxval_mapper.R` — produces the 56-col tibble
- `build_export_sheets()` in `R/export_helpers.R` — currently returns 7-sheet named list for writexl
- `curate_headless()` in `R/curate_headless.R` — current entry point with tag_map, header_row, reference_lists, verbose params
- `writexl::write_xlsx()` — handles multi-sheet Excel output

### Established Patterns
- `system.file("extdata", "reference_cache", package = "chemreg")` for bundled data
- `tag_map` is a named list: `list(column_name = "TagType")`
- Return values use `invisible()` for headless functions
- `message()` for verbose progress reporting (not `cat()`)

### Integration Points
- `build_export_sheets()` signature needs extension to accept ToxVal output tibble
- `curate_headless()` needs to call `parse_numeric_results()` and `harmonize_units()` when harmonize=TRUE
- `DESCRIPTION` Imports list needs `arrow` added
- NAMESPACE needs any new exports

### Files to Modify
- `R/curate_headless.R` — extend with harmonize, format params
- `R/export_helpers.R` — add Sheet 8 to `build_export_sheets()`
- `DESCRIPTION` — add `arrow` to Imports
- `NAMESPACE` — regenerate via roxygen

### Files to Create
- `tests/testthat/test-parquet-roundtrip.R` — round-trip validation test

</code_context>

<specifics>
## Specific Ideas

### curate_headless() Extended Signature
```r
curate_headless(
  input_path,
  output_path,
  tag_map,                # Now accepts "Result", "Unit", "Qualifier", etc.
  skip_flags = NULL,
  header_row = NULL,
  reference_lists = NULL,
  verbose = TRUE,
  harmonize = FALSE,      # NEW: enable numeric parsing + unit harmonization + toxval mapping
  format = "parquet"      # NEW: "parquet", "csv", or "both"
)
```

### Return Value When harmonize=TRUE
```r
list(
  data = <56-col toxval tibble>,         # Replaces resolution_state
  audit_trail = <cleaning audit tibble>,
  harmonize_audit = <harmonization audit tibble>
)
```

### File Naming Convention
```
input: "data/sswqs_benchmark.xlsx"
output_path: "output/sswqs_benchmark.xlsx"   # 8-sheet XLSX
toxval file: "output/sswqs_benchmark_toxval.parquet"  # auto-derived
```

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 35-export-extension-headless*
*Context gathered: 2026-04-17*
