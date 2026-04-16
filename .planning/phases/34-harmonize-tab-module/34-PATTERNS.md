# Phase 34: Harmonize Tab Module - Pattern Map

**Mapped:** 2026-04-16
**Files analyzed:** 5 (2 new, 3 modified)
**Analogs found:** 5 / 5

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `R/mod_harmonize.R` | module (UI + server) | request-response + event-driven | `R/mod_run_curation.R` (pipeline) + `R/mod_clean_data.R` (editors) | exact (composite) |
| `inst/extdata/reference_cache/corrections.rds` | config/seed | batch | `inst/extdata/reference_cache/stop_words.rds` | role-match |
| `inst/app/app.R` | config/wiring | request-response | `inst/app/app.R` (self, lines 70–383) | exact |
| `R/cleaning_reference.R` | service/utility | CRUD | `R/cleaning_reference.R` (self, `load_stop_words` lines 55–71) | exact |
| `NAMESPACE` | config | — | `NAMESPACE` (self) | exact |

---

## Pattern Assignments

### `R/mod_harmonize.R` (module, request-response + event-driven)

**Primary analog — pipeline section:** `R/mod_run_curation.R`
**Primary analog — editor section:** `R/mod_clean_data.R`

---

#### Module skeleton (UI function header)

**From:** `R/mod_run_curation.R` lines 1–11 and `R/mod_clean_data.R` lines 1–11

```r
#' Harmonize Module - UI
#'
#' @param id Module namespace ID
#' @return UI elements for harmonize tab
#' @export
mod_harmonize_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # ... (chip CSS/JS block, then conditionalPanel structure)
  )
}
```

---

#### Chip editor CSS/JS block (verbatim reuse, namespace-adapted)

**From:** `R/mod_clean_data.R` lines 14–57

```r
# Chip editor CSS
tags$style(HTML(sprintf("
  .ref-chip { cursor: pointer; margin: 2px; display: inline-block; }
  .ref-chip:hover { opacity: 0.8; }
  .ref-chip-remove { cursor: pointer; margin-left: 4px; font-weight: bold; }
  .ref-chip-remove:hover { color: red; }
  .ref-chip-container { max-height: 200px; overflow-y: auto; padding: 6px; border: 1px solid #dee2e6; border-radius: 4px; background: #f8f9fa; }
  .ref-term-input { margin-top: 6px; }
"))),
# Chip editor JS — delegated events (adapt input names to harmonize namespace)
tags$script(HTML(sprintf("
  $(document).on('click', '.ref-chip-body[data-ns=\"%s\"]', function() {
    var $chip = $(this);
    Shiny.setInputValue('%s', {
      type: $chip.data('type'),
      term: $chip.data('term'),
      ts: Date.now()
    });
  });
  $(document).on('click', '.ref-chip-remove[data-ns=\"%s\"]', function(e) {
    e.stopPropagation();
    var $btn = $(this);
    Shiny.setInputValue('%s', {
      type: $btn.data('type'),
      term: $btn.data('term'),
      ts: Date.now()
    });
  });
", ns(""), ns("chip_click"), ns(""), ns("chip_remove"))))
```

**Key adaptation:** `chip_toggle` becomes `chip_click` (unit table chips open a modal, not a toggle). The `data-ns` attribute scoping to `ns("")` is the namespace-collision guard — do not share class names or omit this attribute.

---

#### Conditional empty state

**From:** `R/mod_run_curation.R` lines 15–45

```r
conditionalPanel(
  condition = paste0("output['", ns("has_numeric_tags"), "']"),
  # ... main content
),
conditionalPanel(
  condition = paste0("!output['", ns("has_numeric_tags"), "']"),
  div(
    class = "text-center text-muted py-5",
    bsicons::bs_icon("sliders", size = "3em"),
    h4("No numeric columns tagged"),
    p("Tag your Result and Unit columns first, then run harmonization.")
  )
)
```

The server-side indicator uses `outputOptions(..., suspendWhenHidden = FALSE)` — copy exactly from `R/mod_run_curation.R` lines 332–335:

```r
output$has_numeric_tags <- reactive({
  !is.null(data_store$numeric_tags) && length(data_store$numeric_tags) > 0
})
outputOptions(output, "has_numeric_tags", suspendWhenHidden = FALSE)
```

---

#### Run button (disabled initially, guarded enable)

**From:** `R/mod_run_curation.R` lines 22–31 and 100–110

```r
# UI: button starts disabled
shinyjs::disabled(
  actionButton(
    ns("run_harmonization"),
    "Run Harmonization",
    class = "btn-success btn-lg mt-3",
    icon = icon("play")
  )
)

# Server: enable when prerequisites met
observe({
  has_tags <- !is.null(data_store$numeric_tags) && length(data_store$numeric_tags) > 0
  if (has_tags) {
    shinyjs::enable("run_harmonization")
  } else {
    shinyjs::disable("run_harmonization")
  }
})
```

---

#### Pipeline execution — withProgress + tryCatch/finally

**From:** `R/mod_run_curation.R` lines 112–290

```r
observeEvent(input$run_harmonization, {
  req(data_store$clean, data_store$numeric_tags)

  # Guard: require at least one Result-tagged column
  result_cols <- names(data_store$numeric_tags)[data_store$numeric_tags == "Result"]
  if (length(result_cols) == 0) {
    showNotification(
      "No Result column tagged. Tag a Result column before running harmonization.",
      type = "warning", duration = 5
    )
    return()
  }

  shinyjs::disable("run_harmonization")

  tryCatch(
    {
      withProgress(message = "Running harmonization...", value = 0, {
        incProgress(0.2, detail = "Applying one-off corrections...")
        # ... apply_corrections() call ...

        incProgress(0.3, detail = "Parsing numeric results...")
        # ... parse_numeric_results() call ...

        incProgress(0.3, detail = "Harmonizing units...")
        # ... harmonize_units() call ...

        incProgress(0.2, detail = "Finalizing...")
        data_store$harmonize_results <- list(
          parsed    = parse_tibble,
          harmonized = harmonize_tibble,
          input_data = input_df
        )
        data_store$harmonize_audit <- audit_tibble
      })
    },
    error = function(e) {
      showNotification(
        paste("Harmonization failed:", e$message, "Check column tags and try again."),
        type = "error", duration = NULL
      )
    },
    finally = {
      shinyjs::enable("run_harmonization")
    }
  )
})
```

**Note on `data_store$harmonize_results` shape:** The list structure `$parsed`, `$harmonized`, `$input_data` is the contract with Phase 35. Document it as a comment at the top of the `observeEvent` block.

---

#### QC value box layout (post-pipeline renderUI)

**From:** `R/mod_clean_data.R` lines 382–488

```r
output$qc_dashboard <- renderUI({
  req(data_store$harmonize_results)
  hr <- data_store$harmonize_results

  n_parsed     <- nrow(hr$parsed)
  n_harmonized <- sum(hr$harmonized$unit_flag != "unmatched", na.rm = TRUE)
  n_dtxsid     <- if ("consensus_dtxsid" %in% names(hr$input_data)) {
    sum(!is.na(hr$input_data$consensus_dtxsid))
  } else { 0L }
  n_na_numeric <- sum(is.na(hr$parsed$numeric_value))

  bslib::layout_columns(
    col_widths = c(3, 3, 3, 3),
    bslib::value_box(
      title = "Rows Parsed",
      value = n_parsed,
      showcase = bsicons::bs_icon("123"),
      theme = "primary"
    ),
    bslib::value_box(
      title = "Rows Harmonized",
      value = n_harmonized,
      showcase = bsicons::bs_icon("check-circle"),
      theme = "success"
    ),
    bslib::value_box(
      title = "With DTXSID",
      value = n_dtxsid,
      showcase = bsicons::bs_icon("database"),
      theme = "info"
    ),
    bslib::value_box(
      title = "NA Results",
      value = n_na_numeric,
      showcase = bsicons::bs_icon("exclamation-triangle"),
      theme = "warning"
    )
  )
})
```

---

#### Accordion panel structure (collapsed by default)

**From:** `R/mod_clean_data.R` lines 592–620

```r
# In UI function — static wrapper (renders once, counts updated via nested uiOutput)
bslib::accordion(
  id = ns("editors"),
  open = FALSE,
  multiple = TRUE,
  bslib::accordion_panel(
    title = uiOutput(ns("unit_editor_title")),
    icon = bsicons::bs_icon("rulers"),
    uiOutput(ns("unit_chip_editor")),
    actionButton(ns("add_unit_mapping"), "Add Unit Mapping",
                 class = "btn-outline-primary btn-sm mt-2",
                 icon = icon("plus"))
  ),
  bslib::accordion_panel(
    title = uiOutput(ns("corrections_editor_title")),
    icon = bsicons::bs_icon("pencil-square"),
    uiOutput(ns("corrections_chip_editor")),
    actionButton(ns("add_correction"), "Add Correction",
                 class = "btn-outline-primary btn-sm mt-2",
                 icon = icon("plus"))
  ),
  bslib::accordion_panel(
    title = "Unmatched Units",
    icon = bsicons::bs_icon("question-circle"),
    uiOutput(ns("unmatched_panel"))
  )
)
```

---

#### Chip editor render helper (unit table variant)

**From:** `R/mod_clean_data.R` lines 529–582 — adapt `render_chip_editor()` for unit table rows

Unit chips use `from_unit` as the unique term identifier (not `term`). The chip body click opens a modal (not a toggle). Key differences from the original:

```r
render_unit_chip_editor <- function(unit_map_tbl) {
  ns <- session$ns
  chips <- lapply(seq_len(nrow(unit_map_tbl)), function(i) {
    row <- unit_map_tbl[i, ]

    # Badge color by source (mirrors mod_clean_data.R badge logic)
    badge_class <- switch(row$source,
      ECOTOX = "badge bg-success ref-chip",
      SSWQS  = "badge bg-info ref-chip",
      user   = "badge bg-primary ref-chip",
      user_passthrough = "badge bg-secondary ref-chip",
      "badge bg-light text-dark ref-chip"
    )

    # Chip label: "from_unit → to_unit (×multiplier)" per D-07
    chip_label <- sprintf("%s \u2192 %s", row$from_unit, row$to_unit)
    if (!is.na(row$multiplier) && row$multiplier != 1) {
      chip_label <- sprintf("%s (\u00d7%s)", chip_label, row$multiplier)
    }

    # X button for user-added rows only
    remove_btn <- if (row$source %in% c("user", "user_passthrough")) {
      tags$span(
        class = "ref-chip-remove",
        `data-ns` = ns(""),
        `data-type` = "unit_map",
        `data-term` = row$from_unit,
        HTML("&times;")
      )
    }

    tags$span(
      class = badge_class,
      tags$span(
        class = "ref-chip-body",
        `data-ns` = ns(""),
        `data-type` = "unit_map",
        `data-term` = row$from_unit,
        chip_label
      ),
      remove_btn
    )
  })

  div(class = "ref-chip-container", chips)
}
```

---

#### One-shot reactive init for working copy

**From:** `R/mod_clean_data.R` lines 112–120

```r
unit_map_ready <- reactiveVal(FALSE)
observe({
  if (is.null(data_store$unit_map_working) && !is.null(data_store$reference_lists$unit_map)) {
    data_store$unit_map_working <- data_store$reference_lists$unit_map
    if (!unit_map_ready()) unit_map_ready(TRUE)
  }
})

corrections_ready <- reactiveVal(FALSE)
observe({
  if (is.null(data_store$corrections_working)) {
    data_store$corrections_working <- load_corrections(
      system.file("extdata", "reference_cache", package = "chemreg")
    )
    if (!corrections_ready()) corrections_ready(TRUE)
  }
})
```

---

#### Chip click → modal for unit table editing

**From:** `R/mod_clean_data.R` lines 957–968 (modal pattern) + lines 663–674 (chip_toggle handler)

```r
# chip_click fires when a unit chip body is clicked
observeEvent(input$chip_click, {
  msg <- input$chip_click
  req(msg$type == "unit_map", msg$term)

  # Find row by from_unit
  tbl <- data_store$unit_map_working
  row <- tbl[tbl$from_unit == msg$term, ][1, ]

  showModal(modalDialog(
    title = "Edit Unit Mapping",
    textInput(ns("modal_from_unit"), "From Unit", value = row$from_unit),
    textInput(ns("modal_to_unit"), "To Unit", value = row$to_unit),
    numericInput(ns("modal_multiplier"), "Multiplier", value = row$multiplier),
    selectInput(ns("modal_category"), "Category",
      choices = c("mass_concentration", "mass_per_mass", "volume_concentration",
                  "molar", "radioactivity", "biological", "dimensionless", "other"),
      selected = row$category),
    selectInput(ns("modal_confidence"), "Confidence",
      choices = c("HIGH", "MEDIUM", "LOW"), selected = row$confidence),
    textInput(ns("modal_source"), "Source", value = row$source),
    # Store original from_unit to find row on save
    tags$input(type = "hidden", id = ns("modal_orig_from"), value = row$from_unit),
    footer = tagList(
      modalButton("Discard"),
      actionButton(ns("save_unit_mapping"), "Save Mapping", class = "btn-primary")
    ),
    easyClose = FALSE
  ))
})
```

---

#### Chip remove handler (unit table)

**From:** `R/mod_clean_data.R` lines 677–687

```r
observeEvent(input$chip_remove, {
  msg <- input$chip_remove
  req(msg$type == "unit_map", msg$term)

  tbl <- data_store$unit_map_working
  # Only remove user-added rows
  idx <- which(tbl$from_unit == msg$term & tbl$source %in% c("user", "user_passthrough"))
  if (length(idx) > 0) {
    data_store$unit_map_working <- tbl[-idx[1], ]
  }
})
```

---

#### Cascade reset on editor change

**From:** `R/mod_clean_data.R` pattern of `observeEvent` watching store changes, plus `inst/app/app.R` lines 302–306

The cascade reset for editor changes lives in the module server (D-26/D-27). Use a previous-state comparison pattern, mirroring `inst/app/app.R` lines 330–336:

```r
prev_unit_map <- reactiveVal(NULL)
observeEvent(data_store$unit_map_working, {
  if (!is.null(prev_unit_map()) &&
      !identical(prev_unit_map(), data_store$unit_map_working)) {
    data_store$harmonize_results <- NULL
    data_store$harmonize_audit   <- NULL
    data_store$toxval_output     <- NULL
  }
  prev_unit_map(data_store$unit_map_working)
}, ignoreNULL = FALSE)

prev_corrections <- reactiveVal(NULL)
observeEvent(data_store$corrections_working, {
  if (!is.null(prev_corrections()) &&
      !identical(prev_corrections(), data_store$corrections_working)) {
    data_store$harmonize_results <- NULL
    data_store$harmonize_audit   <- NULL
    data_store$toxval_output     <- NULL
  }
  prev_corrections(data_store$corrections_working)
}, ignoreNULL = FALSE)
```

---

#### Unmatched units batch panel

**From:** `R/mod_run_curation.R` pattern (renderUI with conditional) + CONTEXT.md lines 155–169

```r
output$unmatched_panel <- renderUI({
  if (is.null(data_store$harmonize_results)) {
    return(p(class = "text-muted small",
             "Run harmonization to review unmatched units."))
  }

  harmonized <- data_store$harmonize_results$harmonized
  unmatched  <- harmonized[harmonized$unit_flag == "unmatched", ]

  if (nrow(unmatched) == 0) {
    return(div(class = "alert alert-success",
               bsicons::bs_icon("check-circle"), " All units matched."))
  }

  # Summarize by unit string
  unmatched_summary <- unmatched |>
    dplyr::count(orig_unit, name = "n") |>
    dplyr::arrange(dplyr::desc(n))

  div(
    class = "mb-3",
    actionButton(ns("add_all_passthrough"), "Add All as Pass-through",
                 class = "btn-outline-secondary btn-sm"),
    hr(),
    lapply(seq_len(nrow(unmatched_summary)), function(i) {
      u <- unmatched_summary[i, ]
      div(
        class = "d-flex justify-content-between align-items-center mb-2",
        span(sprintf("%s (%d rows)", u$orig_unit, u$n)),
        actionButton(
          ns(paste0("add_map_", make.names(u$orig_unit))),
          "Add Mapping",
          class = "btn-primary btn-sm",
          `data-unit` = u$orig_unit
        )
      )
    })
  )
})
```

---

### `inst/extdata/reference_cache/corrections.rds` (seed data)

**Analog:** `inst/extdata/reference_cache/stop_words.rds` (structure reference — 3-column active-flag tibble) but corrections only needs 2 columns.

**Seed tibble shape** (aligns with RESEARCH.md A4 and `load_corrections()` contract):

```r
# Create this file via a one-time script or in load_corrections() fetch_fn:
tibble::tibble(
  pattern     = character(),  # regex pattern (gsub-compatible)
  replacement = character()   # literal replacement string
)
```

No `source` or `active` columns needed — corrections are always active if present.

---

### `R/cleaning_reference.R` — add `load_corrections()` (utility, CRUD)

**Analog:** `R/cleaning_reference.R` `load_stop_words()` lines 55–71 — exact same `load_or_fetch_reference()` wrapper pattern.

```r
#' Load one-off corrections table
#'
#' Returns a tibble of (pattern, replacement) pairs for correcting source-specific
#' malformed Result values before numeric parsing. Applied as vectorized gsub().
#'
#' @param cache_dir Directory for cache files (e.g., "inst/extdata/reference_cache")
#' @return Tibble with columns: pattern (character), replacement (character)
#' @export
load_corrections <- function(cache_dir) {
  cache_path <- file.path(cache_dir, "corrections.rds")

  fetch_fn <- function() {
    tibble::tibble(
      pattern     = character(),
      replacement = character()
    )
  }

  load_or_fetch_reference(cache_path, fetch_fn, "one-off corrections")
}
```

After adding this function, add it to `load_all_reference_lists()` at line 391–402 only if corrections should be loaded at startup (optional — the module can call it directly).

---

### `inst/app/app.R` — add Harmonize tab and wire module (config/wiring)

**Analog:** `inst/app/app.R` existing nav_panel blocks (lines 84–99) and module wiring (lines 352–381).

**UI addition** (after "Run Curation" nav_panel, line 94):

```r
nav_panel("Harmonize", value = "harmonize_tab",
  icon = bsicons::bs_icon("sliders"),
  chemreg::mod_harmonize_ui("harmonize")
),
```

**data_store initialization** — fields already present (lines 119–125):

```r
# These already exist in data_store — no new fields needed for Phase 34:
# numeric_tags, harmonize_results, harmonize_audit, toxval_output,
# prev_numeric_tags
# New field to add:
unit_map_working = NULL,
corrections_working = NULL,
```

**Hide on startup** (in `session$onFlushed`, lines 236–243):

```r
bslib::nav_hide("main_tabs", target = "harmonize_tab", session = session)
```

**Show trigger** (after existing `observe` blocks, lines 309–320):

```r
shiny::observe({
  shiny::req(data_store$numeric_tags)
  show_tab_with_pulse("harmonize_tab")
})
```

**Module server wiring** (after `mod_run_curation_server` call, line 367):

```r
chemreg::mod_harmonize_server("harmonize", data_store)
```

**reset_all_downstream** (lines 259–288) — already clears `harmonize_results`, `harmonize_audit`, `toxval_output`. Add `unit_map_working` and `corrections_working` resets here:

```r
data_store$unit_map_working    <- NULL
data_store$corrections_working <- NULL
```

---

### `NAMESPACE` — export new symbols (config)

**Analog:** `NAMESPACE` lines 46–60 — existing module export pairs.

Add via roxygen `@export` tags on the new functions. After `devtools::document()` this appends:

```
export(load_corrections)
export(mod_harmonize_server)
export(mod_harmonize_ui)
```

---

### `tests/testthat/test-modules-render.R` — extend for mod_harmonize_server (test)

**Analog:** `tests/testthat/test-modules-render.R` lines 75–83 (`mod_run_curation_server` test)

```r
test_that("mod_harmonize_server initializes without error", {
  shiny::testServer(mod_harmonize_server, args = list(
    data_store = create_test_store()
  ), {
    session$flushReact()
    expect_true(TRUE)
  })
})
```

Also update `create_test_store()` (lines 4–15) to include Phase 33+ and Phase 34 fields:

```r
create_test_store <- function() {
  shiny::reactiveValues(
    # ... existing fields ...
    numeric_tags = NULL,
    metadata_tags = NULL,
    harmonize_results = NULL,
    harmonize_audit = NULL,
    toxval_output = NULL,
    prev_chemical_tags = NULL,
    prev_numeric_tags = NULL,
    unit_map_working = NULL,
    corrections_working = NULL
  )
}
```

---

## Shared Patterns

### Authentication / Session Guards
Not applicable. No auth in this project. The equivalent guard is `req()` before pipeline execution.

**Source:** All existing modules — use `req(data_store$clean, data_store$numeric_tags)` at the top of every `observeEvent`.

### Error Handling (tryCatch + showNotification)

**Source:** `R/mod_run_curation.R` lines 144–290
**Apply to:** `run_harmonization` observeEvent, corrections applier, all modal save handlers

```r
tryCatch(
  { ... },
  error = function(e) {
    showNotification(paste("... failed:", e$message), type = "error", duration = NULL)
  },
  finally = {
    shinyjs::enable("run_harmonization")
  }
)
```

### withProgress + incProgress

**Source:** `R/mod_run_curation.R` lines 146–276
**Apply to:** `run_harmonization` pipeline body exclusively. Do not use in chip editor handlers.

```r
withProgress(message = "Running harmonization...", value = 0, {
  incProgress(amount, detail = "Stage description...")
  # ... work ...
})
```

### Reactive init flag (one-shot observe)

**Source:** `R/mod_clean_data.R` lines 113–120 (`ref_lists_ready` pattern)
**Apply to:** `unit_map_working` and `corrections_working` initialization in module server.

```r
some_ready <- reactiveVal(FALSE)
observe({
  if (is.null(data_store$some_field) && !some_ready()) {
    data_store$some_field <- load_something(...)
    some_ready(TRUE)
  }
})
```

### showModal / removeModal for forms

**Source:** `R/mod_clean_data.R` lines 957–968
**Apply to:** "Add Unit Mapping" button, chip body click (edit mode), "Add Mapping" per unmatched unit, "Add Correction" button

```r
showModal(modalDialog(
  title = "...",
  # ... form inputs ...
  footer = tagList(
    modalButton("Discard"),
    actionButton(ns("save_..."), "Save", class = "btn-primary")
  ),
  easyClose = FALSE
))
# In the save observeEvent:
removeModal()
```

### data_store cascade reset

**Source:** `inst/app/app.R` lines 302–306 (`reset_numeric_downstream`)
**Apply to:** Unit table and corrections editor change observers (D-26/D-27)

```r
data_store$harmonize_results <- NULL
data_store$harmonize_audit   <- NULL
data_store$toxval_output     <- NULL
```

### outputOptions suspendWhenHidden = FALSE

**Source:** `R/mod_run_curation.R` lines 334–335
**Apply to:** All boolean output indicators used in `conditionalPanel` conditions.

```r
output$has_numeric_tags <- reactive({ ... })
outputOptions(output, "has_numeric_tags", suspendWhenHidden = FALSE)
```

---

## No Analog Found

All files have clear analogs. No files require falling back to RESEARCH.md patterns exclusively.

| File | Closest Analog | Note |
|---|---|---|
| `apply_corrections()` helper | No direct analog in codebase | Design is fully specified in RESEARCH.md Code Examples. Implement as a standalone function within `mod_harmonize.R` server body or extract to `R/numeric_parser.R`. |
| `add_passthrough_mapping()` helper | No direct analog | Fully specified in RESEARCH.md Code Examples. Inline or extract. |

---

## Metadata

**Analog search scope:** `R/`, `inst/app/`, `tests/testthat/`, `NAMESPACE`
**Files scanned:** `R/mod_run_curation.R`, `R/mod_clean_data.R` (full), `R/cleaning_reference.R` (full), `inst/app/app.R` (full), `tests/testthat/test-modules-render.R` (full), `NAMESPACE` (full)
**Pattern extraction date:** 2026-04-16
