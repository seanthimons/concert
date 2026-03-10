---
gsd_state_version: 1.0
milestone: v1.4
milestone_name: "Cleaning Pipeline Fixes"
status: roadmap_created
stopped_at: null
last_updated: "2026-03-10T21:00:00Z"
last_activity: "2026-03-10 — Roadmap created for v1.4"
progress:
  total_phases: 1
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State: ChemReg v1.4

**Last Updated:** 2026-03-10
**Milestone:** v1.4 Cleaning Pipeline Fixes
**Status:** Roadmap created, ready for planning

---

## Project Reference

**Core Value:** Users can go from a messy chemical inventory file to validated, curated chemical data in one workflow — upload, detect, clean, tag, curate, resolve, export.

**Current Focus:** Fix three cleaning pipeline bugs producing false positives — formula detection, stop word matching, and IUPAC comma protection.

---

## Current Position

**Phase:** 16 - Cleaning Pipeline Bug Fixes
**Plan:** None (roadmap just created)
**Status:** Not started
**Progress:** ░░░░░░░░░░ 0% (0/7 requirements satisfied)

---

## Performance Metrics

**Milestone Stats:**
- Phases: 1
- Requirements: 7 total (FORM: 2, STOP: 2, SPLIT: 2, VAL: 1)
- Coverage: 7/7 mapped (100%)

**Current Phase:**
- Plans: TBD
- Tasks: TBD
- Requirements: 7

**Velocity:** N/A (milestone just started)

**Cumulative (all milestones):**
- Total milestones shipped: 4 (v1.0, v1.1, v1.2, v1.3)
- Total phases: 15 (Phases 1-15)
- Total plans: 29
- LOC: 14,548 R

---

## Accumulated Context

### Decisions Made

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-10 | Single phase for all bug fixes | All 7 requirements target same 2 files (cleaning_pipeline.R, cleaning_reference.R); no natural decomposition boundary |
| 2026-03-10 | Coarse granularity maintained | Small bug fix milestone, no need for fine-grained phases |

### Known Issues / Blockers

**None** — roadmap just created, planning phase not yet started.

### Open Questions

**None** — requirements are clear, all target existing cleaning pipeline code.

### TODOs

- [ ] Run `/gsd:plan-phase 16` to create execution plans
- [ ] Identify exact regex/logic changes needed in `R/cleaning_pipeline.R`
- [ ] Determine IUPAC comma protection strategy (extend existing placeholder logic)
- [ ] Design validation test cases for all three fixes

### Pending Todos (Carried from v1.2)

1. Add richer context to resolution dropdown (ui) — carried from v1.2
2. Revisit Review Results table column visibility (ui) — carried from v1.2

---

## Session Continuity

### What Just Happened

Roadmap created for v1.4 Cleaning Pipeline Fixes milestone:
- Phase 16 defined with 6 success criteria covering all 7 requirements
- All requirements mapped to Phase 16
- 100% coverage validated
- Files written: ROADMAP.md, STATE.md
- REQUIREMENTS.md traceability already has Phase 16 mappings

### Next Action

Run `/gsd:plan-phase 16` to decompose Phase 16 into executable plans.

### Context for Next Session

This is a targeted bug fix milestone addressing three false positive issues discovered in v1.3's cleaning pipeline:

1. **Formula detection** (FORM-01, FORM-02): `flag_bare_formulas()` in `R/cleaning_pipeline.R` currently uses a broad regex that catches valid names like "Naphthalene" and "Sodium chloride". Need to tighten detection to actual bare formulas while preserving true positives.

2. **Stop word matching** (STOP-01, STOP-02): `flag_quality_adjectives()` uses substring matching, so "na" flags "Naphthalene" and "Sodium bicarbonate". Need whole-word or exact matching.

3. **Synonym splitting** (SPLIT-01, SPLIT-02): `clean_names_step()` uses comma/semicolon split but doesn't protect letter-comma-letter patterns like "N,N-" causing "N,N-Dimethylformamide" to split incorrectly. Existing IUPAC protection (digit-comma-digit, inverted names) needs expansion.

All fixes are in existing pipeline code, no new steps required. Validation via lightweight test script (not full smoke test since no UI changes).

---

*State initialized: 2026-03-10*
