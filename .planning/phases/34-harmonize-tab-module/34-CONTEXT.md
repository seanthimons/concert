# Phase 34: Harmonize Tab Module - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the Harmonize tab module that orchestrates numeric parsing and unit harmonization, plus three editor UIs for user-controlled data tables.

**Scope:**
1. Harmonize tab module following `mod_run_curation.R` pattern — button-triggered pipeline (UITG-04)
2. Pre-export QC dashboard with value boxes (UITG-05)
3. User-editable unit table UI (DATA-04)
4. One-off corrections table for source-specific malformed values (PARS-06)
5. Unmatched-unit review UI with batch actions (UNIT-06)

**Not in scope:**
- Parquet/CSV export (Phase 35)
- Headless pipeline extension (Phase 35)
- ToxVal schema mapping UI (handled by mapper function from Phase 32)

</domain>

<decisions>
## Implementation Decisions

### Module Layout
- **D-01:** Flat layout with accordions, following `mod_clean_data.R` pattern
- **D-02:** Run Harmonization button at top of tab
- **D-03:** QC value boxes appear below button after pipeline completes
- **D-04:** Three accordion panels (collapsed by default):
  - Unit Table Editor
  - Corrections Editor
  - Unmatched Units
- **D-05:** Editors expand on demand, keeping focus on pipeline results

### Editor Pattern
- **D-06:** Chip editors for ALL editable tables — no rhandsontable (bad UX per user)
- **D-07:** Unit table chips display `from_unit → to_unit` as label (e.g., "ug/L → mg/L")
- **D-08:** Click chip to expand/edit via modal showing all 6 fields (from_unit, to_unit, multiplier, category, confidence, source)
- **D-09:** "Add Unit Mapping" button opens modal form with all fields
- **D-10:** Corrections table: simple pattern → replacement chips, modal for add/edit
- **D-11:** Reuse chip editor CSS/JS from `mod_clean_data.R` where possible

### Unmatched Unit UX
- **D-12:** Batch review panel (not inline chips) for unmatched units
- **D-13:** List unmatched units with row counts (e.g., "ppb (47 rows)", "NTU (12 rows)")
- **D-14:** Bulk action: "Add All as Pass-through" for units that should remain unconverted
- **D-15:** Individual action: "Add Mapping" button per unmatched unit → opens modal pre-filled with `from_unit`
- **D-16:** After adding mappings, user re-runs harmonization to apply

### QC Dashboard
- **D-17:** Value boxes on Harmonize tab only (not separate tab)
- **D-18:** Appears after "Run Harmonization" completes
- **D-19:** Metrics to display:
  - Rows parsed (total input rows)
  - Rows harmonized (successful unit conversion)
  - Rows with DTXSID (from upstream curation)
  - Rows with NA toxval_numeric (parse failures or missing Result)
- **D-20:** Follow `mod_clean_data.R` value box pattern with `bslib::value_box()` and `bsicons::bs_icon()`

### Pipeline Integration
- **D-21:** Read `data_store$numeric_tags` from Phase 33 tag dispatch
- **D-22:** Call `parse_numeric_results()` on Result-tagged columns
- **D-23:** Call `harmonize_units()` on Unit-tagged columns with parsed values
- **D-24:** Write results to `data_store$harmonize_results` and `data_store$harmonize_audit`
- **D-25:** Use `withProgress()` for pipeline stages (matching mod_run_curation.R pattern)

### Cascade Reset
- **D-26:** Unit table or corrections table changes → reset `harmonize_results`, `harmonize_audit`
- **D-27:** Harmonization results change → reset `toxval_output` (downstream Phase 35)
- **D-28:** Store previous editor state to detect changes (compare old vs new)

### Claude's Discretion
- Exact accordion panel ordering
- Value box icons and color themes
- Modal form field layout and validation messages
- Chip badge colors for different unit categories
- Internal helper function organization

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Upstream Phase Context
- `.planning/phases/33-extended-column-tagging/33-CONTEXT.md` — Tag dispatch mechanism, `numeric_tags` subset
- `.planning/phases/32-toxval-schema-mapper/32-CONTEXT.md` — ToxVal schema, `map_to_toxval_schema()` signature
- `.planning/phases/31.5-units-package-assimilation/31.5-CONTEXT.md` — `harmonize_units()` with context-aware conversions
- `.planning/phases/30-numeric-result-parser/30-CONTEXT.md` — `parse_numeric_results()` output structure

### Pattern References
- `R/mod_run_curation.R` — Pipeline module pattern (button, withProgress, data_store writes)
- `R/mod_clean_data.R` — Chip editor pattern, accordion sections, value box dashboard

### Function Signatures
- `R/numeric_result_parser.R` — `parse_numeric_results(values)`
- `R/unit_harmonizer.R` — `harmonize_units(values, units, unit_map, media, dtxsid, molecular_weight)`
- `R/cleaning_reference.R` — `load_unit_map()` for unit table loading

### Requirements
- `.planning/REQUIREMENTS.md` — UITG-04, UITG-05, DATA-04, PARS-06, UNIT-06 definitions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Chip editor CSS/JS in `mod_clean_data.R` lines 15-57 — delegated click handlers, input bindings
- `render_chip_editor()` helper in `mod_clean_data.R` lines 529-582 — generates chip HTML
- `bslib::value_box()` pattern in `mod_clean_data.R` lines 383-487 — QC dashboard layout
- `withProgress()` pattern in `mod_run_curation.R` lines 146-276 — pipeline progress

### Established Patterns
- `data_store$*` for reactive state (existing pattern throughout app)
- Accordion panels via `bslib::accordion()` and `bslib::accordion_panel()`
- Modal dialogs via `showModal(modalDialog(...))` with form inputs
- Cascade reset via `observeEvent()` watching editor state changes

### Integration Points
- `data_store$numeric_tags` — input from Phase 33 tag dispatch
- `data_store$harmonize_results` — output consumed by Phase 35 export
- `data_store$harmonize_audit` — audit trail for export
- `inst/app/app.R` — wire new module into tab navigation

### Files to Create
- `R/mod_harmonize.R` — new module (UI + server)
- `inst/extdata/reference_cache/corrections.rds` — empty initial corrections table

### Files to Modify
- `inst/app/app.R` — add Harmonize tab, wire module
- `R/cleaning_reference.R` — add `load_corrections()` loader if needed
- `NAMESPACE` — export `mod_harmonize_ui`, `mod_harmonize_server`

</code_context>

<specifics>
## Specific Ideas

### Chip Display for Unit Mappings
```r
# Chip label: "ug/L → mg/L (×0.001)"
chip_label <- sprintf("%s → %s", row$from_unit, row$to_unit)
if (!is.na(row$multiplier)) {

chip_label <- sprintf("%s (×%s)", chip_label, row$multiplier)
}
```

### Batch Unmatched Panel Structure
```r
# Unmatched units accordion panel content
div(
  class = "mb-3",
  actionButton(ns("add_all_passthrough"), "Add All as Pass-through", class = "btn-outline-secondary btn-sm"),
  hr(),
  # List of unmatched with counts
  lapply(unmatched_summary, function(u) {
    div(
      class = "d-flex justify-content-between align-items-center mb-2",
      span(sprintf("%s (%d rows)", u$unit, u$count)),
      actionButton(ns(paste0("add_", u$id)), "Add Mapping", class = "btn-primary btn-sm")
    )
  })
)
```

### QC Value Box Layout
```r
bslib::layout_columns(
  col_widths = c(3, 3, 3, 3),
  bslib::value_box(title = "Rows Parsed", value = n_parsed, showcase = bsicons::bs_icon("123"), theme = "primary"),
  bslib::value_box(title = "Rows Harmonized", value = n_harmonized, showcase = bsicons::bs_icon("check-circle"), theme = "success"),
  bslib::value_box(title = "With DTXSID", value = n_dtxsid, showcase = bsicons::bs_icon("database"), theme = "info"),
  bslib::value_box(title = "NA Results", value = n_na, showcase = bsicons::bs_icon("exclamation-triangle"), theme = "warning")
)
```

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 34-harmonize-tab-module*
*Context gathered: 2026-04-15*
