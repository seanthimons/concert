# Roadmap: ChemReg

## Milestones

- **v1.5 Disagreement Enrichment** -- Phases 17-18 (shipped 2026-03-13)
- **v1.6 Cleaning Ruleset Fixes** -- Phases 19-21 (shipped 2026-03-20)
- **v1.7 UI Polish & Isotope Cleaning** -- Phases 22-23 (shipped 2026-04-13)
- **v1.8 R Package Migration** -- Phases 24-28 (shipped 2026-04-14)
- **v1.9 Number and Unit Coercion Harmonization** -- Phases 29-36 (shipped 2026-04-21)
- **v2.0 Pipeline Performance & Date/Media Harmonization** -- Phases 37-42 (in progress)

## Phases

<details>
<summary>v1.5 Disagreement Enrichment (Phases 17-18) -- SHIPPED 2026-03-13</summary>

### Phase 17: Enrichment Pipeline
**Goal**: Enrich disagreement candidates with CompTox metadata
**Plans**: Complete

### Phase 18: Comparison Modal + Export
**Goal**: Surface enrichment in resolution UI and export
**Plans**: Complete

</details>

<details>
<summary>v1.6 Cleaning Ruleset Fixes (Phases 19-21) -- SHIPPED 2026-03-20</summary>

- [x] Phase 19: Synonym Splitter Comma Protection (1/1 plans) -- completed 2026-03-19
- [x] Phase 20: Roman Numeral Handling (1/1 plans) -- completed 2026-03-19
- [x] Phase 21: Unicode Cleaning Coverage (1/1 plans) -- completed 2026-03-20

</details>

<details>
<summary>v1.7 UI Polish & Isotope Cleaning (Phases 22-23) -- SHIPPED 2026-04-13</summary>

- [x] Phase 22: UI Polish (1/1 plans) -- completed 2026-04-01
- [x] Phase 23: Isotope Cleaning (2/2 plans) -- completed 2026-04-02

</details>

<details>
<summary>v1.8 R Package Migration (Phases 24-28) -- SHIPPED 2026-04-14</summary>

- [x] Phase 24: Package Scaffolding (1/1 plans) -- completed 2026-04-13
- [x] Phase 25: Source File Cleanup (1/1 plans) -- completed 2026-04-13
- [x] Phase 26: App Relocation (1/1 plans) -- completed 2026-04-13
- [x] Phase 27: Headless Pipeline (1/1 plans) -- completed 2026-04-14
- [x] Phase 28: Test Migration (1/1 plans) -- completed 2026-04-14

</details>

<details>
<summary>v1.9 Number and Unit Coercion Harmonization (Phases 29-36) -- SHIPPED 2026-04-21</summary>

**Goal:** Extend ChemReg from compound-only curation to full benchmark/regulatory data curation with numeric result parsing, unit harmonization, and toxval-schema output.

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

### v2.0 Pipeline Performance & Date/Media Harmonization (In Progress)

**Milestone Goal:** Make the cleaning+harmonization pipeline production-fast at 100K+ rows via distinct-string dedup and short-circuit evaluation, then extend harmonization coverage to date/duration parsing and environmental media classification.

- [ ] **Phase 37: Performance Architecture** -- PERF-01, PERF-02, PERF-03, PERF-04, SKIP-01, SKIP-02, SKIP-03
- [x] **Phase 38: Benchmark Harness** -- BENCH-01, BENCH-02, BENCH-03 (completed 2026-04-26)
- [ ] **Phase 39: Duration Conversion** -- DUR-01, DUR-02, DUR-03, DUR-04, DUR-05
- [ ] **Phase 40: Date Parser** -- DATE-01, DATE-02, DATE-03, DATE-04, DATE-05, DATE-06
- [ ] **Phase 41: Media Harmonizer & AMOS Pipeline** -- MEDIA-01, MEDIA-02, MEDIA-03, MEDIA-04, MEDIA-05, MEDIA-06, AMOS-01, AMOS-02, AMOS-03
- [ ] **Phase 42: Integration & Shiny Polish** -- RECO-01, RECO-02, MEDIT-01, MEDIT-02, MEDIT-03

## Phase Details

### Phase 37: Performance Architecture
**Goal**: Users can run the cleaning and harmonization pipelines at full 100K-row scale without unacceptable wait times, because distinct-string dedup eliminates redundant processing and short-circuit evaluation skips steps with nothing to do.
**Depends on**: Phase 36
**Requirements**: PERF-01, PERF-02, PERF-03, PERF-04, SKIP-01, SKIP-02, SKIP-03
**Success Criteria** (what must be TRUE):
  1. Running the cleaning pipeline on a 100K-row dataset with 2% unique chemical names processes at least 5x faster than before dedup was applied
  2. The audit trail after dedup remapping contains correct parent row IDs -- no audit row ID exceeds the parent dataset row count
  3. A cleaning step whose pre-check returns FALSE (e.g., no non-ASCII characters present) is skipped entirely and produces an empty-but-typed audit trail row, not NULL
  4. Companion tests exist for each pre-check that prove a vector passing the pre-check but requiring transformation would still be caught (false-negative detection)
  5. Dedup-eligible steps are migrated one at a time with the 953+ test suite green after each migration
**Plans:** 4/4 plans executed
Plans:
- [x] 37-01-PLAN.md -- Dedup infrastructure: dedup_step() and remap_audit_to_parent()
- [x] 37-02-PLAN.md -- Pre-check predicates and SKIP-03 false-negative companion tests
- [x] 37-03-PLAN.md -- Wire dedup and pre-checks into run_cleaning_pipeline()
- [x] 37-04-PLAN.md -- Unit-key dedup in harmonize_units()

### Phase 38: Benchmark Harness
**Goal**: Users (and developers) can run a documented benchmark script that proves the dedup architecture delivers measurable speedup at 100K rows, with before/after comparison committed to the repository.
**Depends on**: Phase 37
**Requirements**: BENCH-01, BENCH-02, BENCH-03
**Success Criteria** (what must be TRUE):
  1. `scripts/benchmark_pipeline.R` runs to completion against real data at n = 1K, 10K, and 100K rows and produces a results table with median timing and memory allocation per level
  2. The benchmark measures cold-start cost separately from steady-state cost and reports the actual uniqueness rate of the test data
  3. A before/after speedup factor is documented showing the measured improvement from the dedup architecture
**Plans:** 2/1 plans complete
Plans:
- [x] 38-01-PLAN.md -- Wire use_dedup toggle bypass in pipeline functions and add toggle tests

### Phase 39: Duration Conversion
**Goal**: Users can tag columns as DurationUnit and have the harmonization pipeline convert duration values to hours as a common base unit, with the result wired into the ToxVal schema study_duration fields.
**Depends on**: Phase 37
**Requirements**: DUR-01, DUR-02, DUR-03, DUR-04, DUR-05
**Success Criteria** (what must be TRUE):
  1. Duration strings like "96 hr", "14 days", "2 wk", "6 mo", "1 yr" all convert correctly to hours via the existing `harmonize_units()` machinery
  2. The unit table contains explicit entries for all common duration abbreviations (h/hr/hrs/hour, d/day/days, wk/week, mo/month, yr/year, min/minute, s/sec/second) with hours as the base unit
  3. A column tagged DurationUnit in the Harmonize tab routes through duration harmonization and its output appears in `study_duration_value` and `study_duration_units` in the ToxVal export
  4. The ambiguous "m" abbreviation is never silently treated as months -- the custom synonym map resolves it explicitly and the pitfall is covered by a test
**Plans**: TBD

### Phase 40: Date Parser
**Goal**: Users can tag columns as StudyDate and have the harmonization pipeline parse mixed-format date strings into ISO-8601 structured output with ambiguity flagging, wired to the ToxVal `original_year` field.
**Depends on**: Phase 37
**Requirements**: DATE-01, DATE-02, DATE-03, DATE-04, DATE-05, DATE-06
**Success Criteria** (what must be TRUE):
  1. `parse_dates()` in `R/date_parser.R` correctly parses ISO, MDY, DMY, SAS (15JAN1985), YYYYMMDD, year-only, and 2-digit year formats from a single mixed-format column
  2. Dates where both the day and month are <= 12 are flagged as "ambiguous" in the audit trail rather than silently assigned a format
  3. A column tagged StudyDate in the Harmonize tab routes through `parse_dates()` in Stage 3c and its `date_year` output populates `original_year` in the ToxVal schema
  4. `curate_headless()` with `harmonize=TRUE` processes StudyDate-tagged columns and produces identical output to the Shiny interactive path
**Plans**: TBD
**UI hint**: yes

### Phase 41: Media Harmonizer & AMOS Pipeline
**Goal**: Users can tag columns as Media and have the harmonization pipeline classify environmental media strings against the ENVO ontology, with AMOS-derived terms supplementing the vocabulary and canonical media values feeding back into ppb/ppm unit routing.
**Depends on**: Phase 40
**Requirements**: MEDIA-01, MEDIA-02, MEDIA-03, MEDIA-04, MEDIA-05, MEDIA-06, AMOS-01, AMOS-02, AMOS-03
**Success Criteria** (what must be TRUE):
  1. `harmonize_media()` in `R/media_harmonizer.R` maps raw media strings to canonical ENVO terms and returns a tibble with `orig_row_id`, `raw_media`, `canonical_media`, and `media_flag`
  2. Compound media inputs like "freshwater sediment" resolve to a first-class canonical term rather than picking a single component; ambiguous multi-match inputs are flagged rather than silently resolved
  3. `scripts/build_amos_media.R` completes successfully, producing `inst/extdata/reference_cache/amos_media.rds` with a fetch timestamp; the RDS is committed and never called at runtime
  4. A column tagged Media in the Harmonize tab routes through Stage 3d; the resulting canonical media value is passed as the `media` parameter to `harmonize_units()` in Stage 3, closing the ppb/ppm routing loop
  5. `curate_headless()` with `harmonize=TRUE` processes Media-tagged columns and produces the same canonical media classification as the Shiny interactive path
**Plans**: TBD

### Phase 42: Integration & Shiny Polish
**Goal**: Users see a pre-flight recommendation modal before running the cleaning or harmonization pipeline that shows which steps will fire versus skip, and can edit the media classification table directly in the Harmonize tab with unmatched terms surfaced for user mapping.
**Depends on**: Phase 41
**Requirements**: RECO-01, RECO-02, MEDIT-01, MEDIT-02, MEDIT-03
**Success Criteria** (what must be TRUE):
  1. Clicking "Run Cleaning" or "Run Harmonization" shows a modal listing each pipeline step with a fire/skip indicator based on pre-check results before any processing begins
  2. The user can choose to run only the steps that will fire (subset run) or all steps (full run) from the pre-flight modal
  3. The Harmonize tab contains an editable media classification table with term, canonical, source, and active columns; user edits persist across sessions via RDS and trigger a pipeline re-run cascade
  4. Media strings that did not match any canonical term are surfaced in the editor as unmatched rows, allowing the user to assign canonical values that are immediately available for the next run
**Plans**: TBD
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
| 38. Benchmark Harness | v2.0 | 2/1 | Complete   | 2026-04-26 |
| 39. Duration Conversion | v2.0 | 0/TBD | Not started | - |
| 40. Date Parser | v2.0 | 0/TBD | Not started | - |
| 41. Media Harmonizer & AMOS Pipeline | v2.0 | 0/TBD | Not started | - |
| 42. Integration & Shiny Polish | v2.0 | 0/TBD | Not started | - |
