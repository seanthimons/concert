# Requirements: ChemReg

**Defined:** 2026-02-27
**Core Value:** Users can go from a messy chemical inventory file to validated, curated chemical data in one workflow — upload, detect, tag, curate, export.

## v1.1 Requirements

Requirements for Curation Process Update milestone. Each maps to roadmap phases.

### Prototype

- [ ] **PROTO-01**: Standalone R script demonstrates full curation pipeline (dedup → tiered search → consensus)
- [ ] **PROTO-02**: Script runs against sample data and produces consensus output

### Deduplication

- [ ] **DEDUP-01**: User's tagged columns are deduplicated to unique values before API calls
- [ ] **DEDUP-02**: Lookup results are mapped back to all original rows via dedup key

### Curation Search

- [ ] **CURE-01**: Exact match search via ct_chemical_search_equal_bulk for chemical names
- [ ] **CURE-02**: Starts-with fallback for names that fail exact match
- [ ] **CURE-03**: CAS numbers validated via is_cas/as_cas and looked up for DTXSID
- [ ] **CURE-04**: Each lookup result includes search tier used and confidence score

### Consensus

- [ ] **CONS-01**: Each row's DTXSID results compared across all tagged columns
- [ ] **CONS-02**: Rows classified as agree (same DTXSID), disagree (different DTXSIDs), or partial (some columns unmatched)
- [ ] **CONS-03**: User can select preferred column per individual disagreement row
- [ ] **CONS-04**: User can set column preference en masse for all disagreements

### Integration

- [ ] **INTG-01**: Prototype pipeline refactored into R/curation.R
- [ ] **INTG-02**: Shiny app wires new curation pipeline into Run Curation tab
- [ ] **INTG-03**: Review Results tab displays consensus status and resolution controls

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Extended Search

- **CURE-05**: Contains search tier as optional fallback for persistent misses
- **CURE-06**: Synonym-aware search using CompTox synonym endpoints

### Advanced Resolution

- **CONS-05**: Auto-resolution rules (e.g., always prefer CAS over name when CAS is valid)
- **CONS-06**: Resolution audit trail tracking who picked which column

## Out of Scope

| Feature | Reason |
|---------|--------|
| Contains search tier | Too fuzzy, may produce unreliable matches — deferred to v2 |
| New tag types beyond Name/CASRN | Future milestone scope |
| Changes to upload/detection flow | Existing pipeline untouched per v1.0 decision |
| Drag-and-drop column tagging | Decided against in v1.0 |
| Session persistence | High complexity, defer to future |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| PROTO-01 | — | Pending |
| PROTO-02 | — | Pending |
| DEDUP-01 | — | Pending |
| DEDUP-02 | — | Pending |
| CURE-01 | — | Pending |
| CURE-02 | — | Pending |
| CURE-03 | — | Pending |
| CURE-04 | — | Pending |
| CONS-01 | — | Pending |
| CONS-02 | — | Pending |
| CONS-03 | — | Pending |
| CONS-04 | — | Pending |
| INTG-01 | — | Pending |
| INTG-02 | — | Pending |
| INTG-03 | — | Pending |

**Coverage:**
- v1.1 requirements: 15 total
- Mapped to phases: 0
- Unmapped: 15 ⚠️

---
*Requirements defined: 2026-02-27*
*Last updated: 2026-02-27 after initial definition*
