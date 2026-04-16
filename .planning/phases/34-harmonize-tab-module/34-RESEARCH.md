# Phase 34: Harmonize Tab Module - Research

**Researched:** 2026-04-16
**Domain:** Shiny module development — R/bslib, chip editor pattern, pipeline orchestration, reactive state management
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Flat layout with accordions, following `mod_clean_data.R` pattern
- **D-02:** Run Harmonization button at top of tab
- **D-03:** QC value boxes appear below button after pipeline completes
- **D-04:** Three accordion panels (collapsed by default): Unit Table Editor, Corrections Editor, Unmatched Units
- **D-05:** Editors expand on demand, keeping focus on pipeline results
- **D-06:** Chip editors for ALL editable tables — no rhandsontable (bad UX per user)
- **D-07:** Unit table chips display `from_unit → to_unit` as label
- **D-08:** Click chip to expand/edit via modal showing all 6 fields
- **D-09:** "Add Unit Mapping" button opens modal form with all fields
- **D-10:** Corrections table: simple pattern → replacement chips, modal for add/edit
- **D-11:** Reuse chip editor CSS/JS from `mod_clean_data.R` where possible
- **D-12:** Batch review panel (not inline chips) for unmatched units
- **D-13:** List unmatched units with row counts (e.g., "ppb (47 rows)")
- **D-14:** Bulk action: "Add All as Pass-through"
- **D-15:** Individual "Add Mapping" button per unmatched unit, opens modal pre-filled
- **D-16:** After adding mappings, user re-runs harmonization to apply
- **D-17:** Value boxes on Harmonize tab only (not separate tab)
- **D-18:** Appears after "Run Harmonization" completes
- **D-19:** Metrics: Rows parsed, Rows harmonized, Rows with DTXSID, Rows with NA toxval_numeric
- **D-20:** Follow `mod_clean_data.R` value box pattern with `bslib::value_box()` and `bsicons::bs_icon()`
- **D-21:** Read `data_store$numeric_tags` from Phase 33 tag dispatch
- **D-22:** Call `parse_numeric_results()` on Result-tagged columns
- **D-23:** Call `harmonize_units()` on Unit-tagged columns with parsed values
- **D-24:** Write results to `data_store$harmonize_results` and `data_store$harmonize_audit`
- **D-25:** Use `withProgress()` for pipeline stages
- **D-26:** Unit table or corrections table changes → reset `harmonize_results`, `harmonize_audit`
- **D-27:** Harmonization results change → reset `toxval_output`
- **D-28:** Store previous editor state to detect changes

### Claude's Discretion

- Exact accordion panel ordering
- Value box icons and color themes
- Modal form field layout and validation messages
- Chip badge colors for different unit categories
- Internal helper function organization

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope. Parquet/CSV export and ToxVal schema mapping UI are Phase 35 scope.

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UITG-04 | Harmonize tab module following `mod_run_curation.R` pattern — button-triggered pipeline, `withProgress()`, write to data_store | Pipeline pattern confirmed in existing codebase; `parse_numeric_results()` and `harmonize_units()` both exported and ready |
| UITG-05 | Pre-export QC dashboard — value boxes: rows parsed, rows harmonized, rows with dtxsid, rows with NA toxval_numeric | `bslib::value_box()` + `bslib::layout_columns(col_widths = c(3,3,3,3))` pattern confirmed from `mod_clean_data.R` lines 383-488 |
| DATA-04 | User-editable unit table UI following v1.3 reference list editor pattern with re-run cascade | Chip editor pattern confirmed in `mod_clean_data.R`; `load_unit_map()` is the loader; unit table schema is 6-column |
| PARS-06 | One-off corrections table — user-editable `(pattern, replacement)` for source-specific malformed values | Requires new `corrections.rds` file and `load_corrections()` function; corrections applied before `parse_numeric_results()` |
| UNIT-06 | Unmatched-unit review UI — show unmatched units, allow inline add to unit table, re-run harmonization | Unmatched units identified from `harmonize_units()` output where `unit_flag == "unmatched"`; batch and per-unit patterns designed |

</phase_requirements>

---

## Summary

Phase 34 builds a single new Shiny module (`R/mod_harmonize.R`) that orchestrates the numeric parsing and unit harmonization pipeline already implemented in Phases 30 and 31.5. The pattern is well-established in this codebase: all three upstream pattern modules (`mod_clean_data.R`, `mod_run_curation.R`) follow the same structure — a guarded button, a `withProgress()` pipeline, reactive `data_store` writes, and optional post-run UI sections.

The complexity in this phase is concentrated in the three editor UIs rather than the pipeline itself. The chip editor system from `mod_clean_data.R` can be reused nearly verbatim for the unit table and corrections editors, with the key difference that unit table chips trigger a modal (6-field form) rather than a simple toggle. The unmatched unit panel is a new pattern — a batch list with per-row action buttons — but follows Bootstrap 5 flex layout conventions the project already uses.

There are two key integration points that require attention. First, the `corrections` system does not yet exist: `corrections.rds` needs to be created as an empty tibble and a `load_corrections()` loader added to `cleaning_reference.R`. Second, the pipeline must apply one-off corrections before calling `parse_numeric_results()`, making corrections a pre-processing step.

**Primary recommendation:** Build `mod_harmonize.R` strictly following `mod_run_curation.R` structure for the pipeline section and `mod_clean_data.R` structure for the editor sections. Reuse the chip editor CSS/JS verbatim from `mod_clean_data.R` lines 15-57, adapting only the data-binding attributes for the new namespace.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Pipeline orchestration (parse + harmonize) | Shiny server (mod_harmonize) | — | CPU-bound R computation, no HTTP needed |
| Unit table display + editing | Shiny server (mod_harmonize) | Browser (JS delegated events) | Chip editor uses JS for click capture, but state lives in R |
| Corrections table display + editing | Shiny server (mod_harmonize) | Browser (JS delegated events) | Same chip editor pattern |
| Unmatched unit batch actions | Shiny server (mod_harmonize) | — | List generated server-side after pipeline run |
| QC value box display | Shiny server (mod_harmonize) | — | Computed from `harmonize_results`, rendered via `renderUI` |
| Cascade reset (editor changes) | Shiny server (mod_harmonize) | app.R observeEvent | Module fires reset on `data_store`; app.R already has numeric reset |
| Data persistence (unit_map, corrections) | `cleaning_reference.R` loaders | `inst/extdata/reference_cache/` | Consistent with all other reference data in this project |

---

## Standard Stack

### Core (already in project)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shiny | ≥1.7 | Module system, reactiveValues, observeEvent | Project foundation |
| bslib | ≥0.6 | `accordion()`, `value_box()`, `layout_columns()` | Project UI framework (Bootstrap 5 Flatly) |
| bsicons | ≥0.1 | `bs_icon()` for value boxes and tab icon | Used throughout existing modules |
| shinyjs | ≥2.1 | `disable()`/`enable()` on button during pipeline | Already imported; used in `mod_run_curation.R` |

[VERIFIED: codebase grep — all four are already in `NAMESPACE` imports and loaded in `inst/app/app.R`]

### Supporting (already in project, needed by pipeline)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dplyr | ≥1.1 | Data manipulation for pipeline results | Joining parsed + harmonized output |
| tibble | ≥3.2 | Typed tibbles for corrections table | Creating zero-row seed for `corrections.rds` |
| purrr | ≥1.0 | `safely()` wrapping in pipeline stages | Following `detect_data_start()` pattern for error resilience |

[VERIFIED: all three are in project `DESCRIPTION` Imports and used throughout existing R files]

### New File to Create

| File | Purpose | Notes |
|------|---------|-------|
| `inst/extdata/reference_cache/corrections.rds` | Empty corrections table seed | 2-column tibble: `pattern`, `replacement` (both character) |

### No New Package Dependencies Required

This phase introduces zero new R package dependencies. All required functionality exists in installed packages. [VERIFIED: codebase scan — `parse_numeric_results()` and `harmonize_units()` are in `NAMESPACE`, both exported]

---

## Architecture Patterns

### System Architecture Diagram

```
User action: "Run Harmonization"
         |
         v
[data_store$numeric_tags]
         |
         +---> Extract Result-tagged columns --> apply corrections --> parse_numeric_results()
         |                                                                     |
         +---> Extract Unit-tagged columns                               [parse_tibble]
                        |                                                      |
                        +----> harmonize_units(values, units, unit_map) <-----+
                                         |
                                    [harmonize_tibble]
                                         |
                          +-----------------------------+
                          |                             |
                   data_store$harmonize_results   data_store$harmonize_audit
                          |
                     [QC metrics computed]
                          |
                     renderUI: value boxes
                          |
                     renderUI: unmatched units list (unit_flag == "unmatched")
```

Editor interaction path (independent of pipeline):
```
User edits unit table / corrections --> observeEvent detects change
         |
         v
   data_store$harmonize_results <- NULL
   data_store$harmonize_audit <- NULL
   data_store$toxval_output <- NULL
         |
         v
   (value boxes disappear, unmatched panel reverts to pre-run state)
```

### Recommended Project Structure

The module is a single file following the existing pattern:

```
R/
├── mod_harmonize.R          # New — UI + server (this phase)
inst/extdata/reference_cache/
├── corrections.rds          # New — empty 2-column tibble seed
```

Modified files:
```
inst/app/app.R               # Add Harmonize nav_panel, wire module server
R/cleaning_reference.R       # Add load_corrections() loader
NAMESPACE                    # Add mod_harmonize_ui, mod_harmonize_server exports
```

### Pattern 1: Pipeline Button with withProgress (from mod_run_curation.R)

**What:** Button click triggers a multi-stage pipeline with Shiny's built-in progress bar. Button is disabled during execution and re-enabled in `finally`.
**When to use:** All pipeline execution buttons in this project.

```r
# Source: R/mod_run_curation.R lines 113-291 (verified)
observeEvent(input$run_harmonization, {
  req(data_store$clean, data_store$numeric_tags)
  shinyjs::disable("run_harmonization")

  tryCatch({
    withProgress(message = "Running harmonization...", value = 0, {
      incProgress(0.3, detail = "Parsing numeric results...")
      # ... parse_numeric_results() call ...
      incProgress(0.3, detail = "Harmonizing units...")
      # ... harmonize_units() call ...
      incProgress(0.4, detail = "Finalizing...")
      data_store$harmonize_results <- result
      data_store$harmonize_audit <- audit
    })
  },
  error = function(e) {
    showNotification(paste("Harmonization failed:", e$message, "Check column tags and try again."),
                     type = "error", duration = NULL)
  },
  finally = {
    shinyjs::enable("run_harmonization")
  })
})
```

[VERIFIED: codebase — `mod_run_curation.R` lines 113-291]

### Pattern 2: Chip Editor (from mod_clean_data.R)

**What:** Delegated JS click events bound to chip body (toggle/edit) and chip × button (remove). CSS inlines in `tagList()` at top of UI function.
**When to use:** All editable reference list editors in this project.

The JS in `mod_clean_data.R` lines 24-57 uses `data-ns`, `data-type`, and `data-term` attributes. For the harmonize module the chip interaction needs different input names (`chip_unit_toggle`, `chip_unit_remove`, `chip_unit_add`) to avoid collision if both modules are active.

Key adaptation: the `data-term` for unit chips must encode the row identity uniquely. Use `from_unit` as the term identifier for the unit table (guaranteed unique per row). For corrections, use `pattern` as the term identifier.

```r
# Source: R/mod_clean_data.R lines 15-57 (verified — reuse with namespace adaptation)
tags$script(HTML(sprintf("
  $(document).on('click', '.unit-chip-body[data-ns=\"%s\"]', function() {
    Shiny.setInputValue('%s', {
      term: $(this).data('term'),
      ts: Date.now()
    });
  });
  // ... remove and add handlers follow same pattern
", ns(""), ns("chip_unit_click"))))
```

[VERIFIED: codebase — `mod_clean_data.R` lines 15-57]

### Pattern 3: Accordion Panel with Dynamic Title Badge

**What:** `bslib::accordion_panel()` title includes item count. Panel open state is `FALSE` by default.
**When to use:** Collapsible editor sections in this phase (D-04, D-05).

```r
# Source: R/mod_clean_data.R lines 501-509 (verified — accordion pattern)
# Title with count badge pattern from 34-UI-SPEC.md:
bslib::accordion(
  id = ns("editors"),
  open = FALSE,
  multiple = TRUE,
  bslib::accordion_panel(
    title = uiOutput(ns("unit_editor_title")),  # "Unit Table Editor (151 mappings)"
    icon = bsicons::bs_icon("rulers"),
    uiOutput(ns("unit_chip_editor"))
  )
)
```

Note: accordion panel titles with reactive counts require `uiOutput()` inside the title, or building the title string in `renderUI` for the full accordion. The simpler approach is building the entire accordion in `renderUI`, accepting the re-render cost on count change.

[VERIFIED: codebase — `mod_clean_data.R` lines 592-620, accordion structure]

### Pattern 4: Conditional Empty State

**What:** `conditionalPanel()` keyed off a server-side reactive output for tab-level visibility.
**When to use:** All modules with "nothing to show yet" states.

```r
# Source: R/mod_run_curation.R lines 15-45 (verified)
conditionalPanel(
  condition = paste0("output['", ns("has_numeric_tags"), "']"),
  # ... main content
),
conditionalPanel(
  condition = paste0("!output['", ns("has_numeric_tags"), "']"),
  div(class = "text-center text-muted py-5",
    bsicons::bs_icon("sliders", size = "3em"),
    h4("No numeric columns tagged"),
    p("Tag your Result and Unit columns first, then run harmonization.")
  )
)
```

[VERIFIED: codebase — `mod_run_curation.R` lines 14-46]

### Pattern 5: Modal Form for Add/Edit

**What:** `showModal(modalDialog(...))` with form inputs inside the modal body. Modal triggered by button or chip click. Confirmation button calls `observeEvent()` to apply the change and `removeModal()`.
**When to use:** Unit mapping add/edit (D-08, D-09) and corrections add/edit (D-10).

```r
# Source: R/mod_clean_data.R lines 957-968 (multi-CAS split modal — verified)
showModal(modalDialog(
  title = "Add Unit Mapping",
  textInput(ns("modal_from_unit"), "From Unit", placeholder = "e.g., ug/L"),
  textInput(ns("modal_to_unit"), "To Unit", placeholder = "e.g., mg/L"),
  numericInput(ns("modal_multiplier"), "Multiplier", value = NA),
  selectInput(ns("modal_category"), "Category",
    choices = c("mass_concentration", "mass_per_mass", "volume_concentration",
                "molar", "radioactivity", "biological", "dimensionless", "other")),
  selectInput(ns("modal_confidence"), "Confidence", choices = c("HIGH", "MEDIUM", "LOW")),
  textInput(ns("modal_source"), "Source", value = "user"),
  footer = tagList(
    modalButton("Discard"),
    actionButton(ns("save_unit_mapping"), "Save Mapping", class = "btn-primary")
  ),
  easyClose = FALSE
))
```

[VERIFIED: codebase — `mod_clean_data.R` lines 957-968 modal pattern]

### Anti-Patterns to Avoid

- **rhandsontable for editable tables:** Explicitly prohibited by D-06. Chip editor is the required pattern.
- **Automatic re-run on editor change:** D-16 specifies the user must manually re-run after adding mappings. No auto-trigger.
- **Blocking on corrections errors:** One-off corrections are best-effort. If a correction pattern fails (bad regex), skip it with a warning rather than crashing the pipeline.
- **Embedding pipeline function signatures differently from existing functions:** `parse_numeric_results(values)` takes a character vector; `harmonize_units(values, units, unit_map, ...)` takes vectors of equal length. The pipeline must extract the correct column vectors from the data frame before calling these functions.
- **Storing unit_map only in data_store without the canonical loader:** The unit map must be loaded via `load_unit_map()` so changes survive session restart. Store the working copy in `data_store$unit_map_working` for session-local edits; do NOT persist to the RDS file during the session (consistent with how `reference_lists` works — in-memory only, no write-back).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Numeric parsing edge cases (Fortran exp, ranges, qualifiers) | Custom regex chain | `parse_numeric_results()` from `R/numeric_parser.R` | Already handles all PARS-01 through PARS-05 requirements; hand-rolling would miss the range-before-Fortran ordering requirement |
| Unit conversion arithmetic | Custom multiplier lookup | `harmonize_units()` from `R/unit_harmonizer.R` | Handles case-sensitive/insensitive fallback, molarity, ppb/ppm media routing, and audit trail |
| Unit map loading | Direct `readRDS()` call | `load_unit_map()` from `cleaning_reference.R` | Follows project caching pattern; handles missing file gracefully with fallback |
| Progress display | Custom JS spinner | `withProgress()` + `incProgress()` | Shiny built-in; matches all existing pipeline modules |
| Modal dialogs | Custom overlays | `showModal(modalDialog(...))` + `removeModal()` | Shiny built-in; already used in `mod_clean_data.R` |
| Chip CSS/JS | Re-implementing event delegation | Copy lines 15-57 of `mod_clean_data.R` | Namespace parameterization handles uniqueness; re-implementing risks divergence |

**Key insight:** Every piece of core logic this module calls was purpose-built in earlier phases. Phase 34 is an orchestration layer, not a computation layer.

---

## Runtime State Inventory

Not applicable — this is a greenfield module with no rename/refactor component.

---

## Common Pitfalls

### Pitfall 1: Corrections Applied After Normalization

**What goes wrong:** Applying `(pattern, replacement)` corrections after `parse_numeric_results()` has already normalized the string means the patterns never match the messy originals.
**Why it happens:** The corrections table is for source-specific malformed values (PARS-06 scope), not for post-parse cleanup.
**How to avoid:** Apply corrections as a vectorized `gsub()` pass on the raw Result column values, before passing to `parse_numeric_results()`. Pattern is treated as a regex; replacement is literal.
**Warning signs:** Corrections entries exist but QC metrics show unchanged NA count.

### Pitfall 2: Unit Map Working Copy vs. Loaded Copy

**What goes wrong:** If the module reads `data_store$reference_lists$unit_map` for pipeline execution but writes edits to a separate `data_store$unit_map_working`, a race condition occurs where old maps are used.
**Why it happens:** The reference_lists structure was designed for read-only reference data. The unit map is editable this phase.
**How to avoid:** Initialize `data_store$unit_map_working` from `reference_lists$unit_map` at module startup (in an `observe()` with a once-flag). All pipeline calls use `data_store$unit_map_working`. All chip editor mutations write to `data_store$unit_map_working`.
**Warning signs:** Edits to the unit table are not reflected when harmonization is re-run.

### Pitfall 3: Unmatched Unit Count Disappears on Accordion Collapse

**What goes wrong:** If the unmatched units panel title count is computed inside `renderUI()` for the accordion, collapsing and re-opening the accordion causes a re-render flash.
**Why it happens:** `renderUI()` of the full accordion re-renders the DOM element, briefly showing the collapsed state.
**How to avoid:** Render accordion title counts as separate `output$xxx_count` reactive values, then embed `uiOutput()` in the accordion panel title string — OR accept the minor flash (low visual impact, matches existing accordion patterns in the project).

### Pitfall 4: Chip JS Namespace Collision

**What goes wrong:** If `mod_harmonize.R` reuses the same JS selector classes as `mod_clean_data.R` without namespacing the `data-ns` attribute, chip clicks in one module trigger handlers in the other.
**Why it happens:** Both modules could be rendered in the same DOM at the same time.
**How to avoid:** The delegated event handlers in `mod_clean_data.R` already use `data-ns` to scope to their module namespace. The same approach works for `mod_harmonize.R` — the `data-ns` value must be the module's own `ns("")` output. Never share delegated event class names across modules without namespace scoping.
**Warning signs:** Clicking a unit chip in the harmonize tab triggers an action in the clean data tab's chip observer.

### Pitfall 5: Pipeline Called with No Result Column

**What goes wrong:** `data_store$numeric_tags` exists but no column has tag `"Result"` (e.g., user only tagged `"Unit"`). Calling `parse_numeric_results()` with an empty vector returns a zero-row tibble, which propagates correctly, but the QC metrics show confusing zeros.
**Why it happens:** Phase 33 validation warns but does not block unpaired tags (D-14/D-15).
**How to avoid:** In the `run_harmonization` observeEvent, check that at least one Result-tagged column exists before running. If not, show a warning notification and return early.

### Pitfall 6: `data_store$harmonize_results` Shape Assumption in Phase 35

**What goes wrong:** Phase 35 reads `harmonize_results` expecting a specific tibble shape. If Phase 34 writes a differently-shaped result, Phase 35 breaks silently.
**Why it happens:** Phase 34 builds this structure; Phase 35 consumes it. Shape must be documented.
**How to avoid:** Define `harmonize_results` as a list with named elements: `$parsed` (output of `parse_numeric_results()`), `$harmonized` (output of `harmonize_units()`), `$input_data` (the original clean/curated data frame for joining). Document this structure as a comment in `mod_harmonize.R`.

---

## Code Examples

Verified patterns from existing codebase:

### Applying One-Off Corrections Before Parsing

```r
# Source: PARS-06 design — apply before parse_numeric_results()
apply_corrections <- function(values, corrections_tbl) {
  # corrections_tbl has columns: pattern (regex), replacement (literal)
  if (is.null(corrections_tbl) || nrow(corrections_tbl) == 0) return(values)

  result <- values
  for (i in seq_len(nrow(corrections_tbl))) {
    tryCatch(
      result <- gsub(corrections_tbl$pattern[i], corrections_tbl$replacement[i], result),
      error = function(e) {
        warning(sprintf("Correction pattern '%s' failed: %s", corrections_tbl$pattern[i], e$message))
      }
    )
  }
  result
}
```

### Unit Table Working Copy Initialization

```r
# Source: mod_clean_data.R lines 113-119 pattern (one-shot init) [VERIFIED]
unit_map_ready <- reactiveVal(FALSE)
observe({
  if (is.null(data_store$unit_map_working) && !is.null(data_store$reference_lists$unit_map)) {
    data_store$unit_map_working <- data_store$reference_lists$unit_map
    if (!unit_map_ready()) unit_map_ready(TRUE)
  }
})
```

### QC Metrics Extraction from Pipeline Results

```r
# Source: design from 34-CONTEXT.md D-19, using output structures from Phase 30 and 31
# harmonize_results$parsed: orig_row_id, orig_result, numeric_value, qualifier, range_bin, parse_flag
# harmonize_results$harmonized: orig_row_id, orig_unit, harmonized_value, harmonized_unit, conversion_factor, unit_flag
# harmonize_results$input_data: the input data frame

n_parsed      <- nrow(harmonize_results$parsed)
n_harmonized  <- sum(harmonize_results$harmonized$unit_flag != "unmatched", na.rm = TRUE)
n_dtxsid      <- if ("consensus_dtxsid" %in% names(harmonize_results$input_data)) {
  sum(!is.na(harmonize_results$input_data$consensus_dtxsid))
} else { 0L }
n_na_numeric  <- sum(is.na(harmonize_results$parsed$numeric_value))
```

### Adding Pass-through Entry for Unmatched Unit

```r
# Source: 34-CONTEXT.md D-14 / 34-UI-SPEC.md interaction contract
add_passthrough_mapping <- function(unit_string, unit_map) {
  new_row <- tibble::tibble(
    from_unit   = unit_string,
    to_unit     = unit_string,
    multiplier  = 1,
    category    = "dimensionless",
    confidence  = "LOW",
    source      = "user_passthrough"
  )
  dplyr::bind_rows(unit_map, new_row)
}
```

### Tab Wiring in app.R

```r
# Source: inst/app/app.R lines 70-100 (existing navset_underline) [VERIFIED]
# Add after "Run Curation" nav_panel:
nav_panel("Harmonize", value = "harmonize_tab",
  icon = bsicons::bs_icon("sliders"),
  chemreg::mod_harmonize_ui("harmonize")
)

# In server:
chemreg::mod_harmonize_server("harmonize", data_store)

# In session$onFlushed() hide list:
bslib::nav_hide("main_tabs", target = "harmonize_tab", session = session)

# Show trigger: after curation complete OR when numeric_tags set
shiny::observe({
  shiny::req(data_store$numeric_tags)
  show_tab_with_pulse("harmonize_tab")
})
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| rhandsontable for inline editing | Chip editor + modal | Phase 34 decision (D-06) | Better UX; consistent with existing reference list editors |
| Global `column_tags` for all tag types | Partitioned `chemical_tags` / `numeric_tags` / `metadata_tags` | Phase 33 | Each downstream module reads only its relevant subset |
| Manual unit conversion per dataset | Shared `unit_conversion.rds` with 151 rows | Phase 29 | User edits persist within session; no re-implementation per run |

**No deprecated patterns in this phase.** All patterns used are current project conventions.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `data_store$unit_map_working` does not exist yet — must be initialized from `reference_lists$unit_map` in module startup | Code Examples: Unit Table Init | If `unit_map_working` is already initialized elsewhere, double-init could clobber session edits |
| A2 | Phase 35 will read `harmonize_results` as a list with `$parsed`, `$harmonized`, `$input_data` sub-elements | Pitfall 6, Code Examples | If Phase 35 expects a flat tibble, the shape will need changing in this phase's output |
| A3 | The Harmonize tab should be shown when `numeric_tags` is set (not only after curation) | Code Examples: Tab Wiring | Some users may tag numeric columns without chemical columns; tab should still be reachable |
| A4 | `corrections.rds` seed is a 2-column tibble with columns `pattern` (character) and `replacement` (character) | Architecture Patterns | If Phase 35 or the export helper expects additional columns, seed must be extended |

---

## Open Questions (RESOLVED)

1. **DTXSID column name for QC metric**
   - What we know: `n_dtxsid` requires checking if a DTXSID column exists; `consensus_dtxsid` is the name in the consensus pipeline
   - What's unclear: After the harmonize pipeline, the input data frame may not have been through curation (some users may skip chemical curation). The column may not exist.
   - Recommendation: Check for `consensus_dtxsid` first; fall back to 0 if absent. Display "0" for this metric with a tooltip "Run curation to add DTXSID data."
   - **RESOLVED:** Use `consensus_dtxsid` column name. Check with `"consensus_dtxsid" %in% names(input_data)`, fall back to `0L` if absent. Implemented in Plan 01 Task 2 QC dashboard `output$qc_dashboard`.

2. **Corrections persistence across sessions**
   - What we know: `PARS-06` says "user-editable" — implies session-level changes are expected. `cleaning_reference.R` caches reference data to disk.
   - What's unclear: Should corrections be saved to `corrections.rds` on change (write-through), or are they session-local only?
   - Recommendation: Mirror the reference list behavior — session-local edits, not persisted to disk. Phase 35 can export them as a sheet in the Excel export (consistent with how reference lists are exported).
   - **RESOLVED:** Session-local only, no write-through to disk. Corrections live in `data_store$corrections_working` (initialized from `corrections.rds` seed). Consistent with how all reference lists work in this project. Implemented in Plan 01 Task 2 working copy initialization.

3. **Accordion tab show trigger**
   - What we know: The Harmonize tab should appear after tagging. The existing app.R shows tabs via `show_tab_with_pulse()` in `observe()` blocks.
   - What's unclear: Should the tab appear as soon as `numeric_tags` is set (without requiring curation to also run), or only after curation?
   - Recommendation: Show when `numeric_tags` is non-null. Users may have purely numeric datasets with no chemical columns.
   - **RESOLVED:** Show tab when `numeric_tags` is non-null via `shiny::observe({ shiny::req(data_store$numeric_tags); show_tab_with_pulse("harmonize_tab") })`. No curation gate required. Implemented in Plan 01 Task 3 app.R wiring.

---

## Environment Availability

Step 2.6: Not applicable — this phase introduces no external tools, CLI utilities, or external services. All dependencies are R packages already installed in the project.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat 3.x |
| Config file | `tests/testthat.R` |
| Quick run command | `testthat::test_file("tests/testthat/test-modules-render.R")` |
| Full suite command | `testthat::test_dir("tests/testthat")` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UITG-04 | `mod_harmonize_server` initializes without error | unit | `testthat::test_file("tests/testthat/test-modules-render.R")` | ✅ (extend existing file) |
| UITG-04 | Pipeline completes and writes `harmonize_results` to data_store | unit | `testthat::test_file("tests/testthat/test-harmonize-module.R")` | ❌ Wave 0 |
| UITG-05 | QC metrics computed correctly from pipeline output | unit | `testthat::test_file("tests/testthat/test-harmonize-module.R")` | ❌ Wave 0 |
| DATA-04 | Unit table chip add appends row to `data_store$unit_map_working` | unit | `testthat::test_file("tests/testthat/test-harmonize-module.R")` | ❌ Wave 0 |
| DATA-04 | Unit table change triggers cascade reset of harmonize_results | unit | `testthat::test_file("tests/testthat/test-harmonize-module.R")` | ❌ Wave 0 |
| PARS-06 | `apply_corrections()` applies pattern→replacement before parse | unit | `testthat::test_file("tests/testthat/test-harmonize-module.R")` | ❌ Wave 0 |
| UNIT-06 | Unmatched units correctly identified from `unit_flag == "unmatched"` | unit | `testthat::test_file("tests/testthat/test-harmonize-module.R")` | ❌ Wave 0 |
| UNIT-06 | "Add All as Pass-through" adds identity mappings for all unmatched | unit | `testthat::test_file("tests/testthat/test-harmonize-module.R")` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `testthat::test_file("tests/testthat/test-modules-render.R")`
- **Per wave merge:** `testthat::test_dir("tests/testthat")`
- **Phase gate:** Full suite green + Shiny cold boot test (`chemreg::run_app()`) before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `tests/testthat/test-harmonize-module.R` — covers UITG-04, UITG-05, DATA-04, PARS-06, UNIT-06
- [ ] `tests/testthat/test-modules-render.R` needs `create_test_store()` updated to include Phase 33+ fields (`numeric_tags`, `harmonize_results`, `harmonize_audit`, `toxval_output`) and a new test for `mod_harmonize_server` init

**Note on cold boot test:** Per `CLAUDE.md`, Shiny cold boot is mandatory after any change to app.R, module files, or reactive state. This phase modifies all three. Cold boot must be the final gate before marking the phase complete.

---

## Security Domain

No security-relevant functionality in this phase. The module operates entirely on data already loaded into the Shiny session's reactive state. No file I/O (read or write) of sensitive data, no authentication, no API calls in the primary pipeline path (MW lookup via ComptoxR is optional and already guarded with `requireNamespace()`).

---

## Project Constraints (from CLAUDE.md)

| Directive | Category | Impact on Phase |
|-----------|----------|-----------------|
| `shiny::runApp()` cold boot test mandatory after Shiny changes | Testing | Add cold boot as explicit task in plan |
| `testthat::test_dir("tests")` for all unit tests | Testing | Use existing testthat infrastructure |
| `air` formatter with 120-char line width, 2-space indent | Formatting | All new R code must be formatted with `air` before commit |
| Commit iteratively after each logical unit of work | Git | Plan should assign commits per wave/task group |
| Feature branch already exists (`feature/32-toxval-schema-mapper`) | Git | New code goes on this branch |
| `pak` for package installation | Dependency mgmt | No new packages this phase, so no action needed |

---

## Sources

### Primary (HIGH confidence)

- `R/mod_run_curation.R` — pipeline button pattern, `withProgress()`, tryCatch/finally, `shinyjs::disable/enable`
- `R/mod_clean_data.R` — chip editor CSS/JS (lines 15-57), `render_chip_editor()` (lines 529-582), `bslib::value_box()` layout (lines 383-488), accordion structure (lines 592-620), modal pattern (lines 957-968)
- `R/numeric_parser.R` — `parse_numeric_results()` signature and return structure
- `R/unit_harmonizer.R` — `harmonize_units()` signature, parameters, and return structure
- `R/cleaning_reference.R` — `load_unit_map()`, `load_all_reference_lists()`, `load_or_fetch_reference()` pattern
- `R/tag_helpers.R` — `classify_tags()`, `detect_tag_changes()`, `validate_tag_pairing()` signatures
- `inst/app/app.R` — existing `data_store` reactiveValues shape (lines 106-126), tab navigation pattern (lines 237-288), cascade reset functions (lines 290-306)
- `.planning/phases/34-harmonize-tab-module/34-UI-SPEC.md` — complete visual and interaction contract
- `.planning/phases/34-harmonize-tab-module/34-CONTEXT.md` — all locked decisions D-01 through D-28
- `.planning/REQUIREMENTS.md` — UITG-04, UITG-05, DATA-04, PARS-06, UNIT-06 definitions

### Secondary (MEDIUM confidence)

- `NAMESPACE` — confirmed exports of `parse_numeric_results`, `harmonize_units`, `classify_tags`, `detect_tag_changes`
- `tests/testthat/test-modules-render.R` — test pattern for module server initialization, `create_test_store()` helper

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all libraries are verified present in NAMESPACE and already loaded in app.R
- Architecture: HIGH — all patterns directly verified in existing module files; no new patterns invented
- Pitfalls: HIGH — derived from specific code inspection of existing chip editor, modal, and pipeline patterns
- Pipeline integration: HIGH — function signatures verified from source files; output tibble structures inspected

**Research date:** 2026-04-16
**Valid until:** 2026-05-16 (stable project; patterns are internal, not external library-dependent)
