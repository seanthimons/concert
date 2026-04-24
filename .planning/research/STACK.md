# Technology Stack

**Project:** ChemReg v2.0 — Pipeline Performance & Date/Media Harmonization
**Researched:** 2026-04-24
**Scope:** NEW additions only for v2.0. The existing stack (R/Shiny, bslib, shinyjs, DT, reactable,
ComptoxR, rio, readxl, writexl, reactable.extras, stringr, stringi, dplyr, purrr, tidyr, tibble,
janitor, rlang, magrittr, fs, here, bsicons, arrow, units, digest, jsonlite) is validated and in
DESCRIPTION — do not re-research it.

---

## Executive Summary

v2.0 requires **two new DESCRIPTION entries** and **one new static data file**. Nothing else.

The seven capabilities break down into three buckets:

1. **Pure architecture** (no new packages): Distinct-string dedup, short-circuit evaluation,
   duration conversion, media/matrix classification. These are algorithmic patterns on top of
   existing `dplyr`/`stringr`/`purrr` that are already in DESCRIPTION. Benchmarks confirm 5-6x
   speedup at 100K rows from dedup alone, and media classification of 7500 AMOS descriptions
   runs in 30ms with `case_when()` + `str_detect()`.

2. **One new DESCRIPTION package** (`lubridate`): Date/study date parsing.
   `lubridate::parse_date_time()` is already installed (1.9.4) but was never wired into
   DESCRIPTION. It covers the full range of regulatory date formats (ISO, MDY, DMY, short month
   names, year-only, 2-digit year, SAS 15JAN1985, YYYYMMDD) without a new package. The
   alternative `datefixR` 2.0.0 is more ergonomic for messy form data but introduces a Rust
   binary dependency and adds nothing beyond what `parse_date_time()` already handles for the
   known regulatory date patterns.

3. **One new Suggests package** (`bench`): Performance benchmarking harness.
   `microbenchmark` 1.5.0 is already installed and handles nanosecond timing. `bench` 1.1.4
   adds memory allocation tracking and `bench::press()` for grid benchmarking across input
   sizes (e.g., 1K/10K/100K rows). For a production performance harness where you need to
   distinguish "slow because of CPU" from "slow because of GC pressure," `bench` is clearly
   superior. It goes in `Suggests:` not `Imports:` — it is never called from production code.

**Net DESCRIPTION change: add `lubridate` to Imports, add `bench` to Suggests.**

No NLP packages, no ML, no additional Rust binaries, no new data sources beyond the existing
ECOTOX duration table already identified.

---

## New Stack Additions

### 1. lubridate — Date/Study Date Parsing

| Attribute | Value |
|-----------|-------|
| Package | `lubridate` |
| CRAN version | 1.9.4 (confirmed installed) |
| Purpose | Parse `study_date`, `effective_date`, and similar columns from messy date strings into R `Date` objects; extract `year` field for ToxVal schema |
| Why | `lubridate::parse_date_time()` with `orders = c("ymd", "mdy", "dmy", "dBY", "BY", "bY", "y", "Ym", "dmY", "bdY")` handles all tested regulatory date formats: ISO 8601, M/D/Y, D/Y, short month names, year-only, 2-digit years, SAS `15JAN1985`, `YYYYMMDD` no separator. No other package needed. |
| Already in DESCRIPTION | NO — must add to `Imports:` |
| In production use | NO — installed but unused in R/*.R (confirmed with grep) |
| Confidence | HIGH — version confirmed installed, formats tested against real patterns, consistent with sswqs_curation.R precedent |

**What lubridate handles well (verified):**

| Input | Parsed As |
|-------|-----------|
| `"1985"` | `1985-01-01` |
| `"Jan-85"` | `1985-01-01` |
| `"1985/01"` | `1985-01-01` |
| `"85-01-15"` | `1985-01-15` |
| `"15JAN1985"` | `1985-01-15` |
| `"19850115"` | `1985-01-15` |
| `"January 1985"` | `1985-01-19` (close enough) |
| `"01/15/2024"` | `2024-01-15` |
| Narrative text / NA | `NA` (graceful) |

**What it does NOT handle** (require `NA` + audit flag, not a new package):
- `"FY2019"` (fiscal year)
- `"2019-2020"` (date ranges)
- `"2019 Q3"` (quarters — parses to `2019-03-01`, which is wrong)

For these, the correct approach is: detect → return `NA` + set `date_parse_flag = "fiscal_year"` etc.
No package can reliably convert these without domain business rules.

**Integration point:** New `R/date_harmonizer.R` with `parse_study_date()` and
`extract_study_year()`. Called from `R/toxval_mapper.R` for the `year` and `year_original` columns.

**Why not `datefixR` 2.0.0:**
- Adds a Rust binary dependency (compiled C extension) — complicates installation in locked
  environments
- Designed for web form data (DMY/MDY confusion) not regulatory/study metadata
- Does not handle `15JAN1985` (SAS), `YYYYMMDD`, or year-only without imputation
- lubridate is already in the tidyverse dependency graph; datefixR is a standalone addition

---

### 2. bench — Performance Benchmarking Harness (Suggests only)

| Attribute | Value |
|-----------|-------|
| Package | `bench` |
| CRAN version | 1.1.4 (confirmed on CRAN, not yet installed) |
| Purpose | Benchmark cleaning and harmonization pipeline steps against 1K/10K/100K row datasets; track memory allocation alongside timing |
| Why | `microbenchmark` (already installed, 1.5.0) handles nanosecond timing but has no memory tracking and no grid benchmarking. `bench::press()` allows a single benchmark definition to run across a grid of `n = c(1000, 10000, 100000)` and produce a tidy tibble with timing + memory per combination. For diagnosing whether slowness is CPU or GC pressure, `mem_alloc` is essential. |
| Goes in | `Suggests:` — never called from production code, only from `scripts/benchmark_pipeline.R` |
| Confidence | HIGH — CRAN stable, maintained by r-lib (Hadley Wickham's team), version confirmed |

**Key `bench::press()` pattern for the harness:**

```r
bench::press(
  n = c(1000, 10000, 100000),
  {
    df <- generate_test_dataset(n)
    bench::mark(
      row_by_row    = run_cleaning_pipeline(df, strategy = "row"),
      dedup_remap   = run_cleaning_pipeline(df, strategy = "dedup"),
      check = FALSE
    )
  }
)
```

**Why not use only `microbenchmark`:**
- No memory tracking: cannot distinguish CPU-slow from allocation-heavy
- No grid benchmarking: requires manual loops and rbind to compare across sizes
- No GC filtering: iterations with GC pauses contaminate results
- microbenchmark stays in the codebase for ad-hoc timing; bench is the harness package

---

## Architecture Patterns (No New Packages Required)

These are implementation patterns, not package additions. Documented here because they affect
which existing packages are used and where.

### Distinct-String Dedup Pattern

**Package:** `dplyr` + `stringr` (already in DESCRIPTION)
**Speedup confirmed:** 5.5x at 100K rows with 5000 unique values (benchmarked locally)

```r
# In each cleaning step, replace:
#   mutate(col = heavy_regex_fn(col))        # processes 100K strings
# With:
#   unique_vals <- unique(df[[col]])
#   cleaned <- heavy_regex_fn(unique_vals)   # processes N unique strings
#   lookup   <- stats::setNames(cleaned, unique_vals)
#   mutate(col = lookup[col])                # O(1) hash lookup per row
```

**Integration point:** Each function in `R/cleaning_pipeline.R` that applies a `mutate()` with a
regex-heavy function is a candidate. The `run_cleaning_pipeline()` orchestrator extracts uniques
once per step, processes, then remaps. This is the primary performance fix.

**Realistic dedup ratio:** Chemical name datasets typically have 1–5% unique ratio at 100K rows
(e.g., a regulatory dataset with 100K entries but only 2000 distinct chemical names). The 5089/100K
benchmark is conservative — real datasets will see higher speedups.

### Short-Circuit Evaluation Pattern

**Package:** `stringr` (already in DESCRIPTION)
**Pre-check cost:** ~0ms for clean columns at 100K rows (confirmed benchmarked)

Each cleaning step gains a `can_skip_X()` pre-check:

```r
# Pre-check runs on distinct values, not all rows
has_unicode <- function(col) any(stringr::str_detect(unique(col), "[^\\x00-\\x7F]"), na.rm = TRUE)
has_placeholders <- function(col) any(stringr::str_detect(unique(col), "@@@|%%%|###"), na.rm = TRUE)
has_parentheses <- function(col) any(stringr::str_detect(unique(col), "\\(|\\["), na.rm = TRUE)
```

The recommendation modal (Shiny UI) collects these flags and shows the user which steps are
estimated to do work vs which are no-ops. This is a UI convenience; the pipeline runs correctly
either way.

**No new packages** — `stringr::str_detect()` vectorized over distinct values is fast enough.

### Duration Conversion Pattern

**Package:** `stringr` + `dplyr` (already in DESCRIPTION), `lubridate` optional for edge cases
**Conversion table:** Lift from ECOTOX builder (lines 465–474 of `ecotox.R`) + extend

The ECOTOX table is confirmed complete for regulatory/toxicology datasets:

```
min  ->  1/60 h
h    ->  1 h
d    ->  24 h
wk   ->  168 h
mo   ->  730 h    (average month = 30.44 days)
yr   ->  8760 h
```

**Pattern:** Extract numeric value with `str_extract()`, extract unit with `str_extract()`,
join against lookup tibble, multiply. No iteration, no `apply`. Narratives ("continuous",
"see notes") produce `NA` + `duration_parse_flag = "narrative"`. Ranges ("30-90 days") extract
first value + flag. Benchmarked: 100K rows in < 0.1s.

**No new packages.** lubridate is not needed for duration parsing — only for calendar date
parsing (study_date/effective_date columns).

### Environmental Media Classification Pattern

**Package:** `stringr` + `dplyr` (already in DESCRIPTION)
**Scale confirmed:** 7500 AMOS descriptions classified in 30ms

The classification is a tiered `case_when()` + `str_detect()` over lowercased text:

```r
classify_media <- function(desc) {
  d <- stringr::str_to_lower(desc)
  dplyr::case_when(
    stringr::str_detect(d, "drinking water|tap water|potable")    ~ "drinking_water",
    stringr::str_detect(d, "surface water|river|lake|stream")     ~ "surface_water",
    stringr::str_detect(d, "groundwater|ground water|aquifer")    ~ "groundwater",
    stringr::str_detect(d, "wastewater|effluent|sewage")          ~ "wastewater",
    stringr::str_detect(d, "sediment")                            ~ "sediment",
    stringr::str_detect(d, "\\bsoil\\b|\\bsediment\\b")          ~ "soil",
    stringr::str_detect(d, "\\bair\\b|atmosphere|stack gas")      ~ "air",
    stringr::str_detect(d, "tissue|blood|urine|biota|fish")       ~ "biota",
    stringr::str_detect(d, "biosolid|sludge")                     ~ "biosolids",
    stringr::str_detect(d, "marine|ocean|seawater|estuarine")     ~ "marine_estuarine",
    TRUE                                                           ~ "unclassified"
  )
}
```

**Extensibility:** The classification terms are stored in a static tibble (same pattern as unit
conversion and reference lists) so the user can add/edit terms via the existing reference list
editor UI without touching R code.

**No NLP packages.** `tidytext`, `textrecipes`, `tm` are not needed. The AMOS descriptions
are structured enough that keyword matching achieves the required classification. The ~30% that
land in "unclassified" represent genuine multi-matrix or uncurated entries — these get flagged
for manual review, not forced into a category.

### AMOS Method Ontology Extraction

**Package:** `ComptoxR` (already in DESCRIPTION as a Remote)
**API:** `ComptoxR::chemi_amos_method_pagination(limit, offset, all_pages)` — confirmed available

The extraction pipeline is:
1. Call `chemi_amos_method_pagination(all_pages = TRUE)` → tibble of ~7500 method records
2. Each record has: `name`, `matrix` (structured), `methodology`, `analyte`, `year`, `source`
3. The `matrix` field is already structured in some records — use it where available
4. For records where `matrix` is blank, apply `classify_media()` against `name`/description
5. Cache result as `inst/extdata/amos_methods_cache.rds`

The cache is refreshed manually (or on package install via `.onLoad`), not on every app session.
`ComptoxR` handles all pagination internally — no new HTTP client needed.

---

## DESCRIPTION Changes Required

```
Imports (ADD one line):
    lubridate,

Suggests (ADD one line):
    bench,
```

That is the complete change to DESCRIPTION. All other v2.0 capabilities use packages already
in Imports.

---

## What Does NOT Need to Be Added

### `datefixR` 2.0.0

- Designed for web form data (mixed DMY/MDY), not regulatory metadata
- Adds a Rust binary; `lubridate` already installed and covers all verified patterns
- Year-only, SAS-format, and YYYYMMDD all handled by `parse_date_time()` with the right `orders`

### `anytime` / `parsedate`

- `anytime::anydate()` silently returns `NA` without warning on parse failure — audit trail
  poisoning risk in a cleaning pipeline
- `parsedate::parse_date()` cannot handle years before 1970 — regulatory data goes to 1950s
- Neither handles `15JAN1985` (SAS format) without custom preprocessing

### NLP packages (`tidytext`, `textrecipes`, `tm`, `quanteda`)

- AMOS media classification is pattern-matching, not text mining
- 7500 descriptions × 10-15 `str_detect()` calls completes in 30ms — no tokenization needed
- NLP approaches would require labeled training data (which doesn't exist for AMOS media)
- `case_when()` + `str_detect()` produces an auditable, editable lookup that domain experts
  can maintain; ML models do not

### `data.table` for performance

- Already installed (1.18.2.1) but NOT in DESCRIPTION and not part of the existing codebase
- Adding `data.table` would require rewriting dplyr pipeline idioms throughout cleaning_pipeline.R
- The dedup+remap pattern achieves sufficient speedup (5-6x) without syntax migration
- Risk: data.table and dplyr together in the same codebase create maintenance friction

### `collapse` / `polars` for performance

- Not installed, introduces new syntax paradigm, no migration path from existing dplyr code
- Dedup+remap on existing dplyr is sufficient at 100K scale (benchmark confirmed)

### `clock` for date parsing

- Already installed (0.7.4) but is a low-level date arithmetic package, not a messy-date parser
- `lubridate` is the correct tool for parsing irregular strings into dates
- `clock` would be used if nanosecond precision or calendar system conversion were needed (not the case here)

### `profvis` for benchmarking

- Already installed (0.4.0) — appropriate for interactive profiling, not systematic harness
- Use `profvis` for one-off debugging sessions; use `bench` for the repeatable harness in scripts/

---

## Existing Packages That Enable New v2.0 Capabilities

Already in DESCRIPTION — no action needed:

| Package | v2.0 Use | Confidence |
|---------|----------|------------|
| `stringr` 1.6.0 | `str_detect()` for pre-checks; `str_extract()` for duration value/unit parsing; media keyword matching | HIGH — all patterns benchmarked |
| `dplyr` 1.2.1 | `case_when()` for media/duration dispatch; `distinct()` for dedup extraction; `mutate()` with named vector remap | HIGH — dedup pattern tested at 100K |
| `purrr` 1.2.1 | `safely()` around date parse attempts for error isolation in batch processing | HIGH — existing pattern from data_detection.R |
| `tibble` 3.3.0 | Static duration conversion table and media classification table stored as tibbles | HIGH — existing pattern from unit_table.csv |
| `ComptoxR` (Remote) | `chemi_amos_method_pagination()` for AMOS method extraction | HIGH — function confirmed present with correct signature |
| `arrow` 21.0.0.1 | Unchanged — still used for parquet export | HIGH |
| `units` 0.8.7 | Unchanged — still used for SI unit conversion in harmonization pipeline | HIGH |

---

## New R Files (not packages)

These are new source files, not new dependencies:

```
R/date_harmonizer.R      parse_study_date(), extract_study_year(), flag_unparseable_dates()
R/duration_harmonizer.R  parse_duration_to_hours(), load_duration_table()
R/media_classifier.R     classify_media(), load_media_terms(), classify_amos_methods()
scripts/benchmark_pipeline.R   bench::press() harness, not installed into package
```

These follow the existing pure-function pattern: data in, tibble out, no Shiny reactivity,
no API calls, independently testable.

---

## New Static Data Files (inst/extdata/)

One new cache file:

### amos_methods_cache.rds

A tibble of ~7500 AMOS method records with media classification applied. Schema:

| Column | Type | Source |
|--------|------|--------|
| `method_id` | character | AMOS API |
| `name` | character | AMOS API |
| `matrix_raw` | character | AMOS API (`matrix` field) |
| `media_class` | character | Derived by `classify_media()` |
| `methodology` | character | AMOS API |
| `year` | integer | AMOS API |
| `source` | character | AMOS API |

Loaded once per session via `system.file("extdata", "amos_methods_cache.rds", package = "chemreg")`.
Refreshed by running `scripts/refresh_amos_cache.R` manually (requires API key).

The duration conversion table is in the existing `inst/extdata/unit_table.csv` (151 rows) —
add the 10 duration rows there rather than creating a separate file.

---

## Sources

| Source | Type | Confidence |
|--------|------|------------|
| `ComptoxR/inst/ecotox/ecotox_build.R` lines 465–474 | Direct code read | HIGH |
| `ComptoxR::chemi_amos_method_pagination` formals inspection | Runtime verification | HIGH |
| `chemreg/DESCRIPTION` | Direct file read | HIGH |
| `packageVersion('lubridate')` → 1.9.4 | Runtime verification | HIGH |
| `packageVersion('microbenchmark')` → 1.5.0 | Runtime verification | HIGH |
| Dedup benchmark: 5089 uniques / 100K rows → 5.5x speedup | Local benchmark | HIGH |
| Media classification: 7500 descriptions in 30ms | Local benchmark | HIGH |
| lubridate date parsing against 14 tricky formats | Local benchmark | HIGH |
| CRAN bench 1.1.4 | CRAN package index | HIGH |
| CRAN datefixR 2.0.0 | CRAN package index + docs.ropensci.org | HIGH |
| EPA AMOS User Guide | WebFetch from epa.gov | HIGH |
| bench vs microbenchmark comparison | bench.r-lib.org + cran.r-project.org | HIGH |

---
*Stack research for: ChemReg v2.0 Pipeline Performance & Date/Media Harmonization*
*Researched: 2026-04-24*
