# Feature Research

**Domain:** ETL pipeline performance optimization, date/duration parsing, and environmental media harmonization for chemical regulatory data curation
**Milestone:** v2.0 Pipeline Performance & Date/Media Harmonization
**Researched:** 2026-04-24
**Supersedes:** Previous FEATURES.md (v1.9 Number and Unit Coercion Harmonization milestone)
**Confidence:** HIGH (features grounded in existing codebase and verified ecosystem patterns)

---

## Executive Summary

v2.0 has two distinct concerns that must be sequenced correctly: (1) architectural performance work that applies globally to all pipeline steps, and (2) three new domain features (date parsing, duration normalization, media classification). The architectural work must land first — adding new pipeline steps to a slow pipeline makes performance worse, not better.

The distinct-string dedup pattern is a well-established split-apply-combine optimization: extract unique strings, process the unique set, join results back by key. At 100K rows with ~2K unique chemical names, this is a 50x reduction in string operations. The ECOTOX codebase (`curation/ecotox/ecotox.R`) already demonstrates the duration conversion table pattern (hours as canonical, conversion factors as numeric multipliers). AMOS media categorization is the most technically open-ended feature — 7,500 method descriptions require text mining, not lookup tables.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features the v2.0 milestone must deliver. Missing any of these means the milestone goal is not met.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Distinct-string dedup for cleaning pipeline** | 100K-row datasets are currently unusable — the cleaning pipeline processes each row individually even when 95%+ of strings are duplicates of a small unique set | HIGH | Core architectural change. Pattern: `unique_strings <- distinct(df, val)` → apply all cleaning steps to `unique_strings` → `left_join(df, unique_strings, by = "val")`. Must preserve audit trail (row_id remapping required). Applies to unicode cleaning, stop-word matching, isotope expansion, synonym splitting |
| **Distinct-string dedup for harmonization pipeline** | Same problem: unit harmonization calls `normalize_unit_string()` and the lookup table for every row, but most datasets have <50 unique unit strings across 100K rows | MEDIUM | Simpler than cleaning dedup because harmonization produces scalar outputs (harmonized_unit, conversion_factor). Pattern: `unit_map <- harmonize_units(distinct_units)` → `left_join(df, unit_map, by = "orig_unit")`. No audit trail remapping needed |
| **Short-circuit step evaluation** | Users should not wait for all 15 cleaning steps when a dataset is already clean for most steps. Per-step "does this step need to run?" check prevents wasted work | MEDIUM | Each step needs a cheap "any candidates?" pre-check. E.g., unicode step: `any(stringr::str_detect(vals, "[^\x00-\x7F]"))`. If FALSE, skip step entirely. Steps that modify row count (synonym splitting) cannot be safely short-circuited without downstream row-count reconciliation |
| **Recommendation modal before pipeline execution** | User uploads a dataset and clicks "Run Cleaning." App should inspect data characteristics and recommend which steps are likely to fire vs. safe to skip, with a preview count for each | MEDIUM | Inspection is cheap (run each pre-check on full dataset before pipeline starts). Modal shows table: Step | Estimated Changes | Recommended. User can override. Prevents surprise long runs for datasets that are already mostly clean |
| **Date/study date parsing** | ToxVal `study_date` and similar fields are commonly populated in regulatory source data. Users need these parsed and normalized — right now they pass through as raw strings | MEDIUM | `datefixR` (v2.0.0, rOpenSci) handles the messy/partial date problem better than lubridate alone. Supports mixed formats, imputes missing day/month, Rust backend for performance. API: `fix_date_char(x)` → standard R `Date`. Falls back to `lubridate::parse_date_time()` with multi-format orders for cleaner data |
| **Duration normalization** | Exposure duration fields ("96h", "21 days", "4 wk") are useless until normalized to a canonical unit. ToxVal uses hours. ECOTOX already has this conversion table | LOW-MEDIUM | The ECOTOX builder (`curation/ecotox/ecotox.R` lines 643-677) is the reference. Conversion factors: seconds=1/3600, minutes=1/60, hours=1, days=24, weeks=168, months=730.49 (24×30.43685). Pattern: regex parse value+unit → apply factor. Ambiguous inputs (bare "96" with no unit) need a default-unit fallback |
| **Environmental media/matrix classification** | ToxVal `media` field requires a controlled vocabulary (freshwater, saltwater, soil, sediment, air, etc.). Users tag a media column, but raw values are messy and need mapping to the canonical list | MEDIUM | Lookup table pattern (same as unit harmonization). Core ontology: freshwater, saltwater/marine, brackish, soil, sediment, air/atmosphere, groundwater, effluent, biota, food/diet, NR (not reported). Source values need many-to-one mapping with user-editable override table |
| **AMOS media ontology extraction** | ComptoxR provides `chemi_amos_method_pagination()` returning ~7,500 method records. Each has a `matrix` field describing sample media in free text. Extracting structured media categories from this requires text mining, not just lookup | HIGH | The AMOS database uses "harmonized media category" from EPA's MMDB. Matrix field is messy free text. Pattern: keyword-matching dictionary (freshwater/marine/soil keywords) → majority-vote classification per method. Not an LLM problem — a `quanteda` dictionary approach with ~50 rules covers 80%+ of cases |

### Differentiators (Competitive Advantage)

Features that make v2.0 more than just a performance patch.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Performance benchmark harness** | Proves the optimization actually worked. Without benchmarks, "100K rows is fast now" is a claim, not a fact. Benchmark harness also catches performance regressions in future phases | LOW | `bench::mark()` or `system.time()` on synthetic 100K dataset generated from real data patterns. Target: full cleaning pipeline <30 seconds on 100K rows. Benchmark script in `scripts/` |
| **Step-level timing in pipeline progress UI** | Today the pipeline progress bar advances per step but shows no timing. Adding wall-clock seconds per step surfaces which steps are bottlenecks, helping users understand what the recommendation modal is saving them | LOW | `proc.time()` or `system.time()` per step. Store timing in pipeline result metadata. Display in value boxes (Step X: 0.3s) |
| **Date range parsing** | Regulatory data often contains date ranges ("1990-1995", "Jan-Mar 2020"). Parsing start/end dates from ranges enables temporal filtering in downstream analysis | MEDIUM | Pattern: detect " - " or "/" as range separator → apply `fix_date_char()` to each component → return start_date + end_date columns. `datefixR` does not handle ranges natively; custom pre-processing layer needed |
| **Duration range support** | ECOTOX has records like "96-120 hours". Supporting duration ranges produces `duration_min_h` and `duration_max_h` alongside `duration_h` | LOW | Same range-splitting pattern as numeric result ranges (already built). Apply after duration normalization |
| **User-editable media classification table** | Curators encounter dataset-specific media descriptions that don't match the core ontology. Same reference list editor pattern as stop words and unit synonyms | MEDIUM | RDS in `inst/extdata/reference_cache/`. UI in Harmonize tab. Re-run cascade on save |
| **AMOS method → media lookup cache** | Building the AMOS media classifications at runtime each time is expensive and makes the Shiny app API-dependent. Cache the 7,500 classified methods as an RDS file at build time. App loads cache; falls back to API pagination only for new methods | MEDIUM | Build script in `data-raw/` or `scripts/`. Cache checked into `inst/extdata/`. TTL of 90 days (same checkpoint pattern as `curation/ecotox/ecotox.R`) |

### Anti-Features (Commonly Requested, Often Problematic)

| Anti-Feature | Why Requested | Why Problematic | Alternative |
|--------------|---------------|-----------------|-------------|
| **Parallel step execution in cleaning pipeline** | "Run all steps simultaneously for max speed" sounds appealing | Steps are data-dependent: synonym splitting changes row count, which breaks subsequent steps that use row_id for audit trail. Parallelizing across columns is feasible but adds complexity for minimal gain vs. the dedup optimization | Apply distinct-string dedup first (50x speedup), then evaluate if parallelism is still needed — it likely won't be |
| **LLM-based media classification for AMOS** | 7,500 descriptions is a lot — why not use an LLM? | Opaque audit trail, API key dependency, rate limits, cost, non-reproducibility. AMOS media categories are a finite domain (~15 values). A dictionary with 50 keyword rules gives 80%+ coverage with full transparency | `quanteda` dictionary classifier with unmatched records flagged for manual review |
| **Auto-detecting date columns by content inspection** | Convenient — app scans all columns and auto-tags anything that looks like a date | Date-like strings appear in chemical names, CAS numbers, batch numbers, and regulatory text. Silent auto-tagging produces false positives in chemical name columns | Require user to tag date columns explicitly in the extended column tagging UI. Pre-check can show "3 columns look like they might contain dates" as a hint, but not auto-tag |
| **Universal duration parser that handles all ambiguous inputs** | "Just figure it out" from bare numbers like "96" or "14" | Without a unit, "96" is ambiguous (96 hours is acute; 96 days would be chronic). Silent assumption of hours is wrong for mammalian chronic data. Produces incorrect ToxVal `study_duration_value` | Require a default unit configuration if the duration column lacks explicit unit tokens. Show a warning for bare-number entries |
| **Rolling window or time-series features for date sequences** | Once you have dates, analyze trends | This is analytical work, not curation work. CONCERT's job is to clean and export to ToxVal — downstream analysis belongs in dedicated tools | Export clean dates to ToxVal; time-series work happens in the database layer |
| **Full ECOTOX duration dictionary integration** | ECOTOX has ~100 duration_unit_codes with fractional codes (0.5h, 0.125d) | Full integration adds 100-row lookup dependency and edge cases (fractional days) for minimal real-world benefit. The vast majority of duration values in user uploads follow simple text patterns | Use the 7-row conversion factor table (seconds, minutes, hours, days, weeks, months) with regex parsing. Handle fractional inputs numerically |

---

## Feature Dependencies

```
[Distinct-string dedup architecture]
    |
    ├──required by──> [Cleaning pipeline performance]
    |                     └──feeds──> [Recommendation modal]
    |
    └──required by──> [Harmonization pipeline performance]

[Short-circuit step evaluation]
    └──requires──> [Per-step pre-check functions]
                       └──reused by──> [Recommendation modal]

[Extended column tagging: Date, Duration, Media]   <-- already built (v1.9)
    |
    ├──enables──> [Date/study date parsing]
    |                 └──enhances──> [Date range parsing]
    |
    ├──enables──> [Duration normalization]
    |                 └──enhances──> [Duration range support]
    |
    └──enables──> [Media/matrix classification]
                      └──enhanced by──> [AMOS media ontology extraction]
                      └──enhanced by──> [User-editable media table]

[AMOS media ontology extraction]
    └──requires──> [ComptoxR::chemi_amos_method_pagination()]
    └──produces──> [AMOS method media cache RDS]
                       └──used by──> [Media classification lookup]

[Performance benchmark harness]
    └──requires──> [Distinct-string dedup] (must be built before benchmarking)
```

### Dependency Notes

- **Distinct-string dedup requires audit trail remapping:** The current audit trail records `row_id` from the full dataset. When processing on unique strings, the pipeline must track which original row_ids map to each unique value, then expand the audit entries back. This is the hardest implementation detail of the dedup architecture.

- **Short-circuit evaluation conflicts with full audit trail:** If a step is skipped, the audit trail must still record "step X was skipped (0 candidates)" rather than having a gap. Gaps in audit trail make re-import/re-run detection unreliable.

- **AMOS ontology extraction depends on ComptoxR API availability:** The `chemi_amos_method_pagination()` call requires the `ctx_api_key` environment variable. Build-time cache generation is the correct pattern — Shiny app should never call paginated APIs at runtime.

- **Date parsing depends on datefixR (new dependency):** `datefixR` v2.0.0 is on CRAN (rOpenSci). Rust backend, no system dependencies. Add to DESCRIPTION. Alternative: pure lubridate with `parse_date_time()` multi-format orders, but partial date imputation is weaker.

- **Duration normalization is standalone:** Does not depend on any other v2.0 feature. Could be implemented first as a warmup.

---

## MVP Definition

The v2.0 milestone has two natural release checkpoints.

### Phase A: Performance Architecture (must ship first)

- [ ] **Distinct-string dedup for cleaning pipeline** — without this, the benchmark harness cannot show a meaningful speedup and every new feature added makes things worse
- [ ] **Short-circuit step evaluation with per-step pre-checks** — enables the recommendation modal and visible step timing
- [ ] **Recommendation modal** — user-visible payoff of the architectural work; makes speed improvement tangible
- [ ] **Performance benchmark harness** — proves the work, catches regressions

### Phase B: New Domain Features (after Phase A lands)

- [ ] **Duration normalization** — lowest complexity new feature; validates the "new column type in harmonization pipeline" pattern before tackling dates and media
- [ ] **Date/study date parsing** — `datefixR` + lubridate fallback; requires new column tag type (already present in v1.9 extended tagging)
- [ ] **Media/matrix classification** — lookup table pattern; requires user-editable table UI
- [ ] **AMOS media ontology pipeline** — most complex; can ship as a background build script with cached output rather than blocking the Shiny app

### Future Consideration (v2.x or v3.0)

- [ ] **Date range parsing** — needs real-world data to validate range separator detection; defer until a dataset requires it
- [ ] **Duration range support** — same rationale as date range parsing
- [ ] **Step-level timing display** — nice UX enhancement but not blocking any curation workflow

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Distinct-string dedup (cleaning) | HIGH | HIGH | P1 |
| Short-circuit evaluation | HIGH | MEDIUM | P1 |
| Recommendation modal | HIGH | MEDIUM | P1 |
| Performance benchmark harness | MEDIUM | LOW | P1 |
| Duration normalization | HIGH | LOW | P1 |
| Date/study date parsing | HIGH | MEDIUM | P1 |
| Media/matrix classification | HIGH | MEDIUM | P1 |
| Distinct-string dedup (harmonization) | MEDIUM | LOW | P2 |
| AMOS media ontology pipeline | HIGH | HIGH | P2 |
| User-editable media classification table | MEDIUM | MEDIUM | P2 |
| Date range parsing | MEDIUM | MEDIUM | P3 |
| Duration range support | LOW | LOW | P3 |
| Step-level timing display | LOW | LOW | P3 |

**Priority key:**
- P1: Required for v2.0 milestone to be considered complete
- P2: Should ship in v2.0 but can slip to v2.1 without blocking downstream work
- P3: Nice to have; add only after P1+P2 are solid

---

## Implementation Pattern References

### Pattern 1: Distinct-String Dedup (the core architecture change)

The split-apply-combine pattern for string processing at scale:

```r
# Extract unique strings
unique_vals <- tibble::tibble(
  orig_val = unique(df[[col_name]])
)

# Process only the unique set
cleaned_unique <- apply_cleaning_step(unique_vals$orig_val)
unique_map <- tibble::tibble(orig_val = unique_vals$orig_val, cleaned_val = cleaned_unique)

# Remap to full dataset
df <- dplyr::left_join(df, unique_map, by = setNames("orig_val", col_name))
```

For audit trail, the remapping step must expand unique-level audit records back to all matching rows:
```r
# unique_audit has one row per unique string that changed
# expand to all original rows
full_audit <- dplyr::left_join(
  tibble::tibble(row_id = seq_len(nrow(df)), orig_val = df[[col_name]]),
  unique_audit,
  by = "orig_val"
) %>% dplyr::filter(!is.na(cleaned_val))
```

### Pattern 2: Short-Circuit Pre-Check

```r
# Cheap vectorized scan — runs before the step
needs_unicode_cleaning <- function(vals) {
  any(stringr::str_detect(vals, "[^\x00-\x7F]"), na.rm = TRUE)
}

# In pipeline orchestrator
if (!needs_unicode_cleaning(df[[col_name]])) {
  # Record as skipped in step metadata, skip processing
  step_result <- list(cleaned_data = df, audit_trail = empty_audit(), skipped = TRUE)
} else {
  step_result <- run_unicode_step(df, col_name)
}
```

### Pattern 3: Duration Normalization (from `curation/ecotox/ecotox.R`)

```r
# Conversion factors (hours as canonical base unit)
DURATION_TO_HOURS <- c(
  second = 1 / 3600,
  minute = 1 / 60,
  hour = 1,
  day = 24,
  week = 24 * 7,
  month = 24 * 30.43685  # average month
)

# Parse "96h", "21 days", "4 wk" pattern
parse_duration_hours <- function(x) {
  num <- as.numeric(stringr::str_extract(x, "[0-9.]+"))
  unit_raw <- tolower(stringr::str_extract(x, "[a-zA-Z]+"))
  unit_key <- dplyr::case_when(
    stringr::str_detect(unit_raw, "^sec") ~ "second",
    stringr::str_detect(unit_raw, "^min") ~ "minute",
    stringr::str_detect(unit_raw, "^h") ~ "hour",
    stringr::str_detect(unit_raw, "^d") ~ "day",
    stringr::str_detect(unit_raw, "^w") ~ "week",
    stringr::str_detect(unit_raw, "^mo") ~ "month",
    .default = NA_character_
  )
  num * DURATION_TO_HOURS[unit_key]
}
```

### Pattern 4: Date Parsing Strategy (datefixR + lubridate fallback)

```r
# Primary: datefixR for messy/partial dates
# fix_date_char() handles: mixed formats, partial dates (year-only, month-year),
# two-digit years, named months in 6 languages, Excel serial numbers
clean_dates <- datefixR::fix_date_char(raw_dates, day.impute = 1L, month.impute = 7L)

# Fallback: lubridate::parse_date_time() with multiple format orders
# for datasets where dates are mostly clean but have format heterogeneity
clean_dates_fallback <- lubridate::parse_date_time(
  raw_dates,
  orders = c("ymd", "mdy", "dmy", "y", "ym", "my"),
  quiet = TRUE
)
```

### Pattern 5: Media Classification (quanteda dictionary approach)

```r
# Build domain dictionary
media_dict <- quanteda::dictionary(list(
  freshwater = c("fresh*", "river*", "lake*", "stream*", "pond*", "surface water"),
  saltwater  = c("salt*", "marine*", "ocean*", "sea*", "coastal*", "estuari*"),
  sediment   = c("sediment*", "benthic*", "bed material*"),
  soil       = c("soil*", "terrestrial*", "land*"),
  air        = c("air*", "atmospher*", "vapor*", "aerosol*"),
  groundwater = c("ground*water*", "well*", "aquifer*"),
  effluent   = c("effluent*", "wastewater*", "sewage*")
))

# Apply to corpus of method descriptions
corpus <- quanteda::corpus(methods_df, text_field = "matrix_description")
dfm <- quanteda::dfm(quanteda::tokens(corpus))
scores <- quanteda::dfm_lookup(dfm, dictionary = media_dict)
# Assign media category = highest-scoring dictionary term
```

---

## Complexity Assessment

| Feature | Estimated LOC | Key Risk | Notes |
|---------|--------------|----------|-------|
| Distinct-string dedup (cleaning) | 200 | MEDIUM — audit trail row_id expansion | The `unique_map` join is trivial; the audit expansion is the tricky part |
| Distinct-string dedup (harmonization) | 80 | LOW | Harmonization outputs are scalar; no audit expansion needed |
| Short-circuit pre-checks | 120 | LOW | One function per step; pure vectorized detection |
| Recommendation modal | 150 | LOW | Shiny modal with DT table; existing modal pattern |
| Performance benchmark harness | 60 | LOW | `bench::mark()` + synthetic data generator |
| Duration normalization | 100 | LOW | Regex + lookup; ECOTOX reference already exists |
| Date parsing (datefixR integration) | 120 | LOW | New dependency; API is simple |
| Media classification (lookup table) | 150 | LOW | Same pattern as unit harmonization |
| Media editor UI | 180 | MEDIUM | Reference list editor pattern from v1.3 |
| AMOS media ontology pipeline | 300 | HIGH | Pagination + text mining + cache management |
| Date range detection | 100 | MEDIUM | Range separator heuristic is tricky |

**Total estimate for P1 features:** ~830 LOC  
**Total estimate for P1+P2 features:** ~1,310 LOC

---

## Sources

- `curation/ecotox/ecotox.R` lines 643-677 — ECOTOX duration conversion table (hours as canonical, DURATION_TO_HOURS pattern)
- `R/cleaning_pipeline.R` — existing 15-step pipeline structure with audit trail; dedup must preserve this contract
- `R/unit_harmonizer.R` — existing unit harmonization architecture; dedup pattern applies here too
- `R/numeric_parser.R` — existing numeric parsing patterns (qualifier extraction, Fortran exponents)
- [datefixR v2.0.0 (rOpenSci/CRAN)](https://docs.ropensci.org/datefixR/) — Rust-backed date standardization; handles partial dates and mixed formats better than lubridate alone for messy regulatory data
- [lubridate::parse_date_time() reference](https://lubridate.tidyverse.org/reference/parse_date_time.html) — multi-format order parsing; fallback for cleaner date data
- [EPA AMOS Database User Guide](https://www.epa.gov/comptox-tools/analytical-methods-and-open-spectral-amos-database-user-guide) — AMOS matrix field description; media category from MMDB
- [ECOTOXr package (CRAN, September 2025)](https://cran.r-project.org/web/packages/ECOTOXr/ECOTOXr.pdf) — `as_unit_ecotox()`, `process_ecotox_dates()` functions confirm hours-canonical pattern
- [quanteda: Quantitative Text Analysis](http://quanteda.io/) — dictionary classifier for AMOS media ontology extraction
- [Dagster ETL Pipeline Best Practices](https://dagster.io/guides/etl-pipelines-5-key-components-and-5-critical-best-practices) — conditional step execution patterns from production ETL tooling

---

*Feature research for: v2.0 Pipeline Performance & Date/Media Harmonization*
*Researched: 2026-04-24*
