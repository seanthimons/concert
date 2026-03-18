# ChemReg

## What This Is

A Shiny application for uploading, cleaning, and validating chemical inventory data with intelligent frontmatter detection, a 12-step pre-curation cleaning pipeline, DTXSID-based consensus curation, and post-curation QC. Users upload messy CSV/XLSX files, the app detects where actual data begins, cleans CAS numbers and chemical names, flags reference matches, then curates chemical identifiers against EPA's CompTox Dashboard via tiered search. Results are classified by consensus with per-row conflict resolution, exported as 7-sheet audit workbooks, and can be re-imported to restore state.

## Core Value

Users can go from a messy chemical inventory file to validated, curated chemical data in one workflow — upload, detect, clean, tag, curate, resolve, export.

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
- ✓ Enrichment of disagreement candidates with CASRN, molecular formula, molecular weight via CompTox API — v1.5
- ✓ Side-by-side comparison modal for disagreement resolution — v1.5
- ✓ Source column and search tier attribution per candidate — v1.5
- ✓ Export enrichment metadata (consensus_casrn, consensus_formula, consensus_mw) — v1.5

### Active

## Current Milestone: v1.6 Cleaning Ruleset Fixes

**Goal:** Fix cleaning pipeline bugs and unicode coverage gaps discovered during live dataset roadtesting.

**Target features:**
- Fix multi-locant comma protection in synonym splitter (2,4,6- patterns)
- Investigate and fix roman numeral → formula column misrouting (chromium iii/vi)
- Fix unicode cleaning coverage (ensure α and ′ are caught, align tests with current ComptoxR mappings)
- Extensible — add phases as roadtesting surfaces more issues

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

Shipped v1.5 Disagreement Enrichment with ~15,750 LOC R across 18 files.
Tech stack: R/Shiny, bslib, shinyjs, ComptoxR, DT, rio/readxl, openxlsx2, rhandsontable.

The app has 8 top-level tabs: Data Preview, Detection Info, Raw Data, Clean Data, Tag Columns, Run Curation, Review Results, plus sidebar upload and config import. On startup only Upload is visible; tabs appear progressively as the user advances.

Key files:
- `app.R` — orchestration-only UI/server (207 lines)
- `R/modules/` — 8 Shiny modules (mod_upload, mod_data_preview, mod_detection_info, mod_raw_data, mod_clean_data, mod_tag_columns, mod_run_curation, mod_review_results)
- `R/curation.R` — curation pipeline orchestrator with enrichment (~1,020 lines)
- `R/consensus.R` — consensus classification, resolution, and enrichment (320+ lines)
- `R/cleaning_pipeline.R` — 12-step pre-curation cleaning pipeline
- `R/cleaning_reference.R` — reference list loaders with provenance tracking
- `R/file_handlers.R` — file reading/validation (218 lines)
- `R/data_detection.R` — frontmatter detection algorithms (405 lines)

Known tech debt: None actively tracked — v1.5 resolved prior dropdown/visibility concerns with the comparison modal.

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

---
*Last updated: 2026-03-18 after v1.6 milestone start*
