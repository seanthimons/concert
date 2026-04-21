---
gsd_state_version: 1.0
milestone: v1.5
milestone_name: milestone
current_plan: 2
status: completed
stopped_at: Phase 36 context gathered
last_updated: "2026-04-21T20:36:40.229Z"
last_activity: 2026-04-17 -- Phase 35 complete (export extension + headless harmonize)
progress:
  total_phases: 17
  completed_phases: 16
  total_plans: 24
  completed_plans: 24
  percent: 100
---

# Project State: ChemReg

**Last Updated:** 2026-04-17
**Milestone:** v1.9 Number and Unit Coercion Harmonization
**Status:** Milestone complete

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-14)

**Core value:** Users can go from messy regulatory/benchmark data files to validated, harmonized, toxval-compatible datasets in one workflow.
**Current focus:** Phase 35 — export-extension-headless (COMPLETE)

---

## Current Position

Phase: 35 (export-extension-headless) — COMPLETE
Plan: 2 of 2
Current Plan: 2
Status: Phase complete
Last activity: 2026-04-17 -- Phase 35 complete (export extension + headless harmonize)

Progress: ██████████ 100% (24/24 plans)

---

## Performance Metrics

**Cumulative (all milestones):**

- Total milestones shipped: 8 (v1.0–v1.7)
- Total phases: 23 complete
- Total plans: 40 complete
- LOC: ~17,900 R

**v1.9 final:**

- Phases complete: 7/7
- Plans complete: 13/13
- Milestone shipped: 2026-04-17

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
- [Phase 32]: digest package added to Imports for SHA256 source_hash generation
- [Phase 32]: 56-column ToxVal schema with typed NAs (NA_character_, NA_real_) enforced via assert_typed_nas()
- [Phase 32]: 19 audit columns (*_original + original_year) for harmonization tracking
- [Phase 33]: Tag dispatch helpers as single source of truth (classify_tags, validate_tag_pairing, detect_tag_changes)
- [Phase 33]: column_tags contains ONLY chemical tags for backwards compatibility with curation pipeline
- [Phase 33]: Granular cascade resets per tag type (reset_chemical_downstream, reset_numeric_downstream)
- [Phase 35]: arrow as hard Imports dependency (D-02) — parquet always available, no requireNamespace() guard
- [Phase 35]: Sheet 8 "ToxVal Output" always present in Excel export; placeholder note when harmonization not run (D-09, D-10)
- [Phase 35]: curate_headless(harmonize=TRUE) runs full pipeline: corrections → parse → harmonize → toxval map (D-05)
- [Phase 35]: Parquet round-trip validation is test-only (D-12) — no runtime schema assertion at export time

### Pending Todos

None.

### Roadmap Evolution

- Phase 31.5 inserted after Phase 31: Units Package Assimilation (URGENT) — replaces manual unit table with `units` package + registrations, adds context-aware conversions

### Known Issues / Blockers

- `test_cleaning_reference.R` has 1 pre-existing failure (expects 3 keys from `load_all_reference_lists`, gets 4 including `strip_terms`) — will be fixed in Phase 28 (TST-03)

---

## Session Continuity

Last session: 2026-04-21T20:36:40.215Z
Stopped at: Phase 36 context gathered
Resume file: .planning/phases/36-wire-toxval-shiny/36-CONTEXT.md

---

*State initialized: 2026-03-10*
