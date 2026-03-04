# Phase 9: Modularization - Context

**Gathered:** 2026-03-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Extract all 6 existing tabs into Shiny modules and reduce app.R to orchestration-only code. File upload and sidebar controls also become a module. No new features — purely structural refactor. All existing functionality must work identically after extraction.

</domain>

<decisions>
## Implementation Decisions

### Module Communication
- Follow Serapeum pattern: shared store via reactive args + module return values for cross-module communication
- Pass the whole `data_store` reactiveValues object to modules that need it — don't break into individual reactives
- Modules return reactive lists/functions that app.R wires together
- Pass navigation callbacks as plain functions (not global state awareness)
- Rely on direct `data_store` reactivity for cross-module refresh — no explicit trigger reactiveVals needed

### File Organization
- Modules live in `R/modules/` subfolder (separate from utility files in `R/`)
- One file per module containing both `mod_X_ui()` and `mod_X_server()` (e.g., `R/modules/mod_data_preview.R`)
- `mod_` prefix on all module function names
- Auto-source all R files recursively: `for (f in list.files("R", recursive = TRUE, pattern = "\\.R$", full.names = TRUE)) source(f)`

### State Management
- Keep `data_store` as a single `reactiveValues` object, pass whole object to modules
- File upload + sidebar detection controls become their own module (`mod_file_upload.R`), not inline in app.R
- Upload module returns results that app.R writes to `data_store`
- Keep bslib `navset_tab` for tab switching — no dynamic renderUI rewrite

### Migration Strategy
- Extract all 6 tabs + upload in one coordinated pass (not incremental)
- All tabs treated equally regardless of when added (v1.0 and v1.2 tabs alike)
- Verification: module render tests (testServer or shinytest2) + manual cold start of app
- Existing test suite must still pass without modification

### Claude's Discretion
- Exact module boundaries (which helpers each module internalizes vs shares)
- testServer() vs shinytest2 for module render tests
- Internal structure within each module file
- How to handle any edge cases in the upload/detection flow during extraction

</decisions>

<specifics>
## Specific Ideas

- Follow Serapeum's module patterns exactly: shared store via reactive args, module return values, navigation callbacks as functions, auto-sourcing
- Upload module should own the sidebar UI (fileInput + detection mode toggle + manual row input)
- App.R should be truly minimal — theme setup, module calls, wiring return values, and `data_store` creation

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 09-modularization*
*Context gathered: 2026-03-04*
