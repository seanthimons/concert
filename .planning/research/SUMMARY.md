# Research Summary: ChemReg v2.0

**Milestone:** v2.0 Pipeline Performance & Date/Media Harmonization
**Synthesized:** 2026-04-24
**Sources:** STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md + user clarification (ENVO ontology)

---

## Stack Additions

**Two DESCRIPTION changes only:**
- `lubridate` → Imports (date parsing via `parse_date_time()` with multi-format orders)
- `bench` → Suggests (performance harness with `bench::press()` grid benchmarking + memory tracking)

Everything else uses existing packages (dplyr, stringr, purrr, ComptoxR, units, arrow).

**Rejected:** datefixR (Rust binary, no advantage over lubridate for regulatory data), quanteda/tidytext/NLP (keyword matching suffices for media), data.table/polars (dedup pattern sufficient at 100K scale).

---

## Key Findings

### Performance Architecture (First Priority)

- **Distinct-string dedup** is the dominant optimization: 5-50x speedup depending on uniqueness ratio. Chemical name datasets typically have 1-5% unique ratio at 100K rows. Pattern: `unique()` → process → `match()` remap. 9 of 15 cleaning steps are dedup-eligible; 6 require row context (row-level cross-column interaction, cardinality changes).
- **Dedup is a wrapper, not an internal change.** Step functions stay unchanged. `run_cleaning_pipeline()` gains a `dedup_step()` helper that handles slice/process/remap/audit-expand. Audit trail integrity requires `remap_audit_to_parent()` to expand slice row IDs back to all parent rows.
- **Short-circuit pre-checks** are cheap (~0ms at 100K rows) vectorized scans that gate each step. One checker per step, called from the orchestrator. Steps return `list(cleaned_data, audit_trail)` unchanged — skip logic is orchestrator-only.
- **Recommendation modal** collects pre-check flags before pipeline execution and shows which steps will fire vs. skip. Lives in `mod_harmonize.R` (harmonization) and `mod_clean_data.R` (cleaning).

### Date/Duration Parsing

- **Date parsing is harmonization-layer, not cleaning-layer.** Requires knowing which column is tagged `StudyDate` — post-tagging info. New `R/date_parser.R` mirrors `parse_numeric_results()` return shape.
- **Duration conversion needs no new file.** Add ~15 rows to `unit_table.csv` (hours as base unit, matching ECOTOX convention from ComptoxR ecotox.R section 12). Route `DurationUnit`-tagged columns through existing `harmonize_units()`.
- **Critical pitfall:** `lubridate::duration("10 m")` = 10 months, not minutes. Must use custom synonym map, not lubridate, for free-text duration parsing.
- **Date ambiguity:** Day <= 12 AND month <= 12 dates must be flagged as format-ambiguous in audit trail.

### Media/Matrix Harmonization

- **ENVO ontology (ENVO_00010483 root) is the harmonization target** — user-specified formal ontology for environmental media types. This provides a structured vocabulary rather than ad-hoc keyword classifiers.
- **AMOS methods (~7,500 via `ComptoxR::chemi_amos_method_pagination()`) are training/source data** for building the media map against ENVO terms.
- **AMOS extraction is build-time only.** Script produces `amos_media.rds` committed to package; never called at runtime.
- **Media harmonization feeds back into unit harmonization** — canonical media values close the ppb/ppm routing loop (`get_media_target()` already exists with aqueous/air/solid branches).
- **Compound media types** (e.g., "freshwater sediment") must be first-class values, not silent single-picks. Ambiguity flag required.
- **Media classification uses `case_when()` + `str_detect()` against ENVO-derived vocabulary** — tested at 7,500 descriptions in 30ms. No NLP packages needed.

---

## Architecture Integration

### New Components
| Component | File | Pattern |
|-----------|------|---------|
| `date_parser.R` | `R/date_parser.R` | Mirrors `parse_numeric_results()` return shape |
| `media_harmonizer.R` | `R/media_harmonizer.R` | New canonical reference list type with ENVO vocabulary |
| `build_amos_media.R` | `scripts/build_amos_media.R` | Build-time AMOS extraction; produces `amos_media.rds` |
| `benchmark_pipeline.R` | `scripts/benchmark_pipeline.R` | `bench::press()` harness; Suggests-only dependency |

### Modified Components
| Component | Change |
|-----------|--------|
| `cleaning_pipeline.R` | Add `dedup_step()` wrapper, `remap_audit_to_parent()`, short-circuit checker calls, `empty_audit_trail()` |
| `unit_table.csv` | Add ~15 duration conversion rows (hours base unit) |
| `tag_helpers.R` | Add `"StudyDate"` to `numeric_types`, `"Media"` to `metadata_types` |
| `mod_harmonize.R` | Recommendation modal; media editor panel; date/duration routing; Stages 3b/3c/3d |
| `curate_headless.R` | Add Stages 3b/3c/3d in harmonize block |
| `toxval_mapper.R` | Add optional `dates` and `media` parameters |

### Data Flow Extension
```
[mod_harmonize.R / curate_headless harmonize block]
    Stage 1: apply_corrections()              (unchanged)
    Stage 2: parse_numeric_results()           (unchanged)
    Stage 3: harmonize_units()                 (unchanged)
    Stage 3b: harmonize_durations()            [NEW — if DurationUnit tag present]
    Stage 3c: parse_dates()                    [NEW — if StudyDate tag present]
    Stage 3d: harmonize_media()                [NEW — if Media tag present]
                → canonical_media feeds back into Stage 3 media param
    Stage 4: map_to_toxval_schema(dates=, media=)  (extended)
```

---

## Build Order (Dependency-Aware)

1. **Dedup wrapper + short-circuit checkers** — pure infrastructure, no new files, validates performance claim
2. **Benchmark harness** — proves the architecture works at 100K; catches regressions
3. **Duration conversion** — lowest complexity; table-only change reusing all existing machinery
4. **Date parser** — new file, isolated; one-line tag type addition
5. **Media harmonizer + ENVO ontology mapping** — new file + reference list; AMOS build script in parallel
6. **AMOS build script** — standalone; commit RDS after manual validation
7. **ToxVal schema wiring** — terminal; extends `map_to_toxval_schema()` with new optional params
8. **Recommendation modal** — final Shiny touch after all pipeline steps proven

---

## Critical Pitfalls

| # | Pitfall | Prevention | Phase |
|---|---------|------------|-------|
| P1 | Dedup audit row IDs are slice positions, not parent | `remap_audit_to_parent()` + CI assertion: `max(audit$row_id) <= nrow(parent)` | Dedup architecture |
| P2 | Short-circuit pre-check weaker than step logic | Companion tests: vectors that pass pre-check but would be transformed | Short-circuit |
| P3 | Ambiguous dates (day/month both <= 12) | Flag as ambiguous; `parse_date_time()` with explicit orders | Date parsing |
| P4 | `lubridate` "m" = months not minutes | Custom duration synonym map; never `lubridate::duration()` on free text | Duration |
| P5 | Media overlap (freshwater sediment) | Compound categories as first-class ENVO terms; ambiguity flag | Media |
| P6 | AMOS classifier overfits to high-frequency | Tabulate full corpus first; held-out validation; "unclassified" ≠ NA | AMOS pipeline |
| P7 | Benchmark warm-cache bias | Cold-start, real data, measured uniqueness rate, report median | Benchmark |
| P8 | ppb routing must accept new media values | Extend `get_media_target()` for all ENVO categories | Media |

---

## Watch Out For

- **Dedup migration must be one step at a time** — run full 953+ test suite after each step migration
- **`inject_row_lineage()` must run before any pre-check** — short-circuit cannot skip lineage injection
- **`curate_headless()` must expose all new parameters** — headless users must reproduce Shiny runs
- **ENVO ontology terms need manual curation** — automated AMOS extraction is a starting point, not the final vocabulary

---

*Synthesized: 2026-04-24 from 4 parallel research agents + user ENVO clarification*
*Ready for requirements: yes*
