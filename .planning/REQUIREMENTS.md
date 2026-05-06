# Requirements: ChemReg

**Defined:** 2026-05-06
**Core Value:** Users can go from messy regulatory/benchmark data files to validated, harmonized, toxval-compatible datasets in one workflow.

## v2.2 Requirements

Requirements for WQX Pipeline Refinement milestone. Each maps to roadmap phases.

### Pipeline Ordering

- [ ] **ORD-01**: WQX matching tier runs before CompTox starts-with in the curation search chain
- [ ] **ORD-02**: CompTox starts-with fires only on names still unresolved after WQX matching

### Confidence Control

- [ ] **CONF-01**: Pre-flight modal includes a WQX fuzzy threshold slider with numeric input (default 0.85)
- [ ] **CONF-02**: Pipeline passes user-configured threshold to match_wqx() instead of hardcoded default
- [ ] **CONF-03**: Review Results table displays WQX fuzzy match confidence score as a visible column

### Resolution

- [ ] **RES-01**: User can search the WQX dictionary via type-ahead input to find the correct canonical name for a mismatched or unresolved row
- [ ] **RES-02**: User can reject a bad WQX fuzzy match and either pick a type-ahead result or mark it unresolvable
- [ ] **RES-03**: WQX manual overrides persist through export (same pattern as existing DTXSID resolution)

### Pipeline Toggle

- [ ] **TOG-01**: Pre-flight modal includes a toggle to enable/disable CompTox starts-with tier (off by default)
- [ ] **TOG-02**: Pipeline skips starts-with search when toggle is off

## Future Requirements

None deferred for this milestone.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Removing starts-with entirely | Made toggleable instead — preserves option for datasets where it helps |
| WQX fuzzy threshold per-row adjustment | Pre-flight global threshold is sufficient; per-row adds complexity without clear value |
| Re-running WQX at different threshold post-hoc | Would require pipeline re-execution; pre-flight control covers this use case |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ORD-01 | — | Pending |
| ORD-02 | — | Pending |
| CONF-01 | — | Pending |
| CONF-02 | — | Pending |
| CONF-03 | — | Pending |
| RES-01 | — | Pending |
| RES-02 | — | Pending |
| RES-03 | — | Pending |
| TOG-01 | — | Pending |
| TOG-02 | — | Pending |

**Coverage:**
- v2.2 requirements: 10 total
- Mapped to phases: 0
- Unmapped: 10 ⚠️

---
*Requirements defined: 2026-05-06*
*Last updated: 2026-05-06 after initial definition*
