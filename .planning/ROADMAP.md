# Roadmap: ChemReg

## Milestones

- ✅ **v1.5 Disagreement Enrichment** — Phases 17-18 (shipped 2026-03-13)
- ✅ **v1.6 Cleaning Ruleset Fixes** — Phases 19-21 (shipped 2026-03-20)
- ✅ **v1.7 UI Polish & Isotope Cleaning** — Phases 22-23 (shipped 2026-04-13)
- ✅ **v1.8 R Package Migration** — Phases 24-28 (shipped 2026-04-14)
- **v1.9 Number and Unit Coercion Harmonization** — Phases 29-35 (active)

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

<details>
<summary>✅ v1.7 UI Polish & Isotope Cleaning (Phases 22-23) — SHIPPED 2026-04-13</summary>

- [x] Phase 22: UI Polish (1/1 plans) — completed 2026-04-01
- [x] Phase 23: Isotope Cleaning (2/2 plans) — completed 2026-04-02

</details>

<details>
<summary>✅ v1.8 R Package Migration (Phases 24-28) — SHIPPED 2026-04-14</summary>

- [x] Phase 24: Package Scaffolding (1/1 plans) — completed 2026-04-13
- [x] Phase 25: Source File Cleanup (1/1 plans) — completed 2026-04-13
- [x] Phase 26: App Relocation (1/1 plans) — completed 2026-04-13
- [x] Phase 27: Headless Pipeline (1/1 plans) — completed 2026-04-14
- [x] Phase 28: Test Migration (1/1 plans) — completed 2026-04-14

</details>

### v1.9 Number and Unit Coercion Harmonization (Phases 29-35)

**Goal:** Extend ChemReg from compound-only curation to full benchmark/regulatory data curation with numeric result parsing, unit harmonization, and toxval-schema output.

**Build order rationale:** Pure-R functions first (Phases 29-32), UI integration second (Phases 33-35). This enables full TDD before any Shiny code and keeps the 953-test regression surface untouched during development.

- [ ] Phase 29: Static Data Foundations — DATA-01, DATA-02, DATA-03
  - **Goal:** Create static data infrastructure for numeric/unit harmonization
  - **Plans:** 2 plans
    - [ ] 29-01-PLAN.md — Unit conversion table and loader function
    - [ ] 29-02-PLAN.md — ToxVal schema manifest
- [ ] Phase 30: Numeric Result Parser — PARS-01 through PARS-05
- [ ] Phase 31: Unit Harmonization Engine — UNIT-01 through UNIT-05
- [ ] Phase 32: ToxVal Schema Mapper — SCHM-01, SCHM-02
- [ ] Phase 33: Extended Column Tagging — UITG-01, UITG-02, UITG-03
- [ ] Phase 34: Harmonize Tab Module — UITG-04, UITG-05, DATA-04, PARS-06, UNIT-06
- [ ] Phase 35: Export Extension + Headless — SCHM-03, SCHM-04, SCHM-05, UITG-06

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 19. Synonym Splitter Comma Protection | v1.6 | 1/1 | Complete | 2026-03-19 |
| 20. Roman Numeral Handling | v1.6 | 1/1 | Complete | 2026-03-19 |
| 21. Unicode Cleaning Coverage | v1.6 | 1/1 | Complete | 2026-03-20 |
| 22. UI Polish | v1.7 | 1/1 | Complete | 2026-04-01 |
| 23. Isotope Cleaning | v1.7 | 2/2 | Complete | 2026-04-02 |
| 24. Package Scaffolding | v1.8 | 1/1 | Complete    | 2026-04-13 |
| 25. Source File Cleanup | v1.8 | 1/1 | Complete    | 2026-04-13 |
| 26. App Relocation | v1.8 | 1/1 | Complete   | 2026-04-14 |
| 27. Headless Pipeline | v1.8 | 1/1 | Complete    | 2026-04-14 |
| 28. Test Migration | v1.8 | 1/1 | Complete    | 2026-04-14 |
| 29. Static Data Foundations | v1.9 | 0/2 | Planned | — |
| 30. Numeric Result Parser | v1.9 | 0/? | Not Started | — |
| 31. Unit Harmonization Engine | v1.9 | 0/? | Not Started | — |
| 32. ToxVal Schema Mapper | v1.9 | 0/? | Not Started | — |
| 33. Extended Column Tagging | v1.9 | 0/? | Not Started | — |
| 34. Harmonize Tab Module | v1.9 | 0/? | Not Started | — |
| 35. Export Extension + Headless | v1.9 | 0/? | Not Started | — |
