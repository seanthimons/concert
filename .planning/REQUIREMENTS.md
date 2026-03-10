# Requirements: ChemReg

**Defined:** 2026-03-10
**Core Value:** Users can go from a messy chemical inventory file to validated, curated chemical data in one workflow — upload, detect, clean, tag, curate, resolve, export.

## v1.5 Requirements

Requirements for Disagreement Enrichment. Each maps to roadmap phases.

### Enrichment Data

- [ ] **ENRCH-01**: After curation completes, unique DTXSID candidates from disagree rows are enriched via `ct_chemical_detail` with CASRN, molecular formula, and molecular weight
- [ ] **ENRCH-02**: Enrichment data is cached per-session to avoid redundant API calls when the table re-renders
- [ ] **ENRCH-03**: Each candidate in a disagreement carries its source column name (which tagged column produced it) and search tier (exact/CAS/starts-with)

### Comparison UI

- [ ] **COMP-01**: Disagree rows in Review Results show a "Compare" button alongside the resolution dropdown
- [ ] **COMP-02**: Clicking "Compare" opens a modal with a side-by-side table of all candidate DTXSIDs for that row
- [ ] **COMP-03**: Each candidate in the modal shows: DTXSID, preferredName, CASRN, molecular formula, molecular weight, source column, search tier, rank
- [ ] **COMP-04**: User can select a candidate from within the modal to resolve the disagreement (equivalent to picking from the dropdown)
- [ ] **COMP-05**: Modal resolution pins the row and updates the resolution state immediately

### Backward Compatibility

- [ ] **COMPAT-01**: Existing resolution dropdown continues to work as before for quick resolution without opening the modal
- [ ] **COMPAT-02**: Enrichment failures (API errors, missing data) degrade gracefully — modal still shows available data with "N/A" for missing fields
- [ ] **COMPAT-03**: Export includes enrichment metadata for resolved rows (consensus_casrn, consensus_formula, consensus_mw columns)

## Future Requirements

- Enrichment for agree/single rows (lower priority since no decision needed)
- Link to CompTox Dashboard page per candidate
- Molecular structure image display in modal

## Out of Scope

| Feature | Reason |
|---------|--------|
| Full chemical details panel | Enrichment is scoped to CASRN/formula/MW only — not full CompTox profiles |
| Enrichment for non-disagree rows | No decision ambiguity — enrichment is a resolution aid |
| Tooltip-based enrichment | User chose modal; tooltips are hard to read for tabular data |
| Richer dropdown labels | Dropdowns get too wide; modal is the chosen UI pattern |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ENRCH-01 | Phase 17 | Pending |
| ENRCH-02 | Phase 17 | Pending |
| ENRCH-03 | Phase 17 | Pending |
| COMP-01 | Phase 18 | Pending |
| COMP-02 | Phase 18 | Pending |
| COMP-03 | Phase 18 | Pending |
| COMP-04 | Phase 18 | Pending |
| COMP-05 | Phase 18 | Pending |
| COMPAT-01 | Phase 18 | Pending |
| COMPAT-02 | Phase 18 | Pending |
| COMPAT-03 | Phase 17 | Pending |

**Coverage:**
- v1.5 requirements: 11 total
- Mapped to phases: 11
- Unmapped: 0

---
*Requirements defined: 2026-03-10*
*Last updated: 2026-03-10 after initial definition*
