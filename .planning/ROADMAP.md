# Roadmap: ChemReg v1.6 Cleaning Ruleset Fixes

## Milestones

- ✅ **v1.5 Disagreement Enrichment** - Phases 17-18 (shipped 2026-03-13)
- 🚧 **v1.6 Cleaning Ruleset Fixes** - Phases 19-21 (in progress)

## Phases

<details>
<summary>✅ v1.5 Disagreement Enrichment (Phases 17-18) - SHIPPED 2026-03-13</summary>

### Phase 17: Enrichment Pipeline
**Goal**: Enrich disagreement candidates with CompTox metadata
**Plans**: Complete

### Phase 18: Comparison Modal + Export
**Goal**: Surface enrichment in resolution UI and export
**Plans**: Complete

</details>

### 🚧 v1.6 Cleaning Ruleset Fixes (In Progress)

**Milestone Goal:** Fix cleaning pipeline bugs and unicode coverage gaps discovered during live dataset roadtesting.

#### Phase 19: Synonym Splitter Comma Protection
**Goal**: The synonym splitter correctly handles all IUPAC comma patterns without splitting valid multi-locant chemical names
**Depends on**: Phase 18
**Requirements**: SPLIT-01, SPLIT-02
**Success Criteria** (what must be TRUE):
  1. A name like "2,4,6-trichlorophenol" passes through the synonym splitter as a single name (no split on the locant commas)
  2. The existing single-locant protection for names like "2,4-D" continues to work without regression
  3. A name with a plain non-locant comma (e.g., "acetone, purified") is still split correctly
**Plans**: 1 plan

Plans:
- [ ] 19-01-PLAN.md — Extend locant comma protection to multi-locant patterns with repeat-until-stable loop and validate with test suite

#### Phase 20: Roman Numeral Handling
**Goal**: Chemical names containing roman numeral oxidation states are cleaned and routed correctly without misassignment to the formula column
**Depends on**: Phase 19
**Requirements**: ROMAN-01, ROMAN-02
**Success Criteria** (what must be TRUE):
  1. "chromium III" and "chromium VI" retain their roman numerals as part of the name after cleaning
  2. "chromium (III)" in parenthetical form is not misrouted to the formula column
  3. The formula column receives only genuine molecular formula strings, not names containing roman numerals
**Plans**: TBD

Plans:
- [ ] 20-01: Diagnose misrouting root cause, apply fix, and validate roman numeral cases

#### Phase 21: Unicode Cleaning Coverage
**Goal**: The cleaning pipeline catches all known chemistry-relevant unicode characters before QC runs, and tests align with the current ComptoxR mapping format
**Depends on**: Phase 20
**Requirements**: UNIC-01, UNIC-02, UNIC-03
**Success Criteria** (what must be TRUE):
  1. Greek alpha (U+03B1, α) in a chemical name is converted to its ASCII equivalent by the pipeline before post-curation QC runs
  2. Prime symbol (U+2032, ′) in a chemical name is converted to its ASCII equivalent by the pipeline before post-curation QC runs
  3. The unicode cleaning test suite passes without dot-notation format errors (tests use current ComptoxR mapping format)
**Plans**: TBD

Plans:
- [ ] 21-01: Verify ComptoxR mapping coverage for α and ′, fix pipeline gaps, and align test format

## Progress

**Execution Order:** 19 → 20 → 21

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 19. Synonym Splitter Comma Protection | 1/1 | Complete   | 2026-03-19 | - |
| 20. Roman Numeral Handling | v1.6 | 0/1 | Not started | - |
| 21. Unicode Cleaning Coverage | v1.6 | 0/1 | Not started | - |
