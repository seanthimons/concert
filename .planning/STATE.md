---
gsd_state_version: 1.0
milestone: v2.2
milestone_name: WQX Pipeline Refinement
status: planning
stopped_at: Phase 47 context gathered
last_updated: "2026-05-07T00:23:07.970Z"
last_activity: 2026-05-06 — Roadmap created for v2.2 (2 phases, 10 requirements mapped)
progress:
  total_phases: 2
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State: ChemReg

**Last Updated:** 2026-05-06
**Milestone:** v2.2 WQX Pipeline Refinement
**Status:** Roadmap created — ready to plan Phase 47

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-06)

**Core value:** Users can go from messy regulatory/benchmark data files to validated, harmonized, toxval-compatible datasets in one workflow.
**Current focus:** Phase 47 — Pipeline Reordering, Threshold Control & Starts-With Toggle

---

## Current Position

Phase: 47 of 48 (Pipeline Reordering, Threshold Control & Starts-With Toggle)
Plan: Not started
Status: Ready to plan
Last activity: 2026-05-06 — Roadmap created for v2.2 (2 phases, 10 requirements mapped)

Progress: [░░░░░░░░░░] 0%

---

## Performance Metrics

**Cumulative (all milestones):**

- Total milestones shipped: 11 (v1.0–v2.1)
- Total phases complete: 40 (through Phase 46)
- Total plans complete: 80
- LOC: ~94,200 R

---

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
All v2.1 decisions archived — see PROJECT.md for full table.

### Pending Todos

None.

### Known Issues / Blockers

- Tech debt: `^tests$` in `.Rbuildignore` blocks R CMD check (devtools::test() works)
- Tech debt: `R/archive/prototype_pipeline.R` has bare library() calls, not excluded from build
- Benchmark results template (`docs/benchmark_results.md`) has placeholders — needs real 100K data run

---

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Date/Duration | DFUT-01/02/03: Date/duration ranges + step timing | Future milestone | v2.0 |
| Tests | Phase 47 stale test fixes from Phases 37-41 | Tracked as bean chemreg-mtpo | v2.1 |

---

## Session Continuity

Last session: 2026-05-07T00:23:07.964Z
Stopped at: Phase 47 context gathered
Resume file: .planning/phases/47-pipeline-reordering-threshold-control-starts-with-toggle/47-CONTEXT.md
