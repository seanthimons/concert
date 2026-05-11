# Roadmap: ChemReg

## Milestones

- ✅ **v1.5 Disagreement Enrichment** -- Phases 17-18 (shipped 2026-03-13)
- ✅ **v1.6 Cleaning Ruleset Fixes** -- Phases 19-21 (shipped 2026-03-20)
- ✅ **v1.7 UI Polish & Isotope Cleaning** -- Phases 22-23 (shipped 2026-04-13)
- ✅ **v1.8 R Package Migration** -- Phases 24-28 (shipped 2026-04-14)
- ✅ **v1.9 Number and Unit Coercion Harmonization** -- Phases 29-36 (shipped 2026-04-21)
- ✅ **v2.0 Pipeline Performance & Date/Media Harmonization** -- Phases 37-42 (shipped 2026-04-29)
- ✅ **v2.1 WQX Parameter Harmonization** -- Phases 43-46 (shipped 2026-05-06)
- ✅ **v2.2 WQX Pipeline Refinement** -- Phases 47-48 (shipped 2026-05-08)
- 🚧 **v2.3 Curation Intelligence** -- Phases 49-52 (in progress)

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

<details>
<summary>✅ v2.2 WQX Pipeline Refinement (Phases 47-48) -- SHIPPED 2026-05-08</summary>

- [x] Phase 47: Pipeline Reordering, Threshold Control & Starts-With Toggle (2/2 plans) -- completed 2026-05-07
- [x] Phase 48: WQX Resolution UI (5/5 plans) -- completed 2026-05-08

</details>

### 🚧 v2.3 Curation Intelligence (In Progress)

**Milestone Goal:** Improve curation pipeline accuracy with automated conflict scoring, explicit user flagging, and configurable detection sensitivity.

- [x] **Phase 49: Conflict Scoring Engine** - Prototype and implement Jaro-Winkler-based similarity scoring for name-vs-CAS disagreements using CompTox synonym and rank data (completed 2026-05-08)
- [x] **Phase 50: Auto-Resolve & Suggest** - Consume scores to auto-resolve clear mismatches and surface a ranked best-match suggestion for ambiguous cases (completed 2026-05-11)
- [ ] **Phase 51: Row Flagging** - Add BAD/FOLLOW-UP/VERIFIED flag labels to the resolution UI with batch flagging and export persistence
- [ ] **Phase 52: Detection Threshold Wiring** - Wire threshold parameters through `detect_data_start()` and both call sites in `mod_file_upload.R`

## Phase Details

### Phase 49: Conflict Scoring Engine
**Goal**: Users can see a similarity score for each candidate in disagree rows, computed from CompTox synonym lists and rank data
**Depends on**: Phase 48 (v2.2 complete)
**Requirements**: SCORE-01, SCORE-02
**Success Criteria** (what must be TRUE):
  1. Prototype script produces a numeric similarity score (0-1) for each candidate name against the input string for a known disagree row (e.g., Silica vs Estradiol)
  2. Scoring uses CompTox synonym list and rank data — lower-rank synonyms and closer Jaro-Winkler distance produce higher scores
  3. Review Results table shows a similarity score column for disagree rows, not blank for agree/single rows
  4. Score computation runs without additional API calls (uses data already fetched during enrichment)
**Plans**: 2 plans
Plans:
- [x] 49-01-PLAN.md -- Backend scoring infrastructure (enrich_synonyms, compute_similarity_scores, score_one_candidate + tests)
- [x] 49-02-PLAN.md -- UI wiring (pipeline integration, Sim. Score colDef, modal badges, export passthrough, smoke test)
**UI hint**: yes

### Phase 50: Auto-Resolve & Suggest
**Goal**: Clear mismatches are auto-resolved without user action; ambiguous cases show a ranked suggested match the user can accept or override
**Depends on**: Phase 49
**Requirements**: SCORE-03, SCORE-04
**Success Criteria** (what must be TRUE):
  1. A Silica/sand vs Estradiol disagree row is auto-resolved (to the correct candidate) with an audit trail entry explaining the auto-resolution
  2. An ambiguous disagree row shows a "Suggested: [name]" indicator in the resolution UI that the user can accept with one click
  3. User can override an auto-resolution or reject a suggestion and manually choose any candidate
  4. Auto-resolved rows are visually distinguishable from manually resolved rows in Review Results
**Plans**: 3 plans
Plans:
- [x] 50-01-PLAN.md -- Backend classification and resolution functions (classify_auto_resolve, accept_all_suggestions, extended consensus functions + tests)
- [x] 50-02-PLAN.md -- Pipeline wiring and UI integration (status chips, modal suggestion highlight, bulk accept, value boxes)
- [x] 50-03-PLAN.md -- Export extensions and smoke test (resolution audit columns, summary counts, cold boot verification)
**UI hint**: yes

### Phase 51: Row Flagging
**Goal**: Users can label any row as BAD, FOLLOW-UP, or VERIFIED from the resolution UI, select multiple rows for batch flagging, and find the flag column in the exported file
**Depends on**: Phase 48 (can run parallel to 49-50, depends on UI module only)
**Requirements**: FLAG-01, FLAG-02, FLAG-03
**Success Criteria** (what must be TRUE):
  1. Each row in Review Results has a flag dropdown or button set offering BAD, FOLLOW-UP, and VERIFIED options (plus an unset/clear state)
  2. User can select multiple rows via checkboxes and apply a flag to all selected rows in one action
  3. Flag status survives tab navigation and re-render within the session
  4. Exported Excel/Parquet file contains a dedicated flag column with the per-row flag values
**Plans**: TBD
**UI hint**: yes

### Phase 52: Detection Threshold Wiring
**Goal**: `detect_data_start()` accepts threshold parameters and both Shiny call sites pass them through, making detection sensitivity configurable without a UI
**Depends on**: Phase 48 (v2.2 complete; independent of Phases 49-51)
**Requirements**: DETECT-01, DETECT-02
**Success Criteria** (what must be TRUE):
  1. `detect_data_start()` signature accepts `min_filled_ratio` and `min_cols` parameters and forwards them to the heuristic sub-function
  2. Both calls to `detect_data_start()` in `mod_file_upload.R` pass the threshold arguments (even if defaulted) without error
  3. Calling `detect_data_start(data, min_filled_ratio = 0.5)` on a borderline file produces a different (lower) detected header row than the default 0.7 threshold
**Plans**: TBD

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
| 47. Pipeline Reordering, Threshold Control & Starts-With Toggle | v2.2 | 2/2 | Complete | 2026-05-07 |
| 48. WQX Resolution UI | v2.2 | 5/5 | Complete | 2026-05-08 |
| 49. Conflict Scoring Engine | v2.3 | 2/2 | Complete    | 2026-05-08 |
| 50. Auto-Resolve & Suggest | v2.3 | 3/3 | Complete   | 2026-05-11 |
| 51. Row Flagging | v2.3 | 0/? | Not started | - |
| 52. Detection Threshold Wiring | v2.3 | 0/? | Not started | - |
