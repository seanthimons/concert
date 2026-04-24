---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Pipeline Performance & Date/Media Harmonization
current_plan: 0
status: ready_to_plan
stopped_at: null
last_updated: "2026-04-24"
last_activity: 2026-04-24 -- Roadmap created; 6 phases defined (37-42)
progress:
  total_phases: 6
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State: ChemReg

**Last Updated:** 2026-04-24
**Milestone:** v2.0 Pipeline Performance & Date/Media Harmonization
**Status:** Ready to plan Phase 37

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-24)

**Core value:** Users can go from messy regulatory/benchmark data files to validated, harmonized, toxval-compatible datasets in one workflow.
**Current focus:** Phase 37 — Performance Architecture

---

## Current Position

Phase: 37 of 42 (Performance Architecture)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-04-24 — v2.0 roadmap created; Phases 37-42 defined

Progress: ░░░░░░░░░░ 0% (v2.0 milestone)

---

## Performance Metrics

**Cumulative (all milestones):**

- Total milestones shipped: 9 (v1.0–v1.9)
- Total phases: 30 complete (through Phase 36)
- Total plans: 53 complete
- LOC: ~17,900 R

---

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Notable additions in v1.9:

- [Phase 29]: 6-column unit table schema (from_unit, to_unit, multiplier, category, confidence, source) with 151 rows
- [Phase 31.5]: units package as hard Imports dependency; domain units registered via .onLoad() in R/zzz.R
- [Phase 31.5-03]: ppb/ppm routing: aqueous→mg/L, solid→mg/kg, air→mg/m3; default aqueous with "media_inferred" flag
- [Phase 32]: 56-column ToxVal schema with typed NAs enforced via assert_typed_nas()
- [Phase 33]: Tag dispatch helpers as single source of truth; column_tags contains ONLY chemical tags for backwards compat

v2.0 architecture decisions (from research 2026-04-24):
- Dedup is orchestrator wrapper (`dedup_step()`), NOT internal to step functions
- Short-circuit pre-checks are orchestrator-only; step functions always return `list(cleaned_data, audit_trail)`
- Date parsing is harmonization-layer (post-tagging), new `R/date_parser.R`
- Duration uses custom synonym map — never `lubridate::duration()` ("m" = months pitfall)
- AMOS extraction is build-time only; `amos_media.rds` committed, never called at runtime
- `lubridate` → Imports; `bench` → Suggests only

### Pending Todos

None.

### Known Issues / Blockers

- Tech debt: `^tests$` in `.Rbuildignore` blocks R CMD check (devtools::test() works)
- Tech debt: `R/archive/prototype_pipeline.R` has bare library() calls, not excluded from build
- Phase 37 dedup migration must be one step at a time with 953+ tests green after each

---

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Date/Duration | DFUT-01/02/03: Date/duration ranges + step timing | Future milestone | v2.0 |
| WQX | WFUT-01/02/03: WQX parameter mapping | Future milestone | v2.0 |

---

## Session Continuity

Last session: 2026-04-24
Stopped at: v2.0 roadmap created; ready to plan Phase 37
Resume file: —

---

*State initialized: 2026-03-10*
