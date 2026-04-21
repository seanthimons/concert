# Phase 36: Wire ToxVal Schema in Shiny Path - Context

**Gathered:** 2026-04-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire `map_to_toxval_schema()` into the Shiny interactive harmonization path so `data_store$toxval_output` is populated and Sheet 8 "ToxVal Output" in the Excel export shows real data. Also gate the Harmonize tab behind curation completion, close SCHM-01/SCHM-04/UITG-06 requirements.

**Scope:**
1. Call `map_to_toxval_schema()` at the end of the Run Harmonization pipeline in `mod_harmonize.R`
2. Write result to `data_store$toxval_output` so `build_export_sheets()` receives real data
3. Gate Harmonize tab behind both numeric tags AND curation completion
4. Mark SCHM-04 complete with note (arrow is hard dep, CSV is format choice not fallback)
5. Close SCHM-01 (toxval schema transmutation now wired E2E) and UITG-06 (Sheet 8 shows real data)

**Not in scope:**
- Modifying `map_to_toxval_schema()` function itself (Phase 32, complete)
- Modifying `build_export_sheets()` Sheet 8 logic (Phase 35, complete)
- Modifying `curate_headless()` (Phase 35, already wires mapper)

</domain>

<decisions>
## Implementation Decisions

### Mapper Call Placement
- **D-01:** Call `map_to_toxval_schema()` inline at the end of the Run Harmonization `observeEvent` in `mod_harmonize.R`, right after `harmonize_units()` completes — matching the `curate_headless()` pattern
- **D-02:** Write result to `data_store$toxval_output` in the same pipeline run
- **D-03:** Include in `withProgress()` reporting (e.g., "Mapping to ToxVal schema...")

### Input Assembly
- **D-04:** Read `data_store$resolution_state` for curated columns (dtxsid, casrn, name) and `data_store$harmonize_results` for harmonized columns — pass both to `map_to_toxval_schema()` which handles the internal join
- **D-05:** `source_name` defaults to `data_store$file_info$name` (uploaded filename) in the Shiny path

### Tab Gating
- **D-06:** Hide Harmonize tab until BOTH `data_store$numeric_tags` AND `data_store$resolution_state` are available
- **D-07:** Change the existing `observe()` in `app.R` (line ~361-364) from `req(data_store$numeric_tags)` to `req(data_store$numeric_tags, data_store$resolution_state)`
- **D-08:** This enforces the full linear workflow: upload → detect → clean → tag → curate → harmonize

### SCHM-04 Resolution
- **D-09:** Mark SCHM-04 complete in REQUIREMENTS.md with note: "Superseded by D-02 (arrow as hard dep). CSV available as format choice, not fallback."
- **D-10:** No code changes needed for SCHM-04 — the functionality already exists from Phase 35

### Error Handling
- **D-11:** Since harmonization is gated behind curation completion (D-06), `data_store$resolution_state` is always available when the mapper runs — no need for defensive NULL checks on curation data
- **D-12:** If `map_to_toxval_schema()` throws an unexpected error, use `tryCatch()` with `showNotification()` — set `data_store$toxval_output` to NULL so Sheet 8 shows placeholder

### Claude's Discretion
- Exact position within the harmonize `observeEvent` for the mapper call
- Column selection from `resolution_state` for `curated_data` argument
- withProgress message text
- Error notification wording
- Test case selection

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Upstream Phase Context
- `.planning/phases/32-toxval-schema-mapper/32-CONTEXT.md` — `map_to_toxval_schema()` signature: `(curated_data, harmonized_data, source_name)`, 56-column schema, typed NA strategy
- `.planning/phases/34-harmonize-tab-module/34-CONTEXT.md` — `mod_harmonize.R` module structure, pipeline integration pattern, `data_store$harmonize_results` and `data_store$harmonize_audit`
- `.planning/phases/35-export-extension-headless/35-CONTEXT.md` — `build_export_sheets()` toxval_output param, Sheet 8 placeholder logic, `curate_headless()` mapper wiring (reference implementation)

### Key Source Files
- `R/mod_harmonize.R` — Target file: add `map_to_toxval_schema()` call inside Run Harmonization pipeline
- `R/toxval_mapper.R` — `map_to_toxval_schema()` function (DO NOT MODIFY — just call it)
- `R/export_helpers.R` — `build_export_sheets()` with `toxval_output` param (DO NOT MODIFY — already wired)
- `R/mod_review_results.R` line ~1456 — Already passes `data_store$toxval_output` to `build_export_sheets()`
- `R/curate_headless.R` line ~293 — Reference implementation of mapper wiring in headless path
- `inst/app/app.R` line ~361-364 — Harmonize tab show logic (needs gating change)

### Requirements
- `.planning/REQUIREMENTS.md` — SCHM-01, SCHM-04, UITG-06 definitions (Phase 36 pending items)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `map_to_toxval_schema()` in `R/toxval_mapper.R` — exported, tested, ready to call
- `build_export_sheets(toxval_output=)` in `R/export_helpers.R` — already accepts toxval_output, handles NULL with placeholder
- `data_store$toxval_output` slot — already declared in `app.R` (line ~127), already passed in `mod_review_results.R` (line ~1466)

### Established Patterns
- `withProgress()` in `mod_run_curation.R` — pipeline progress reporting
- `tryCatch()` with `showNotification()` — error handling in pipeline modules
- `data_store$*` reactive state writes at end of pipeline
- `curate_headless.R` line ~270-303 — reference implementation of mapper call with same inputs

### Integration Points
- `mod_harmonize.R` Run Harmonization `observeEvent` — add mapper call at end
- `inst/app/app.R` Harmonize tab observer — change `req()` condition
- `data_store$toxval_output` — bridge between harmonize module and export module

### Files to Modify
- `R/mod_harmonize.R` — add `map_to_toxval_schema()` call and `data_store$toxval_output` write
- `inst/app/app.R` — change Harmonize tab gating from `req(numeric_tags)` to `req(numeric_tags, resolution_state)`
- `.planning/REQUIREMENTS.md` — mark SCHM-01, SCHM-04, UITG-06 complete

</code_context>

<specifics>
## Specific Ideas

### Mapper Call Pattern (from curate_headless.R reference)
```r
# Inside Run Harmonization observeEvent, after harmonize_units():
incProgress(0.1, message = "Mapping to ToxVal schema...")
toxval_tibble <- tryCatch(
  map_to_toxval_schema(
    curated_data = data_store$resolution_state,
    harmonized_data = data_store$harmonize_results,
    source_name = data_store$file_info$name
  ),
  error = function(e) {
    showNotification(
      paste("ToxVal mapping failed:", conditionMessage(e)),
      type = "warning",
      duration = 8
    )
    NULL
  }
)
data_store$toxval_output <- toxval_tibble
```

### Tab Gating Change
```r
# In app.R, replace:
shiny::observe({
  shiny::req(data_store$numeric_tags)
  show_tab_with_pulse("harmonize_tab")
})

# With:
shiny::observe({
  shiny::req(data_store$numeric_tags, data_store$resolution_state)
  show_tab_with_pulse("harmonize_tab")
})
```

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 36-wire-toxval-shiny*
*Context gathered: 2026-04-21*
