# Requirements: ChemReg

**Defined:** 2026-03-18
**Core Value:** Users can go from a messy chemical inventory file to validated, curated chemical data in one workflow — upload, detect, clean, tag, curate, resolve, export.

## v1.6 Requirements

Requirements for cleaning ruleset fixes. Each maps to roadmap phases.

### Synonym Splitting

- [x] **SPLIT-01**: Multi-locant IUPAC names (e.g., 2,4,6-trichlorophenol) are not split by the synonym splitter
- [x] **SPLIT-02**: Existing single-locant protection (2,4-D) continues to work correctly

### Roman Numerals

- [ ] **ROMAN-01**: Chemical names with roman numeral oxidation states (e.g., chromium III, chromium VI) retain the numeral as part of the name
- [ ] **ROMAN-02**: Roman numerals in parenthetical form (e.g., chromium (III)) are not misrouted to formula column

### Unicode Cleaning

- [ ] **UNIC-01**: Greek alpha (U+03B1, α) is cleaned by the pipeline before QC runs
- [ ] **UNIC-02**: Prime symbol (U+2032, ′) is cleaned by the pipeline before QC runs
- [ ] **UNIC-03**: Unicode cleaning tests align with current ComptoxR mapping format (no dot notation)

## Future Requirements

None — milestone is extensible via `/gsd:add-phase` as roadtesting surfaces more issues.

## Out of Scope

| Feature | Reason |
|---------|--------|
| ct_details API fix | User fixing in ComptoxR separately |
| jsonlite named vector warning | Cosmetic, no functional impact |
| Widget ID warning | Shiny internals, no functional impact |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SPLIT-01 | Phase 19 | Complete |
| SPLIT-02 | Phase 19 | Complete |
| ROMAN-01 | Phase 20 | Pending |
| ROMAN-02 | Phase 20 | Pending |
| UNIC-01 | Phase 21 | Pending |
| UNIC-02 | Phase 21 | Pending |
| UNIC-03 | Phase 21 | Pending |

**Coverage:**
- v1.6 requirements: 7 total
- Mapped to phases: 7
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-18*
*Last updated: 2026-03-18 after roadmap creation*
