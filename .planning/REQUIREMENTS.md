# Requirements: ChemReg

**Defined:** 2026-05-08
**Core Value:** Users can go from messy regulatory/benchmark data files to validated, harmonized, toxval-compatible datasets in one workflow.

## v2.3 Requirements

Requirements for Curation Intelligence milestone. Each maps to roadmap phases.

### Conflict Scoring

- [ ] **SCORE-01**: User can see a similarity score between original input and each candidate name in disagree rows
- [ ] **SCORE-02**: Similarity scoring incorporates CompTox synonym lists and rank data to weight candidates
- [ ] **SCORE-03**: Clear mismatches (e.g., Silica vs Estradiol) are auto-resolved with audit trail
- [ ] **SCORE-04**: Ambiguous cases show a suggested best match that user can accept or override

### User Flagging

- [ ] **FLAG-01**: User can flag individual rows as BAD, FOLLOW-UP, or VERIFIED in the resolution UI
- [ ] **FLAG-02**: User can batch-flag multiple selected rows at once
- [ ] **FLAG-03**: Flag status persists through export with dedicated column

### Detection Wiring

- [ ] **DETECT-01**: `detect_data_start()` accepts and passes threshold params to sub-functions
- [ ] **DETECT-02**: Both call sites in mod_file_upload.R pass threshold values through

## Future Requirements

### Deferred from previous milestones

- **DFUT-01**: Date/duration range parsing (e.g., "3-5 days")
- **DFUT-02**: Duration step timing extraction
- **DFUT-03**: Advanced date range handling

## Out of Scope

| Feature | Reason |
|---------|--------|
| Third-party cross-reference (PubChem, ChEBI) for arbitration | High complexity, CompTox synonyms sufficient for v2.3 |
| Detection threshold UI controls (sliders/numerics) | Function params + wiring is sufficient; UI can be added later if users request |
| AI/ML-powered conflict resolution | Opaque audit trail, domain too specialized |
| Auto-split multi-analyte expressions | Flagging only (implemented in v1.7); splitting too risky |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SCORE-01 | Phase 49 | Pending |
| SCORE-02 | Phase 49 | Pending |
| SCORE-03 | Phase 50 | Pending |
| SCORE-04 | Phase 50 | Pending |
| FLAG-01 | Phase 51 | Pending |
| FLAG-02 | Phase 51 | Pending |
| FLAG-03 | Phase 51 | Pending |
| DETECT-01 | Phase 52 | Pending |
| DETECT-02 | Phase 52 | Pending |

**Coverage:**
- v2.3 requirements: 9 total
- Mapped to phases: 9
- Unmapped: 0

---
*Requirements defined: 2026-05-08*
*Last updated: 2026-05-08 after roadmap creation (v2.3 Phases 49-52)*
