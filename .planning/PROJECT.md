# ChemReg

## What This Is

A Shiny application and R package for curating chemical regulatory and benchmark data. Originally built for inventory curation (compound identification via DTXSID consensus), ChemReg is expanding to handle benchmark/regulatory datasets with numeric criteria, units, and exposure metadata. Users upload messy CSV/XLSX files, the app detects frontmatter, cleans chemical identifiers, harmonizes numeric values and units, and exports toxval-schema-compatible datasets for integration with local toxicological databases.

## Core Value

Users can go from messy regulatory/benchmark data files to validated, harmonized, toxval-compatible datasets in one workflow — upload, detect, clean, tag columns, curate compounds, harmonize values/units, resolve conflicts, export.

## Requirements

### Validated

- ✓ File upload with CSV/XLSX support (50MB limit) — existing
- ✓ Intelligent frontmatter detection via 3-algorithm ensemble — existing
- ✓ Manual header row override — existing
- ✓ Data preview with column filtering and summary statistics — existing
- ✓ Detection info display with method comparison — existing
- ✓ Raw data preview — existing
- ✓ Column selection via sidebar checkboxes — existing
- ✓ Column tagging (Chemical Name, CASRN, Other) — existing
- ✓ CAS number validation via ComptoxR — existing
- ✓ Chemical name lookup via CompTox API — existing
- ✓ Curation results display with match statistics — existing
- ✓ Excel export with curated data, report, and column tags — existing
- ✓ 3 separate top-level curation tabs (Tag Columns, Run Curation, Review Results) — v1.0
- ✓ Gated tab access enforcing linear workflow — v1.0
- ✓ Full-width tab layouts without nested cards — v1.0
- ✓ Dropdown-per-column tagging with table layout — v1.0
- ✓ Deduplication of tagged column values before API calls — v1.1
- ✓ Tiered curation search (exact → starts-with) via CompToxR — v1.1
- ✓ Healing workflow for unmatched chemicals (escalating search strategies) — v1.1
- ✓ DTXSID-based consensus across tagged columns per row — v1.1
- ✓ User resolution UI for disagreements (per-row or en masse column preference) — v1.1
- ✓ Standalone prototype script before Shiny integration — v1.1
- ✓ Reorder search chain: exact → CAS → starts-with — v1.2
- ✓ "Other" tagged columns searched against CompTox (full chain, consensus) — v1.2
- ✓ Match Type column and search tier notification — v1.2
- ✓ Untagged columns hidden from Review Results UI — v1.2
- ✓ Column visibility toggle via colvis button — v1.2
- ✓ Richer resolution dropdown (preferredName, rank, QC level) — v1.2
- ✓ Manual DTXSID entry with bulk validation — v1.2
- ✓ Error row retry: filter → re-tag → re-curate → merge-back — v1.2
- ✓ Unresolvable status and Excel export needs_review flagging — v1.2
- ✓ Shiny modules for all tabs (app.R orchestration-only) — v1.3 Phase 9
- ✓ Per-row audit trail for all cleaning transformations — v1.3 Phase 10
- ✓ Reference list loaders with ComptoxR seeding and local RDS caching — v1.3 Phase 10
- ✓ Unicode-to-ASCII cleaning via ComptoxR::clean_unicode (157 chemistry mappings) — v1.3 Phase 10/15
- ✓ Clean Data tab with gated workflow between Data Preview and Tag Columns — v1.3 Phase 10
- ✓ CAS placeholder detection, normalization, rescue from names, multi-CAS flagging — v1.3 Phase 11
- ✓ Value box dashboard and step-by-step progress for cleaning pipeline — v1.3 Phase 11
- ✓ Name cleaning: parenthetical stripping, synonym splitting with IUPAC protection, quality adjective removal — v1.3 Phase 12
- ✓ Provenance-tracked reference lists with blocking/warning flag system — v1.3 Phase 13
- ✓ In-app reference list editors with re-run cascade — v1.3 Phase 13
- ✓ 7-sheet Excel export with audit trail, reference lists, and pipeline config — v1.3 Phase 14
- ✓ Re-import detection with selective config restore — v1.3 Phase 14
- ✓ Post-curation QC: unicode detection and CAS re-validation — v1.3 Phase 15
- ✓ Bare formula detection with heuristic pre-checks (consecutive lowercase, abbreviation filter) — v1.4
- ✓ Whole-word stop word matching via word boundaries — v1.4
- ✓ Letter-comma-letter IUPAC pattern protection in synonym splitting — v1.4
- ✓ End-to-end validation test suite for cleaning pipeline fixes (42 assertions) — v1.4
- ✓ Multi-locant IUPAC comma protection in synonym splitter (3+ locants via repeat-until-stable loop) — v1.6 Phase 19
- ✓ Roman numeral oxidation state protection in enclosure stripping (I-XII, case-insensitive, paren+bracket paths) — v1.6 Phase 20
- ✓ Unicode cleaning test alignment with current ComptoxR format (α→alpha, ′→apostrophe, no dot-notation) — v1.6 Phase 21
- ✓ Enrichment of disagreement candidates with CASRN, molecular formula, molecular weight via CompTox API — v1.5
- ✓ Side-by-side comparison modal for disagreement resolution — v1.5
- ✓ Source column and search tier attribution per candidate — v1.5
- ✓ Export enrichment metadata (consensus_casrn, consensus_formula, consensus_mw) — v1.5

- ✓ Column title wrapping in Review Results DT table — v1.7 Phase 22
- ✓ Fix renderWidget explicit widget ID warning — v1.7 Phase 22
- ✓ Fix jsonlite named vector deprecation warning — v1.7 Phase 22
- ✓ Isotope shortcode expansion (u234→Uranium-234) using ComptoxR isotope list with greedy matching — v1.7 Phase 23
- ✓ Chiral designation protection via placeholder pattern, WARNING flagging — v1.7 Phase 23
- ✓ Multi-analyte expression flagging (naked +/and) without auto-splitting — v1.7 Phase 23
- ✓ Shiny app relocated to inst/app/app.R with run_app() launcher — v1.8 Phase 26
- ✓ Reference cache relocated to inst/extdata/reference_cache/ with system.file() access — v1.8 Phase 26
- ✓ 16 module functions exported to NAMESPACE — v1.8 Phase 26
- ✓ DESCRIPTION + NAMESPACE scaffolding with devtools::install() + library(chemreg) working — v1.8 Phase 24
- ✓ Zero bare library() calls in R/*.R source files, devtools::check() passes — v1.8 Phase 25
- ✓ curate_headless() exported for scripting the full pipeline without Shiny UI — v1.8 Phase 27
- ✓ tests/testthat/ standard structure with 953 passing tests — v1.8 Phase 28
- ✓ Static unit conversion table (151 rows, 6-column schema from ECOTOX/SSWQS) — v1.9 Phase 29
- ✓ ToxVal 56-column schema manifest with typed NAs — v1.9 Phase 29
- ✓ Numeric result parser (scientific notation, ranges, qualifiers, Fortran exponents) — v1.9 Phase 30
- ✓ Unit harmonization engine with units package, domain registrations, context-aware conversions — v1.9 Phases 31/31.5
- ✓ Molarity conversion (MW-dependent) and ppb/ppm media routing (aqueous/solid/air) — v1.9 Phase 31.5
- ✓ ToxVal schema mapper with 19 audit columns (*_original) and source_hash — v1.9 Phase 32
- ✓ Extended column tagging UI with numeric/study optgroups and independent cascade resets — v1.9 Phase 33
- ✓ Harmonize tab module with pipeline execution, QC dashboard, and editor UIs — v1.9 Phase 34
- ✓ Parquet/CSV export, Sheet 8 ToxVal Output, curate_headless(harmonize=TRUE) — v1.9 Phase 35
- ✓ ToxVal schema wired into Shiny interactive path — v1.9 Phase 36

## Current State

**Shipped:** v1.9 Number and Unit Coercion Harmonization (2026-04-17)

ChemReg is a proper R package with full compound curation + numeric/unit harmonization + ToxVal schema output. Installed via `devtools::install()`, used interactively via `chemreg::run_app()` or headlessly via `chemreg::curate_headless()`.

**Package capabilities:**
- `library(chemreg)` loads 72+ exported functions
- `chemreg::run_app()` launches the Shiny app from `inst/app/`
- `chemreg::curate_headless(input, output, tag_map, harmonize=TRUE)` runs full pipeline including harmonization
- Numeric result parsing: scientific notation, ranges, qualifiers, Fortran exponents
- Unit harmonization via `units` package with domain registrations, molarity/ppb context routing
- ToxVal 56-column schema mapper with 19 audit columns and source_hash
- Parquet/CSV export alongside 8-sheet Excel export
- `devtools::test()` passes with 1643+ tests
- `use_dedup` toggle on `run_cleaning_pipeline()` and `harmonize_units()` for benchmark comparison

**Known tech debt:**
- `^tests$` in `.Rbuildignore` blocks R CMD check from running tests (critical — devtools::test() works but devtools::check() runs 0 tests)
- `R/archive/prototype_pipeline.R` has bare library() calls and is not excluded from build
- Pipeline performance degrades at 100K+ rows — cleaning and harmonization both affected
- Benchmark results template (`docs/benchmark_results.md`) contains placeholders — needs real data run to populate

## Current Milestone: v2.0 Pipeline Performance & Date/Media Harmonization

**Goal:** Make the cleaning+harmonization pipeline production-fast at 100K+ rows via distinct-string dedup and short-circuit evaluation, then extend harmonization coverage to date/duration parsing and environmental media classification.

**Target features:**
- Distinct-string dedup architecture for cleaning and harmonization pipelines
- Short-circuit evaluation with per-step checkers and recommendation modal
- Performance benchmark harness for 100K training set validation
- Date/study date parsing into structured date values
- Duration conversion lifting ECOTOX pattern (hours as base unit)
- Media/matrix harmonization with extensible source maps and editor UI
- AMOS media ontology pipeline (~7,500 methods via ComptoxR::chemi_amos_method_pagination())

**Key context:**
- Speed is first priority — architecture change before new features
- At 100K rows, current pipeline is unacceptably slow even with vectorization
- Dedup pattern: extract distinct strings → process uniques → remap to parent dataset
- Duration conversion table exists in ComptoxR ECOTOX builder (section 12 of ecotox.R)
- AMOS methods have messy descriptions requiring ontology extraction, not just lookup
- WQX parameter mapping deferred to its own milestone

### Out of Scope

- Drag-and-drop column tagging — decided against, keeping dropdowns simple
- Wizard-style navigation with Next/Back buttons — tabs preferred
- Sub-tabs within a curation section — top-level tabs chosen
- Auto-advance to next tab — disorienting, users should control navigation
- Session persistence across browser refresh — high complexity, defer to future
- Contains search tier — too fuzzy, may produce unreliable matches
- CompToxR wrapper functions — CompToxR functions already vectorized, call directly
- Drag-and-drop pipeline builder — high complexity, low ROI; fixed pipeline with reference list editing is sufficient
- Real-time cleaning as-you-type — confusing UX; explicit "Run Cleaning" button preferred
- AI/ML-powered cleaning — opaque audit trail, chemical names too domain-specific
- Cell-by-cell manual editing in cleaning tab — doesn't scale; batch operations preferred

## Context

Shipped v1.9 Number and Unit Coercion Harmonization. ~17,900 LOC R across `R/`, `inst/app/`, and `tests/testthat/`.
Tech stack: R/Shiny, bslib, shinyjs, ComptoxR, DT, rio/readxl, writexl, rhandsontable, arrow, units, digest.

The app has 9 top-level tabs: Data Preview, Detection Info, Raw Data, Clean Data, Tag Columns, Run Curation, Review Results, Harmonize, plus sidebar upload and config import. On startup only Upload is visible; tabs appear progressively as the user advances.

Key files:
- `inst/app/app.R` — orchestration-only UI/server
- `R/run_app.R` — exported launcher function `chemreg::run_app()`
- `R/curate_headless.R` — headless pipeline entry point `curate_headless()`
- `R/mod_*.R` — 9 Shiny modules with @export tags (including mod_harmonize.R)
- `R/curation.R` — curation pipeline orchestrator with enrichment
- `R/consensus.R` — consensus classification, resolution, and enrichment
- `R/cleaning_pipeline.R` — 15-step pre-curation cleaning pipeline
- `R/cleaning_reference.R` — reference list loaders with provenance tracking
- `R/numeric_parser.R` — numeric result parsing (sci notation, ranges, qualifiers, Fortran)
- `R/unit_harmonization.R` — unit harmonization with units package + context-aware conversions
- `R/toxval_schema.R` — 56-column ToxVal schema mapper with audit columns
- `R/tag_dispatch.R` — tag classification and cascade reset helpers
- `inst/extdata/reference_cache/` — RDS files for reference lists
- `inst/extdata/unit_table.csv` — unit conversion table (151 rows)
- `tests/testthat/` — test suite with 953+ passing tests

## Constraints

- **Tech stack**: R/Shiny with bslib, must stay within existing package ecosystem
- **No new dependencies**: Use existing bslib tab/navigation primitives (openxlsx2 and rhandsontable added in v1.3)
- **Backward compatible**: Upload → detection → preview flow must remain untouched
- **API key**: ComptoxR requires `ctx_api_key` environment variable

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Top-level tabs over sub-tabs | More visible workflow steps, consistent with existing tab pattern | ✓ Good |
| Gated flow over free access | Enforces correct order, prevents confusion from empty states | ✓ Good |
| Dropdown tagging over drag-and-drop | Simplest, familiar, minimal implementation effort | ✓ Good |
| nav_panel + session$onFlushed hide | nav_panel_hidden lacks title param; startup hide preserves titles | ✓ Good |
| Cascade reset on tag changes | Strict invalidation prevents stale curation results | ✓ Good |
| Confirmation modal on re-upload | Prevents accidental data loss; easyClose=FALSE forces explicit choice | ✓ Good |
| Prototype script before Shiny integration | Prove pipeline logic works in isolation before wiring into reactive app | ✓ Good — v1.1 |
| Tiered search (exact → CAS → starts-with) | Maximizes match rate while keeping exact matches highest confidence | ✓ Good — v1.1/v1.2 |
| DTXSID as consensus key | Universal identifier from CompTox; most reliable cross-column comparison | ✓ Good — v1.1 |
| DT escape=FALSE + JS Shiny.setInputValue | Reliable modal buttons and inline interactive controls | ✓ Good — v1.2 |
| Modularization before cleaning pipeline | Prevented app.R from crossing 3,000 lines | ✓ Good — v1.3 |
| INTERLEAVED phase structure | Pipeline + UI built together per phase, not separated | ✓ Good — v1.3 |
| ComptoxR direct usage | as_cas, extract_cas, clean_unicode used directly — no custom implementations | ✓ Good — v1.3 |
| WIDE data shape for CAS operations | New columns not new rows; validated against EPA production scripts | ✓ Good — v1.3 |
| IUPAC comma protection via placeholders | @@@/%%% placeholders protect digit-comma-digit and inverted names during synonym split | ✓ Good — v1.3 |
| Two-pass enclosure stripping | Text cleaning exposes previously non-terminal enclosures; second pass catches them | ✓ Good — v1.3 |
| Provenance-tracked reference lists | (term, source, active) tibble format with soft delete and import merge | ✓ Good — v1.3 |
| Blocking vs warning flag taxonomy | Red blocking flags prevent curation; yellow warnings annotate only | ✓ Good — v1.3 |
| 7-sheet Excel export | Data + audit + refs + config in one file serves as both audit doc and re-entry point | ✓ Good — v1.3 |
| Post-curation QC advisory-only | QC warnings don't gate export; user decides what to act on | ✓ Good — v1.3 |
| icon() wrapper for actionButton icons | bsicons::bs_icon() fails Shiny's validateIcon(); icon() wrapper works | ✓ Good — v1.3 |
| Consecutive-lowercase heuristic for formula detection | Filters obvious non-formulas before regex; more maintainable than perfecting regex | ✓ Good — v1.4 |
| Word boundary matching for stop words | `\b` wrapping prevents substring false positives; simple and performant | ✓ Good — v1.4 |
| Reuse @@@ placeholder for letter-comma-letter | Consistent with existing digit-comma-digit protection; same restore logic | ✓ Good — v1.4 |
| Incremental enrichment caching with structured tibble | Avoids redundant API calls; dtxsid→(casrn, formula, mw) tibble is clean and joins easily | ✓ Good — v1.5 |
| Enrich all DTXSIDs not just disagree | Comprehensive export coverage; agree/single rows get enrichment too | ✓ Good — v1.5 |
| Compare button + modal over richer dropdown | Modal gives space for tabular metadata; dropdowns get too wide | ✓ Good — v1.5 |
| Two-step Select + Confirm resolution | Prevents accidental resolution; progressive disclosure pattern | ✓ Good — v1.5 |
| Repeat-until-stable loop for locant comma protection | Single-pass regex can't protect all commas in 3+ locant chains; loop converges in 1 pass for simple cases | ✓ Good — v1.6 |
| Module-level ROMAN_NUMERAL_PATTERN constant | Anchored regex (I-XII) shared by both paren and bracket paths; avoids duplication | ✓ Good — v1.6 |
| Test alignment over pipeline changes for unicode | ComptoxR already handles α and ′ correctly; only tests needed updating | ✓ Good — v1.6 |
| elementId removal from reactable is safe | session$ns("curation_table") produces same string Shiny auto-assigns; Reactable.setFilter calls unaffected | ✓ Good — v1.7 |
| unname(unlist()) before Shiny output bindings | Prevents jsonlite 2.0.0 named vector deprecation warning from unlist() in reactive context | ✓ Good — v1.7 |
| Content-encoded chiral placeholders (###CHIRAL_PLUS###) | Enables stateless restore without row-index tracking — survives synonym split row reordering | ✓ Good — v1.7 |
| Greedy isotope matching (sort by symbol length desc) | Ensures Pb matched before P when element symbols share prefix | ✓ Good — v1.7 |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-25 — Phase 38 Benchmark Harness complete (use_dedup toggle wired)*
