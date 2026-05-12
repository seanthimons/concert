# Milestones

## v2.2 WQX Pipeline Refinement (Shipped: 2026-05-08)

**Phases completed:** 2 phases (47-48), 7 plans
**Lines changed:** +7,896 / -6,522 across 78 files
**Requirements:** 10/10 satisfied (ORD-01/02, CONF-01/02/03, RES-01/02/03, TOG-01/02)
**Timeline:** 3 days (2026-05-06 → 2026-05-08)

**Key accomplishments:**

- Pipeline reorder: WQX dictionary matching fires as Tier 3 before CompTox starts-with, with starts-with gated behind opt-in toggle (default OFF)
- Configurable WQX fuzzy threshold (0.50–1.00) via pre-flight slider with synced numeric input, threaded through to both Shiny and headless paths
- WQX confidence column (Jaro-Winkler similarity) surfaced in Review Results table as "WQX Conf." with deduplication for multi-tag datasets
- WQX Review modal with type-ahead search over 124K-entry dictionary, override action writing wqx_override_name to dedup groups, and reject action setting unresolvable status
- Override/reject persistence through export (same resolution_state pattern as existing DTXSID resolution)

**UAT:** Phase 47 (2/2 plans verified), Phase 48 (5/5 plans verified with 3 gap closure waves). Human sign-off on WQX Review modal and confidence display approved 2026-05-08.

---

## v2.1 WQX Parameter Harmonization (Shipped: 2026-05-06)

**Phases completed:** 4 phases (43-46), 7 plans
**Lines changed:** +1,303 / -39 across 14 R/test files
**Requirements:** 11/11 satisfied (DICT-01/02/03, MATCH-01/02/03/04, INTG-01/02/03/04)
**Timeline:** 8 days (2026-04-29 → 2026-05-06)

**Key accomplishments:**

- WQX dictionary loader with EPA Characteristic + Alias CSV download, combined 124K-row RDS cache, and lazy-load pattern matching existing reference cache architecture
- Three-tier WQX name matcher: exact canonical (O(1) hash), alias crosswalk (synonym/standardize/retired), Jaro-Winkler fuzzy fallback with configurable threshold
- Pipeline integration: WQX matching fires automatically as Tier 3b after CompTox for unresolved names, wired into both Shiny and headless paths without new arguments
- Consensus classification extended with "wqx" status, WQX-aware value box counting, resolution rendering with canonical name + teal badges, and tier-specific match type labels
- Bug fix: dedup priority in map_results_to_rows now prefers resolved rows over NA-dtxsid exact misses (caught during UAT with sswqs.xlsx wild dataset)

**Known gaps:**

- Phase 47 (stale test fixes from Phases 37-41) deferred — tracked as bean `concert-mtpo`

**UAT:** All 4 phases verified (43: 7/7, 44: 9/9, 45: 9/9, 46: 4/4). Human sign-off on match quality and UI display approved 2026-05-06.

---

## v2.0 Pipeline Performance & Date/Media Harmonization (Shipped: 2026-04-29)

**Phases completed:** 6 phases, 20 plans
**Lines changed:** +6,209 / -756 across 32 R/data files
**Requirements:** 35/35 satisfied (PERF-01/02/03/04, SKIP-01/02/03, BENCH-01/02/03, DUR-01/02/03/04/05, DATE-01/02/03/04/05/06, MEDIA-01/02/03/04/05/06, AMOS-01/02/03, RECO-01/02, MEDIT-01/02/03)
**Timeline:** 5 days (2026-04-24 → 2026-04-28)

**Key accomplishments:**

- Distinct-string dedup architecture (`dedup_step()` + `remap_audit_to_parent()`) with short-circuit pre-checks for 5x+ cleaning pipeline speedup at 100K rows
- Benchmark harness with `bench::press()` grid (1K/10K/100K rows), `use_dedup` toggle for before/after comparison on both cleaning and harmonization paths
- Duration conversion engine with hours as base unit, 23 conversion + 34 synonym entries, "m" ambiguity flagging, and ToxVal `study_duration_value`/`study_duration_units` wiring
- Multi-format date parser (`parse_dates()`) handling ISO/MDY/DMY/SAS/YYYYMMDD/year-only/2-digit-year with day≤12 ambiguity detection, wired to ToxVal `original_year`
- ENVO-based media harmonizer with AMOS pipeline enrichment (26 curated + 7 AMOS-derived terms), compound media resolution, and ppb/ppm routing loop closure
- Unified "Run Pipeline" button with pre-flight modal (fire/skip indicators), media classification editor with unmatched term surfacing, and progress indicators

**Known gaps accepted:**

- Benchmark results template (`docs/benchmark_results.md`) contains placeholders — needs real 100K data run to populate
- No formal milestone audit run

---

## v1.8 R Package Migration (Shipped: 2026-04-14)

**Phases completed:** 5 phases, 5 plans
**Lines of code:** ~9,700 LOC R in R/ and inst/app/; 72 exported functions
**Requirements:** 20/20 satisfied (PKG-01/02/03, SRC-01/02/03/04, APP-01/02/03/04/05, HDL-01/02/03/04, TST-01/02/03/04)
**Timeline:** 1 day (2026-04-13 → 2026-04-14)

**Key accomplishments:**

- DESCRIPTION/NAMESPACE/LICENSE scaffolding with `devtools::install()` and `library(concert)` fully working
- Zero bare `library()` calls in R/*.R source files; `devtools::check()` passes with 0 errors
- Shiny app relocated to `inst/app/app.R` with `concert::run_app()` launcher function
- Reference cache relocated to `inst/extdata/reference_cache/` with `system.file()` access
- `curate_headless(input, output, tag_map)` exported function wires entire pipeline for scripting without Shiny UI
- Test suite migrated to standard `tests/testthat/` structure; `devtools::test()` passes with 953 tests (0 failures, 0 errors)

**Known tech debt accepted:**

- `^tests$` in `.Rbuildignore` blocks R CMD check from running tests (devtools::test() works but devtools::check() runs 0 tests)
- `R/archive/prototype_pipeline.R` has bare library() calls and is not excluded from build

---

## v1.7 UI Polish & Isotope Cleaning (Shipped: 2026-04-13)

**Phases completed:** 2 phases, 3 plans
**Lines changed:** +1,081 / -21 across 7 R files (code); +3,612 / -231 across 25 files total (including docs/tests)
**Requirements:** 8/8 satisfied (UIPOL-01/02/03, ISOT-01/02/03, CHIR-01, MANA-01)
**Timeline:** 13 days (2026-03-31 → 2026-04-13)

**Key accomplishments:**

- Column headers in Review Results now wrap to full text instead of truncating with ellipsis (`wrap=TRUE` in reactable)
- `renderWidget` console warning eliminated by removing redundant `elementId` from reactable call
- `jsonlite` 2.0.0 named vector deprecation warning fixed with `unname(unlist())` pattern at DTXSID validation path
- Isotope shortcode expansion added to cleaning pipeline — `u234` → `Uranium-234` using ComptoxR isotope list with greedy element matching
- Chiral designation protection (`(+)`, `(-)`, `(R)`, `(S)`, `(dl)` etc.) prevents enclosure stripping from destroying chiral markers; content-encoded placeholder scheme enables stateless restore before curation
- Multi-analyte expression flagging (naked `+`/`and` between analytes) added as WARNING without auto-splitting

---

## v1.6 Cleaning Ruleset Fixes (Shipped: 2026-03-20)

**Phases completed:** 3 phases, 3 plans, 6 tasks
**Lines changed:** +1,691 / -73 across 19 files
**Requirements:** 7/7 satisfied (SPLIT-01/02, ROMAN-01/02, UNIC-01/02/03)
**Timeline:** 2 days (2026-03-19 → 2026-03-20)

**Key accomplishments:**

- Multi-locant IUPAC comma protection via repeat-until-stable loop in `split_synonyms()` — fixes 2,4,6-trichlorophenol and longer chains
- Roman numeral oxidation state protection (`ROMAN_NUMERAL_PATTERN` + `has_roman` gating) in both paren and bracket enclosure stripping paths
- Unicode cleaning test alignment with current ComptoxR format — all dot-notation assertions corrected to plain text, prime symbol coverage added

---

## v1.5 Disagreement Enrichment (Shipped: 2026-03-13)

**Phases completed:** 2 phases, 2 plans, 5 tasks
**Lines of code:** +822 across 7 R files
**Requirements:** 11/11 satisfied (ENRCH, COMP, COMPAT)
**Timeline:** 2 days (2026-03-10 → 2026-03-12)

**Key accomplishments:**

- CompTox enrichment pipeline with CASRN, molecular formula, and molecular weight via `ct_chemical_detail` with incremental caching
- Source column attribution and search tier labels per candidate (Exact/CAS/Starts-with/No match)
- Rich comparison modal replacing dropdown for disagree row resolution — card layout with enriched metadata
- Two-step resolution pattern (Select + Confirm) preventing accidental clicks, with Skip and Change options
- Consensus enrichment columns in 7-sheet Excel export (consensus_casrn, consensus_formula, consensus_mw)

---

## v1.4 Cleaning Pipeline Fixes (Shipped: 2026-03-10)

**Phases completed:** 1 phases, 2 plans, 4 tasks

**Key accomplishments:**

- (none recorded)

---

## v1.3 Data Cleaning Pipeline (Shipped: 2026-03-10)

**Phases completed:** 7 phases, 15 plans, 16 tasks
**Lines of code:** 14,548 across 18 R files (97 files changed, +25,372 / -3,880)
**Requirements:** 30/30 satisfied (MODL, INFRA, CAS, NAME, FILT, UIUX, EXPO, POST)
**Timeline:** 7 days (2026-03-04 → 2026-03-10)

**Key accomplishments:**

- Extracted 7 Shiny modules from monolithic app.R (2,276 → 203 lines) with full backward compatibility
- Built 12-step cleaning pipeline: unicode normalization, CAS rescue/validation/multi-CAS split, IUPAC-aware name cleaning with synonym splitting, reference-based flagging
- Provenance-tracked reference lists (ComptoxR-seeded + user-editable) with blocking/warning flag system and re-run cascade
- 7-sheet Excel export carrying curated data, audit trail, reference lists, and pipeline config with re-import detection
- Post-curation QC with ComptoxR's 157 chemistry-specific unicode mappings and auto-run on curation complete
- Value box dashboard, step-by-step progress indicator, and audit trail accordion for full cleaning pipeline visibility

**UAT:** All phases verified (7/7 VERIFICATION.md passed)

---

## v1.0 Curation UI Iteration (Shipped: 2026-02-27)

**Phases completed:** 2 phases, 2 plans, 0 tasks

**Key accomplishments:**

- Split single Curation tab into 3 top-level tabs: Tag Columns, Run Curation, Review Results
- Full-width layouts replacing nested card containers (navset_underline)
- Gated tab visibility — tabs appear only when workflow prerequisites are met
- Cascade reset on re-upload (confirmation modal) and tag changes
- CSS pulse animation on newly unlocked tabs
- Auto-switch to Review Results after curation completes

---

## v1.1 Curation Process Update (Shipped: 2026-03-01)

**Phases completed:** 3 phases, 6 plans, 10 tasks
**Lines of code:** 3,612 across 6 R files
**Requirements:** 15/15 satisfied (PROTO, DEDUP, CURE, CONS, INTG)

**Key accomplishments:**

- TDD-built pipeline with 6 modular functions: dedup tagged columns, tiered CompTox search (exact/starts-with/CAS), and result mapping
- Pipeline validated against sample_messy.csv (4 rows) and uncurated_chemicals (100 rows, 75 unique names, 49 unique CAS)
- Consensus classification with 5 status labels (agree/agree_caveat/disagree/single/error) and QC tier scoring
- Per-row override and en masse priority chain resolution with pinning protection
- Self-contained R/curation.R with Shiny orchestrator, dedup preview, and step-by-step progress tracking
- Review Results UI with consensus value boxes, color-coded table rows, resolution dropdowns, and full audit trail export

**UAT:** 12/12 tests passed

---

## v1.2 Curation Refinement (Shipped: 2026-03-03)

**Phases completed:** 3 phases, 6 plans, 7 tasks
**Lines of code:** 4,109 across 5 R files
**Requirements:** 12/12 satisfied (SRCH, RECV, UIPX)

**Key accomplishments:**

- Reordered search tiers (exact → CAS → starts-with) with 3-char minimum filter for improved precision
- "Other" tagged columns participate in full curation chain and consensus voting
- Column visibility tiers, color-coded badges, and enhanced resolution dropdowns with preferredName context
- Manual DTXSID entry with inline editing, queue system, and bulk CompTox validation
- Error row retry workflow: filter → select → re-tag → re-curate → merge-back with pin preservation
- Unresolvable status tracking and comprehensive Excel export with needs_review flagging

**UAT:** 10/10 tests passed

---
