# Feature Landscape

**Domain:** Numeric result parsing, unit harmonization, and toxval schema output for regulatory/benchmark data curation
**Milestone:** v1.9 Number and Unit Coercion Harmonization
**Researched:** 2026-04-14
**Supersedes:** Previous FEATURES.md (v1.3 chemical inventory cleaning milestone)

---

## Executive Summary

The v1.9 milestone converts ChemReg from a compound-identification tool into a full regulatory/benchmark data curation pipeline. The core loop is: parse messy numeric result strings → harmonize units to a standard target → classify exposure context → map everything to the 56-column ToxVal schema → export to parquet/CSV for database integration.

A working reference implementation already exists in `curation/epa/sswqs/sswqs_curation.R`. That script demonstrates the entire feature set end-to-end: narrative filter, result string normalization (Fortran exponents, scientific notation, space removal), range splitting with mid-row generation, unit harmonization via `case_when` lookup table, protection code decoding, and ToxVal schema transmutation. ChemReg v1.9 is the Shiny-wrapped, audit-trailed, user-facing version of this pattern.

The key complexity gap between sswqs_curation.R and ChemReg v1.9 is that sswqs_curation.R is dataset-specific (hardcoded column names, hardcoded unit tables, hardcoded protection code lookup). ChemReg v1.9 must generalize these to work on any regulatory/benchmark file a user uploads.

---

## Table Stakes

Features that must exist for v1.9 to function. Missing any of these = the pipeline cannot produce a valid ToxVal output.

| Feature | Why Required | Complexity | Existing Dependency | Notes |
|---------|--------------|------------|---------------------|-------|
| **Narrative result filter** | Non-parsable text values (e.g., "see table", "within X") must be excluded before numeric parsing or `as.numeric()` produces NA silently | Low | stringr (existing) | Filter on regex patterns: `\bsee\b`, `\bwithin\b`, `/`, `\bnot\b`, etc. Must preserve a `removed_reason` audit column — don't silently drop |
| **Result string normalization** | Messy inputs: commas in numbers ("1,000"), spaces before exponents ("5.0 e-9"), Fortran-style exponents ("4.56+02"), x10^ notation ("5x10^-9"), "million" as text | Low-Medium | stringr (existing) | All patterns demonstrated in sswqs_curation.R lines 779-784. One-off corrections (e.g., `6.90E+0.1 → 6.90E+01`) are real and must be supported via a user-editable one-off corrections table |
| **Qualifier extraction** | Values like "<0.005", ">10", "~3.2" must split qualifier from numeric value; qualifier stored separately as `=`, `<`, `>`, `~` | Low-Medium | stringr str_match (existing) | Named capture group pattern: `^([<>=~]?)\s*([\d.]+(?:[eE][+-]?\d+)?)$`. sswqs uses `result_bin` (as_is/low/high/mid) for range qualifiers; explicit qualifier symbols need the same treatment |
| **Range splitting** | Values like "5.6-7.8" must become two rows (low=5.6, high=7.8) plus an optional midpoint row | Medium | tidyr unnest (existing) | sswqs_curation.R lines 787-801 demonstrate the `str_split` + `unnest` pattern. Ambiguity: "-" is both range separator and negative sign — must parse numeric first, then re-attempt range split on non-numeric |
| **Unit string normalization** | Raw unit strings have micro symbols (µ vs u), mixed case, spaces around "/", latin vs ASCII variants | Low | stringi (existing) | sswqs_curation.R line 813-818: `str_replace_all("[\\u00B5\\u03BC]", "u")`, `stri_trans_general("latin-ascii")`, `str_to_lower()`, normalize " per " → "/" |
| **Unit harmonization lookup** | Map variant unit spellings to canonical targets (ug/l, mg/l, ppm → ug/l; mpn/100ml → count/100ml, etc.) | Medium | dplyr case_when (existing) | sswqs_curation.R lines 820-858 is the reference lookup table. ChemReg lifts ComptoxR unit tables and extends. Must support user-editable additions via reference list pattern (same as v1.3 stop words) |
| **Unit conversion arithmetic** | Convert parsed numeric values using factor (mg/L × 1000 → ug/L) or formula (°F = (°F-32)*5/9 → °C) | Low | dplyr mutate (existing) | sswqs_curation.R lines 861-891. Must store `conversion_factor` alongside result for audit trail |
| **Extended column tagging** | User must be able to tag columns as: Result, Unit, Duration, Qualifier, Application (human health/aquatic life), Location (freshwater/saltwater), Exposure route, Study type | Medium | mod_tag_columns (existing) | Extends existing 3-option dropdown (Chemical Name / CASRN / Other) to ~10 tag types. Same table-per-column UI pattern. Must preserve backward compat with existing curation tag types |
| **ToxVal schema transmutation** | Output must match the 56-column ToxVal schema exactly: toxval_id, dtxsid, source, toxval_type, toxval_numeric, toxval_units, toxval_numeric_qualifier, study_type, study_duration_class, species, exposure_route, media, etc. | High | dplyr transmute (existing) | sswqs_curation.R lines 925-1139 is the complete reference transmutation. `*_original` audit columns required for every harmonized field. NA_character_ for columns not mappable from source |
| **Export to parquet/CSV** | toxval.duckdb integration requires parquet or matching CSV schema | Low | rio (existing) | `rio::export(file = "output.parquet")` uses arrow backend. Verify arrow package available in project |

---

## Differentiators

Features that elevate ChemReg from a script wrapper to a real curation tool for this domain.

| Feature | Value Proposition | Complexity | Existing Dependency | Notes |
|---------|-------------------|------------|---------------------|-------|
| **User-editable unit harmonization table** | Curators encounter new unit variants in each new dataset; static lookup tables become stale. Editable table (same pattern as v1.3 reference list editors) lets users add mappings without touching code | High | mod_clean_data reference list pattern (existing) | Store as RDS in `inst/extdata/reference_cache/` alongside existing reference lists. Re-run harmonization cascade on save, same as v1.3 stop word edits |
| **Narrative filter review UI** | Rows excluded by narrative filter represent real data (regulatory decisions often expressed in prose). Show curator excluded rows with reason, allow manual override to keep a row and enter manual value | Medium | DT + reactiveValues (existing) | Reduces false exclusions. Pattern: show excluded rows in separate DT tab within harmonization UI; "Keep this row" button with manual value entry |
| **One-off corrections table** | Edge cases like `6.90E+0.1 → 6.90E+01` are real (seen in sswqs data). Curators need to log and apply source-specific fixes | Low | Reference list pattern (existing) | Store as editable `(pattern, replacement)` tibble. Applied as `str_replace` chain before normalization |
| **Range midpoint toggle** | sswqs generates low/high/mid rows from ranges. For toxval integration, mid rows are optional (some sources want only bounds). Let user choose: expand ranges to low/high/mid, low/high only, or midpoint only | Low | Reactive config (existing) | Checkbox in harmonization config panel |
| **Protection code / exposure classification decoder** | Source files encode exposure context as codes (H, Aa, AFc, etc.) that map to application/location/subtype. sswqs has 55+ codes. General solution: user uploads or edits a code→label lookup table | High | Reference list pattern (existing) | This is the general form of the 55-row `protection_lookup` in sswqs_curation.R. High value for regulatory datasets that use similar shorthand |
| **Harmonization audit trail** | For each row: what was `orig_result`, what normalization steps ran, what `cleaned_unit` was, what `harmonized_unit` it became, what conversion factor was applied | Medium | append_comment() pattern (existing v1.3) | Extends existing audit trail infrastructure. Adds columns: `harmonization_audit`, `unit_audit`, `qualifier_audit` |
| **Pre-export schema validation** | Before export, verify required ToxVal columns are not all-NA, dtxsid has been populated (via curation), numeric values are in range | Low | dplyr + notifications (existing) | Show a QC dashboard (value boxes) like existing post-curation QC in v1.3 Phase 15. Advisory only — don't gate export |
| **headless harmonization support** | `curate_headless()` already exists. Extend it to accept unit harmonization config and run the full v1.9 pipeline without UI | Medium | curate_headless.R (existing) | Critical for scripted batch processing of multiple benchmark sources. Preserves existing headless contract |

---

## Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Automatic unit inference from column name** | Column names like "conc_ugl" or "result_ppm" are tempting to parse, but source files are inconsistent — "result" could be ug/L or mg/L. Silent inference produces wrong conversions with no audit trail | Require user to tag a Unit column explicitly, or provide a default unit input if no Unit column exists |
| **UCUM / `units` package for harmonization** | The `units` package is elegant for SI physics but does not know `count/100ml`, `pcu`, `ntu`, `pci/l` or regulatory-specific units. Using it forces mapping regulatory units to UCUM first, adding an extra translation layer with no benefit | Use the existing `case_when` lookup table pattern (proven in sswqs_curation.R). Extend iteratively with new unit variants as they appear |
| **Bidirectional unit conversion** | Converting ug/L to mg/L and back introduces floating point drift; some conversions (°F→°C) are not reversible without original value. No downstream use case requires bidirectional conversion | Always convert to canonical target unit once; preserve original in `*_original` column |
| **Auto-split ranges on any dash** | Dashes appear in: negative numbers (-0.5), date strings, CASRN-like strings, compound names. Auto-splitting on "-" without numeric pre-check produces garbage rows | Parse numeric first; only attempt range split if `as.numeric()` returns NA and the string matches `^\d[\d.]*-\d[\d.]*$` |
| **Wizard-style value entry for narrative rows** | Giving curators a form to manually enter numeric values for narrative rows (e.g., "see page 42") opens the door to untracked manual data entry. Audit trail becomes unreliable | Mark narrative rows as `excluded_narrative` in audit column; allow curator to note reason but not silently inject numbers |
| **Full ToxVal schema enforcement at column-tag time** | Requiring all 56 ToxVal columns to be mapped before proceeding creates an impossible gating condition for sparse sources | Map what you can; leave unmappable columns as NA_character_; validate at export time (advisory only) |

---

## Feature Dependencies

```
Extended Column Tagging (Result, Unit, Duration, Qualifier, Application, Location)
    ↓
Narrative Result Filter
    ↓
Result String Normalization (comma removal, space removal, Fortran exponents, x10^ notation)
    ↓
One-off Corrections (user-editable patch table)
    ↓
Qualifier Extraction (<, >, ~, =)
    ↓
Numeric Parsing (as.numeric → parsed_value)
    ↓
Range Splitting (str_split on "-" → unnest → low/high/mid rows)
    ↓
Unit String Normalization (micro symbol, latin-ascii, lowercase, per→/)
    ↓
Unit Harmonization Lookup (case_when → harmonized_unit + conversion_factor)
    ↓
Unit Conversion Arithmetic (parsed_value × factor, or formula for °F)
    ↓
Harmonization Audit Trail (orig_result, cleaned_unit, harmonized_unit, conversion_factor)
    ↓
ToxVal Schema Transmutation (56-column output with *_original columns)
    ↓
Pre-export Schema Validation (QC value boxes)
    ↓
Export (parquet / CSV)
```

**Critical path:** Qualifier extraction must happen BEFORE range splitting (a qualifier "<5.6-7.8" is ambiguous — decide if the qualifier applies to the whole range or just the lower bound).

**Dependencies on existing features:**
- Extended column tagging sits inside mod_tag_columns; existing Name/CASRN/Other tags must remain intact and functional alongside new tags
- Harmonization audit trail extends `append_comment()` from v1.3 cleaning pipeline
- headless support extends `curate_headless()` from v1.8
- Reference list editors reuse pattern from v1.3 `cleaning_reference.R` + `mod_clean_data.R`
- Export extends existing 7-sheet openxlsx2 export; adds ToxVal sheet + harmonization audit sheet

---

## MVP Recommendation

Build in 3 increments. Each increment ships a usable capability.

### Increment 1: Core Numeric Pipeline (headless-first)
Build and validate as a standalone R function before wiring into Shiny.

1. `parse_result_string(x)` — normalization + qualifier extraction + numeric parse. Returns `list(qualifier, parsed_value, parse_success, parse_notes)`.
2. `split_ranges(df, result_col)` — range detection + row expansion (low/high/mid). Returns expanded df.
3. `normalize_unit_string(x)` — micro symbol + latin-ascii + lowercase + spacing. Returns cleaned string.
4. `harmonize_units(df, unit_col)` — lookup table → harmonized_unit + conversion_factor + converted_value. Returns df with audit columns.
5. Test all four functions with sswqs data as ground truth.

Defer: UI, ToxVal mapping, export.

### Increment 2: Extended Tagging + Harmonization UI
1. Extend `mod_tag_columns` with new tag types (Result, Unit, Duration, Qualifier, Application, Location, Exposure).
2. Add "Harmonize" tab (new top-level tab) that shows: narrative filter results, normalization preview, unit harmonization summary, range expansion preview.
3. Wire Increment 1 functions into reactive pipeline under the new tab.
4. User-editable unit harmonization table (reference list pattern).

### Increment 3: ToxVal Mapping + Export
1. `map_to_toxval(df, tag_map, source_metadata)` — transmute to 56-column schema. Returns toxval-schema df.
2. Add ToxVal mapping configuration UI (source name, subsource, toxval_type default, media, exposure_route defaults).
3. Pre-export QC dashboard (value boxes for: rows with numeric value, rows with harmonized unit, rows with dtxsid, rows with NA toxval_numeric).
4. Export to parquet/CSV.
5. Extend `curate_headless()` to accept harmonization config.

---

## Complexity Assessment

| Feature | LOC Estimate | Risk | Notes |
|---------|--------------|------|-------|
| `parse_result_string()` | 80 | Medium | Fortran exponent regex is tricky; sswqs_curation.R line 782 is the reference |
| `split_ranges()` | 60 | Medium | Dash ambiguity (negative vs range) is the main edge case |
| `normalize_unit_string()` | 40 | Low | Mechanical string transforms; well-tested pattern |
| `harmonize_units()` lookup table | 150 | Low | case_when lookup; ComptoxR tables as starting point |
| Unit harmonization arithmetic | 60 | Low | Straightforward multiply/formula; °F→°C special-cased |
| Extended column tagging UI | 100 | Low | Extend existing dropdown list; same table layout |
| Harmonize tab UI | 250 | Medium | New tab, 4 preview sub-sections, reactive wiring |
| User-editable unit table | 200 | Medium | Same pattern as v1.3 reference list editors |
| One-off corrections table | 100 | Low | Simple editable (pattern, replacement) tibble |
| Protection code decoder | 150 | High | Generalizing sswqs-specific 55-row lookup to user-uploadable table |
| Harmonization audit trail | 80 | Low | Extends existing append_comment() infrastructure |
| `map_to_toxval()` | 200 | High | 56-column schema with *_original columns; source-specific logic |
| ToxVal config UI | 150 | Medium | Source metadata form + defaults |
| Pre-export QC dashboard | 80 | Low | Value boxes + DT; same pattern as v1.3 post-curation QC |
| Parquet/CSV export | 40 | Low | `rio::export()` with arrow backend |
| `curate_headless()` extension | 80 | Low | Additive; existing contract unchanged |

**Total estimate:** ~1,820 LOC for full feature set. MVP Increment 1 ≈ 400 LOC (pure functions, no UI).

---

## Key Patterns from Reference Implementation

The sswqs_curation.R script establishes these patterns that ChemReg v1.9 should follow:

### Pattern 1: Preserve `orig_result` Before Any Mutation
```r
rename(orig_result = result) %>%
mutate(result = str_to_lower(orig_result), ...)
```
Never overwrite the original. Rename first, then work on the renamed copy.

### Pattern 2: `.id` Column for Range Group Identity
```r
mutate(.id = 1:n()) %>%
... unnest(result) %>%
group_by(.id) %>%
mutate(result_bin = case_when(n() == 1 ~ "as_is", ...))
```
Row-level identity survives the unnest explosion. Required for correct range midpoint calculation.

### Pattern 3: Two-Step Unit Harmonization
Step 1: `cleaned_unit` (normalize string). Step 2: `harmonized_unit` + `conversion_factor_str` (lookup + formula). Step 3: apply conversion to produce final `parsed_value`. Never skip the intermediate `cleaned_unit` — it is what the lookup table keys on.

### Pattern 4: Qualifier from Range Context vs Explicit Symbol
sswqs derives qualifier from `result_bin` (as_is/low/high/mid). Explicit qualifier symbols (`<`, `>`) require separate extraction before range splitting. Both must map to ToxVal's `toxval_numeric_qualifier` field (`=`, `<`, `>`, `~`).

### Pattern 5: NA_character_ for Unmappable ToxVal Fields
sswqs transmutation sets `toxval_id = NA_character_`, `source_hash = NA_character_`, etc. for fields that require database-side assignment. ChemReg should follow this — never fabricate IDs.

---

## Sources

- `curation/epa/sswqs/sswqs_curation.R` — PRIMARY reference implementation (lines 713-1142 cover full parsing + harmonization + ToxVal mapping pipeline)
- [ToxValDB v9.7.0 on EPA Figshare](https://epa.figshare.com/articles/dataset/ToxValDB_v9_1/20394501) — Schema reference and version history
- [USEPA/toxvaldbstage GitHub](https://github.com/USEPA/toxvaldbstage) — R package for ToxVal staging (code transparency; full reproduction not supported)
- [Development of ToxValDB (Wall et al. 2025, ScienceDirect)](https://www.sciencedirect.com/article/abs/pii/S2468111325000258) — Schema design rationale, two-phase curation + standardization model
- [baytrends: Processing Censored Water Quality Data (CRAN)](https://cran.r-project.org/web/packages/baytrends/vignettes/Processing_Censored_Data.html) — Censored data conventions (_lo/_hi suffix, upper >= lower validation)
- [units package (CRAN)](https://cran.r-project.org/package=units) — Evaluated and rejected for this domain (see Anti-Features)
- [R for Data Science 2e — Regular Expressions](https://r4ds.hadley.nz/regexps.html) — Named capture group patterns for qualifier extraction
