# Requirements: ChemReg

**Defined:** 2026-04-29
**Core Value:** Users can go from messy regulatory/benchmark data files to validated, harmonized, toxval-compatible datasets in one workflow.

## v2.1 Requirements

Requirements for WQX Parameter Harmonization milestone. Each maps to roadmap phases.

### Dictionary

- [ ] **DICT-01**: Package downloads WQX Characteristic.csv and Characteristic Alias.csv from EPA and caches as combined lookup RDS in `inst/extdata/reference_cache/`
- [ ] **DICT-02**: Package checks for dictionary RDS on first use and downloads/builds if missing
- [ ] **DICT-03**: Exported `refresh_wqx_cache()` function re-downloads and rebuilds the lookup RDS

### Matching

- [ ] **MATCH-01**: Exact case-insensitive match against ~13,800 canonical WQX Characteristic Names
- [ ] **MATCH-02**: Exact case-insensitive match against alias crosswalk (WQX SYNONYM REGISTRY, STANDARDIZE NAME, RETIRED NAME types) resolving to canonical name
- [ ] **MATCH-03**: Fuzzy fallback via stringdist against canonical names for remaining unresolved, with configurable distance threshold
- [ ] **MATCH-04**: Console logging (cli-formatted) for each match: success reports name + match type, failure reports nearest candidate + distance

### Integration

- [ ] **INTG-01**: Standalone prototype script validates WQX matching against detections.csv training data before Shiny integration
- [ ] **INTG-02**: WQX match resolves into the same output column as curated compound names (treated as a resolution, not a separate annotation)
- [ ] **INTG-03**: Auto-fires for names that failed CompTox curation — no user toggle
- [ ] **INTG-04**: `curate_headless()` includes WQX matching in its pipeline

## Future Requirements

### Testing

- **WFUT-01**: Test suite for WQX matching (exact, alias, fuzzy, no-match scenarios)

### Dictionary Metadata

- **WFUT-02**: Version/date tracking in dictionary RDS metadata

### UI

- **WFUT-03**: Shiny UI surfacing of WQX match results

### Deferred from v2.0

- **DFUT-01/02/03**: Date/duration ranges + step timing

## Out of Scope

| Feature | Reason |
|---------|--------|
| Fuzzy matching against alias names | 93K aliases × unresolved names is expensive; exact alias match covers known variants |
| WQX parameter metadata (units, methods, fractions) | Not compounds, no identifier — canonical name is the only output needed |
| User-editable WQX dictionary | Unlike reference lists, this is authoritative EPA data — no user edits |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DICT-01 | Phase 43 | Pending |
| DICT-02 | Phase 43 | Pending |
| DICT-03 | Phase 43 | Pending |
| MATCH-01 | Phase 44 | Pending |
| MATCH-02 | Phase 44 | Pending |
| MATCH-03 | Phase 44 | Pending |
| MATCH-04 | Phase 44 | Pending |
| INTG-01 | Phase 44 | Pending |
| INTG-02 | Phase 45 | Pending |
| INTG-03 | Phase 45 | Pending |
| INTG-04 | Phase 45 | Pending |

**Coverage:**
- v2.1 requirements: 11 total
- Mapped to phases: 11
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-29*
*Last updated: 2026-04-29 after roadmap creation*
