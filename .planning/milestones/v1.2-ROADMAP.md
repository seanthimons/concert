# Roadmap: ChemReg

## Milestones

- ✅ **v1.0 Curation UI Iteration** - Phases 1-2 (shipped 2026-02-27)
- ✅ **v1.1 Curation Process Update** - Phases 3-5 (shipped 2026-03-01)
- 🚧 **v1.2 Curation Refinement** - Phases 6-8 (in progress)

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

### 🚧 v1.2 Curation Refinement (In Progress)

**Milestone Goal:** Improve curation accuracy, error recovery, and result presentation

- ✅ **Phase 6: Search Pipeline Refinement** (2/2 plans) - Reorder search tiers and enable Other tag curation
- [ ] **Phase 7: UI Polish** - Column visibility improvements and richer resolution context
- [ ] **Phase 8: Error Recovery Workflows** - Manual DTXSID entry and error row retry

## Phase Details

### Phase 6: Search Pipeline Refinement
**Goal**: Improve curation accuracy via optimized search tier order and expanded tag participation
**Depends on**: Phase 5
**Requirements**: SRCH-01, SRCH-02, SRCH-03
**Success Criteria** (what must be TRUE):
  1. User sees CAS validation attempted before fuzzy starts-with matching (exact → CAS → starts-with order)
  2. User can tag columns as "Other" and those values participate in CompTox search with full tier chain
  3. User sees DTXSID results from "Other" tagged columns counted equally in consensus classification
  4. User observes improved match rate for chemical identifiers (CAS validation catches exact IDs before fuzzy search dilutes accuracy)
**Plans**: 2 plans

Plans:
- [x] 06-01-PLAN.md -- Tier reorder (exact->CAS->starts-with) and Other tag expansion in R/curation.R (completed 2026-03-01)
- [x] 06-02-PLAN.md -- Match Type column and search summary notification in app.R (completed 2026-03-01)

### Phase 7: UI Polish
**Goal**: Reduce cognitive load and provide richer context for curation decisions
**Depends on**: Phase 6
**Requirements**: UIPX-01, UIPX-02, UIPX-03, UIPX-04
**Success Criteria** (what must be TRUE):
  1. User sees only tagged columns in Review Results table by default (untagged columns automatically hidden but included in Excel export)
  2. User can toggle column visibility via colvis button to show/hide specific columns
  3. User sees preferredName, rank, and QC level in resolution dropdown (not just raw DTXSID)
  4. User receives Excel export with error rows flagged as "needs manual review" in dedicated column
**Plans**: 1 plan

Plans:
- [ ] 07-01-PLAN.md -- Column visibility, colvis toggle, badges, enhanced dropdown, error flagging

### Phase 8: Error Recovery Workflows
**Goal**: Enable users to manually resolve curation errors and retry failed rows
**Depends on**: Phase 7
**Requirements**: RECV-01, RECV-02, RECV-03, RECV-04, RECV-05
**Success Criteria** (what must be TRUE):
  1. User can manually enter DTXSID for any error-status row via inline cell click
  2. User can bulk-validate all manually entered DTXSIDs against CompTox in one action
  3. User sees validated manual DTXSIDs populate preferredName and update consensus status
  4. User can select error rows, re-assign tag types via modal, and re-curate just that subset
  5. User sees re-curated results merge back into main table preserving row order and existing pinned resolutions
**Plans**: 3 plans

Plans:
- [ ] 08-01-PLAN.md -- Backend: validate_manual_dtxsids(), merge_retry_results(), consensus status extensions + unit tests
- [ ] 08-02-PLAN.md -- Manual DTXSID inline entry, validation queue, Validate All button with progress
- [ ] 08-03-PLAN.md -- Error filter, row selection, re-tag modal, re-curate pipeline, merge-back + human verification

## Progress

**Execution Order:**
Phases execute in numeric order: 6 → 7 → 8

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Multi-Tab Structure | v1.0 | 1/1 | Complete | 2026-02-26 |
| 2. Gated Navigation | v1.0 | 1/1 | Complete | 2026-02-26 |
| 3. Prototype Pipeline | v1.1 | 2/2 | Complete | 2026-03-01 |
| 4. Consensus Logic | v1.1 | 2/2 | Complete | 2026-03-01 |
| 5. Shiny Integration | v1.1 | 2/2 | Complete | 2026-03-01 |
| 6. Search Pipeline Refinement | 2/2 | Complete   | 2026-03-01 | - |
| 7. UI Polish | v1.2 | 0/1 | Planned | - |
| 8. Error Recovery Workflows | v1.2 | 0/3 | Planned | - |

---
*Last updated: 2026-03-03 after phase 08 planning*
