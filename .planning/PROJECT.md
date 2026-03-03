# ChemReg

## What This Is

A Shiny application for uploading, cleaning, and validating chemical inventory data with intelligent frontmatter detection and DTXSID-based consensus curation. Users upload messy CSV/XLSX files, the app detects where actual data begins, then provides tools to tag columns and curate chemical identifiers against EPA's CompTox Dashboard via tiered search (exact, starts-with, CAS validation). Results are classified by consensus across tagged columns with per-row and en masse conflict resolution.

## Core Value

Users can go from a messy chemical inventory file to validated, curated chemical data in one workflow — upload, detect, tag, curate, resolve, export.

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

### Active

(None — next milestone requirements TBD)

### Out of Scope

- Drag-and-drop column tagging — decided against, keeping dropdowns simple
- Wizard-style navigation with Next/Back buttons — tabs preferred
- Sub-tabs within a curation section — top-level tabs chosen
- Auto-advance to next tab — disorienting, users should control navigation
- Session persistence across browser refresh — high complexity, defer to future
- Contains search tier — too fuzzy, may produce unreliable matches
- CompToxR wrapper functions — CompToxR functions already vectorized, call directly

## Context

Shipped v1.2 Curation Refinement with 4,109 LOC R across 5 files.
Tech stack: R/Shiny, bslib, shinyjs, ComptoxR, DT, rio/readxl, writexl.

The app has 6 top-level tabs: Data Preview, Detection Info, Raw Data, Tag Columns, Run Curation, Review Results. On startup only Upload (sidebar) is visible; tabs appear progressively as the user advances through the workflow.

Key files:
- `app.R` — main UI/server definition (2,275 lines)
- `R/curation.R` — self-contained pipeline orchestrator (954 lines)
- `R/consensus.R` — consensus classification and resolution functions (257 lines)
- `R/file_handlers.R` — file reading/validation (218 lines)
- `R/data_detection.R` — frontmatter detection algorithms (405 lines)

## Constraints

- **Tech stack**: R/Shiny with bslib, must stay within existing package ecosystem
- **No new dependencies**: Use existing bslib tab/navigation primitives
- **Backward compatible**: Upload → detection → preview flow must remain untouched
- **API key**: ComptoxR requires `ctx_api_key` environment variable

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Top-level tabs over sub-tabs | More visible workflow steps, consistent with existing tab pattern | ✓ Good |
| Gated flow over free access | Enforces correct order, prevents confusion from empty states | ✓ Good |
| Dropdown tagging over drag-and-drop | Simplest, familiar, minimal implementation effort | ✓ Good |
| nav_panel + session$onFlushed hide over nav_panel_hidden | nav_panel_hidden lacks title param; startup hide preserves titles | ✓ Good |
| Cascade reset on tag changes | Strict invalidation prevents stale curation results | ✓ Good |
| Confirmation modal on re-upload | Prevents accidental data loss; easyClose=FALSE forces explicit choice | ✓ Good |
| Prototype script before Shiny integration | Prove pipeline logic works in isolation before wiring into reactive app | ✓ Good — v1.1 |
| Tiered search (equal → starts-with) | Maximizes match rate while keeping exact matches highest confidence | ✓ Good — v1.1 |
| DTXSID as consensus key | Universal identifier from CompTox; most reliable cross-column comparison | ✓ Good — v1.1 |
| Migrate pipeline into R/curation.R | Self-contained module, prototype kept as historical reference | ✓ Good — v1.1 |
| withProgress() for pipeline UX | Built-in Shiny progress with per-tier callbacks | ✓ Good — v1.1 |
| DT inline select for resolution | escape=FALSE + JS callback for immediate resolution UX | ✓ Good — v1.1 |
| TDD for pipeline and consensus functions | Tests written first, ensuring reliable functions before Shiny integration | ✓ Good — v1.1 |
| Direct CompToxR calls (no wrappers) | CompToxR functions already vectorized and optimized | ✓ Good — v1.1 |
| Tier reorder: exact → CAS → starts-with | CAS validation before fuzzy search increases precision | ✓ Good — v1.2 |
| 3-char minimum on starts-with | Reduces API noise from short strings | ✓ Good — v1.2 |
| Other tags as full tier chain participants | Enables curation of arbitrary identifier columns | ✓ Good — v1.2 |
| match_type derived in app.R not curation.R | Keeps UI transformations in UI layer | ✓ Good — v1.2 |
| JS-triggered modal buttons over actionButton | Shiny actionButton in modals fails to re-register on reopen | ✓ Good — v1.2 |
| Vector indexing over dplyr joins in mapping | Prevents row duplication from many-to-many joins | ✓ Good — v1.2 |
| Unresolvable = error before AND after retry | Distinguishes first-attempt failures from exhausted retries | ✓ Good — v1.2 |
| Queue-then-validate for manual DTXSIDs | Batch API calls reduce overhead vs per-cell validation | ✓ Good — v1.2 |

---
*Last updated: 2026-03-03 after v1.2 milestone*
