# Architecture Research: Tab Gating in Shiny Workflow Apps

**Domain:** R Shiny bslib multi-step workflow with gated tab access
**Researched:** 2026-02-26
**Confidence:** HIGH

## Problem Statement

How should a Shiny app be restructured when breaking a monolithic tab (with 3 stacked cards) into 3 separate top-level tabs with gated access? Specifically: transforming a single "Curation" tab containing Tag Columns → Run Curation → Review Results into 3 independent top-level tabs where users cannot access downstream tabs until upstream actions complete.

## Recommended Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer (bslib)                      │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │  Data    │  │ Detection│  │   Raw    │  │ Curation │    │
│  │ Preview  │  │   Info   │  │   Data   │  │  Tabs    │    │
│  │  (base)  │  │  (base)  │  │  (base)  │  │ (gated)  │    │
│  └──────────┘  └──────────┘  └──────────┘  └────┬─────┘    │
│                                                   │          │
│  ┌───────────────────────────────────────────────┘          │
│  │                                                           │
│  ├──► Tab 1: Tag Columns (nav_panel)                        │
│  │    - Always visible after data upload                    │
│  │    - Enables: tags_applied = TRUE                        │
│  │                                                           │
│  ├──► Tab 2: Run Curation (nav_panel_hidden initially)      │
│  │    - Shown via nav_show() when tags_applied == TRUE      │
│  │    - Enables: curation_completed = TRUE                  │
│  │                                                           │
│  └──► Tab 3: Review Results (nav_panel_hidden initially)    │
│       - Shown via nav_show() when curation_completed == TRUE│
│                                                              │
├──────────────────────────────────────────────────────────────┤
│                    Reactive State Layer                      │
├──────────────────────────────────────────────────────────────┤
│  reactiveValues(                                             │
│    raw, clean, detection, file_info,  # Existing state      │
│    selected_columns, column_tags,     # Tag step state      │
│    curation_results, curation_report, # Curation state      │
│    curation_status,                   # Status tracking     │
│    tabs_unlocked                      # NEW: Tab gate state │
│  )                                                           │
├──────────────────────────────────────────────────────────────┤
│                    Business Logic Layer                      │
├──────────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────────┐  │
│  │  R/curation.R: Pure Functions                          │  │
│  │  - validate_cas_numbers()                              │  │
│  │  - lookup_chemical_names()                             │  │
│  │  - curate_chemical_data()                              │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Communicates With |
|-----------|----------------|-------------------|
| **Base Tabs** (Data Preview, Detection Info, Raw Data) | Display uploaded data, detection metadata, raw file contents | Shared `data_store` reactiveValues |
| **Tag Columns Tab** | Column tagging UI, apply tags action | `data_store$column_tags`, enables Run Curation tab |
| **Run Curation Tab** | Initiate curation API calls, show progress | `R/curation.R` functions, `data_store$curation_results` |
| **Review Results Tab** | Display curated data, export controls | `data_store$curation_results`, download handler |
| **reactiveValues Store** | Central state container | All observers and reactive expressions |
| **Tab Gate Observers** | Control tab visibility via `nav_show()` | `data_store$tabs_unlocked`, bslib nav functions |
| **Business Logic** (R/curation.R) | Pure data transformations, API calls | Server observers (called with `data_store` values) |

## Architectural Patterns

### Pattern 1: Hidden Tabs with Reactive Gating

**What:** Start tabs hidden using `nav_panel_hidden()`, then reveal them conditionally with `nav_show()` based on reactive state flags.

**When to use:** Multi-step workflows where downstream steps require upstream completion (e.g., can't run curation until tags applied).

**Trade-offs:**
- ✅ Prevents user confusion from empty states
- ✅ Enforces correct workflow order
- ✅ Native bslib pattern (no custom CSS/JS)
- ⚠️ Requires careful state tracking to prevent "stuck" UI
- ⚠️ Once shown, tabs remain visible (can't re-hide without `nav_hide()` logic)

**Example:**
```r
# UI Definition
ui <- page_sidebar(
  navset_card_tab(
    id = "main_tabs",

    # Always visible
    nav_panel(
      title = "Tag Columns",
      value = "tag_columns",
      icon = bs_icon("tag"),
      # ... tagging UI ...
      actionButton("apply_tags", "Apply Tags")
    ),

    # Hidden until tags applied
    nav_panel_hidden(
      title = "Run Curation",
      value = "run_curation",
      icon = bs_icon("play"),
      # ... curation UI ...
      actionButton("run_curation", "Start Curation")
    ),

    # Hidden until curation completes
    nav_panel_hidden(
      title = "Review Results",
      value = "review_results",
      icon = bs_icon("check-circle"),
      # ... results UI ...
    )
  )
)

# Server Logic
server <- function(input, output, session) {
  data_store <- reactiveValues(
    column_tags = NULL,
    curation_results = NULL,
    tabs_unlocked = list(
      run_curation = FALSE,
      review_results = FALSE
    )
  )

  # Gate 1: Unlock Run Curation after tags applied
  observeEvent(input$apply_tags, {
    req(input$selected_columns)

    # Apply tags logic...
    data_store$column_tags <- # ... tag data ...

    # Unlock tab
    if (!data_store$tabs_unlocked$run_curation) {
      nav_show("main_tabs", target = "run_curation", select = TRUE)
      data_store$tabs_unlocked$run_curation <- TRUE

      showNotification("Tags applied! Proceed to Run Curation.", type = "success")
    }
  })

  # Gate 2: Unlock Review Results after curation completes
  observeEvent(input$run_curation, {
    req(data_store$column_tags)

    # Run curation logic...
    data_store$curation_results <- curate_chemical_data(...)

    # Unlock tab
    if (!data_store$tabs_unlocked$review_results) {
      nav_show("main_tabs", target = "review_results", select = TRUE)
      data_store$tabs_unlocked$review_results <- TRUE

      showNotification("Curation complete! Review results.", type = "success")
    }
  })
}
```

**Key Implementation Details:**
- `nav_panel_hidden()` takes same parameters as `nav_panel()` but starts invisible
- `nav_show(id, target, select = TRUE)` reveals tab and optionally switches to it
- Track unlock state in `data_store$tabs_unlocked` to prevent redundant `nav_show()` calls
- Use `value` parameter on nav panels for programmatic reference (not just title)

### Pattern 2: Reactive State Store with Workflow Flags

**What:** Use a single `reactiveValues()` object as central state store, including explicit workflow stage flags.

**When to use:** Any multi-step Shiny workflow where multiple observers/outputs need to coordinate.

**Trade-offs:**
- ✅ Single source of truth for all state
- ✅ Easy to debug (inspect `data_store` in debugger)
- ✅ Prevents scattered reactive state across multiple `reactiveVal()` objects
- ⚠️ Can become large; consider grouping related state into nested lists
- ⚠️ No automatic change detection for nested lists (must replace entire list to trigger reactivity)

**Example:**
```r
data_store <- reactiveValues(
  # Existing state (from upload/detection)
  raw = NULL,
  clean = NULL,
  detection = NULL,
  file_info = NULL,

  # Step 1: Tag Columns
  selected_columns = NULL,
  column_tags = NULL,          # Named list: col_name -> "Name"|"CASRN"|"Other"

  # Step 2: Run Curation
  curation_results = NULL,     # Output from curate_chemical_data()
  curation_report = NULL,      # Summary stats
  curation_status = NULL,      # "idle", "running", "complete", "error"

  # Workflow control
  tabs_unlocked = list(
    run_curation = FALSE,
    review_results = FALSE
  )
)
```

**Best Practices:**
- Group related state (e.g., `tabs_unlocked` as a list)
- Use explicit status enums (`"idle"`, `"running"`, `"complete"`) over boolean flags
- Initialize all fields in `reactiveValues()` to avoid NULL checks everywhere
- Document expected data structures in comments

### Pattern 3: Conditional UI with `conditionalPanel`

**What:** Use `conditionalPanel()` to show/hide UI elements within a tab based on reactive outputs.

**When to use:** For fine-grained control within a single tab (e.g., hiding "Start Curation" button until tags applied).

**Trade-offs:**
- ✅ No server-side logic needed for simple show/hide
- ✅ Animates in browser (smoother than `uiOutput`/`renderUI`)
- ⚠️ Uses JavaScript conditions (must expose reactive value via `outputOptions(suspendWhenHidden = FALSE)`)
- ⚠️ Can become verbose with complex conditions

**Example:**
```r
# UI
nav_panel(
  title = "Run Curation",

  conditionalPanel(
    condition = "output.tags_applied",

    actionButton("run_curation", "Start Curation"),
    uiOutput("curation_progress")
  ),

  conditionalPanel(
    condition = "!output.tags_applied",

    div(
      class = "alert alert-warning",
      "Apply column tags before running curation."
    )
  )
)

# Server
output$tags_applied <- reactive({
  !is.null(data_store$column_tags) && length(data_store$column_tags) > 0
})
outputOptions(output, "tags_applied", suspendWhenHidden = FALSE)
```

**When to Prefer Over `nav_panel_hidden()`:**
- Showing/hiding elements **within** a tab (not the tab itself)
- Simple conditions (e.g., "show if not null")
- Need smooth CSS transitions (browser-rendered)

**When to Use `nav_panel_hidden()` Instead:**
- Hiding entire tabs from tab bar
- Multi-step workflows with sequential unlocking
- Server-side authorization logic (e.g., role-based access)

### Pattern 4: Separation of Business Logic from Reactivity

**What:** Keep pure business functions (data transformations, API calls) in separate R files, called from reactive observers.

**When to use:** Always, for any non-trivial Shiny app.

**Trade-offs:**
- ✅ Testable without Shiny session
- ✅ Reusable across apps
- ✅ Clear separation of concerns
- ⚠️ Requires discipline (easy to put logic in observers)

**Example:**
```r
# R/curation.R (Pure functions, no reactivity)
curate_chemical_data <- function(clean_data, column_tags) {
  # ... business logic ...
  list(
    curated_data = curated_df,
    report = report_stats
  )
}

# app.R (Server observers call pure functions)
observeEvent(input$run_curation, {
  req(data_store$clean, data_store$column_tags)

  data_store$curation_status <- "running"

  tryCatch({
    # Call pure function
    result <- curate_chemical_data(
      clean_data = data_store$clean,
      column_tags = data_store$column_tags
    )

    # Store results
    data_store$curation_results <- result$curated_data
    data_store$curation_report <- result$report
    data_store$curation_status <- "complete"

    # Unlock next tab
    nav_show("main_tabs", target = "review_results", select = TRUE)

  }, error = function(e) {
    data_store$curation_status <- "error"
    showNotification(paste("Curation failed:", e$message), type = "error")
  })
})
```

**Benefits:**
- Unit test `curate_chemical_data()` with test fixtures
- Use in RMarkdown reports or other scripts
- Easier to refactor (no Shiny-specific code)

## Data Flow

### Upload → Detection → Tagging → Curation → Review

```
[File Upload]
    ↓
[safely_read_file()] → data_store$raw
    ↓
[detect_data_start()] → data_store$detection
    ↓
[extract_clean_data()] → data_store$clean
    ↓
[User: Select Columns] → data_store$selected_columns
    ↓
[User: Apply Tags] → data_store$column_tags
    ↓ (triggers nav_show("run_curation"))
[User: Start Curation]
    ↓
[curate_chemical_data()] → data_store$curation_results
    ↓ (triggers nav_show("review_results"))
[User: Download Curated Data]
    ↓
[Excel Export with sheets]
```

### Reactive Dependency Chain

```
data_store$raw
    ↓
data_store$clean (filtered by selected_columns)
    ↓
filtered_data (reactive expression)
    ↓
output$data_table (DT table)

data_store$column_tags
    ↓
output$tags_applied (reactive boolean)
    ↓
conditionalPanel visibility
    ↓
nav_show("run_curation") observer

data_store$curation_results
    ↓
output$curation_completed (reactive boolean)
    ↓
nav_show("review_results") observer
    ↓
output$curation_table (DT table)
```

### State Transitions

```
State 1: Initial
- All tabs: Data Preview, Detection Info, Raw Data visible
- Tag Columns: visible
- Run Curation: hidden
- Review Results: hidden

↓ [Apply Tags Button]

State 2: Tags Applied
- Run Curation: revealed via nav_show(), auto-selected
- data_store$tabs_unlocked$run_curation = TRUE

↓ [Start Curation Button]

State 3: Curation Running
- data_store$curation_status = "running"
- Progress indicator shown

↓ [Curation API completes]

State 4: Curation Complete
- Review Results: revealed via nav_show(), auto-selected
- data_store$tabs_unlocked$review_results = TRUE
- Download button enabled
```

## Component Boundaries (What Moves Where)

### Current Structure (app.R, lines 197-273)
```r
nav_panel(
  title = "Curation",

  # Card 1: Tag Columns
  card(...),

  # Card 2: Run Curation
  card(...),

  # Card 3: Review Results
  card(...)
)
```

### New Structure

**Tab 1: Tag Columns (lines ~197-245)**
- **Move:** Card 1 body content → `nav_panel(value = "tag_columns")`
- **Keep:** `uiOutput("column_tagging_ui")`, `actionButton("apply_tags")`
- **Remove:** Card wrapper (card is redundant when tab uses full space)
- **Add:** Instructions text at top, more whitespace

**Tab 2: Run Curation (lines ~246-265)**
- **Move:** Card 2 body content → `nav_panel_hidden(value = "run_curation")`
- **Keep:** `conditionalPanel(output.tags_applied)`, `uiOutput("curation_summary")`, `actionButton("run_curation")`
- **Remove:** Card wrapper
- **Add:** Progress bar, estimated time, cancel button (future enhancement)

**Tab 3: Review Results (lines ~266-273)**
- **Move:** Card 3 body content → `nav_panel_hidden(value = "review_results")`
- **Keep:** `conditionalPanel(output.curation_completed)`, `uiOutput("curation_stats")`, `DTOutput("curation_table")`, `downloadButton`
- **Remove:** Card wrapper
- **Add:** Summary statistics cards at top (value boxes), filter controls

**Server Changes (app.R, lines 864-1100)**
- **Modify:** `observeEvent(input$apply_tags)` → add `nav_show("run_curation")` call
- **Modify:** `observeEvent(input$run_curation)` completion → add `nav_show("review_results")` call
- **Add:** `data_store$tabs_unlocked` tracking
- **Keep:** All existing reactive logic, outputs, business function calls

**No Changes:**
- `R/curation.R` (pure business logic remains untouched)
- `R/file_handlers.R` (upload logic remains untouched)
- `R/data_detection.R` (detection logic remains untouched)

## Build Order and Dependencies

### Phase 1: Extract and Refactor Tab UI (1-2 hours)
**Goal:** Split monolithic tab into 3 separate tabs, no gating yet.

**Steps:**
1. Add `tabs_unlocked` field to `data_store` reactiveValues
2. Convert Card 1 → `nav_panel(value = "tag_columns", ...)`
3. Convert Card 2 → `nav_panel(value = "run_curation", ...)`
4. Convert Card 3 → `nav_panel(value = "review_results", ...)`
5. Test: All 3 tabs visible, existing functionality works

**Validation:**
- All existing outputs render correctly
- No JavaScript console errors
- Tab switching works
- Column tagging, curation, download still functional

### Phase 2: Implement Tab Gating (1 hour)
**Goal:** Hide tabs 2 and 3 initially, reveal conditionally.

**Steps:**
1. Change `nav_panel()` → `nav_panel_hidden()` for Run Curation and Review Results
2. Add `nav_show("main_tabs", "run_curation", select = TRUE)` to `observeEvent(input$apply_tags)`
3. Add `nav_show("main_tabs", "review_results", select = TRUE)` to curation completion logic
4. Add `tabs_unlocked` state tracking to prevent redundant `nav_show()` calls
5. Test: Tabs unlock in sequence, can't access downstream tabs prematurely

**Validation:**
- Tab 2 hidden until Apply Tags clicked
- Tab 3 hidden until curation completes
- User notifications guide workflow ("Tags applied! Proceed to Run Curation.")
- State persists on tab switches (don't lose data)

### Phase 3: UI Polish (1-2 hours)
**Goal:** Use freed-up space for better layouts.

**Steps:**
1. Remove unnecessary nested cards (tabs provide structure)
2. Add `layout_columns()` for side-by-side layouts in wider tabs
3. Add `value_box()` for key stats in Review Results
4. Increase whitespace, improve typography
5. Test: Layout responsive, readable on different screen sizes

**Validation:**
- No excessive scrolling within tabs
- Key actions (buttons) easily discoverable
- Stats/summaries visually prominent

### Dependencies

```
Phase 1 (Extract UI)
    ↓ (Must complete before Phase 2)
Phase 2 (Implement Gating)
    ↓ (Must complete before Phase 3)
Phase 3 (UI Polish)
```

**Why this order:**
1. **Phase 1 first:** Establish new tab structure without breaking existing functionality (safe refactor)
2. **Phase 2 second:** Add gating logic once tabs are working independently (behavior change)
3. **Phase 3 last:** Polish UI after core functionality proven (avoid rework)

**Parallel work (optional):**
- Can write unit tests for pure functions (R/curation.R) anytime
- Can document curation logic separately

## Anti-Patterns

### Anti-Pattern 1: Using `uiOutput`/`renderUI` for Tab Gating

**What people do:** Conditionally render entire tabs with `uiOutput()` and `renderUI()` based on reactive flags.

**Why it's wrong:**
- Destroys/recreates entire UI tree (loses scroll position, input state)
- Slower than `nav_panel_hidden()` + `nav_show()` (server round-trip)
- Breaks browser back/forward navigation
- No smooth transitions

**Do this instead:** Use `nav_panel_hidden()` with `nav_show()` for programmatic tab control (native bslib pattern).

### Anti-Pattern 2: Multiple `reactiveVal()` for Workflow State

**What people do:** Track workflow state with separate `reactiveVal()` objects:
```r
tags_applied <- reactiveVal(FALSE)
curation_running <- reactiveVal(FALSE)
curation_complete <- reactiveVal(FALSE)
```

**Why it's wrong:**
- State scattered across server function
- Hard to debug (can't inspect all state at once)
- Easy to introduce inconsistencies (forgot to update one flag)

**Do this instead:** Use a single `reactiveValues()` object with structured fields:
```r
data_store <- reactiveValues(
  column_tags = NULL,
  curation_status = "idle",  # "idle", "running", "complete", "error"
  tabs_unlocked = list(...)
)
```

### Anti-Pattern 3: Re-hiding Tabs on Reset

**What people do:** Try to "reset" workflow by calling `nav_hide()` on all gated tabs.

**Why it's wrong:**
- Confusing UX (tabs disappear unexpectedly)
- User loses context of what they already completed
- Can't review earlier steps without restarting

**Do this instead:**
- Keep tabs visible once unlocked (allows revisiting steps)
- Use "Reset" button to clear data and restart workflow (full app reload or clear `data_store`)
- Show status indicators (checkmarks) on completed tabs

### Anti-Pattern 4: Business Logic in observeEvent

**What people do:** Put complex data transformations, API calls, validation logic inside `observeEvent()` blocks.

```r
observeEvent(input$run_curation, {
  # 50 lines of CAS validation, API calls, data munging...
})
```

**Why it's wrong:**
- Can't unit test without Shiny session
- Can't reuse in other contexts (scripts, reports)
- Hard to refactor (mixed concerns)

**Do this instead:** Extract pure functions to separate files (e.g., `R/curation.R`), call from observers:
```r
observeEvent(input$run_curation, {
  result <- curate_chemical_data(data_store$clean, data_store$column_tags)
  data_store$curation_results <- result
})
```

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| **UI ↔ Server** | Input bindings (`input$*`), reactive outputs (`output$*`) | Standard Shiny pattern |
| **Server ↔ Business Logic** | Function calls with plain data structures | `R/curation.R` functions accept data frames, return lists |
| **Tab Gating ↔ State** | `observeEvent()` watching `data_store` flags, calling `nav_show()` | `tabs_unlocked` prevents redundant `nav_show()` calls |
| **Tabs ↔ Shared State** | All tabs read/write to same `data_store` reactiveValues | No tab-specific state isolation |

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| **EPA CompTox API** | Via `ComptoxR` package functions | Requires `ctx_api_key` env var, handles rate limiting internally |
| **File System** | `rio`, `readxl`, `writexl` for CSV/XLSX I/O | Uploads via `fileInput()`, downloads via `downloadHandler()` |

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| **Current (single user, local)** | Existing architecture is sufficient. Single `reactiveValues()` store, synchronous API calls. |
| **10-50 concurrent users (Shiny Server)** | Add async API calls with `promises`/`future` to prevent blocking. Add session-level caching of API results. |
| **100+ concurrent users (ShinyProxy/K8s)** | Move to stateless design: store `data_store` in database (PostgreSQL) or Redis, keyed by session ID. Use Shiny modules for better code organization. |

### Scaling Priorities

1. **First bottleneck:** CompTox API rate limits
   - **Solution:** Implement caching layer (DuckDB or SQLite) for previously curated chemicals
   - **When:** If >50 unique chemicals/day being re-curated

2. **Second bottleneck:** Large file uploads (>50MB) blocking UI
   - **Solution:** Add async file processing with `future`, show real-time progress bar
   - **When:** If users complain of UI freezing during upload

## Sources

**High Confidence:**
- [bslib Navigation Containers (Context7)](https://context7.com/rstudio/bslib/llms.txt) — nav_panel_hidden, nav_show, nav_select patterns
- [Dynamically Update Nav Containers (bslib docs)](https://rstudio.github.io/bslib/reference/nav_select.html) — official nav_select, nav_show, nav_hide documentation
- [Navigation Items Reference (bslib docs)](https://rstudio.github.io/bslib/reference/nav-items.html) — nav_panel_hidden usage

**Medium Confidence:**
- [Shiny Reactive Values Guide (datanovia)](https://www.datanovia.com/learn/tools/shiny-apps/server-logic/reactive-values.html) — reactiveValues patterns and best practices
- [Mastering Shiny Chapter 15 (Hadley Wickham)](https://mastering-shiny.org/reactivity-objects.html) — reactive building blocks
- [Shiny App Structure Guide (datanovia)](https://www.datanovia.com/learn/tools/shiny-apps/fundamentals/app-structure.html) — UI-server architecture patterns
- [Conditional Panel Guide (Posit Community)](https://forum.posit.co/t/conditional-tabbox-with-shinydashboard/1991) — conditional tab patterns
- [Mastering Shiny Chapter 10 (Hadley Wickham)](https://mastering-shiny.org/action-dynamic.html) — dynamic UI patterns

**Low Confidence (verification recommended):**
- [Effective State Management in Shiny Modules (Jakub Sobolewski)](https://jakubsobolewski.com/blog/the-other-way-of-lifting-state-up-from-shiny-modules/) — advanced module patterns (not needed for this project, but useful reference)

---
*Architecture research for: ChemReg tab refactoring*
*Researched: 2026-02-26*
*Next: This informs phase structure in roadmap (3 phases: Extract UI → Implement Gating → Polish)*
