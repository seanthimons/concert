# Roadmap: ChemReg v1.4

**Milestone:** v1.4 Cleaning Pipeline Fixes
**Created:** 2026-03-10
**Granularity:** Coarse
**Coverage:** 7/7 requirements mapped

## Phases

- [ ] **Phase 16: Cleaning Pipeline Bug Fixes** - Fix formula detection, stop word matching, and synonym splitting false positives

## Phase Details

### Phase 16: Cleaning Pipeline Bug Fixes
**Goal:** Cleaning pipeline correctly distinguishes valid chemical names from formulas, uses whole-word stop word matching, and protects letter-comma-letter IUPAC patterns

**Depends on:** Nothing (standalone bug fixes)

**Requirements:** FORM-01, FORM-02, STOP-01, STOP-02, SPLIT-01, SPLIT-02, VAL-01

**Success Criteria** (what must be TRUE):
1. Valid chemical names like "Naphthalene" and "Sodium chloride" are not falsely flagged as bare formulas
2. Actual bare formulas like "C10H22" and "CaCl2" are still detected and blocked correctly
3. Chemical names containing stop word substrings ("Naphthalene" with "na", "Sodium bicarbonate" with "na") are not flagged
4. IUPAC patterns like "N,N-Dimethylformamide" are not split at the comma
5. Normal comma/semicolon-separated synonym lists still split correctly
6. Validation test script confirms all three fixes against known-good and known-bad cases

**Plans:** TBD

---

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 16. Cleaning Pipeline Bug Fixes | 0/? | Not started | - |

---

## Historical Milestones

- ✅ **v1.0 Curation UI Iteration** - Phases 1-2 (shipped 2026-02-27)
- ✅ **v1.1 Curation Process Update** - Phases 3-5 (shipped 2026-03-01)
- ✅ **v1.2 Curation Refinement** - Phases 6-8 (shipped 2026-03-03)
- ✅ **v1.3 Data Cleaning Pipeline** - Phases 9-15 (shipped 2026-03-10)

---

*Roadmap created: 2026-03-10*
*Last updated: 2026-03-10*
