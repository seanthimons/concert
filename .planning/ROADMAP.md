# Roadmap: ChemReg

## Milestones

- ✅ **v1.5 Disagreement Enrichment** — Phases 17-18 (shipped 2026-03-13)
- ✅ **v1.6 Cleaning Ruleset Fixes** — Phases 19-21 (shipped 2026-03-20)
- 🚧 **v1.7 UI Polish & Isotope Cleaning** — Phases 22-23 (in progress)

## Phases

<details>
<summary>✅ v1.5 Disagreement Enrichment (Phases 17-18) — SHIPPED 2026-03-13</summary>

### Phase 17: Enrichment Pipeline
**Goal**: Enrich disagreement candidates with CompTox metadata
**Plans**: Complete

### Phase 18: Comparison Modal + Export
**Goal**: Surface enrichment in resolution UI and export
**Plans**: Complete

</details>

<details>
<summary>✅ v1.6 Cleaning Ruleset Fixes (Phases 19-21) — SHIPPED 2026-03-20</summary>

- [x] Phase 19: Synonym Splitter Comma Protection (1/1 plans) — completed 2026-03-19
- [x] Phase 20: Roman Numeral Handling (1/1 plans) — completed 2026-03-19
- [x] Phase 21: Unicode Cleaning Coverage (1/1 plans) — completed 2026-03-20

</details>

### 🚧 v1.7 UI Polish & Isotope Cleaning (In Progress)

**Milestone Goal:** Fix truncated column headers in Review Results, silence console warnings, and add isotope shortcode expansion to the pre-curation cleaning pipeline.

## Phases

- [x] **Phase 22: UI Polish** - Fix column header truncation in Review Results and silence two console warnings (completed 2026-04-01)
- [ ] **Phase 23: Isotope Cleaning** - Add isotope shortcode expansion, chiral designation protection, and multi-analyte flagging to pre-curation pipeline

## Phase Details

### Phase 22: UI Polish
**Goal**: Users see full column header text in Review Results and the R console is free of renderWidget and jsonlite deprecation warnings
**Depends on**: Phase 21 (complete)
**Requirements**: UIPOL-01, UIPOL-02, UIPOL-03
**Success Criteria** (what must be TRUE):
  1. Review Results DT column headers wrap to multiple lines rather than truncating with ellipsis
  2. No `renderWidget` warning appears in the R console when the results table renders
  3. No `jsonlite` named vector deprecation warning appears in the R console during curation
**Plans**: 1 plan

Plans:
- [x] 22-01-PLAN.md — Apply wrap=TRUE, remove elementId, fix named vector warnings

**UI hint**: yes

### Phase 23: Isotope Cleaning
**Goal**: Users' chemical name columns are cleaned of isotope shortcodes before the bare formula detection step runs, with chiral designation protection and multi-analyte flagging also added to the pipeline
**Depends on**: Phase 22
**Requirements**: ISOT-01, ISOT-02, ISOT-03, CHIR-01, MANA-01
**Success Criteria** (what must be TRUE):
  1. The cleaning pipeline audit trail shows an isotope expansion step that runs before bare formula detection
  2. Isotope shortcodes (e.g., `u234`, `pb210`) are expanded to full element names (e.g., `Uranium-234`, `Lead-210`) when they appear in chemical name strings
  3. Carbon backbone patterns (e.g., `C12H22O11`) and deuterium d-prefix patterns (e.g., `d-glucose`) are not incorrectly expanded
  4. Only shortcodes under 5 characters from the ComptoxR known isotope list are matched — longer or ambiguous codes are left unchanged
  5. Chiral designations are protected from enclosure stripping and flagged as WARNING
  6. Multi-analyte expressions (naked `+` or `and`) are flagged as WARNING without auto-splitting
**Plans**: 2 plans

Plans:
- [ ] 23-01-PLAN.md — Implement three new cleaning functions (chiral protection, isotope expansion, multi-analyte flagging) with unit tests
- [ ] 23-02-PLAN.md — Wire functions into pipeline orchestrators, add integration tests, run smoke test

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 19. Synonym Splitter Comma Protection | v1.6 | 1/1 | Complete | 2026-03-19 |
| 20. Roman Numeral Handling | v1.6 | 1/1 | Complete | 2026-03-19 |
| 21. Unicode Cleaning Coverage | v1.6 | 1/1 | Complete | 2026-03-20 |
| 22. UI Polish | v1.7 | 1/1 | Complete    | 2026-04-01 |
| 23. Isotope Cleaning | v1.7 | 0/2 | Not started | - |
