# ChemReg

## What This Is

A Shiny application for uploading, cleaning, and validating chemical inventory data. Users upload messy CSV/XLSX files, the app detects where actual data begins (filtering out report headers and frontmatter), then provides tools to tag columns and curate chemical identifiers against EPA's CompTox Dashboard via the ComptoxR package. The workflow is guided through gated tabs that appear as prerequisites are met.

## Core Value

Users can go from a messy chemical inventory file to validated, curated chemical data in one workflow — upload, detect, tag, curate, export.

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

### Active

(No active requirements — next milestone TBD)

### Out of Scope

- Drag-and-drop column tagging — decided against, keeping dropdowns simple
- Wizard-style navigation with Next/Back buttons — tabs preferred
- Sub-tabs within a curation section — top-level tabs chosen
- Auto-advance to next tab — disorienting, users should control navigation
- Session persistence across browser refresh — high complexity, defer to future
- New tag types or curation features — deferred to future iteration
- Changes to upload, detection, or export logic — existing pipeline untouched

## Context

Shipped v1.0 Curation UI Iteration with 2,106 LOC R across 4 files.
Tech stack: R/Shiny, bslib, shinyjs, ComptoxR, DT, rio/readxl.

The app has 6 top-level tabs: Data Preview, Detection Info, Raw Data, Tag Columns, Run Curation, Review Results. On startup only Upload (sidebar) is visible; tabs appear progressively as the user advances through the workflow. Re-uploading triggers a confirmation modal; tag changes cascade-reset downstream tabs.

Key files:
- `app.R` — main UI/server definition (1,318 lines)
- `R/curation.R` — curation logic (165 lines)
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

---
*Last updated: 2026-02-27 after v1.0 milestone*
