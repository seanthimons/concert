# Roadmap: ChemReg

## Milestones

- ✅ **v1.5 Disagreement Enrichment** -- Phases 17-18 (shipped 2026-03-13)
- ✅ **v1.6 Cleaning Ruleset Fixes** -- Phases 19-21 (shipped 2026-03-20)
- ✅ **v1.7 UI Polish & Isotope Cleaning** -- Phases 22-23 (shipped 2026-04-13)
- ✅ **v1.8 R Package Migration** -- Phases 24-28 (shipped 2026-04-14)
- ✅ **v1.9 Number and Unit Coercion Harmonization** -- Phases 29-36 (shipped 2026-04-21)
- ✅ **v2.0 Pipeline Performance & Date/Media Harmonization** -- Phases 37-42 (shipped 2026-04-29)
- ✅ **v2.1 WQX Parameter Harmonization** -- Phases 43-46 (shipped 2026-05-06)
- 🚧 **v2.2 WQX Pipeline Refinement** -- Phases 47-48 (in progress)

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
- [x] Phase 31.5 Units Package Assimilation -- UNIT-01 through UNIT-05 (completed 2026-04-15)
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

<details>
<summary>✅ v2.1 WQX Parameter Harmonization (Phases 43-46) -- SHIPPED 2026-05-06</summary>

- [x] Phase 43: WQX Dictionary (2/2 plans) -- completed 2026-05-05
- [x] Phase 44: Matching Engine + Prototype (2/2 plans) -- completed 2026-05-05
- [x] Phase 45: Pipeline Integration (2/2 plans) -- completed 2026-05-06
- [x] Phase 46: WQX UI Display Fixes (1/1 plans) -- completed 2026-05-06

</details>

### v2.2 WQX Pipeline Refinement (In Progress)

**Milestone Goal:** Fix WQX/CompTox pipeline ordering, expose fuzzy match confidence, and add interactive WQX value resolution for misses and bad matches.

#### Phase 47: Pipeline Reordering, Threshold Control & Starts-With Toggle
- [x] **Phase 47: Pipeline Reordering, Threshold Control & Starts-With Toggle** - Reorder search chain so WQX fires before CompTox starts-with, expose fuzzy threshold in pre-flight modal, and make starts-with opt-in (completed 2026-05-07)

#### Phase 48: WQX Resolution UI
- [ ] **Phase 48: WQX Resolution UI** - Add fuzzy confidence column to Review Results, type-ahead WQX search for overrides, reject/re-pick workflow, and export persistence (gap closure in progress)

## Phase Details

### Phase 47: Pipeline Reordering, Threshold Control & Starts-With Toggle
**Goal**: Users control the search chain precisely — WQX fires before starts-with, fuzzy threshold is configurable in the pre-flight modal, and starts-with is off by default
**Depends on**: Phase 46
**Requirements**: ORD-01, ORD-02, TOG-01, TOG-02, CONF-01, CONF-02
**Success Criteria** (what must be TRUE):
  1. Running the curation pipeline against sswqs.xlsx shows WQX matches resolving names that previously fell through to starts-with
  2. The pre-flight modal contains a numeric slider for the WQX fuzzy threshold (defaulting to 0.85) that changes the matching behavior when adjusted
  3. The pre-flight modal contains a starts-with toggle that is off by default; enabling it causes starts-with to fire as before
  4. Names that WQX resolves do not appear in the starts-with search batch even when the toggle is on
  5. Headless curate_headless() respects both the threshold and the starts-with toggle via its argument interface
**Plans**: 2 plans
Plans:
- [x] 47-01-PLAN.md — Pipeline reorder + headless API params + unit tests
- [x] 47-02-PLAN.md — Pre-flight modal UI controls + curation wiring
**UI hint**: yes

### Phase 48: WQX Resolution UI
**Goal**: Users can inspect WQX fuzzy match confidence, reject bad matches, search for the correct canonical WQX name, and have overrides persist through export
**Depends on**: Phase 47
**Requirements**: CONF-03, RES-01, RES-02, RES-03
**Success Criteria** (what must be TRUE):
  1. Review Results table shows a wqx_confidence column with the Jaro-Winkler score for rows resolved via WQX fuzzy matching
  2. User can type into a search input on a WQX-matched row and see matching WQX canonical names appear as type-ahead suggestions
  3. User can select a type-ahead result to override a bad WQX fuzzy match, and the row reflects the new canonical name
  4. User can reject a WQX fuzzy match and mark the row unresolvable without selecting an alternative
  5. Exported Excel and Parquet files include the user's WQX override or unresolvable status on the affected rows
**Plans**: 3 plans
Plans:
- [x] 48-01-PLAN.md — Pipeline plumbing (wqx_confidence), Review button, JS handler, colDef, unit tests
- [x] 48-02-PLAN.md — WQX Review modal (open, override, reject), type-ahead wiring, smoke test
- [ ] 48-03-PLAN.md — Gap closure: fix map_results_to_rows wqx_confidence propagation + integration test
**UI hint**: yes

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
| 43. WQX Dictionary | v2.1 | 2/2 | Complete | 2026-05-05 |
| 44. Matching Engine + Prototype | v2.1 | 2/2 | Complete | 2026-05-05 |
| 45. Pipeline Integration | v2.1 | 2/2 | Complete | 2026-05-06 |
| 46. WQX UI Display Fixes | v2.1 | 1/1 | Complete | 2026-05-06 |
| 47. Pipeline Reordering, Threshold Control & Starts-With Toggle | v2.2 | 2/2 | Complete    | 2026-05-07 |
| 48. WQX Resolution UI | v2.2 | 2/3 | Gap Closure | — |
