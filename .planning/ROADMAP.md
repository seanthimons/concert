# Roadmap: ChemReg

## Milestones

- ✅ **v1.0 Curation UI Iteration** - Phases 1-2 (shipped 2026-02-27)
- 🚧 **v1.1 Curation Process Update** - Phases 3-5 (in progress)

## Phases

<details>
<summary>✅ v1.0 Curation UI Iteration (Phases 1-2) - SHIPPED 2026-02-27</summary>

- [x] Phase 1: Multi-Tab Structure (1/1 plans) - completed 2026-02-26
- [x] Phase 2: Gated Navigation (1/1 plans) - completed 2026-02-26

</details>

### 🚧 v1.1 Curation Process Update (In Progress)

**Milestone Goal:** Replace naive curation with a deduplicated, tiered-search pipeline that heals missing matches and provides DTXSID-based consensus across columns with user-driven conflict resolution.

- [ ] **Phase 3: Prototype Pipeline** - Standalone script with deduplication and direct CompToxR calls
- [ ] **Phase 4: Consensus Logic** - Row-level DTXSID comparison with conflict resolution
- [ ] **Phase 5: Shiny Integration** - Production pipeline orchestration integrated into app

## Phase Details

### Phase 3: Prototype Pipeline
**Goal**: Standalone R script demonstrates deduplication and tiered curation via direct CompToxR calls
**Depends on**: Phase 2
**Requirements**: PROTO-01, PROTO-02, DEDUP-01, DEDUP-02, CURE-01, CURE-02, CURE-03, CURE-04
**Success Criteria** (what must be TRUE):
  1. Script deduplicates unique values from multiple tagged columns before API calls
  2. Script calls `ct_chemical_search_equal_bulk()` directly for exact match on chemical names
  3. Script calls `ct_chemical_search_start_with()` directly as fallback for names that fail exact match
  4. Script calls `is_cas()` and `as_cas()` directly to validate CAS numbers and looks up DTXSID
  5. Script produces lookup results table with search tier (exact/starts-with/CAS) and confidence metadata
  6. Script runs successfully against `data/sample_messy.csv` (7 rows)
  7. Script validated against first 100 rows of `uncurated_chemicals_2023-05-16_12-43-41.csv` (12K row dataset)
**Plans**: 2 plans in 2 waves

Plans:
- [ ] 03-01-PLAN.md — Core pipeline functions (dedup + tiered search + CAS validation) via TDD
- [ ] 03-02-PLAN.md — Validate pipeline against sample_messy.csv and uncurated_chemicals (100 rows)

### Phase 4: Consensus Logic
**Goal**: Row-level DTXSID consensus comparison with conflict resolution controls
**Depends on**: Phase 3
**Requirements**: CONS-01, CONS-02, CONS-03, CONS-04
**Success Criteria** (what must be TRUE):
  1. Each row's DTXSID results are compared across all tagged columns
  2. Rows are classified as agree (same DTXSID), disagree (different DTXSIDs), or partial (some unmatched)
  3. User can select preferred column for individual disagreement rows
  4. User can set en masse column preference that applies to all disagreement rows
  5. Consensus logic runs on prototype output and produces classification results
**Plans**: TBD

Plans:
- [ ] 04-01: TBD
- [ ] 04-02: TBD

### Phase 5: Shiny Integration
**Goal**: Production-ready pipeline orchestration integrated into app with consensus display
**Depends on**: Phase 4
**Requirements**: INTG-01, INTG-02, INTG-03
**Success Criteria** (what must be TRUE):
  1. Prototype pipeline orchestration logic (dedup → call CompToxR directly → heal misses → consensus) integrated into R/curation.R
  2. Run Curation tab executes new pipeline and stores consensus results reactively
  3. Review Results tab displays consensus status per row with resolution controls (per-row and en masse selection)
  4. User can run full workflow (upload → tag → curate → resolve → export) without errors
  5. Curation results include DTXSID, search tier, and consensus classification for each row
**Plans**: TBD

Plans:
- [ ] 05-01: TBD
- [ ] 05-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 3 → 4 → 5

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Multi-Tab Structure | v1.0 | 1/1 | Complete | 2026-02-26 |
| 2. Gated Navigation | v1.0 | 1/1 | Complete | 2026-02-26 |
| 3. Prototype Pipeline | v1.1 | 0/2 | Not started | - |
| 4. Consensus Logic | v1.1 | 0/? | Not started | - |
| 5. Shiny Integration | v1.1 | 0/? | Not started | - |

---
*Last updated: 2026-02-27 after roadmap revision*
