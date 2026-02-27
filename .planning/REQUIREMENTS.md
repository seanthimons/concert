# Requirements: ChemReg

**Defined:** 2026-02-27
**Core Value:** Users can go from a messy chemical inventory file to validated, curated chemical data in one workflow — upload, detect, tag, curate, export.

## v1.1 Requirements

Requirements for Curation Process Update milestone. Each maps to roadmap phases.

### Prototype

- [ ] **PROTO-01**: Standalone R script demonstrates full curation pipeline (dedup → tiered search → consensus) using `data/sample_messy.csv` (7 rows with Chemical, CAS, Formula columns)
- [ ] **PROTO-02**: Script validated against subset (first 100 rows) of `uncurated_chemicals_2023-05-16_12-43-41.csv` (12K rows with raw_cas, raw_chem_name columns)

### Deduplication

- [ ] **DEDUP-01**: User's tagged columns are deduplicated to unique values before API calls
- [ ] **DEDUP-02**: Lookup results are mapped back to all original rows via dedup key

### Curation Search

- [ ] **CURE-01**: Script calls `ct_chemical_search_equal_bulk()` directly for exact match search on chemical names
- [ ] **CURE-02**: Script calls `ct_chemical_search_start_with()` directly for starts-with fallback on names that fail exact match
- [ ] **CURE-03**: Script calls `is_cas()` and `as_cas()` directly to validate CAS numbers, then looks up DTXSID via CompToxR
- [ ] **CURE-04**: Lookup results include search tier used (exact/starts-with/CAS) and confidence metadata from CompToxR responses

### Consensus

- [ ] **CONS-01**: Each row's DTXSID results compared across all tagged columns
- [ ] **CONS-02**: Rows classified as agree (same DTXSID), disagree (different DTXSIDs), or partial (some columns unmatched)
- [ ] **CONS-03**: User can select preferred column per individual disagreement row
- [ ] **CONS-04**: User can set column preference en masse for all disagreements

### Integration

- [ ] **INTG-01**: Prototype pipeline orchestration logic integrated into R/curation.R (dedup → call CompToxR directly → heal misses → consensus)
- [ ] **INTG-02**: Shiny app wires new curation pipeline into Run Curation tab with reactive execution
- [ ] **INTG-03**: Review Results tab displays consensus status and resolution controls (per-row and en masse selection)

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
| CompToxR wrapper functions | CompToxR functions are already vectorized and optimized — call them directly |
| Contains search tier | Too fuzzy, may produce unreliable matches — deferred to v2 |
| New tag types beyond Name/CASRN | Future milestone scope |
| Changes to upload/detection flow | Existing pipeline untouched per v1.0 decision |
| Drag-and-drop column tagging | Decided against in v1.0 |
| Session persistence | High complexity, defer to future |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| PROTO-01 | Phase 3 | Pending |
| PROTO-02 | Phase 3 | Pending |
| DEDUP-01 | Phase 3 | Pending |
| DEDUP-02 | Phase 3 | Pending |
| CURE-01 | Phase 3 | Pending |
| CURE-02 | Phase 3 | Pending |
| CURE-03 | Phase 3 | Pending |
| CURE-04 | Phase 3 | Pending |
| CONS-01 | Phase 4 | Pending |
| CONS-02 | Phase 4 | Pending |
| CONS-03 | Phase 4 | Pending |
| CONS-04 | Phase 4 | Pending |
| INTG-01 | Phase 5 | Pending |
| INTG-02 | Phase 5 | Pending |
| INTG-03 | Phase 5 | Pending |

**Coverage:**
- v1.1 requirements: 15 total
- Mapped to phases: 15 (100%)
- Unmapped: 0 ✓

---
*Requirements defined: 2026-02-27*
*Last updated: 2026-02-27 after roadmap revision*
