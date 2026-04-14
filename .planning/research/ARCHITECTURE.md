# Architecture Research: ChemReg v1.9 Number and Unit Coercion Harmonization

**Domain:** R/Shiny Regulatory/Benchmark Data Curation — Numeric Parsing, Unit Harmonization, ToxVal Schema
**Researched:** 2026-04-14
**Confidence:** HIGH (based on direct code inspection of ~9,700 LOC existing codebase + ComptoxR package introspection + ToxValDB schema sources)

---

## Executive Summary

ChemReg v1.9 extends an already-modularized R package (8 Shiny modules, 953 passing tests, `curate_headless()` scripting entry point) from compound-only curation to full regulatory/benchmark data curation. The pivot requires:

1. A **numeric result parser** that handles regulatory data's quirky value formats (ranges, qualifiers, scientific notation, Fortran exponents)
2. A **unit harmonization engine** that maps heterogeneous source units to ToxValDB's controlled vocabulary
3. An **extended column tagging system** (currently: Name/CASRN/Other — must expand to: Name/CASRN/Result/Unit/Duration/Qualifier/Species/ExposureRoute/Other)
4. A **ToxVal schema mapper** that assembles curated rows into 56-column toxval-compatible output
5. A **new export path** (parquet/CSV) alongside the existing 7-sheet Excel export
6. A **new Harmonize tab** inserted between Run Curation and Review Results

The existing architecture is well-positioned for this. The modularized structure (v1.3–v1.8) means new features slot in as new modules or new pipeline steps without touching the file upload, detection, or compound curation subsystems.

---

## Current Architecture (v1.8 Baseline)

### Tab Flow and Gating

```
Sidebar: Upload (always visible)
         Config Import (always visible)

Tabs (gated, revealed sequentially):
  Data Preview       — always visible
  Detection Info     — shown after upload
  Raw Data           — shown after upload
  Tag Columns        — shown after upload
  Clean Data         — shown after tagging
  Run Curation       — shown after cleaning
  Review Results     — shown after curation
```

**Gate triggers in app.R server:**
- `data_store$clean` → show Detection Info, Raw Data, Tag Columns
- `data_store$column_tags` → show Clean Data
- `on_cleaning_complete()` callback → show Run Curation
- `on_curation_complete()` callback → show Review Results + run post-curation QC

### Data Store (reactiveValues in app.R)

```r
data_store <- shiny::reactiveValues(
  # Upload/detection layer
  raw = NULL,              # Original uploaded data frame
  clean = NULL,            # Post-detection, pre-cleaning data
  detection = NULL,        # Detection result (method, confidence, header_row)
  file_info = NULL,        # name, size

  # Tagging/cleaning layer
  selected_columns = NULL, # Columns user kept
  column_tags = NULL,      # Named list: col_name → "Name"/"CASRN"/"Other"
  cleaning_audit = NULL,   # Audit trail tibble from cleaning pipeline
  cleaned_data = NULL,     # Post-cleaning data (input to curation)
  reference_lists = NULL,  # Editable reference lists (stop words, etc.)

  # Curation layer
  curation_results = NULL,
  curation_report = NULL,
  curation_status = NULL,
  dedup_preview = NULL,
  consensus_data = NULL,
  consensus_summary = NULL,
  resolution_state = NULL, # Final curated data table
  dtxsid_cols = NULL,
  priority_order = NULL,
  error_filter_active = FALSE,
  display_row_map = NULL,
  selected_error_rows = NULL,
  manual_queue = list(),
  qc_results = NULL,
  enrichment_cache = NULL,
  enrichment_failed = NULL
)
```

### Module Inventory

| File | Module | Input from data_store | Writes to data_store |
|------|--------|----------------------|----------------------|
| mod_file_upload.R | upload | — | raw, clean, detection, file_info |
| mod_data_preview.R | preview | clean | — |
| mod_detection_info.R | detection | detection | — |
| mod_raw_data.R | raw | raw | — |
| mod_tag_columns.R | tags | clean, selected_columns | column_tags |
| mod_clean_data.R | cleaning | clean, column_tags, reference_lists | cleaned_data, cleaning_audit |
| mod_run_curation.R | curation | cleaned_data, column_tags | curation_results, consensus_data, consensus_summary, resolution_state, ... |
| mod_review_results.R | results | resolution_state, consensus_summary, qc_results, enrichment_cache | resolution_state (on resolution actions) |

### Existing Pipeline Functions

```
run_cleaning_pipeline(df, tag_map, reference_lists)
  → Steps 0-9: lineage inject → unicode → trim → CAS normalize → CAS rescue
               → multi-CAS detect → chiral protect → enclosure strip
               → quality adjectives → salt refs → isotope expand
               → multi-analyte flag → chiral restore
  → Returns: list(cleaned_data, audit_trail, new_tags)

run_curation_pipeline(clean_data, column_tags)
  → deduplicate_tagged_columns() → tiered CompTox search (exact → CAS → starts-with)
  → classify_consensus() → enrichment
  → Returns: list(results, dedup_summary, search_summary, consensus_summary)

build_export_sheets(...) → 7-sheet Excel via writexl::write_xlsx()
```

### Headless Entry Point

`curate_headless(input_path, output_path, tag_map, ...)` mirrors the Shiny pipeline for scripted use. Any new pipeline steps added to the Shiny path must also be reflected here.

---

## v1.9 New Architecture

### What Changes

```
EXISTING (unchanged):
  Upload → Detect → Preview → Tag Columns → Clean Data → Run Curation

NEW:
  Run Curation → [NEW] Harmonize → Review Results → [NEW] Export ToxVal
```

Three integration layers:

1. **Column tagging** — expand tag vocabulary from 3 values to ~9
2. **Post-curation harmonization pipeline** — new `R/harmonize_pipeline.R`
3. **ToxVal schema mapper + parquet/CSV export** — new `R/toxval_mapper.R`

### Extended Tab Flow

```
Sidebar: Upload (unchanged)
         Config Import (unchanged)

Tabs:
  Data Preview     — unchanged
  Detection Info   — unchanged
  Raw Data         — unchanged
  Tag Columns      — MODIFIED (new tag types: Result, Unit, Duration, etc.)
  Clean Data       — unchanged
  Run Curation     — unchanged (still DTXSID consensus)
  [NEW] Harmonize  — NEW tab, revealed after curation
  Review Results   — MODIFIED (add toxval preview, harmonization QC)
```

**Gate for Harmonize tab:** `on_curation_complete()` reveals both Harmonize and Review Results. The existing `on_curation_complete` callback in app.R currently calls `show_tab_with_pulse("review_results")` — this extends to also call `show_tab_with_pulse("harmonize_tab")`.

### New data_store Fields

```r
# Add to existing data_store reactiveValues:
harmonize_results = NULL,     # Output of harmonize_pipeline: numeric_parsed + unit_harmonized
harmonize_audit = NULL,       # Audit trail of numeric parse and unit map changes
toxval_output = NULL,         # Assembled 56-column toxval-schema tibble
toxval_export_format = "csv"  # "csv" or "parquet"
```

**The existing fields do not change.** New fields append to the existing reactiveValues block in app.R.

---

## New Component Specifications

### Component 1: Extended Column Tagging (mod_tag_columns.R — MODIFIED)

**Current tag choices:**
```r
choices = c("Select type..." = "", "Chemical Name" = "Name",
            "CASRN" = "CASRN", "Other" = "Other")
```

**New tag choices (v1.9):**
```r
choices = c(
  "Select type..." = "",
  # Chemical identity (existing)
  "Chemical Name" = "Name",
  "CASRN" = "CASRN",
  # Numeric result (new)
  "Result Value" = "Result",
  "Result Units" = "Unit",
  "Result Qualifier" = "Qualifier",
  # Study metadata (new)
  "Study Duration" = "Duration",
  "Duration Units" = "DurationUnit",
  "Species" = "Species",
  "Exposure Route" = "ExposureRoute",
  # Passthrough
  "Other" = "Other"
)
```

**Impact on downstream code:**
- `run_cleaning_pipeline()` currently treats Name and CASRN tags with special logic. Result/Unit/Duration tags must pass through cleaning without Name-specific transformations (enclosure stripping, synonym splitting, chiral protection). The pipeline already handles this via `name_cols <- names(tag_map)[tag_map == "Name"]` — only Name-tagged columns get name cleaning. New tag types will be ignored by the cleaning pipeline as long as they are not `"Name"` or `"CASRN"`.
- `run_curation_pipeline()` only searches Name/CASRN/Other tagged columns. New tags (Result, Unit, etc.) will be ignored by the CompTox search since `deduplicate_tagged_columns()` filters on those three values. No changes needed in curation.
- The `column_tags` named list format (col_name → tag_type string) is unchanged. New tag values are additive.

**Files modified:** `R/mod_tag_columns.R` only (the selectInput choices block).

---

### Component 2: Numeric Result Parser (R/numeric_parser.R — NEW)

**Purpose:** Parse raw result value strings into structured numeric form.

**Input patterns handled:**
- Plain numeric: `"0.5"`, `"500"`
- Scientific notation: `"1.2e-3"`, `"1.2E-3"`
- Fortran exponent: `"1.2D-3"` (D replaced by E)
- Qualified values: `">100"`, `"<0.1"`, `">=10"`, `"<=5"`
- Ranges: `"10-100"` (ambiguous with CAS — context-sensitive), `"10 to 100"`
- Range with qualifier: `"10-100 mg/L"` (unit embedded — strip before parse)
- Whitespace variants: `"  1.5  "`, `"1 000"` (European thousands separator)
- Missing/non-numeric: `"NA"`, `"-"`, `"not reported"`, `"ND"` → `NA_real_`

**Output contract:**
```r
parse_numeric_result(x)
# Returns list:
# $numeric_value   numeric — extracted numeric, NA if unparseable
# $qualifier       character — one of ">", "<", ">=", "<=", "~", NA
# $range_low       numeric — lower bound if range, else NA
# $range_high      numeric — upper bound if range, else NA
# $is_range        logical
# $parse_flag      character — "ok", "range", "qualified", "unparseable", "fortran_exp"
```

**Column output strategy:** For a column tagged "Result", parsing produces THREE new columns added to the data frame:
- `{col_name}_numeric` — extracted numeric value
- `{col_name}_qualifier` — qualifier string
- `{col_name}_parse_flag` — flag for audit and QC

This is consistent with the existing wide-data pattern used in CAS operations (new columns, not new rows).

**Audit trail:** Integrates with `build_audit_trail()` by treating `{col_name}_numeric` as the "cleaned" column and `{col_name}` (original) as the before state.

**Dependency:** No new R package dependencies. Uses `stringr` (already in Imports) and base R `as.numeric()`.

---

### Component 3: Unit Harmonization Engine (R/unit_harmonizer.R — NEW)

**Purpose:** Map heterogeneous source unit strings to ToxValDB controlled vocabulary.

**Data source:** ToxValDB uses a units dictionary mapping source terms to standard units. ComptoxR v1.4.0 does not expose a unit conversion table as a named export — `chemi_services_convert()` is a generic API wrapper, not a unit lookup table. The unit dictionary must be **built locally** and stored as a reference list in `inst/extdata/reference_cache/unit_map.rds`.

**Unit map structure:**
```r
# unit_map tibble: (source_unit, canonical_unit, unit_class, conversion_factor, notes)
# unit_class: "mass_per_volume", "mass_per_mass", "mass_per_area",
#              "volume", "mass", "concentration", "dimensionless"
```

**Seeding strategy:**
1. Pull from `ct_hazard_toxval_search()` API results across a broad chemical set to collect observed unit strings
2. Build manual mapping for common regulatory units (mg/L, mg/kg-d, ug/L, ppb, ppm, etc.)
3. Store in RDS cache, same pattern as existing `stop_words.rds`, `block_patterns.rds`

**harmonize_unit() contract:**
```r
harmonize_unit(x, unit_map)
# x: character vector of raw unit strings
# Returns list:
# $canonical_unit    character — matched standard unit, NA if no match
# $unit_class        character — type classification
# $unit_flag         character — "exact_match", "fuzzy_match", "no_match"
```

**Match strategy:** Exact match first (case-insensitive after trimming), then regex-based fuzzy match for common variants (e.g., `"mg/L"` matches `"mg/l"`, `"mg l-1"`, `"MG/L"`). No external API call — purely local lookup.

**Dependency:** `stringr` (existing). No new packages.

---

### Component 4: Harmonization Pipeline Orchestrator (R/harmonize_pipeline.R — NEW)

**Purpose:** Orchestrate numeric parsing + unit harmonization across all tagged columns, producing the harmonize_results table.

```r
run_harmonize_pipeline(df, column_tags, unit_map)
# df: cleaned_data after curation (contains consensus_dtxsid, etc.)
# column_tags: extended tag map including Result, Unit, Duration, etc.
# unit_map: unit_map tibble
# Returns list:
#   $harmonized_data: df with _numeric, _qualifier, _canonical_unit columns added
#   $audit_trail: tibble (same schema as cleaning audit trail)
#   $summary: list(n_parsed, n_unparseable, n_units_matched, n_units_unmatched)
```

**Steps:**
1. For each "Result" tagged column: call `parse_numeric_result()`, attach `_numeric` + `_qualifier` + `_parse_flag` columns
2. For each "Unit" tagged column: call `harmonize_unit()`, attach `_canonical` + `_unit_flag` columns
3. For each "Duration" tagged column: parse numeric + extract duration class (acute/chronic via lookup)
4. Build audit trail via `build_audit_trail()` equivalents
5. Return harmonized_data, audit_trail, summary

**Integration point:** Called from `mod_harmonize_server()` after `mod_run_curation_server()` completes. Does NOT modify `resolution_state` in-place — produces a separate `data_store$harmonize_results` tibble.

---

### Component 5: ToxVal Schema Mapper (R/toxval_mapper.R — NEW)

**Purpose:** Assemble harmonized ChemReg data into ToxValDB 56-column schema.

**ToxValDB core columns (based on published schema):**
```
# Chemical identity
dtxsid, casrn, name, preferred_name

# Toxicity value
toxval_type, toxval_numeric, toxval_numeric_qualifier, toxval_units,
toxval_units_original, toxval_numeric_original

# Study design
species, strain, sex, generation, lifestage
study_duration_value, study_duration_units, study_duration_class
exposure_route, exposure_method, exposure_form

# Source metadata
source, subsource, source_url, source_version
study_year, long_ref, title, author

# Effect metadata
effect, endpoint, critical_effect
study_type

# Quality/tracking
priority_id, record_url, toxval_id, dtxsid_version
```

**Mapping contract:**
```r
map_to_toxval_schema(harmonized_data, column_tags, source_metadata)
# Produces 56-column tibble
# For each input column with a recognized tag, maps to toxval field
# Appends *_original columns: toxval_units_original, toxval_numeric_original
# Fills unmapped toxval columns with NA
# Returns: toxval_tibble (one row per curated row)
```

**Original audit columns pattern:** Every mapped value field gets a `{field}_original` companion holding the raw source value before harmonization. This matches ToxValDB convention and provides the audit trail in the output.

**Column tag → toxval field mapping:**
```
"Name"          → name
"CASRN"         → casrn
"Result"        → toxval_numeric_original (raw); parsed → toxval_numeric
"Unit"          → toxval_units_original (raw); harmonized → toxval_units
"Qualifier"     → toxval_numeric_qualifier
"Duration"      → study_duration_value + study_duration_units (parsed)
"Species"       → species
"ExposureRoute" → exposure_route
consensus_dtxsid → dtxsid (from curation)
```

---

### Component 6: New Harmonize Tab (mod_harmonize.R — NEW)

**UI structure:**
```
Harmonize Tab
  ├── Value boxes: n_parsed, n_units_matched, n_unparseable, n_units_unmatched
  ├── "Run Harmonization" button (with progress bar)
  ├── Parsed Results table (DT): shows _numeric, _qualifier per Result column
  ├── Unit Map table (DT): shows source_unit → canonical_unit with match type
  ├── "Review Unmatched Units" section: list units with no_match flag
  │     └── Manual mapping input (add to unit_map reference)
  └── "Build ToxVal Output" button → triggers toxval_mapper
```

**Server interactions:**
- Reads: `data_store$resolution_state`, `data_store$column_tags`, `data_store$reference_lists$unit_map`
- Writes: `data_store$harmonize_results`, `data_store$harmonize_audit`, `data_store$toxval_output`
- Calls `run_harmonize_pipeline()` on button click
- Calls `map_to_toxval_schema()` on "Build ToxVal Output" button

**Pattern:** Follows `mod_run_curation.R` pattern exactly — button-triggered pipeline, `withProgress()` wrapper, write results to `data_store`, call `on_complete` callback to reveal Review Results.

---

### Component 7: Export Path Extension (R/export_helpers.R — MODIFIED + new export handler)

**Current export:** 7-sheet Excel via `writexl::write_xlsx()` from `build_export_sheets()`.

**v1.9 additions:**

1. **Add sheet 8 to existing Excel export:** "ToxVal Output" sheet containing the mapped toxval tibble (if harmonization was run)
2. **New parquet/CSV export handler** in `mod_review_results.R`: a second download button "Export ToxVal Format" that writes `data_store$toxval_output` to parquet (via `arrow::write_parquet()`) or CSV

**Dependency decision:** `arrow` for parquet export. This is a new dependency. Assess: if the primary consumer of the toxval output is a DuckDB instance, parquet is the right format (DuckDB reads parquet natively). If the user wants a fallback, provide CSV option. **Recommendation:** add `arrow` to DESCRIPTION Imports, provide both format options.

**Export function signature:**
```r
export_toxval(toxval_tibble, output_path, format = c("parquet", "csv"))
```

---

## Data Flow: Before vs After v1.9

### Current Flow (v1.8)

```
Upload → raw
  → detect_data_start() → clean
  → [Tag Columns UI] → column_tags (Name/CASRN/Other only)
  → run_cleaning_pipeline(clean, column_tags) → cleaned_data + cleaning_audit
  → run_curation_pipeline(cleaned_data, column_tags) → resolution_state
  → perform_unicode_qc(resolution_state) → qc_results
  → build_export_sheets() → 7-sheet Excel
```

### New Flow (v1.9)

```
Upload → raw
  → detect_data_start() → clean
  → [Tag Columns UI] → column_tags (Name/CASRN/Other/Result/Unit/Duration/...)
  → run_cleaning_pipeline(clean, column_tags) → cleaned_data + cleaning_audit
    [cleaning pipeline ignores non-Name/CASRN tags — no change needed]
  → run_curation_pipeline(cleaned_data, column_tags) → resolution_state
    [curation pipeline ignores non-Name/CASRN/Other tags — no change needed]
  → perform_unicode_qc(resolution_state) → qc_results        [unchanged]
  → [NEW] run_harmonize_pipeline(resolution_state, column_tags, unit_map)
      → harmonize_results + harmonize_audit                   [NEW]
  → [NEW] map_to_toxval_schema(harmonize_results, column_tags, source_metadata)
      → toxval_output                                         [NEW]
  → build_export_sheets() → 7-sheet Excel + sheet 8 (ToxVal) [EXTENDED]
  → [NEW] export_toxval(toxval_output, path, format)          [NEW]
```

**Critical observation:** The new harmonization + mapping steps operate on `resolution_state` (output of curation). They do NOT touch the cleaning or curation pipelines. This is a clean extension, not a modification.

---

## Cascade Reset Extension

The existing cascade reset is defined in `reset_all_downstream()` in app.R. v1.9 adds two new fields that must be reset:

| Trigger | Additional resets needed (beyond current) |
|---------|------------------------------------------|
| Re-upload | `harmonize_results = NULL`, `harmonize_audit = NULL`, `toxval_output = NULL` |
| Tag change | `harmonize_results = NULL`, `harmonize_audit = NULL`, `toxval_output = NULL` |
| Re-run curation | `harmonize_results = NULL`, `harmonize_audit = NULL`, `toxval_output = NULL` |
| Re-run harmonization | `toxval_output = NULL` only |

**Implementation:** Add the three new field nullifications to `reset_all_downstream()` in app.R. Also nullify them in the `on_tags_applied` callback in `mod_tag_columns_server`.

---

## headless Pipeline Extension (R/curate_headless.R — MODIFIED)

`curate_headless()` must expose the harmonization step as an optional extension:

```r
curate_headless(
  input_path, output_path, tag_map,
  # existing params...
  harmonize = FALSE,             # NEW: run harmonization pipeline
  unit_map = NULL,               # NEW: custom unit map (or load from cache)
  export_toxval = FALSE,         # NEW: write toxval parquet alongside Excel
  source_metadata = list()       # NEW: source, subsource, source_url etc.
)
```

When `harmonize = TRUE`:
- After Step 8 (curation), add Step 8b: `run_harmonize_pipeline()`
- After Step 8b, add Step 8c: `map_to_toxval_schema()`
- In Step 9: include ToxVal sheet in Excel + optionally write parquet

**Backward compatibility:** Default `harmonize = FALSE` means existing scripts calling `curate_headless()` without the new params continue to work without change.

---

## Component Boundaries

| Component | New vs Modified | File | Dependencies |
|-----------|----------------|------|-------------|
| Extended tag types | Modified | R/mod_tag_columns.R | None |
| Numeric parser | New | R/numeric_parser.R | stringr (existing) |
| Unit harmonizer | New | R/unit_harmonizer.R | stringr (existing) |
| Unit map reference | New | inst/extdata/reference_cache/unit_map.rds | — |
| Harmonization pipeline | New | R/harmonize_pipeline.R | numeric_parser, unit_harmonizer |
| ToxVal schema mapper | New | R/toxval_mapper.R | harmonize_pipeline |
| Harmonize tab module | New | R/mod_harmonize.R | harmonize_pipeline, toxval_mapper |
| Export extension | Modified + New | R/export_helpers.R | arrow (new dep) |
| app.R wiring | Modified | inst/app/app.R | mod_harmonize |
| curate_headless extension | Modified | R/curate_headless.R | harmonize_pipeline, toxval_mapper |

---

## Build Order (Dependency-Aware)

### Phase A: Foundation — Pure R, No UI

**A1. Build unit_map reference seed** (`inst/extdata/reference_cache/unit_map.rds`)
- Seed from ToxValDB documentation + common regulatory units
- Store as tibble: (source_unit, canonical_unit, unit_class)
- Add loader to `R/cleaning_reference.R` (`load_unit_map()`) + include in `load_all_reference_lists()`
- **Why first:** All downstream components depend on this data existing

**A2. Implement numeric parser** (`R/numeric_parser.R`)
- `parse_numeric_result(x)` — returns list with numeric_value, qualifier, range fields, parse_flag
- No dependencies beyond stringr
- Write testthat tests immediately (pure function — easy to TDD)
- **Why A2:** Depends only on A1 (indirectly), unblocks A3 and A5

**A3. Implement unit harmonizer** (`R/unit_harmonizer.R`)
- `harmonize_unit(x, unit_map)` — returns list with canonical_unit, unit_class, unit_flag
- `load_unit_map(cache_dir)` already handled in A1
- Write testthat tests immediately
- **Why A3:** Depends only on A1, unblocks A4

**A4. Implement harmonization pipeline** (`R/harmonize_pipeline.R`)
- `run_harmonize_pipeline(df, column_tags, unit_map)` — orchestrates A2 + A3 per tagged column
- Duration parsing sub-function: extract numeric + classify acute/chronic
- Returns harmonized_data + audit_trail + summary
- **Why A4:** Depends on A2, A3. This is the core orchestrator.

**A5. Implement ToxVal schema mapper** (`R/toxval_mapper.R`)
- `map_to_toxval_schema(harmonized_data, column_tags, source_metadata)` — assembles 56-column output
- `export_toxval(toxval_tibble, output_path, format)` — writes parquet or CSV
- **Why A5:** Depends on A4. Terminal step in the data pipeline.

### Phase B: UI Integration

**B1. Extend column tag choices** (`R/mod_tag_columns.R`)
- Add Result, Unit, Qualifier, Duration, DurationUnit, Species, ExposureRoute to selectInput choices
- No other changes to mod_tag_columns — tag storage format unchanged
- Smoke test: app starts, Tag Columns shows new dropdown options
- **Why B1 first in UI phase:** Everything else depends on users being able to apply the new tags

**B2. Extend data_store and reset logic** (`inst/app/app.R`)
- Add `harmonize_results`, `harmonize_audit`, `toxval_output`, `toxval_export_format` to reactiveValues
- Extend `reset_all_downstream()` to null the new fields
- Add `harmonize_tab` hide to `session$onFlushed` startup hides
- No new UI yet — just plumbing
- **Why B2 before B3:** Module must find its data_store fields when initialized

**B3. Build Harmonize tab module** (`R/mod_harmonize.R`)
- `mod_harmonize_ui("harmonize")` — value boxes, Run Harmonization button, results tables
- `mod_harmonize_server("harmonize", data_store, on_harmonize_complete)` — wires to run_harmonize_pipeline + map_to_toxval_schema
- **Why B3 after B2:** Module reads/writes data_store fields created in B2

**B4. Wire Harmonize module into app.R**
- Add `nav_panel("Harmonize", value = "harmonize_tab", ...)` to navset_underline
- Call `mod_harmonize_server("harmonize", data_store, on_harmonize_complete = function() { show_tab_with_pulse("review_results") })`
- Extend `on_curation_complete` to also show harmonize_tab
- **Why B4 last in UI:** All components must exist before wiring

### Phase C: Export Extension

**C1. Add ToxVal export to existing Excel** (`R/export_helpers.R`)
- Add sheet 8 "ToxVal Output" to `build_export_sheets()` when `data_store$toxval_output` is not NULL
- Backward-compatible: if toxval_output is NULL, sheet 8 is omitted
- **Why C1:** Lowest friction — extends existing export path

**C2. Add parquet/CSV download handler** (`R/mod_review_results.R`)
- Add "Export ToxVal Format" downloadButton to Review Results tab
- `downloadHandler` writes `data_store$toxval_output` via `export_toxval()`
- Add format selector: radio buttons for "CSV" vs "Parquet"
- **Why C2 after C1:** C1 proves the toxval tibble is correctly assembled before adding a new export path

### Phase D: headless Extension + Tests

**D1. Extend curate_headless()** (`R/curate_headless.R`)
- Add harmonize/toxval params (default FALSE for backward compat)
- Conditional Steps 8b, 8c when harmonize = TRUE
- **Why D1 after B-C:** headless must mirror the proven Shiny path

**D2. Test suite for new components**
- `tests/testthat/test-numeric-parser.R` — parse_numeric_result edge cases
- `tests/testthat/test-unit-harmonizer.R` — harmonize_unit exact/fuzzy/no-match
- `tests/testthat/test-harmonize-pipeline.R` — run_harmonize_pipeline integration
- `tests/testthat/test-toxval-mapper.R` — map_to_toxval_schema column output
- **Target:** Existing 953 tests still pass; add ~100 new tests for v1.9 components

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Parsing Units Inside the Numeric Parser

**What happens:** Developer tries to strip units from `"100 mg/L"` inside `parse_numeric_result()`.

**Why wrong:** Unit extraction is a separate concern from numeric extraction. Coupling them creates a function that silently eats unit information and produces wrong results when units contain numbers (`"10^6 CFU/mL"`).

**Instead:** Pre-process "Result" columns to extract embedded units into a separate column BEFORE parsing. Or rely on the user having tagged a separate "Unit" column. The numeric parser should only receive pure value strings.

### Anti-Pattern 2: Modifying resolution_state In-Place in Harmonization

**What happens:** `run_harmonize_pipeline()` directly mutates `data_store$resolution_state` to add harmonized columns.

**Why wrong:** Mixes compound curation state with numeric harmonization state. Re-running harmonization would corrupt the resolution_state that mod_review_results depends on.

**Instead:** `run_harmonize_pipeline()` writes to `data_store$harmonize_results` (a new tibble). The toxval mapper joins resolution_state + harmonize_results. resolution_state is read-only after curation completes.

### Anti-Pattern 3: Hardcoding 56 ToxVal Columns

**What happens:** `map_to_toxval_schema()` has 56 hardcoded column names in the function body.

**Why wrong:** ToxValDB schema evolves between versions. Hardcoded columns are a maintenance liability and cause silent data loss when the schema changes.

**Instead:** Define the 56-column schema as a named character vector constant at the top of toxval_mapper.R (`TOXVAL_SCHEMA_COLS`). The mapper iterates over this vector, filling matched fields and NA-filling the rest. Schema changes require editing one constant.

### Anti-Pattern 4: Treating Duration Columns as Plain Text in the Tagging UI

**What happens:** Duration is tagged as "Other" and passes through to toxval output as a raw string.

**Why wrong:** ToxValDB has separate `study_duration_value` (numeric) and `study_duration_units` (string) and `study_duration_class` (acute/chronic/subchronic) columns. Raw duration strings like `"28 days"` cannot be ingested.

**Instead:** The "Duration" tag triggers duration-specific parsing in `run_harmonize_pipeline()`: extract numeric + unit components, classify into acute/subacute/subchronic/chronic via duration class lookup table.

### Anti-Pattern 5: Adding arrow as a Hard Dependency for Parquet

**What happens:** `arrow` added to DESCRIPTION Imports, making all users install it even if they never export parquet.

**Why wrong:** `arrow` is a large package (~50MB) with system library dependencies (libarrow). Many users only want the CSV path.

**Instead:** Move `arrow` to Suggests. In `export_toxval()`, check `requireNamespace("arrow", quietly = TRUE)` and fall back to CSV with a message if arrow is not available. Document that `install.packages("arrow")` is needed for parquet support.

---

## Scalability Notes

| Concern | At Current Scale (~1,000 rows) | At 10k-50k rows |
|---------|-------------------------------|-----------------|
| Numeric parsing | Vectorized via stringr — fast | Still fast (vectorized) |
| Unit harmonization | Local lookup table join — fast | Still fast (dplyr join) |
| Harmonize pipeline | <1 second | 3-10 seconds — add withProgress() |
| ToxVal mapper | Column bind operations — fast | Fast unless 56 columns × 50k rows hits memory limits (unlikely in R) |
| Parquet export | arrow::write_parquet is fast | Still fast |

No architectural changes needed for scale within realistic benchmark dataset sizes (typically <10k rows for regulatory/benchmark data files).

---

## Sources

- ToxValDB v9.7.0 schema documentation: [EPA FigShare ToxValDB dataset](https://epa.figshare.com/articles/dataset/ToxValDB_v9_1/20394501)
- ToxValDB methodology paper: [Wall et al. 2025, Computational Toxicology](https://www.sciencedirect.com/science/article/abs/pii/S2468111325000258)
- ToxValDB GitHub (staging R package): [USEPA/toxvaldbstage](https://github.com/USEPA/toxvaldbstage)
- ToxValDB main harmonization package: [USEPA/toxvaldbmain](https://github.com/USEPA/toxvaldbmain)
- EPA Downloadable Computational Toxicology Data: [EPA CompTox Tools](https://www.epa.gov/comptox-tools/downloadable-computational-toxicology-data)
- ComptoxR v1.4.0 package inspection (direct): `toxvaldb_sourcedict` data object; no unit harmonization tables exported
- ChemReg codebase direct inspection: `R/cleaning_pipeline.R` (1,700+ lines), `R/curation.R` (1,020+ lines), `R/curate_headless.R` (177 lines), `inst/app/app.R` (337 lines)

---

*Architecture research for: ChemReg v1.9 Number and Unit Coercion Harmonization*
*Researched: 2026-04-14*
*Confidence: HIGH — based on direct code inspection of existing codebase, ComptoxR package introspection, and ToxValDB published schema sources*
