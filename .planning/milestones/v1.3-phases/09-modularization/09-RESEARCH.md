# Phase 9: Modularization - Research

**Researched:** 2026-03-04
**Domain:** Shiny module architecture and refactoring patterns
**Confidence:** HIGH

## Summary

Phase 9 extracts all 6 existing tabs from app.R (currently 2,275 lines) into Shiny modules, reducing app.R to orchestration-only code (<500 lines). The current app has extensive functionality across Data Preview, Detection Info, Raw Data, Tag Columns, Run Curation, and Review Results tabs. The refactor follows the Serapeum pattern: shared `reactiveValues` store passed to modules, modules return reactive lists/functions, navigation callbacks as plain functions, auto-sourcing from R/ directory.

Shiny modules use `NS()` for namespace isolation and `moduleServer()` for server logic. Modules can accept reactive arguments and return reactive values for cross-module communication. The file upload + sidebar controls will become a standalone module (`mod_file_upload.R`), passing results to app.R which writes to the shared `data_store`. Testing uses `testServer()` for module render validation with the existing testthat framework.

**Primary recommendation:** Extract all tabs in one coordinated pass (not incremental) using one file per module in `R/modules/`, with both `mod_X_ui()` and `mod_X_server()` in each file. Follow the user's Serapeum pattern exactly: pass whole `data_store` reactiveValues object to modules, return reactive lists, use direct reactivity for cross-module refresh (no explicit trigger reactiveVals).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Follow Serapeum pattern: shared store via reactive args + module return values for cross-module communication
- Pass the whole `data_store` reactiveValues object to modules that need it — don't break into individual reactives
- Modules return reactive lists/functions that app.R wires together
- Pass navigation callbacks as plain functions (not global state awareness)
- Rely on direct `data_store` reactivity for cross-module refresh — no explicit trigger reactiveVals needed
- Modules live in `R/modules/` subfolder (separate from utility files in `R/`)
- One file per module containing both `mod_X_ui()` and `mod_X_server()` (e.g., `R/modules/mod_data_preview.R`)
- `mod_` prefix on all module function names
- Auto-source all R files recursively: `for (f in list.files("R", recursive = TRUE, pattern = "\\.R$", full.names = TRUE)) source(f)`
- Keep `data_store` as a single `reactiveValues` object, pass whole object to modules
- File upload + sidebar detection controls become their own module (`mod_file_upload.R`), not inline in app.R
- Upload module returns results that app.R writes to `data_store`
- Keep bslib `navset_tab` for tab switching — no dynamic renderUI rewrite
- Extract all 6 tabs + upload in one coordinated pass (not incremental)
- All tabs treated equally regardless of when added (v1.0 and v1.2 tabs alike)
- Verification: module render tests (testServer or shinytest2) + manual cold start of app
- Existing test suite must still pass without modification

### Claude's Discretion
- Exact module boundaries (which helpers each module internalizes vs shares)
- testServer() vs shinytest2 for module render tests
- Internal structure within each module file
- How to handle any edge cases in the upload/detection flow during extraction

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| MODL-01 | User can use all existing app functionality after codebase is refactored into Shiny modules | Module pattern preserves reactivity; testServer() validates module behavior; existing tests ensure end-to-end compatibility |
| MODL-02 | App.R is reduced to orchestration-only code (<500 lines) with each tab extracted to its own module | Current app.R is 2,275 lines; extracting 6 tabs + upload (~1,800 lines) to 7 module files leaves ~475 lines for orchestration (theme, data_store init, module calls, wiring) |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shiny | Latest (≥1.7.0) | Module framework via `NS()` and `moduleServer()` | Official Shiny module system; stable API since 1.5.0 |
| bslib | Current | Bootstrap theming (already in use) | Official successor to shinythemes; used in current app |
| testthat | ≥3.0 | Unit testing framework | Already in project; standard R test framework |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| shinytest2 | Latest | Full-app UI testing with headless Chrome | Optional for smoke tests; testServer() sufficient for module render validation |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| testthat + testServer() | shinytest2 only | testServer() is faster and more reliable for module logic; shinytest2 better for full UI integration but slower |
| One file per module | Multiple files (mod_X_ui.R, mod_X_server.R) | User decided on single-file pattern; reduces file count from 14 to 7 |

**Installation:**
```r
# All dependencies already in project
# No new packages needed for modularization
```

## Architecture Patterns

### Recommended Module Structure (R/modules/)
```
R/
├── modules/
│   ├── mod_file_upload.R       # Sidebar upload + detection controls
│   ├── mod_data_preview.R      # Data Preview tab (summary cards + table)
│   ├── mod_detection_info.R    # Detection Info tab (detection metadata)
│   ├── mod_raw_data.R          # Raw Data tab (first 20 rows)
│   ├── mod_tag_columns.R       # Tag Columns tab (column type tagging)
│   ├── mod_run_curation.R      # Run Curation tab (pipeline execution)
│   └── mod_review_results.R    # Review Results tab (resolution + export)
├── data_detection.R            # Utility: detection algorithms
├── file_handlers.R             # Utility: file I/O
├── consensus.R                 # Utility: consensus logic
└── curation.R                  # Utility: curation pipeline
```

### Pattern 1: Shiny Module with Namespace Isolation
**What:** Encapsulate UI and server logic into reusable components with `NS()` namespace wrapping
**When to use:** Every tab and the upload sidebar
**Example:**
```r
# Source: https://context7.com/rstudio/shiny/llms.txt
# R/modules/mod_data_preview.R

# Module UI function
mod_data_preview_ui <- function(id) {
  ns <- NS(id)  # Create namespace function

  tagList(
    # Summary cards
    uiOutput(ns("summary_cards")),

    # Data table (full width, no card wrapper)
    div(
      class = "mt-3",
      DTOutput(ns("data_table"))
    )
  )
}

# Module server function
mod_data_preview_server <- function(id, data_store, preview_rows) {
  moduleServer(id, function(input, output, session) {
    # Filtered data based on column selection
    filtered_data <- reactive({
      req(data_store$clean)
      selected <- data_store$selected_columns

      if (is.null(selected) || length(selected) == 0) {
        return(data_store$clean)
      }

      data_store$clean %>% select(all_of(selected))
    })

    # Output: Summary cards
    output$summary_cards <- renderUI({
      req(data_store$clean)
      # ... summary card logic ...
    })

    # Output: Data table
    output$data_table <- renderDT({
      req(data_store$clean)
      preview_data <- head(filtered_data(), preview_rows())
      # ... datatable rendering ...
    })

    # Return reactive for downstream use (optional)
    return(reactive({
      list(
        filtered_data = filtered_data(),
        row_count = nrow(filtered_data())
      )
    }))
  })
}
```

### Pattern 2: Shared State via reactiveValues Argument
**What:** Pass entire `data_store` reactiveValues object to modules; modules read/write directly
**When to use:** All modules that interact with shared state (all 7 modules)
**Example:**
```r
# Source: Derived from https://www.ardata.fr/en/post/2019/04/26/share-reactive-among-shiny-modules/
# and user's Serapeum pattern

# In app.R server:
server <- function(input, output, session) {
  # Create shared store
  data_store <- reactiveValues(
    raw = NULL,
    clean = NULL,
    detection = NULL,
    # ... other fields ...
  )

  # Pass whole data_store to modules
  upload_result <- mod_file_upload_server("upload", data_store)

  # Upload module writes to data_store when file processed
  observeEvent(upload_result$file_processed(), {
    data_store$raw <- upload_result$raw_data()
    data_store$clean <- upload_result$clean_data()
    data_store$detection <- upload_result$detection_info()
  })

  # Other modules read from data_store directly
  mod_data_preview_server("preview", data_store, reactive(input$preview_rows))
}

# In R/modules/mod_file_upload.R server:
mod_file_upload_server <- function(id, data_store) {
  moduleServer(id, function(input, output, session) {
    # Process file and return reactive results
    # DON'T write to data_store here - let app.R do it
    processed <- reactiveVal(NULL)

    observeEvent(input$file_upload, {
      # Process file...
      result <- process_uploaded_file(input$file_upload)
      processed(result)
    })

    # Return reactive list for app.R to wire
    return(list(
      file_processed = reactive({ !is.null(processed()) }),
      raw_data = reactive({ processed()$raw }),
      clean_data = reactive({ processed()$clean }),
      detection_info = reactive({ processed()$detection })
    ))
  })
}
```

### Pattern 3: Navigation Callbacks as Functions
**What:** Pass tab show/hide functions as plain function arguments, not reactive
**When to use:** Modules that trigger navigation (upload, tag, curation modules)
**Example:**
```r
# In app.R:
show_tab_with_pulse <- function(tab_value) {
  nav_show("main_tabs", target = tab_value)
  # ... pulse animation ...
}

# Pass as plain function (not wrapped in reactive())
mod_tag_columns_server("tags", data_store,
  on_tags_applied = function() {
    show_tab_with_pulse("run_curation_tab")
  }
)

# In R/modules/mod_tag_columns.R:
mod_tag_columns_server <- function(id, data_store, on_tags_applied = NULL) {
  moduleServer(id, function(input, output, session) {
    observeEvent(input$apply_tags, {
      # ... tag logic ...
      data_store$column_tags <- tags

      # Call navigation callback
      if (!is.null(on_tags_applied)) {
        on_tags_applied()
      }
    })
  })
}
```

### Pattern 4: Direct Reactivity for Cross-Module Refresh
**What:** Modules react to `data_store` changes automatically; no explicit trigger reactiveVals
**When to use:** All modules that depend on shared state
**Example:**
```r
# Module A writes to data_store
observeEvent(input$action, {
  data_store$clean <- new_clean_data
})

# Module B automatically reacts (no trigger needed)
output$table <- renderDT({
  req(data_store$clean)  # Automatically reruns when data_store$clean changes
  datatable(data_store$clean)
})

# DON'T do this (unnecessary):
# data_store$trigger_refresh <- runif(1)  # WRONG - not needed with direct reactivity
```

### Pattern 5: Auto-Source R Files Recursively
**What:** Source all .R files from R/ directory including subdirectories before UI/server definition
**When to use:** App startup (replaces individual source() calls)
**Example:**
```r
# In app.R, after library() calls:

# Load helper functions and modules
for (f in list.files("R", recursive = TRUE, pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}

# UI Definition
ui <- page_sidebar(...)

# Server Logic
server <- function(input, output, session) {...}
```

### Anti-Patterns to Avoid
- **Breaking data_store into individual reactives:** Don't do `mod_X_server("id", clean_data = reactive(data_store$clean))`. Pass whole `data_store` instead.
- **Global reactive triggers:** Don't use `data_store$trigger_refresh <- runif(1)` to force updates. Direct reactivity handles this.
- **Module-internal navigation logic:** Don't call `nav_show()` inside modules. Pass callbacks instead.
- **Inline module definitions in app.R:** Don't define module functions in app.R. Each module in separate file in R/modules/.
- **Mixing utility and module files:** Keep modules in R/modules/, utilities in R/ root.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Module namespace isolation | Manual ID prefixing with strings | `NS()` function | Handles nested modules, prevents collisions, official pattern |
| Module testing | Custom test harness with full app startup | `testServer()` | Fast, isolated, official Shiny testing API |
| Reactive value sharing | Event-based message passing system | Direct `reactiveValues` passing | Simpler, reactive graph handles updates automatically |
| File sourcing | Complex dependency tree with explicit source() | Auto-source pattern with list.files() | Works with subdirectories, fewer lines, maintainable |

**Key insight:** Shiny's reactive graph already solves cross-module communication. Don't build event buses or message passing systems on top. Pass `reactiveValues` directly and let reactivity propagate changes.

## Common Pitfalls

### Pitfall 1: Forgetting NS() Wrapping in conditionalPanel
**What goes wrong:** conditionalPanel JavaScript condition doesn't find module inputs
**Why it happens:** conditionalPanel uses JavaScript that needs module namespace
**How to avoid:** Always add `ns = ns` argument to conditionalPanel
**Warning signs:** Console errors about undefined inputs in conditionalPanel
```r
# WRONG:
conditionalPanel(
  condition = "input.detection_mode == 'manual'",
  numericInput(ns("manual_header_row"), ...)
)

# CORRECT:
conditionalPanel(
  condition = "input.detection_mode == 'manual'",
  ns = ns,  # Add this!
  numericInput(ns("manual_header_row"), ...)
)
```

### Pitfall 2: Module Return Value Not Reactive
**What goes wrong:** App.R can't observe module return values; no reactivity
**Why it happens:** Returning plain values instead of reactive expressions
**How to avoid:** Always wrap return values in `reactive()` or return existing reactives
**Warning signs:** Module return values don't trigger updates in app.R
```r
# WRONG:
mod_X_server <- function(id, data_store) {
  moduleServer(id, function(input, output, session) {
    return(list(value = input$x))  # Plain value, not reactive!
  })
}

# CORRECT:
mod_X_server <- function(id, data_store) {
  moduleServer(id, function(input, output, session) {
    return(reactive({
      list(value = input$x)  # Reactive expression
    }))
  })
}
```

### Pitfall 3: Writing to Shared data_store Inside Modules
**What goes wrong:** Makes data flow hard to trace; violates single-responsibility
**Why it happens:** Temptation to update data_store directly from module
**How to avoid:** Modules return results; app.R writes to data_store (orchestration layer)
**Warning signs:** Debugging is hard; can't tell where data_store fields are set
```r
# WRONG (in module):
observeEvent(input$upload, {
  data_store$clean <- process_file(input$upload)  # Module writes directly
})

# CORRECT (module returns, app.R writes):
# In module:
return(reactive({ process_file(input$upload) }))

# In app.R:
upload_result <- mod_upload_server("upload", data_store)
observeEvent(upload_result(), {
  data_store$clean <- upload_result()$clean  # App.R orchestrates
})
```

### Pitfall 4: Testing Modules Without session$flushReact()
**What goes wrong:** Reactive updates don't propagate in testServer() tests
**Why it happens:** testServer() doesn't auto-flush reactive graph like live sessions
**How to avoid:** Call `session$flushReact()` after setting inputs in tests
**Warning signs:** Tests fail with stale reactive values
```r
# Source: https://mastering-shiny.org/scaling-testing.html
testServer(mod_data_preview_server, args = list(data_store = test_store), {
  # Set up test data
  data_store$clean <- test_df

  session$flushReact()  # MUST flush to propagate changes!

  # Now test outputs
  expect_true(!is.null(output$data_table))
})
```

### Pitfall 5: Over-Modularizing Simple Components
**What goes wrong:** Too many tiny modules; more complexity than benefit
**Why it happens:** Reflexive modularization without considering tradeoffs
**How to avoid:** Only modularize reusable, complex, or tab-level components
**Warning signs:** Modules with <20 lines of code; modules used only once
```r
# WRONG: Over-modularization
mod_single_value_box_ui <- function(id) {
  ns <- NS(id)
  value_box(...)  # 5 lines, used once - doesn't need a module
}

# CORRECT: Inline simple components, modularize tabs
ui <- page_sidebar(
  navset_underline(
    nav_panel("Tab 1", mod_data_preview_ui("preview")),  # Tab-level module - YES
    nav_panel("Tab 2",
      value_box(...),  # Simple component - inline it
      plotOutput(...)  # Simple component - inline it
    )
  )
)
```

## Code Examples

Verified patterns from official sources:

### Module Definition (UI + Server)
```r
# Source: https://context7.com/rstudio/shiny/llms.txt
# R/modules/mod_histogram.R

# Module UI function
mod_histogram_ui <- function(id, title = "Histogram") {
  ns <- NS(id)  # Create namespace function

  tagList(
    h4(title),
    fluidRow(
      column(6,
        sliderInput(ns("bins"), "Number of bins:",
                    min = 5, max = 50, value = 25)
      ),
      column(6,
        selectInput(ns("color"), "Color:",
                    choices = c("steelblue", "coral", "forestgreen", "purple"))
      )
    ),
    plotOutput(ns("plot"), height = "250px")
  )
}

# Module server function
mod_histogram_server <- function(id, data) {
  moduleServer(id, function(input, output, session) {
    output$plot <- renderPlot({
      req(data())  # data is reactive argument
      hist(data(), breaks = input$bins, col = input$color,
           border = "white", main = "")
    })

    # Return reactive with current settings (optional)
    reactive({
      list(bins = input$bins, color = input$color)
    })
  })
}
```

### App.R Orchestration Pattern
```r
# Source: Derived from https://context7.com/rstudio/shiny/llms.txt

# app.R

# Libraries
library(shiny)
library(bslib)
# ... other libraries ...

# Auto-source all R files
for (f in list.files("R", recursive = TRUE, pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}

# UI Definition
ui <- page_sidebar(
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  title = "Modular App",

  sidebar = sidebar(
    mod_file_upload_ui("upload")
  ),

  navset_underline(
    id = "main_tabs",
    nav_panel("Preview", mod_data_preview_ui("preview")),
    nav_panel("Detection", mod_detection_info_ui("detection")),
    nav_panel("Raw Data", mod_raw_data_ui("raw"))
  )
)

# Server Logic
server <- function(input, output, session) {
  # Create shared state
  data_store <- reactiveValues(
    raw = NULL,
    clean = NULL,
    detection = NULL
  )

  # Helper for navigation
  show_tab <- function(tab_value) {
    nav_show("main_tabs", target = tab_value)
  }

  # Initialize modules
  upload_result <- mod_file_upload_server("upload", data_store)

  # Wire upload results to data_store
  observeEvent(upload_result$file_processed(), {
    if (upload_result$file_processed()) {
      data_store$raw <- upload_result$raw_data()
      data_store$clean <- upload_result$clean_data()
      data_store$detection <- upload_result$detection_info()
      show_tab("detection")  # Show detection tab after upload
    }
  })

  # Initialize display modules (they read from data_store directly)
  mod_data_preview_server("preview", data_store)
  mod_detection_info_server("detection", data_store)
  mod_raw_data_server("raw", data_store)
}

shinyApp(ui, server)
```

### Testing Modules with testServer()
```r
# Source: https://mastering-shiny.org/scaling-testing.html
# tests/test_module_data_preview.R

library(testthat)
library(shiny)

# Source module
source(here::here("R", "modules", "mod_data_preview.R"))

test_that("Data preview module renders table", {
  # Create test data store
  test_store <- reactiveValues(
    clean = tibble::tibble(
      chemical = c("Acetone", "Ethanol"),
      cas = c("67-64-1", "64-17-5")
    ),
    selected_columns = c("chemical", "cas")
  )

  testServer(
    mod_data_preview_server,
    args = list(
      data_store = test_store,
      preview_rows = reactive(10)
    ),
    {
      # Flush reactive graph
      session$flushReact()

      # Test that outputs exist
      expect_true(!is.null(output$summary_cards))
      expect_true(!is.null(output$data_table))

      # Test module return value
      result <- session$getReturned()()
      expect_equal(result$row_count, 2)
    }
  )
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual ID prefixing | `NS()` function with `moduleServer()` | Shiny 1.5.0 (2020) | Simplified module creation; namespace isolation automatic |
| shinytest (Selenium-based) | shinytest2 (Chrome DevTools) + testServer() | shinytest2 released 2022 | Faster, more reliable tests; testServer() for module logic, shinytest2 for UI integration |
| Individual source() calls | Auto-source with list.files(recursive = TRUE) | Community pattern (2018+) | Scales to subdirectories; fewer lines in app.R |

**Deprecated/outdated:**
- **callModule()**: Replaced by `moduleServer()` in Shiny 1.5.0. Don't use callModule() in new code.
- **shinytest (v1)**: Superseded by shinytest2. Original shinytest uses Selenium (slower, less reliable).

## Open Questions

1. **How to handle gated navigation (nav_hide/nav_show) during modularization?**
   - What we know: Current app uses `nav_hide("main_tabs", target = "tab_value")` to hide tabs on startup, shows tabs after prerequisites met
   - What's unclear: Whether to centralize all navigation logic in app.R or distribute to modules
   - Recommendation: Centralize in app.R. Create `show_tab_with_pulse()` helper in app.R, pass as callback to modules. Keeps navigation state in one place (single source of truth).

2. **How to test that module UIs render without errors?**
   - What we know: testServer() tests module server logic but doesn't render UI
   - What's unclear: Whether shinytest2 AppDriver is needed or if testServer() + manual smoke test is sufficient
   - Recommendation: Use testServer() for module server logic (fast, reliable). Manual cold start of app for smoke test (Success Criterion 1). Skip shinytest2 unless UI rendering bugs found in smoke test.

3. **Should helper functions like `recalc_consensus_summary()` move into modules or stay in R/?**
   - What we know: Helper lives at top-level of app.R (line 376), used by Review Results module
   - What's unclear: General principle for which helpers move into module files vs R/ utility files
   - Recommendation: If used by only one module, move into module file as internal function. If shared by 2+ modules, keep in R/ utility file. `recalc_consensus_summary()` only used by Review Results → move into `mod_review_results.R`.

## Validation Architecture

> Workflow.nyquist_validation is not present in .planning/config.json (defaults to true), so including this section.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat ≥3.0 |
| Config file | none — tests in tests/ directory with test_*.R pattern |
| Quick run command | `testthat::test_file("tests/test_module_X.R")` |
| Full suite command | `testthat::test_dir("tests")` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MODL-01 | All existing app functionality works after modularization | regression | `testthat::test_dir("tests")` (existing tests) | ✅ tests/test_*.R (3 files) |
| MODL-01 | Modules render without error | unit | `testthat::test_file("tests/test_modules_render.R")` | ❌ Wave 0 |
| MODL-02 | App.R is <500 lines | manual | `wc -l app.R` (verify in PR) | N/A (manual check) |
| MODL-02 | Each tab exists as module in R/modules/ | manual | `ls R/modules/` (verify 7 files) | N/A (manual check) |

### Sampling Rate
- **Per task commit:** `testthat::test_file("tests/test_modules_render.R")` (quick module render validation)
- **Per wave merge:** `testthat::test_dir("tests")` (full suite including existing tests)
- **Phase gate:** Full suite green + manual smoke test (cold start app, all 6 tabs render, no console errors) before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/test_modules_render.R` — covers MODL-01 module render validation
  - testServer() for each of 7 modules (upload, data_preview, detection_info, raw_data, tag_columns, run_curation, review_results)
  - Verify module server doesn't error with mock data_store
  - Verify module return values are reactive (where applicable)
- [ ] No new test infrastructure needed — testthat already installed and working

## Sources

### Primary (HIGH confidence)
- /rstudio/shiny - Shiny modules with `NS()` and `moduleServer()` patterns, conditionalPanel scoping
- /hadley/mastering-shiny - Module design patterns, reactive expressions, testServer() testing, state management
- https://rstudio.github.io/shiny/reference/testServer.html - Official testServer() API reference
- https://mastering-shiny.org/scaling-testing.html - Module testing with testServer(), flush reactive graph requirement

### Secondary (MEDIUM confidence)
- https://www.ardata.fr/en/post/2019/04/26/share-reactive-among-shiny-modules/ - Sharing reactiveValues between modules pattern
- https://engineering-shiny.org/structuring-project.html - R/ directory structure for modules, file organization best practices
- https://www.datanovia.com/learn/tools/shiny-apps/best-practices/code-organization.html - File size guidelines (<500 lines per file), module vs inline component decision criteria

### Tertiary (LOW confidence)
None — all findings verified with official documentation or high-reputation sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official Shiny APIs stable since 1.5.0; testServer() in official docs
- Architecture: HIGH - Patterns verified in Context7 + Mastering Shiny; auto-source pattern widely used
- Pitfalls: HIGH - NS() conditionalPanel issue documented in official changelog; testServer() flush requirement in official testing guide

**Research date:** 2026-03-04
**Valid until:** 2026-04-04 (30 days - stable ecosystem, no major Shiny updates expected)
