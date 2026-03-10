---
gsd_state_version: 1.0
milestone: v1.4
milestone_name: milestone
current_phase: "- Plans: TBD"
status: planning
last_updated: "2026-03-10T16:55:17.905Z"
progress:
  total_phases: 1
  completed_phases: 1
  total_plans: 2
  completed_plans: 2
  percent: 100
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
**Plan:** 02 (completed)
**Status:** Complete (100%)
**Progress:** [██████████] 100% (2/2 plans completed, 7/7 requirements satisfied)

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
| 2026-03-10 | Use consecutive-lowercase heuristic to distinguish chemical names from formulas | Simpler than perfecting regex; filters obvious non-formulas before validation |
| 2026-03-10 | Apply word boundaries to stop word substring matching | Prevents "na" from matching inside "Naphthalene"; maintains whole-word detection |
| 2026-03-10 | Reuse @@@ placeholder for letter-comma-letter IUPAC patterns | Consistent with existing digit-comma-digit protection; same restore logic |
| 2026-03-10 | Use here::here() for cross-platform path resolution in test files | Follows existing test pattern for consistent cross-platform compatibility |

**Execution Metrics:**

| Phase | Plan | Duration (s) | Tasks | Files |
|-------|------|--------------|-------|-------|
| 16 | 01 | 913 | 3 | 4 |
| 16 | 02 | 551 | 1 | 1 |

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

Completed Phase 16 Plan 02: End-to-End Pipeline Validation Tests
- Created comprehensive validation test suite with 42 assertions
- Tests confirm all three bug fixes from 16-01 work correctly through full pipeline
- 1 commit created: eec9269
- 7/7 requirements satisfied (all 6 from 16-01 + VAL-01)
- Files created: tests/test_cleaning_pipeline_validation.R
- SUMMARY.md created: .planning/phases/16-cleaning-pipeline-bug-fixes/16-02-SUMMARY.md
- Phase 16 complete: 2/2 plans, 100% done

### Next Action

Phase 16 complete. Milestone v1.4 complete. Ready for next milestone planning or feature work.

### Context for Next Session

This is a targeted bug fix milestone addressing three false positive issues discovered in v1.3's cleaning pipeline:

1. **Formula detection** (FORM-01, FORM-02): `flag_bare_formulas()` in `R/cleaning_pipeline.R` currently uses a broad regex that catches valid names like "Naphthalene" and "Sodium chloride". Need to tighten detection to actual bare formulas while preserving true positives.

2. **Stop word matching** (STOP-01, STOP-02): `flag_quality_adjectives()` uses substring matching, so "na" flags "Naphthalene" and "Sodium bicarbonate". Need whole-word or exact matching.

3. **Synonym splitting** (SPLIT-01, SPLIT-02): `clean_names_step()` uses comma/semicolon split but doesn't protect letter-comma-letter patterns like "N,N-" causing "N,N-Dimethylformamide" to split incorrectly. Existing IUPAC protection (digit-comma-digit, inverted names) needs expansion.

All fixes are in existing pipeline code, no new steps required. Validation via lightweight test script (not full smoke test since no UI changes).

---

*State initialized: 2026-03-10*
