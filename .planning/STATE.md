---
gsd_state_version: 1.0
milestone: v1.9
milestone_name: Number and Unit Coercion Harmonization
current_plan: 3 of 3
status: phase_complete
stopped_at: Completed 31.5-03-PLAN.md
last_updated: "2026-04-15T19:26:29Z"
last_activity: 2026-04-15
progress:
  total_phases: 16
  completed_phases: 12
  total_plans: 17
  completed_plans: 17
  percent: 100
---

# Project State: ChemReg

**Last Updated:** 2026-04-15
**Milestone:** v1.9 Number and Unit Coercion Harmonization
**Status:** Executing

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-14)

**Core value:** Users can go from messy regulatory/benchmark data files to validated, harmonized, toxval-compatible datasets in one workflow.
**Current focus:** Phase 31.5 — units-package-assimilation

---

## Current Position

Phase: 31.5
Current Plan: 3 of 3
Status: Phase 31.5 complete
Last activity: 2026-04-15

Progress: ██████████ 100% (17/17 plans)

---

## Performance Metrics

**Cumulative (all milestones):**

- Total milestones shipped: 8 (v1.0–v1.7)
- Total phases: 23 complete
- Total plans: 40 complete
- LOC: ~17,900 R

**v1.8 so far:**

- Phases complete: 0/5
- Plans complete: 0 (TBD after plan-phase runs)

---

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Notable additions in v1.7:

- Content-encoded chiral placeholders (`###CHIRAL_PLUS###`) — stateless restore, survives synonym split row reordering
- elementId removal from reactable safe — Shiny auto-assigns same HTML ID
- unname(unlist()) before Shiny output bindings — prevents jsonlite 2.0.0 warning
- [Phase 24-package-scaffolding]: MIT License with 2026 Sean Thimons copyright and 0.1.0 version
- [Phase 24-package-scaffolding]: Remotes: seanthimons/ComptoxR required because ComptoxR not on CRAN
- [Phase 24-package-scaffolding]: Imports/Suggests split: Shiny stack in Suggests so headless users don't need it
- [Phase 25]: Add ^tests$ to .Rbuildignore: legacy test files incompatible with R CMD check; migration to tests/testthat/ is Phase 28 scope
- [Phase 26]: Moved Shiny packages to Imports (required for roxygen2 module processing)
- [Phase 26]: Moved module files from R/modules/ to R/ (roxygen2 subdirectory limitation)
- [Phase 27-headless-pipeline]: writexl promoted to Imports — headless XLSX export is unconditional
- [Phase 27-headless-pipeline]: skip_flags reserved for future use — isotope_match handled internally by run_curation_pipeline()
- [Phase 28-test-migration]: isotope_lookup is list(lookup,elem_alt_names) not bare tibble — tests updated to match actual return type
- [Phase 28-test-migration]: local_mocked_bindings(.package='ComptoxR') for API mocking in testthat — replaces broken assignInNamespace pattern
- [Phase 28-test-migration]: enrich_candidates tryCatch added around ct_chemical_detail_search_bulk for graceful API failure
- [Phase 29-static-data-foundations]: 6-column unit table schema (from_unit, to_unit, multiplier, category, confidence, source) with 151 rows from ECOTOX and SSWQS; molar/temperature units stored with LOW confidence for downstream special handling
- [Phase 29-static-data-foundations]: Zero-row tibble via tibble()[0,] slice — tibble() with scalar NAs creates 1-row, must slice
- [Phase 30]: Fortran exponent detection uses ifelse()+grepl() guard to avoid false matches on standard sci notation
- [Phase 30]: Multi-pass comma stripping via 3-iteration for loop (vectorized, avoids while-grepl on vectors)
- [Phase 30]: Range detection before Fortran normalization: normalize_numeric_string Fortran step converts '5-10' to '5e-10', so split_ranges must operate on pre-Fortran form
- [Phase 30]: Tighter Fortran guard in split_ranges: decimal-mantissa-required regex distinguishes '4.56-02' (Fortran) from '5-10' (range) at pre-norm stage
- [Phase 31]: Unit harmonization uses match() for O(n*m) lookup; acceptable for typical unit_map sizes (~150 rows)
- [Phase 31]: normalize_unit_string() is internal (not exported) — normalization is an implementation detail
- [Phase 31]: Empty string "" for exact match unit_flag instead of NA — keeps downstream joins clean
- [Phase 31.5]: units package as hard Imports dependency (D-03) — no requireNamespace() guard needed
- [Phase 31.5]: Domain units registered via .onLoad() in R/zzz.R with tryCatch for reload resilience
- [Phase 31.5-03]: Synonyms loaded internally via system.file() - no user parameter needed
- [Phase 31.5-03]: Molarity conversion: mg/L = molarity x MW x scale_factor (M=1000, mM=1, uM=0.001)
- [Phase 31.5-03]: ppb/ppm routing: aqueous->mg/L, solid->mg/kg, air->mg/m3; default aqueous with "media_inferred" flag
- [Phase 31.5-03]: Extended unit_flag values: "", "case_fallback", "unmatched", "needs_mw", "media_inferred"

### Pending Todos

None.

### Roadmap Evolution

- Phase 31.5 inserted after Phase 31: Units Package Assimilation (URGENT) — replaces manual unit table with `units` package + registrations, adds context-aware conversions

### Known Issues / Blockers

- `test_cleaning_reference.R` has 1 pre-existing failure (expects 3 keys from `load_all_reference_lists`, gets 4 including `strip_terms`) — will be fixed in Phase 28 (TST-03)

---

## Session Continuity

Last session: 2026-04-15T19:26:29Z
Stopped at: Completed 31.5-03-PLAN.md
Resume file: .planning/phases/31.5-units-package-assimilation/31.5-03-SUMMARY.md

---

*State initialized: 2026-03-10*
