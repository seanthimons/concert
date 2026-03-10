# Requirements: ChemReg

**Defined:** 2026-03-10
**Core Value:** Users can go from a messy chemical inventory file to validated, curated chemical data in one workflow — upload, detect, clean, tag, curate, resolve, export.

## v1.4 Requirements

Requirements for Cleaning Pipeline Fixes. Each maps to roadmap phases.

### Formula Detection

- [ ] **FORM-01**: Valid chemical names (e.g., Naphthalene, Sodium chloride) are not falsely flagged as bare formulas
- [ ] **FORM-02**: Actual bare formulas (e.g., C10H22, NaCl, CaCl2) are still correctly detected and blocked

### Stop Word Matching

- [ ] **STOP-01**: Stop word matching uses whole-word or exact matching, not substring
- [ ] **STOP-02**: Legitimate chemical names containing stop word substrings (e.g., "Naphthalene", "Sodium bicarbonate") are not flagged

### Synonym Splitting

- [ ] **SPLIT-01**: Letter-comma-letter IUPAC patterns (N,N- O,O- S,S-) are protected from splitting
- [ ] **SPLIT-02**: Normal comma/semicolon-separated synonyms still split correctly

### Validation

- [ ] **VAL-01**: Lightweight test script validates all three fixes against known-good/known-bad cases

## Future Requirements

None — this is a bug fix milestone.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Full test suite overhaul | Targeted validation scripts only |
| Shiny smoke test | No UI changes in this milestone |
| New cleaning pipeline steps | Bug fixes only, no new features |
| Stop word list expansion | Fix matching logic, not the word list |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FORM-01 | Phase 16 | Pending |
| FORM-02 | Phase 16 | Pending |
| STOP-01 | Phase 16 | Pending |
| STOP-02 | Phase 16 | Pending |
| SPLIT-01 | Phase 16 | Pending |
| SPLIT-02 | Phase 16 | Pending |
| VAL-01 | Phase 16 | Pending |

**Coverage:**
- v1.4 requirements: 7 total
- Mapped to phases: 7
- Unmapped: 0

---
*Requirements defined: 2026-03-10*
*Last updated: 2026-03-10 after initial definition*
