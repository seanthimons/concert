# Roadmap: ChemReg

## Milestones

- ✅ **v1.5 Disagreement Enrichment** -- Phases 17-18 (shipped 2026-03-13)
- ✅ **v1.6 Cleaning Ruleset Fixes** -- Phases 19-21 (shipped 2026-03-20)
- ✅ **v1.7 UI Polish & Isotope Cleaning** -- Phases 22-23 (shipped 2026-04-13)
- ✅ **v1.8 R Package Migration** -- Phases 24-28 (shipped 2026-04-14)
- ✅ **v1.9 Number and Unit Coercion Harmonization** -- Phases 29-36 (shipped 2026-04-21)
- ✅ **v2.0 Pipeline Performance & Date/Media Harmonization** -- Phases 37-42 (shipped 2026-04-29)
- 🚧 **v2.1 WQX Parameter Harmonization** -- Phases 43-45 (in progress)

## Phases

<details>
<summary>✅ v1.5 Disagreement Enrichment (Phases 17-18) -- SHIPPED 2026-03-13</summary>

### Phase 17: Enrichment Pipeline
**Goal**: Enrich disagreement candidates with CompTox metadata
**Plans**: Complete

### Phase 18: Comparison Modal + Export
**Goal**: Surface enrichment in resolution UI and export
**Plans**: Complete

</details>

<details>
<summary>✅ v1.6 Cleaning Ruleset Fixes (Phases 19-21) -- SHIPPED 2026-03-20</summary>

- [x] Phase 19: Synonym Splitter Comma Protection (1/1 plans) -- completed 2026-03-19
- [x] Phase 20: Roman Numeral Handling (1/1 plans) -- completed 2026-03-19
- [x] Phase 21: Unicode Cleaning Coverage (1/1 plans) -- completed 2026-03-20

</details>

<details>
<summary>✅ v1.7 UI Polish & Isotope Cleaning (Phases 22-23) -- SHIPPED 2026-04-13</summary>

- [x] Phase 22: UI Polish (1/1 plans) -- completed 2026-04-01
- [x] Phase 23: Isotope Cleaning (2/2 plans) -- completed 2026-04-02

</details>

<details>
<summary>✅ v1.8 R Package Migration (Phases 24-28) -- SHIPPED 2026-04-14</summary>

- [x] Phase 24: Package Scaffolding (1/1 plans) -- completed 2026-04-13
- [x] Phase 25: Source File Cleanup (1/1 plans) -- completed 2026-04-13
- [x] Phase 26: App Relocation (1/1 plans) -- completed 2026-04-13
- [x] Phase 27: Headless Pipeline (1/1 plans) -- completed 2026-04-14
- [x] Phase 28: Test Migration (1/1 plans) -- completed 2026-04-14

</details>

<details>
<summary>✅ v1.9 Number and Unit Coercion Harmonization (Phases 29-36) -- SHIPPED 2026-04-21</summary>

- [x] Phase 29: Static Data Foundations -- DATA-01, DATA-02, DATA-03 (completed 2026-04-14)
- [x] Phase 30: Numeric Result Parser -- PARS-01 through PARS-05 (completed 2026-04-14)
- [x] Phase 31: Unit Harmonization Engine -- UNIT-01 through UNIT-05 (completed 2026-04-15)
- [x] Phase 31.5: Units Package Assimilation -- UNIT-01 through UNIT-05 (completed 2026-04-15)
- [x] Phase 32: ToxVal Schema Mapper -- SCHM-01, SCHM-02 (completed 2026-04-15)
- [x] Phase 33: Extended Column Tagging -- UITG-01, UITG-02, UITG-03 (completed 2026-04-15)
- [x] Phase 34: Harmonize Tab Module -- UITG-04, UITG-05, DATA-04, PARS-06, UNIT-06 (completed 2026-04-17)
- [x] Phase 35: Export Extension + Headless -- SCHM-03, SCHM-04, SCHM-05, UITG-06 (completed 2026-04-17)
- [x] Phase 36: Wire ToxVal Schema in Shiny Path -- SCHM-01, UITG-06, SCHM-04 (completed 2026-04-21)

</details>

<details>
<summary>✅ v2.0 Pipeline Performance & Date/Media Harmonization (Phases 37-42) -- SHIPPED 2026-04-29</summary>

- [x] Phase 37: Performance Architecture (4/4 plans) -- completed 2026-04-24
- [x] Phase 38: Benchmark Harness (2/2 plans) -- completed 2026-04-26
- [x] Phase 39: Duration Conversion (2/2 plans) -- completed 2026-04-27
- [x] Phase 40: Date Parser (3/3 plans) -- completed 2026-04-27
- [x] Phase 41: Media Harmonizer & AMOS Pipeline (4/4 plans) -- completed 2026-04-27
- [x] Phase 42: Integration & Shiny Polish (5/5 plans) -- completed 2026-04-28

</details>

### v2.1 WQX Parameter Harmonization (In Progress)

**Milestone Goal:** Add an offline WQX dictionary that matches unresolved analyte names to canonical WQX Characteristic Names, using EPA's alias crosswalk with fuzzy fallback. Fires automatically post-CompTox for names that failed curation.

## Phase Details

### Phase 43: WQX Dictionary
**Goal**: The WQX lookup dictionary is available locally and stays current
**Depends on**: Phase 42
**Requirements**: DICT-01, DICT-02, DICT-03
**Success Criteria** (what must be TRUE):
  1. Calling `refresh_wqx_cache()` downloads Characteristic.csv and Characteristic Alias.csv from EPA and writes a combined RDS to `inst/extdata/reference_cache/`
  2. Loading the package or calling a WQX function for the first time automatically downloads and builds the RDS if it is absent
  3. The combined RDS contains both canonical characteristic names and alias-to-canonical mappings ready for lookup
**Plans:** 2/2 plans complete
Plans:
- [x] 43-01-PLAN.md — Tests + implementation of load_wqx_dictionary, .build_wqx_dictionary, refresh_wqx_cache
- [x] 43-02-PLAN.md — Build script + pre-built RDS artifact + NAMESPACE export

### Phase 44: Matching Engine + Prototype
**Goal**: The three-tier WQX matcher is validated against real training data before any pipeline wiring
**Depends on**: Phase 43
**Requirements**: MATCH-01, MATCH-02, MATCH-03, MATCH-04, INTG-01
**Success Criteria** (what must be TRUE):
  1. A standalone prototype script runs against detections.csv and prints match results without starting the Shiny app
  2. Names with exact canonical matches are resolved at tier 1 (case-insensitive)
  3. Names that miss tier 1 but have alias crosswalk entries (SYNONYM REGISTRY, STANDARDIZE NAME, RETIRED NAME) are resolved at tier 2
  4. Names still unresolved after tiers 1-2 receive a fuzzy candidate from stringdist against canonical names, with distance shown
  5. Each match attempt produces a cli-formatted console log line reporting success (name + match type) or failure (nearest candidate + distance)
**Plans:** 2/2 plans complete
Plans:
- [x] 44-01-PLAN.md — TDD: Tests + match_wqx() three-tier engine + DESCRIPTION/NAMESPACE updates
- [x] 44-02-PLAN.md — Prototype script + human verification of match quality

### Phase 45: Pipeline Integration
**Goal**: WQX matching fires automatically in the curation pipeline for names that failed CompTox
**Depends on**: Phase 44
**Requirements**: INTG-02, INTG-03, INTG-04
**Success Criteria** (what must be TRUE):
  1. After CompTox curation, names with no DTXSID result are automatically passed to the WQX matcher without any user action
  2. Rows that receive a WQX canonical name show it in the same output column as curated compound names (treated as a resolution, not a separate annotation)
  3. Running `curate_headless()` on a file with unresolved names produces WQX matches in the output without additional arguments
**Plans:** 2 plans
Plans:
- [ ] 45-01-PLAN.md — TDD: WQX consensus classification (compute_qc_tier + classify_consensus guard)
- [ ] 45-02-PLAN.md — Wire WQX tier into run_curation_pipeline + integration tests + smoke test

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 19. Synonym Splitter Comma Protection | v1.6 | 1/1 | Complete | 2026-03-19 |
| 20. Roman Numeral Handling | v1.6 | 1/1 | Complete | 2026-03-19 |
| 21. Unicode Cleaning Coverage | v1.6 | 1/1 | Complete | 2026-03-20 |
| 22. UI Polish | v1.7 | 1/1 | Complete | 2026-04-01 |
| 23. Isotope Cleaning | v1.7 | 2/2 | Complete | 2026-04-02 |
| 24. Package Scaffolding | v1.8 | 1/1 | Complete | 2026-04-13 |
| 25. Source File Cleanup | v1.8 | 1/1 | Complete | 2026-04-13 |
| 26. App Relocation | v1.8 | 1/1 | Complete | 2026-04-14 |
| 27. Headless Pipeline | v1.8 | 1/1 | Complete | 2026-04-14 |
| 28. Test Migration | v1.8 | 1/1 | Complete | 2026-04-14 |
| 29. Static Data Foundations | v1.9 | 2/2 | Complete | 2026-04-14 |
| 30. Numeric Result Parser | v1.9 | 2/2 | Complete | 2026-04-14 |
| 31. Unit Harmonization Engine | v1.9 | 1/1 | Complete | 2026-04-15 |
| 31.5 Units Package Assimilation | v1.9 | 3/3 | Complete | 2026-04-15 |
| 32. ToxVal Schema Mapper | v1.9 | 1/1 | Complete | 2026-04-15 |
| 33. Extended Column Tagging | v1.9 | 1/1 | Complete | 2026-04-15 |
| 34. Harmonize Tab Module | v1.9 | 4/4 | Complete | 2026-04-17 |
| 35. Export Extension + Headless | v1.9 | 2/2 | Complete | 2026-04-17 |
| 36. Wire ToxVal Schema in Shiny Path | v1.9 | 1/1 | Complete | 2026-04-21 |
| 37. Performance Architecture | v2.0 | 4/4 | Complete | 2026-04-24 |
| 38. Benchmark Harness | v2.0 | 2/2 | Complete | 2026-04-26 |
| 39. Duration Conversion | v2.0 | 2/2 | Complete | 2026-04-27 |
| 40. Date Parser | v2.0 | 3/3 | Complete | 2026-04-27 |
| 41. Media Harmonizer & AMOS Pipeline | v2.0 | 4/4 | Complete | 2026-04-27 |
| 42. Integration & Shiny Polish | v2.0 | 5/5 | Complete | 2026-04-28 |
| 43. WQX Dictionary | v2.1 | 2/2 | Complete    | 2026-05-05 |
| 44. Matching Engine + Prototype | v2.1 | 2/2 | Complete    | 2026-05-05 |
| 45. Pipeline Integration | v2.1 | 0/2 | Not started | - |
