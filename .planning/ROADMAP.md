# Roadmap: ChemReg

## Milestones

- ✅ **v1.0 Curation UI Iteration** - Phases 1-2 (shipped 2026-02-27)
- ✅ **v1.1 Curation Process Update** - Phases 3-5 (shipped 2026-03-01)
- ✅ **v1.2 Curation Refinement** - Phases 6-8 (shipped 2026-03-03)
- 🚧 **v1.3 Data Cleaning Pipeline** - Phases 9-15 (in progress)

## Phases

<details>
<summary>✅ v1.0 Curation UI Iteration (Phases 1-2) - SHIPPED 2026-02-27</summary>

- [x] Phase 1: Multi-Tab Structure (1/1 plans) - completed 2026-02-26
- [x] Phase 2: Gated Navigation (1/1 plans) - completed 2026-02-26

</details>

<details>
<summary>✅ v1.1 Curation Process Update (Phases 3-5) - SHIPPED 2026-03-01</summary>

- [x] Phase 3: Prototype Pipeline (2/2 plans) - completed 2026-03-01
- [x] Phase 4: Consensus Logic (2/2 plans) - completed 2026-03-01
- [x] Phase 5: Shiny Integration (2/2 plans) - completed 2026-03-01

</details>

<details>
<summary>✅ v1.2 Curation Refinement (Phases 6-8) - SHIPPED 2026-03-03</summary>

- [x] Phase 6: Search Pipeline Refinement (2/2 plans) - completed 2026-03-01
- [x] Phase 7: UI Polish (1/1 plan) - completed 2026-03-01
- [x] Phase 8: Error Recovery Workflows (3/3 plans) - completed 2026-03-03

</details>

### 🚧 v1.3 Data Cleaning Pipeline (In Progress)

**Milestone Goal:** Add staged pre- and post-curation cleaning pipeline with interactive UI, editable reference lists, smart multi-sheet Excel export, and re-import detection.

- [ ] **Phase 9: Modularization** - Extract existing 6 tabs into Shiny modules to prevent app.R from becoming unmaintainable
- [x] **Phase 10: Foundation & Clean Data Tab** - Add audit trail infrastructure, reference data loaders, and new gated workflow tab
- [x] **Phase 11: CAS Pipeline** - Implement CAS-RN rescue, normalization, validation, and multi-CAS splitting with UI preview ✅ 2026-03-06
- [x] **Phase 12: Name Cleaning** - Extract formulas and synonyms, strip quality adjectives, protect IUPAC inverted names (completed 2026-03-06)
- [x] **Phase 13: Reference Filters & Editable Lists** - Flag functional categories and bare formulas, enable in-app reference list editing (completed 2026-03-07)
- [x] **Phase 14: Multi-Sheet Export & Re-Import** - Export complete state as 7-sheet workbook, detect and restore ChemReg exports (completed 2026-03-09)
- [ ] **Phase 15: Post-Curation QC** - Re-validate CAS and check for remaining non-ASCII characters after curation

## Phase Details

### Phase 9: Modularization
**Goal**: App.R reduced to orchestration-only code with all tabs extracted to Shiny modules
**Depends on**: Nothing (refactor existing code)
**Requirements**: MODL-01, MODL-02
**Success Criteria** (what must be TRUE):
  1. **Smoke test**: App starts without error, all 6 tabs render, no console errors on initial load
  2. User can upload files and all existing tabs work identically to current behavior
  3. App.R is less than 500 lines containing only UI orchestration and module calls
  4. Each of 6 tabs (Data Preview, Detection Info, Raw Data, Tag Columns, Run Curation, Review Results) exists as its own module file in R/modules/
  5. All tests from v1.0-v1.2 still pass without modification
**Plans**: 2 plans

Plans:
- [ ] 09-01-PLAN.md — Extract all 7 modules (upload, data_preview, detection_info, raw_data, tag_columns, run_curation, review_results) into R/modules/
- [ ] 09-02-PLAN.md — Rewrite app.R to orchestration-only code + add module render tests + smoke test

### Phase 10: Foundation & Clean Data Tab
**Goal**: Users can access a new "Clean Data" tab with audit trail infrastructure and reference data loaded
**Depends on**: Phase 9
**Requirements**: INFRA-01, INFRA-02, INFRA-03, INFRA-04, UIUX-01
**Success Criteria** (what must be TRUE):
  1. **Smoke test**: App starts without error, new "Clean Data" tab renders in correct position, no console errors
  2. User can see a "Clean Data" tab appear between Data Preview and Tag Columns after uploading a file
  3. User can see reference lists (stop words, block lists, functional categories) loaded at app startup from R/cleaning_reference.R functions
  4. User can see unicode characters automatically cleaned to ASCII equivalents when cleaning runs
  5. User can see leading/trailing punctuation and whitespace automatically stripped from text fields when cleaning runs
  6. User can see a per-row audit trail showing what transformations were applied (stored in data_store$cleaning_audit)
**Plans**: 2 plans

Plans:
- [x] 10-01-PLAN.md — Cleaning pipeline functions, audit trail infrastructure, reference data loaders with caching, and tests (353s, 2 tasks, 5 files)
- [x] 10-02-PLAN.md — Clean Data tab Shiny module, app.R wiring, gated navigation updates (448s, 2 tasks, 3 files)

### Phase 11: CAS Pipeline
**Goal**: Users can see CAS-RNs rescued from names, normalized to canonical format, validated, and multi-CAS cells flagged
**Depends on**: Phase 10
**Requirements**: CAS-01, CAS-02, CAS-03, CAS-04, UIUX-02, UIUX-04
**Success Criteria** (what must be TRUE):
  1. **Smoke test**: App starts without error, CAS cleaning UI elements render, no console errors
  2. User can see placeholder text in CAS fields ('no cas', 'n/a', 'proprietary') detected and set to NA with audit comment
  3. User can see CAS-RNs normalized to NNN-NN-N format with checksum validation; invalid CAS set to NA with audit comment
  4. User can see CAS-RNs embedded in chemical name columns extracted, moved to CAS column, and stripped from name with audit comment
  5. User can see rows with multiple CAS-RNs split into separate rows with audit comment logging the original multi-CAS value
  6. User can see summary cards showing "X CAS rescued", "Y CAS validated", "Z multi-CAS split"
  7. User can run CAS cleaning pipeline with step-by-step progress indicator showing each transformation
**Plans**: 2 plans

Plans:
- [x] 11-01-PLAN.md — CAS pipeline functions (normalize, rescue, multi-CAS detect) with TDD tests ✅ 2026-03-06
- [x] 11-02-PLAN.md — UI integration: tab reorder, value boxes, progress indicator, multi-CAS split UI ✅ 2026-03-06

### Phase 12: Name Cleaning
**Goal**: Users can see chemical names cleaned via parenthetical extraction, synonym splitting, and quality adjective stripping
**Depends on**: Phase 11
**Requirements**: NAME-01, NAME-02, NAME-03, NAME-04, UIUX-03
**Success Criteria** (what must be TRUE):
  1. **Smoke test**: App starts without error, name cleaning UI elements render, no console errors
  2. User can see trailing parentheticals and brackets stripped from chemical names, with protection for fragments containing "yl"
  3. User can see formulas and CAS-RNs extracted from parentheticals and preserved as separate tagged values
  4. User can see comma/semicolon-separated synonyms split into separate entries, with IUPAC inverted-name protection (digit-comma-digit patterns preserved)
  5. User can see quality adjectives ('tech grade', 'pure'), salt references ('and its salts'), and 'unspecified' suffixes stripped with audit comments
  6. User can see before/after data comparison showing name cleaning transformations applied to their dataset
**Plans**: 2 plans

Plans:
- [ ] 12-01-PLAN.md — Name cleaning pipeline functions (parentheticals, adjectives, salts, synonym splitting) with TDD tests
- [ ] 12-02-PLAN.md — UI integration: audit trail accordion, name cleaning value boxes, extended progress indicator

### Phase 13: Reference Filters & Editable Lists
**Goal**: Users can see reference-based flags and edit all reference lists in-app with re-run capability
**Depends on**: Phase 12
**Requirements**: FILT-01, FILT-02, FILT-03, FILT-04, FILT-05, FILT-06, UIUX-05
**Success Criteria** (what must be TRUE):
  1. **Smoke test**: App starts without error, reference list editors and flag UI render, no console errors
  2. User can see functional/product category reference lists seeded from ComptoxR functions and cached locally as baseline
  3. User can enrich all reference lists via file upload or manual entry on top of seeded baseline
  4. User can see names matching reference entries flagged as warning, with match source indicated (ComptoxR-seeded vs user-added vs app-default)
  5. User can see bare molecular formulas (H2O, NaCl, CuSO4) detected and flagged as blocking (name set to NA, CAS still curated)
  6. User can edit all reference lists (add/remove entries) via rhandsontable editors and re-run cleaning with updated lists
  7. User can see blocking flags (red) visually distinguished from warning flags (yellow) with clear indication which block curation vs which annotate only
  8. User can re-run cleaning after modifying reference lists, with downstream state (tags, curation) properly invalidated and reset
**Plans**: 2 plans

Plans:
- [ ] 13-01-PLAN.md — Provenance-tracked reference loaders, bare formula detection, and flag matching functions with TDD tests
- [ ] 13-02-PLAN.md — UI integration: rhandsontable editors, DT flag display, CSV upload, re-run cascade, value box extension

### Phase 14: Multi-Sheet Export & Re-Import
**Goal**: Users can export complete state as multi-sheet Excel workbook and re-import config to restore reference lists and settings
**Depends on**: Phase 13
**Requirements**: EXPO-01, EXPO-02, EXPO-03
**Success Criteria** (what must be TRUE):
  1. **Smoke test**: App starts without error, export/import UI elements render, no console errors
  2. User can export a multi-sheet Excel file containing curated data, cleaning audit trail, reference list state, and pipeline configuration
  3. User can re-import a ChemReg export and see a confirmation modal offering to restore embedded reference lists and pipeline state
  4. User can see the multi-sheet export serve as both a standalone audit document (readable in Excel) and a ChemReg re-entry point
  5. User can see export validation that prevents Excel cell/column limit failures before attempting to write the file
**Plans**: 2 plans

Plans:
- [ ] 14-01-PLAN.md — Export builder, config import parser, Excel validation functions with TDD tests
- [ ] 14-02-PLAN.md — UI integration: replace 3-sheet export with 7-sheet, add sidebar config import with modal confirmation

### Phase 15: Post-Curation QC
**Goal**: Users can see resolved CAS-RNs re-validated and remaining non-ASCII characters flagged after curation completes
**Depends on**: Phase 14
**Requirements**: POST-01, POST-02
**Success Criteria** (what must be TRUE):
  1. **Smoke test**: App starts without error, post-curation QC integrates into Review Results without breaking existing UI
  2. User can see resolved CAS-RNs from CompTox re-validated after curation, with any invalid CAS flagged in Review Results table
  3. User can see any remaining non-ASCII characters flagged in the final curated output as a QC check
  4. User can see post-curation QC results integrated into Review Results tab without requiring separate navigation
**Plans**: TBD

Plans:
- [ ] 15-01: TBD

## Progress

**Execution Order:**
Phases execute sequentially: 9 → 10 → 11 → 12 → 13 → 14 → 15

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 9. Modularization | 0/TBD | Not started | - |
| 10. Foundation & Clean Data Tab | 2/2 | Complete    | 2026-03-05 |
| 11. CAS Pipeline | 2/2 | Complete    | 2026-03-06 |
| 12. Name Cleaning | 2/2 | Complete   | 2026-03-06 |
| 13. Reference Filters & Editable Lists | 2/2 | Complete    | 2026-03-07 |
| 14. Multi-Sheet Export & Re-Import | 2/2 | Complete   | 2026-03-09 |
| 15. Post-Curation QC | 0/TBD | Not started | - |

---
*Last updated: 2026-03-07 after Phase 14 planning*
