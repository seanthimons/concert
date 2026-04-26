# Requirements: ChemReg v2.0

**Defined:** 2026-04-24
**Core Value:** Users can go from messy regulatory/benchmark data files to validated, harmonized, toxval-compatible datasets in one workflow.

## v2.0 Requirements

Requirements for Pipeline Performance & Date/Media Harmonization milestone.

### Performance — Distinct-String Dedup

- [ ] **PERF-01**: Cleaning pipeline extracts distinct strings per dedup-eligible step, processes only uniques, remaps results to parent dataset via `dedup_step()` wrapper
- [ ] **PERF-02**: Audit trail integrity preserved through dedup — `remap_audit_to_parent()` expands slice row IDs to all parent rows; `max(audit$row_id) <= nrow(parent)` assertion enforced
- [ ] **PERF-03**: Harmonization pipeline applies dedup pattern to unit/duration/media lookups (scalar outputs, simpler remap)
- [ ] **PERF-04**: Dedup-eligible steps identified and migrated one at a time with full test suite verification after each migration

### Performance — Short-Circuit Evaluation

- [ ] **SKIP-01**: Per-step pre-check predicate functions that return FALSE when step can be safely skipped (e.g., no non-ASCII characters → skip unicode cleaning)
- [ ] **SKIP-02**: Skipped steps produce empty typed audit trail entries (not NULL or gaps)
- [ ] **SKIP-03**: Companion tests for each pre-check: vectors that pass the pre-check but would be transformed by the step (false-negative detection)

### Performance — Recommendation Modal

- [ ] **RECO-01**: Pre-flight modal shown before cleaning/harmonization pipeline runs, displaying which steps will fire vs. skip with estimated change counts
- [ ] **RECO-02**: User can confirm full run or subset run based on pre-check results

### Performance — Benchmark Harness

- [x] **BENCH-01**: `scripts/benchmark_pipeline.R` using `bench::press()` across grid of n = c(1K, 10K, 100K) rows with memory allocation tracking
- [x] **BENCH-02**: Benchmark includes cold-start cost, real data uniqueness rate measurement, and remap overhead — reports median not mean
- [x] **BENCH-03**: Before/after comparison documented with measured speedup factor

### Date Parsing

- [ ] **DATE-01**: `parse_dates()` in `R/date_parser.R` handles ISO, MDY, DMY, SAS (15JAN1985), YYYYMMDD, year-only, 2-digit year formats via `lubridate::parse_date_time()` with multi-format orders
- [ ] **DATE-02**: Returns tibble with `orig_row_id`, `raw_date`, `parsed_date` (ISO-8601), `date_year` (integer), `date_flag` ("" | "inferred_format" | "partial" | "unparseable" | "ambiguous")
- [ ] **DATE-03**: Dates where day <= 12 AND month <= 12 flagged as `"ambiguous"` in audit trail
- [ ] **DATE-04**: `StudyDate` tag type added to `classify_tags()` numeric_types; Harmonize tab routes StudyDate-tagged columns through `parse_dates()`
- [ ] **DATE-05**: `curate_headless()` harmonize block gains Stage 3c conditional call for StudyDate-tagged columns
- [ ] **DATE-06**: `map_to_toxval_schema()` populates `original_year` from `date_year` output

### Duration Conversion

- [ ] **DUR-01**: Evaluate ECOTOX `duration_unit_codes` table (ComptoxR ecotox.R section 12) for gaps and extend with missing abbreviations, compound durations, and edge cases
- [ ] **DUR-02**: Duration conversion rows added to `unit_table.csv` with hours as base unit — covers seconds through years plus common abbreviations (h/hr/hrs/hour, d/day/days, wk/week, mo/month, yr/year, min/minute, s/sec/second)
- [ ] **DUR-03**: `DurationUnit`-tagged columns routed through existing `harmonize_units()` in mod_harmonize.R and curate_headless.R
- [ ] **DUR-04**: Duration output wired to `study_duration_value` and `study_duration_units` in `map_to_toxval_schema()`
- [ ] **DUR-05**: Custom duration synonym map used (NOT `lubridate::duration()`) to avoid "m" = months pitfall

### Media/Matrix Harmonization

- [ ] **MEDIA-01**: `R/media_harmonizer.R` with `harmonize_media(values, media_map)` returning tibble with `orig_row_id`, `raw_media`, `canonical_media`, `media_flag`
- [ ] **MEDIA-02**: Media vocabulary derived from ENVO ontology (ENVO_00010483 root) — canonical terms are formal ENVO categories
- [ ] **MEDIA-03**: Compound media types (e.g., "freshwater sediment") are first-class entries, not silent single-picks; ambiguity flag for multi-match inputs
- [ ] **MEDIA-04**: `Media` tag type added to `classify_tags()` metadata_types; Harmonize tab recognizes Media-tagged columns
- [ ] **MEDIA-05**: Canonical media values feed back into `harmonize_units()` as `media` parameter — closes ppb/ppm routing loop with `get_media_target()`
- [ ] **MEDIA-06**: `curate_headless()` harmonize block gains Stage 3d conditional call for Media-tagged columns

### Media — AMOS Pipeline

- [ ] **AMOS-01**: `scripts/build_amos_media.R` calls `ComptoxR::chemi_amos_method_pagination()`, extracts media/matrix terms from ~7,500 method descriptions, maps against ENVO vocabulary
- [ ] **AMOS-02**: Results cached as `inst/extdata/reference_cache/amos_media.rds` — committed to package, never called at runtime
- [ ] **AMOS-03**: Cache includes fetch timestamp; `refresh_amos_cache()` function for explicit manual refresh with staleness warning

### Media — Editor UI

- [ ] **MEDIT-01**: User-editable media classification table in Harmonize tab following reference list editor pattern (term, canonical, source, active)
- [ ] **MEDIT-02**: Unmatched media terms surfaced for user mapping; user additions persist via RDS and trigger re-run cascade
- [ ] **MEDIT-03**: AMOS-derived terms supplement user-editable map as fallback — user map checked first

## Future Requirements

Deferred to future milestone. Tracked but not in current roadmap.

### Date/Duration Extensions

- **DFUT-01**: Date range parsing ("1990-1995", "Jan-Mar 2020") with start_date + end_date columns
- **DFUT-02**: Duration range support ("96-120 hours") producing `duration_min_h` and `duration_max_h`
- **DFUT-03**: Step-level timing display in pipeline progress UI (wall-clock seconds per step in value boxes)

### WQX Parameter Mapping

- **WFUT-01**: WQX parameter registry download, processing, and database storage pipeline
- **WFUT-02**: WQ parameter standardization against WQX harmonized registry
- **WFUT-03**: SSWQS dataset mapping via WQX parameters (reduces CTX API dependency)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Parallel step execution in cleaning pipeline | Steps are data-dependent (synonym splitting changes row count); dedup provides sufficient speedup |
| LLM-based media classification | Opaque audit trail, API dependency, non-reproducible; ENVO keyword matching gives 80%+ coverage with transparency |
| Auto-detecting date columns by content | Date-like strings appear in CAS numbers, batch numbers; require explicit user tagging |
| Universal duration parser for bare numbers | "96" without unit is ambiguous (hours vs. days); require explicit unit context |
| data.table migration for performance | Dedup pattern achieves sufficient speedup without rewriting dplyr idioms; maintenance friction risk |
| datefixR dependency | Rust binary complicates installation; lubridate handles all verified regulatory date formats |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PERF-01 | Phase 37 | Pending |
| PERF-02 | Phase 37 | Pending |
| PERF-03 | Phase 37 | Pending |
| PERF-04 | Phase 37 | Pending |
| SKIP-01 | Phase 37 | Pending |
| SKIP-02 | Phase 37 | Pending |
| SKIP-03 | Phase 37 | Pending |
| BENCH-01 | Phase 38 | Complete |
| BENCH-02 | Phase 38 | Complete |
| BENCH-03 | Phase 38 | Complete |
| DUR-01 | Phase 39 | Pending |
| DUR-02 | Phase 39 | Pending |
| DUR-03 | Phase 39 | Pending |
| DUR-04 | Phase 39 | Pending |
| DUR-05 | Phase 39 | Pending |
| DATE-01 | Phase 40 | Pending |
| DATE-02 | Phase 40 | Pending |
| DATE-03 | Phase 40 | Pending |
| DATE-04 | Phase 40 | Pending |
| DATE-05 | Phase 40 | Pending |
| DATE-06 | Phase 40 | Pending |
| MEDIA-01 | Phase 41 | Pending |
| MEDIA-02 | Phase 41 | Pending |
| MEDIA-03 | Phase 41 | Pending |
| MEDIA-04 | Phase 41 | Pending |
| MEDIA-05 | Phase 41 | Pending |
| MEDIA-06 | Phase 41 | Pending |
| AMOS-01 | Phase 41 | Pending |
| AMOS-02 | Phase 41 | Pending |
| AMOS-03 | Phase 41 | Pending |
| RECO-01 | Phase 42 | Pending |
| RECO-02 | Phase 42 | Pending |
| MEDIT-01 | Phase 42 | Pending |
| MEDIT-02 | Phase 42 | Pending |
| MEDIT-03 | Phase 42 | Pending |

**Coverage:**
- v2.0 requirements: 35 total (33 active + 2 RECO added to traceability)
- Mapped to phases: 35
- Unmapped: 0

---
*Requirements defined: 2026-04-24*
*Last updated: 2026-04-24 — traceability populated by roadmapper*
