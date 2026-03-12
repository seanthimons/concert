# Roadmap: ChemReg v1.5

**Milestone:** v1.5 Disagreement Enrichment
**Created:** 2026-03-10
**Granularity:** Coarse
**Coverage:** 11/11 requirements mapped

## Phases

- [x] **Phase 17: Enrichment Pipeline** - Fetch and store CompTox chemical details for disagreement candidates (completed 2026-03-11)
- [x] **Phase 18: Comparison Modal UI** - Side-by-side candidate comparison modal with in-modal resolution (completed 2026-03-12)

## Phase Details

### Phase 17: Enrichment Pipeline
**Goal:** After curation, disagreement candidate DTXSIDs are enriched with CASRN, molecular formula, and molecular weight via CompTox API, with source column and search tier attribution

**Depends on:** Nothing (builds on existing curation pipeline output)

**Requirements:** ENRCH-01, ENRCH-02, ENRCH-03, COMPAT-03

**Success Criteria** (what must be TRUE):
1. `enrich_candidates()` function takes unique DTXSIDs from disagree rows and returns a tibble with dtxsid, casrn, molecular_formula, molecular_weight
2. Enrichment is called automatically after `run_curation_pipeline` completes and disagree rows exist
3. Results are stored in `data_store$enrichment_cache` as a named list (DTXSID → metadata)
4. `get_resolution_options()` is extended to include source_column, source_tier, and enrichment metadata per candidate
5. Enrichment failures for individual DTXSIDs don't crash the pipeline — missing fields show as NA
6. Export includes consensus_casrn, consensus_formula, consensus_mw columns for resolved rows

Plans:
- [ ] 17-01-PLAN.md — Enrichment function + curation pipeline integration + export columns

### Phase 18: Comparison Modal UI
**Goal:** Users can open a side-by-side comparison modal for any disagree row, see all candidates with enriched metadata, and resolve directly from the modal

**Depends on:** Phase 17 (enrichment data must be available)

**Requirements:** COMP-01, COMP-02, COMP-03, COMP-04, COMP-05, COMPAT-01, COMPAT-02

**Success Criteria** (what must be TRUE):
1. Each unresolved disagree row shows a "Compare" button in the Resolution column (alongside existing dropdown)
2. Clicking "Compare" opens a modal with a table: one row per candidate DTXSID
3. Table columns: DTXSID, preferredName, CASRN, molecular formula, molecular weight, source column, search tier, rank
4. Each candidate row has a "Select" button that resolves the disagreement (equivalent to dropdown selection)
5. Selecting a candidate from the modal pins the row, updates resolution_state, closes the modal, and shows a notification
6. Existing dropdown resolution continues to work unchanged
7. If enrichment data is missing for a candidate, the modal still renders with "N/A" for missing fields

Plans:
- [x] 18-01-PLAN.md — Compare button in DT table + modal UI + in-modal resolution handler (completed 2026-03-12)

---

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 17. Enrichment Pipeline | 1/1 | Complete | 2026-03-11 |
| 18. Comparison Modal UI | 1/1 | Complete    | 2026-03-12 |

---

## Historical Milestones

- ✅ **v1.0 Curation UI Iteration** - Phases 1-2 (shipped 2026-02-27)
- ✅ **v1.1 Curation Process Update** - Phases 3-5 (shipped 2026-03-01)
- ✅ **v1.2 Curation Refinement** - Phases 6-8 (shipped 2026-03-03)
- ✅ **v1.3 Data Cleaning Pipeline** - Phases 9-15 (shipped 2026-03-10)
- ✅ **v1.4 Cleaning Pipeline Fixes** - Phase 16 (shipped 2026-03-10)

---

*Roadmap created: 2026-03-10*
*Last updated: 2026-03-12*
