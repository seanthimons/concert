# Technology Stack

**Project:** ChemReg v1.9 — Number and Unit Coercion Harmonization
**Researched:** 2026-04-14
**Scope:** NEW additions only for v1.9. The existing stack (R/Shiny, bslib, shinyjs, DT, reactable,
ComptoxR, rio, readxl, writexl, reactable.extras, stringr, stringi, dplyr, purrr, tidyr, tibble,
janitor, rlang, magrittr, fs, here, bsicons) is validated and in DESCRIPTION — do not re-research it.

---

## Executive Summary

v1.9 requires **two new DESCRIPTION entries** and **two new static data files**. Nothing else.

The existing codebase and sibling scripts already demonstrate the complete implementation pattern:

- `ComptoxR/inst/ecotox/ecotox_build.R` lines 271–467: A ~200-row tribble (`unit_result`) encoding
  mass, volume, fraction, mol, length, area, time, radioactivity, and noscience unit types with
  multipliers and canonical targets. This can be lifted wholesale into `inst/extdata/`.
- `curation/epa/sswqs/sswqs_curation.R` lines 775–1141: Working numeric parsing pipeline and full
  56-column ToxVal schema transmute() block, proven against EPA production data.

Neither of these capabilities requires a new framework package. The parsing is pure stringr/dplyr.
The unit conversion is a lookup join against a static tibble. The export is `arrow::write_parquet()`.

**New DESCRIPTION entries: `arrow`, `lubridate`**
Both are already installed on this machine. Neither introduces new system-level dependencies.

---

## New Stack Additions

### 1. arrow — Parquet Export

| Attribute | Value |
|-----------|-------|
| Package | `arrow` |
| Installed version | 21.0.0.1 (confirmed on this machine) |
| Purpose | Write toxval-compatible `.parquet` output via `arrow::write_parquet()` |
| Why | ToxVal local database is DuckDB-backed parquet. `rio::export(..., format="parquet")` delegates to arrow internally — calling arrow directly gives explicit schema control (column types, nullability), which is required to match an existing toxval.duckdb schema exactly. |
| Already in DESCRIPTION | NO — must add to `Imports:` |
| Confidence | HIGH — arrow 21.x confirmed installed, CRAN stable, direct read of arrow docs |

**Integration point:** `R/export_helpers.R` gains a `write_toxval_parquet()` function. The Shiny
export module adds a format toggle (CSV vs Parquet). The schema is enforced by writing against a
zero-row typed tibble stored in `inst/extdata/toxval_schema.rds`.

**Why not use rio for parquet output?** rio delegates to arrow anyway, adding an indirection layer
that prevents setting an explicit Arrow schema. Type coercions that are silent in rio
(e.g., NA_character_ columns becoming logical) will cause DuckDB read failures.

### 2. lubridate — Date Parsing in ToxVal Mapper

| Attribute | Value |
|-----------|-------|
| Package | `lubridate` |
| Installed version | 1.9.4 (confirmed on this machine) |
| Purpose | Parse `effective_date` columns; extract year for `year` / `year_original` ToxVal columns; normalize `study_duration_value` expressions like "24 hr", "7 days" |
| Why | The sswqs_curation.R ToxVal mapper (line 1018) already uses `lubridate::year(effective_date)` for this exact pattern. Consistent with what the downstream scripts expect. |
| Already in DESCRIPTION | NO — must add to `Imports:` |
| Confidence | HIGH — confirmed installed, pattern confirmed in production curation script |

**Integration point:** `R/toxval_mapper.R` (new file) and potentially `R/numeric_parser.R` for
duration normalization. Not needed for the unit conversion pipeline itself.

---

## DESCRIPTION Change Required

```
Imports (ADD two lines):
    arrow,
    lubridate,
```

That is the complete change to DESCRIPTION. All other v1.9 capabilities are covered by packages
already in Imports.

---

## What Does NOT Need to Be Added

### The `units` CRAN Package (installed: 0.8.7)

The `units` package handles SI unit arithmetic via the UDUNITS2 C library. Do not use it here:

- Regulatory data units are domain-specific (`pCi/L`, `NTU`, `count/100mL`, `mg/kg wet weight`,
  `standard units` for pH) that UDUNITS2 does not recognize
- The ecotox_build.R tribble already encodes the complete multiplier lookup table for this domain
- The `units` package adds a compiled C library system dependency (UDUNITS2) that complicates
  package installation across environments
- The sswqs_curation.R script demonstrates the correct pattern: a lookup join + `case_when()` for
  edge cases is maintainable and auditable in a regulatory context

### `readr::parse_number()` for Qualifier Extraction

`readr::parse_number()` strips qualifiers silently (`<0.05` becomes `0.05` with no qualifier capture
and no warning). The correct approach — confirmed in sswqs_curation.R — is to extract qualifiers
first with a regex pass, then normalize the numeric string, then `as.numeric()`. `readr` is already
in the dependency tree; no new package needed.

### `openxlsx2` for ToxVal Export

Not needed for v1.9. The ToxVal output is parquet (arrow) or CSV (writexl/rio). openxlsx2 was
added in v1.3 but is not currently installed and not in DESCRIPTION — do not add it for v1.9.
The existing 7-sheet Excel export (writexl) is unchanged; ToxVal schema export is a separate
output format.

### `unitconv`, `measurements`, or other unit conversion CRAN packages

These packages cover SI/imperial conversions only. None handles environmental regulatory units
(pCi/L, NTU, CFU/100mL, standard pH units, etc.). The lifted ecotox tribble is more complete for
this domain and is already validated against ECOTOX production data.

### `tidytext`, `textrecipes`, or NLP packages

Duration/exposure classification ("acute", "chronic", "freshwater") is done with `str_detect()`
pattern matching on coded columns, not NLP. The sswqs_curation.R protection_lookup tibble confirms
this: 55 protection codes decoded via `case_when()` + `str_detect()`. No text mining needed.

---

## Existing Packages That Enable New v1.9 Capabilities

These are already in DESCRIPTION — no action needed:

| Package | v1.9 Use | Confirmed Pattern |
|---------|----------|-------------------|
| `stringi` 1.8.7 | Unicode micro-symbol normalization: `stringi::stri_trans_general("latin-ascii")` | sswqs_curation.R line ~815 uses this exact call before unit lookup |
| `stringr` | Regex normalization pipeline for numeric parsing (Fortran exponents, x10^, spaces) | Full pipeline in sswqs_curation.R lines 777–782 |
| `dplyr` 1.2.0 | `case_when()` for unit harmonization dispatch; `left_join()` against unit lookup table | Core pattern throughout both source scripts |
| `purrr` 1.2.1 | `purrr::safely()` around per-row parser for error isolation | Consistent with existing ensemble detection pattern in data_detection.R |
| `tibble` | Static unit lookup stored as named tibble in `inst/extdata/` | tribble format matches ecotox_build.R exactly |
| `rio` | Import any user-provided unit override tables (CSV/XLSX) | Already handles all import formats |
| `writexl` | CSV-adjacent export; remains available as non-parquet export option | Already in DESCRIPTION |

---

## New Static Data Files (inst/extdata/)

These are data additions, not packages. Store alongside existing `reference_cache/` files.

### unit_conversion.rds

**Source:** Lifted from `ComptoxR/inst/ecotox/ecotox_build.R` lines 271–467 (`unit_result` tribble).

Schema: 4 columns — `unit` (character), `multiplier` (double), `unit_conv` (character, canonical
target), `type` (character: mass/volume/fraction/mol/length/area/time/radioactivity/noscience/nodata).

Contains ~200 rows covering the ecotoxicology domain. Extend with regulatory-specific rows not
present in ecotox (sourced from sswqs_curation.R unit harmonization block):

| unit (raw) | unit_conv | multiplier | type |
|------------|-----------|------------|------|
| `pCi/L` | `pCi/L` | 1 | radioactivity/volume |
| `NTU` | `NTU` | 1 | noscience |
| `JTU` | `NTU` | 1 | noscience |
| `standard units` | `pH units` | 1 | noscience |
| `pH units` | `pH units` | 1 | noscience |
| `us/cm` | `us/cm` | 1 | electricity/length |
| `umhos/cm` | `us/cm` | 1 | electricity/length |
| `dS/m` | `us/cm` | 1000 | electricity/length |
| `count/100mL` | `count/100mL` | 1 | noscience |
| `CFU/100 mL` | `count/100mL` | 1 | noscience |
| `MPN/100 mL` | `count/100mL` | 1 | noscience |
| `mg/kg (wet weight)` | `mg/kg (wet weight)` | 1 | mass/mass |

Loaded once at pipeline start via `readRDS(system.file("extdata", "unit_conversion.rds", package = "chemreg"))`.

### toxval_schema.rds

A zero-row tibble encoding the 56-column ToxVal schema with correct column types. Derived from the
`transmute()` block in sswqs_curation.R lines 1057–1138.

Purpose: Validates output shape before `arrow::write_parquet()`. Prevents silent column-order or
type mismatches when DuckDB reads the output. Call `dplyr::bind_rows(toxval_schema, result)` as a
shape assertion before writing.

Critical type constraints:

| Column | Required Type | Risk if Wrong |
|--------|---------------|---------------|
| `toxval_numeric` | double | DuckDB will error if character |
| `toxval_numeric_original` | character | Must preserve original string |
| `toxval_numeric_qualifier` | character | `=`, `<`, `>`, `<=`, `>=`, `~` |
| `year` | character | 4-digit string, not integer |
| All `*_original` columns | character | Pre-harmonization audit trail |
| All `NA_character_` columns | character | Arrow infers logical for all-NA without schema |

---

## New R Files (not packages)

These are new R source files in `R/`, not new dependencies:

```
R/numeric_parser.R     parse_result_string(), extract_qualifier(), normalize_numeric_string()
R/unit_harmonizer.R    harmonize_units(), load_unit_table(), normalize_unit_string()
R/toxval_mapper.R      map_to_toxval_schema(), validate_toxval_output()
R/export_helpers.R     EXTEND: add write_toxval_parquet() alongside existing write functions
```

These follow the same pure-function pattern as `cleaning_pipeline.R`: data in, tibble out,
no Shiny reactivity, no API calls, independently testable.

---

## Numeric Parsing Pattern (confirmed, HIGH confidence)

The complete pipeline is already proven in sswqs_curation.R lines 777–801. Transcribed here
as the implementation spec for `R/numeric_parser.R`:

**Step 1 — Extract qualifier (ChemReg addition, not in sswqs):**
```r
qualifier <- str_extract(result, "^[<>]=?|^~|^=")
result    <- str_remove(result, "^[<>]=?|^~|^=")
```

**Step 2 — Normalize text:**
```r
result <- str_to_lower(result)
result <- str_replace_all(result, " million", "e6")
result <- str_remove_all(result, "[\\*,]")
result <- str_remove_all(result, "[[:space:]]")       # "5.0 e-9" -> "5.0e-9"
result <- str_replace_all(result, "x10\\^?", "e")     # "5x10^-9" -> "5e-9"
# Fix Fortran-style exponents: "4.56+02" -> "4.56e+02"
result <- str_replace(result,
  "(?<=[0-9])(?<!e)([+-])(?=0\\d(?!\\d))", "e\\1")
```

**Step 3 — Handle ranges:**
```r
# Split "5.6-7.8" into two rows only if not already numeric
result <- if_else(
  !is.na(as.numeric(result)),
  as.list(result),
  str_split(result, pattern = "-")
)
# unnest() + re-parse
```

**Step 4 — Coerce:**
```r
parsed_value <- as.numeric(result)
```

Non-parseable values (narrative text, "see standard", "ND") produce `NA` from `as.numeric()` and
are retained with `parsed_value = NA` + `parse_flag = "unparseable"` for audit, not silently dropped.

---

## Unit Harmonization Pattern (confirmed, HIGH confidence)

Two-layer design derived from both source scripts:

**Layer 1 — String normalization** (makes lookup reliable):
```r
unit_normalized <- unit_raw %>%
  str_replace_all("[\\u00B5\\u03BC]", "u") %>%   # µ -> u (micro symbol variants)
  stringi::stri_trans_general("latin-ascii") %>%  # all remaining unicode -> ascii
  str_to_lower() %>%
  str_replace_all("\\s+(per|/)\\s+", "/") %>%     # "mg per L" -> "mg/L"
  str_trim()
```

**Layer 2 — Lookup join** (multiplier-based, uses static RDS):
```r
result <- result %>%
  left_join(unit_conversion_table, by = c("unit_normalized" = "unit")) %>%
  mutate(
    harmonized_value = parsed_value * multiplier,
    harmonized_unit  = unit_conv,
    unit_type        = type
  )
```

Unmatched units (no join hit) get `harmonized_unit = unit_normalized`, `multiplier = NA`,
`unit_type = "unknown"` — preserved for audit, flagged for review, not silently converted.

---

## ToxVal Export: Schema Alignment

The sswqs_curation.R `transmute()` block (lines 1057–1138) is the canonical 56-column schema source.
Key structural observations for `R/toxval_mapper.R`:

- All `NA_character_` scaffold columns (e.g., `toxval_id`, `source_hash`, `chemical_id`,
  `study_duration_value`, `strain`, `sex`, `critical_effect`) must remain character type, not
  logical. Arrow infers `logical` for all-NA columns unless an explicit schema is provided.
- `toxval_numeric_original` stores the raw string (e.g., `"<0.05"`) before any parsing.
- `toxval_units_original` stores the raw unit string before normalization.
- `qualifier` mirrors `toxval_numeric_qualifier` for legacy compatibility.
- Column order in the parquet output must match the schema exactly for DuckDB COPY INTO operations.

---

## Sources

| Source | Type | Confidence |
|--------|------|------------|
| `ComptoxR/inst/ecotox/ecotox_build.R` lines 271–469 | Direct code read | HIGH |
| `curation/epa/sswqs/sswqs_curation.R` lines 775–1141 | Direct code read | HIGH |
| `chemreg/DESCRIPTION` | Direct file read | HIGH |
| `packageVersion('arrow')` → 21.0.0.1 | Runtime verification | HIGH |
| `packageVersion('lubridate')` → 1.9.4 | Runtime verification | HIGH |
| `packageVersion('units')` → 0.8.7 (NOT recommended) | Runtime verification | HIGH |
| `packageVersion('stringi')` → 1.8.7 | Runtime verification | HIGH |
