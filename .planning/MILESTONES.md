# Milestones

## v1.8 R Package Migration (Shipped: 2026-04-14)

**Phases completed:** 5 phases, 5 plans
**Lines of code:** ~9,700 LOC R in R/ and inst/app/; 72 exported functions
**Requirements:** 20/20 satisfied (PKG-01/02/03, SRC-01/02/03/04, APP-01/02/03/04/05, HDL-01/02/03/04, TST-01/02/03/04)
**Timeline:** 1 day (2026-04-13 → 2026-04-14)

**Key accomplishments:**

- DESCRIPTION/NAMESPACE/LICENSE scaffolding with `devtools::install()` and `library(chemreg)` fully working
- Zero bare `library()` calls in R/*.R source files; `devtools::check()` passes with 0 errors
- Shiny app relocated to `inst/app/app.R` with `chemreg::run_app()` launcher function
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
