# Stack Research: Gated Multi-Tab Curation Workflow

**Domain:** R Shiny multi-step workflow UI with gated tab navigation
**Researched:** 2026-02-26
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **bslib** | 0.9.0 | Navigation framework | Official RStudio/Posit framework with native nav_show/nav_hide functions for programmatic tab control. Provides page_navbar, page_sidebar, navset_tab with built-in support for conditional tab visibility. Bootstrap 5.3.1 foundation ensures modern, accessible UI. |
| **shinyjs** | 2.1.0 | UI element state control | Complements bslib for enabling/disabling UI elements within tabs. Essential for form validation patterns and progressive disclosure. Already in project dependencies. |
| **shiny** | ≥1.12.1 | Reactive framework | Core framework - already in use. Provides reactiveValues, observe, observeEvent for state management. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **bsicons** | Latest | Tab icons | Add visual clarity to tab navigation (e.g., checkmark for completed steps). Already in project. |
| **DT** | Latest | Data tables in tabs | Display curation results. Already in project. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| testthat | Unit testing | Already installed. Test tab gating logic with reactive state changes. |
| air | Code formatting | Already configured (air.toml exists). |

## Installation

```r
# All required packages already in project dependencies
# Verify current versions:
packageVersion("bslib")    # Should be ≥ 0.9.0
packageVersion("shinyjs")  # Should be ≥ 2.1.0
packageVersion("shiny")    # Should be ≥ 1.12.1

# If updates needed (via existing load_packages.R):
source("load_packages.R")
```

## Recommended Approach for Gated Navigation

### Pattern 1: nav_show/nav_hide (RECOMMENDED)

**What:** Use bslib's native `nav_show()` and `nav_hide()` functions to conditionally display tabs based on reactive state.

**When:** Best for this project's use case - gated workflow where tabs become available as prerequisites are met.

**Why preferred:**
- **Native bslib support**: These functions are designed specifically for this use case
- **Preserves module state**: Unlike nav_insert/nav_remove, doesn't destroy/recreate module instances
- **Accessible**: Properly manages keyboard navigation and screen reader announcements
- **No div-wrapping hacks**: Direct, clean API without workarounds

**Implementation:**

```r
# UI: Assign id to navbar, start tabs hidden
ui <- page_navbar(
  id = "main_nav",
  title = "ChemReg",

  # Always visible tabs
  nav_panel("Data Preview", value = "preview", ...),
  nav_panel("Detection Info", value = "detection", ...),
  nav_panel("Raw Data", value = "raw", ...),

  # Initially hidden workflow tabs
  nav_panel_hidden(
    "Tag Columns",
    value = "tag_columns",
    # Column tagging UI
  ),
  nav_panel_hidden(
    "Run Curation",
    value = "run_curation",
    # Curation controls UI
  ),
  nav_panel_hidden(
    "Review Results",
    value = "review_results",
    # Results display UI
  )
)

# Server: Show tabs based on state
server <- function(input, output, session) {
  # Show Tag Columns tab after data is loaded
  observe({
    req(data_store$clean)
    nav_show("main_nav", target = "tag_columns", select = TRUE)
  })

  # Show Run Curation tab after columns are tagged
  observe({
    req(data_store$column_tags)
    req(length(data_store$column_tags) > 0)
    nav_show("main_nav", target = "run_curation")
  })

  # Show Review Results tab after curation completes
  observe({
    req(data_store$curation_results)
    nav_show("main_nav", target = "review_results", select = TRUE)
  })
}
```

**Confidence:** HIGH - Verified in Context7 bslib documentation and official RStudio docs.

### Pattern 2: nav_panel_hidden + navset_hidden

**What:** Alternative pattern using `nav_panel_hidden()` within a `navset_hidden()` container, controlled by external UI elements (buttons, radio buttons).

**When:** Use when you want completely custom navigation controls (wizard-style Next/Back buttons instead of tabs).

**Why NOT recommended for this project:**
- PROJECT.md explicitly states "Wizard-style navigation with Next/Back buttons — tabs preferred"
- More complex to implement
- Loses visual tab navigation which shows workflow progress

**Confidence:** HIGH - Context7 documentation confirms this pattern exists but is for custom controls.

### Pattern 3: shinyjs toggle + div wrapping

**What:** Wrap nav_panel contents in divs and use shinyjs::show/hide.

**When:** NEVER for tab-level control.

**Why NOT to use:**
- Produces warnings about improper navigation container structure
- Breaks accessibility
- Deprecated pattern from pre-bslib era
- Community discussion confirms this is wrong approach

**Confidence:** HIGH - Explicitly discouraged in Posit Community forum.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| bslib nav_show/nav_hide | shinymgr package | Use shinymgr if building a multi-app platform with complex module dependency graphs, SQLite-backed module registry, and RDS-based reproducibility requirements. Overkill for single-app tab gating. |
| nav_panel_hidden | nav_insert/nav_remove | Use insert/remove when tabs are truly dynamic (user-generated, unknown at init time). Avoid for static workflow steps - destroys module state on removal. |
| page_navbar | page_sidebar with navset_tab | Use page_sidebar if workflow needs persistent sidebar across all tabs. Current app already uses page_sidebar, so extend with nav_show/hide. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **shiny::updateTabsetPanel** | Legacy pre-bslib function. Doesn't work with bslib navigation. Inconsistent Bootstrap 5 styling. | bslib::nav_select, nav_show, nav_hide |
| **shinyjs on nav_panel** | Wrapping tabs in divs breaks navigation container structure. Produces warnings. Poor accessibility. | bslib::nav_hide, nav_show |
| **shinymgr** | Heavyweight framework (SQLite DB, renv, shinydashboard). Last updated May 2024. Designed for multi-app platforms, not single-app tab gating. | Native bslib nav_show/nav_hide |
| **conditionalPanel with tabsetPanel** | Pre-bslib pattern. Doesn't integrate with bslib theming. Less accessible. | bslib::nav_panel_hidden + nav_show |

## Stack Patterns by Variant

**If you need visual state indicators (e.g., checkmarks on completed tabs):**
- Add `icon = bsicons::bs_icon("check-circle")` parameter to nav_panel
- Use `nav_insert()` to replace tab with icon version after completion
- Because bslib nav panels support icon parameter natively

**If you need to disable navigation back to previous steps:**
- Use `nav_hide()` on completed tabs when moving forward
- Store completed data in reactiveValues, not tab UI state
- Because hiding prevents both forward navigation and accidental back-navigation

**If workflow needs to reset (e.g., new file upload):**
- Call `nav_hide()` on all gated tabs
- Clear reactiveValues state
- Use `nav_select()` to return to first tab
- Because this preserves tab instances while resetting visibility

**If you need to programmatically advance tabs:**
- Use `nav_show("nav_id", target = "next_tab", select = TRUE)`
- The `select = TRUE` parameter both shows AND switches to the tab
- Because this creates smooth progression through workflow

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| bslib@0.9.0 | shiny@≥1.12.1 | bslib 0.9.0 requires Bootstrap 5.3.1 support in Shiny |
| bslib@0.9.0 | shinyjs@2.1.0 | No compatibility issues. Use shinyjs for within-tab element control, bslib for tab-level control. |
| bslib@0.8.0+ | page_navbar + nav_panel_hidden | Version 0.8.0 fixed keyboard-discoverability bug in nav_panel_hidden - essential for accessibility. |

## Key Functions Reference

### Tab Visibility Control

| Function | Purpose | Parameters | Example |
|----------|---------|------------|---------|
| `nav_show()` | Make hidden tab visible | id (navbar id), target (tab value), select (auto-switch), session | `nav_show("nav", "tab2", select=TRUE)` |
| `nav_hide()` | Hide visible tab | id, target, session | `nav_hide("nav", "tab2")` |
| `nav_select()` | Switch to different tab | id, selected (tab value), session | `nav_select("nav", "tab3")` |
| `nav_panel_hidden()` | Create initially hidden tab | title, value, ... (UI contents) | `nav_panel_hidden("Secret", value="s", ...)` |

### Element State Control (within tabs)

| Function | Purpose | Use Case |
|----------|---------|----------|
| `shinyjs::enable()` | Enable input element | Enable "Run Curation" button after tags applied |
| `shinyjs::disable()` | Disable input element | Disable inputs during async processing |
| `shinyjs::toggleState()` | Conditional enable/disable | `toggleState("btn", condition = input$valid)` |
| `shinyjs::show()` | Show hidden element | Progressive disclosure within a tab |
| `shinyjs::hidden()` | Wrap initially hidden elements | `hidden(div(id="advanced", ...))` |

## Implementation Notes

### For This Project Specifically

The existing app uses:
- `bslib::page_sidebar()` with sidebar layout
- `nav_panel()` for tabs within the main content area
- `reactiveValues()` data_store pattern for state

**Integration approach:**

1. **Assign id to tab container**: Add `id = "main_tabs"` to the navset containing Data Preview, Detection Info, Raw Data, Tag Columns, etc.

2. **Start workflow tabs hidden**: Convert Tag Columns, Run Curation, Review Results to `nav_panel_hidden()`.

3. **Add reactive observers**:
   - Show "Tag Columns" when `data_store$clean` populated (file uploaded & detected)
   - Show "Run Curation" when `data_store$column_tags` has at least one tag
   - Show "Review Results" when `data_store$curation_results` exists

4. **No new dependencies**: All functions available in current bslib 0.9.0 + shinyjs 2.1.0.

5. **Use shinyjs within tabs**: Enable/disable the "Run Curation" action button based on tag completeness using `toggleState()`.

### Performance Considerations

- `nav_show/hide` does NOT destroy tab contents - Shiny reactive outputs remain instantiated
- Only visible tab outputs recompute (Shiny default behavior)
- No performance penalty vs. always-visible tabs
- Reactives in hidden tabs suspend until tab becomes visible

## Sources

### HIGH Confidence (Official Documentation)

- [bslib Navigation Containers Reference](https://rstudio.github.io/bslib/reference/navset.html) — navset functions, nav_panel_hidden usage
- [bslib Dynamically Update Nav Containers](https://rstudio.github.io/bslib/reference/nav_select.html) — nav_show, nav_hide, nav_select, nav_insert, nav_remove
- [bslib Navigation Items Reference](https://rstudio.github.io/bslib/reference/nav-items.html) — nav_panel, nav_menu, nav_panel_hidden
- Context7 /rstudio/bslib — Programmatic tab control examples, nav_show/nav_hide patterns
- Context7 /daattali/shinyjs — enable, disable, toggleState, show, hide, hidden, toggle functions
- [bslib CRAN Package Page](https://cran.r-project.org/package=bslib) — Version 0.9.0, January 30, 2025
- [bslib Changelog](https://cran.r-project.org/web/packages/bslib/news/news.html) — v0.8.0 nav_panel_hidden keyboard accessibility fix
- [shinyjs CRAN Package](https://cran.r-project.org/web/packages/shinyjs/index.html) — Version 2.1.0, January 15, 2026

### MEDIUM Confidence (Community Best Practices)

- [Posit Community: Dynamically show/hide panels](https://forum.posit.co/t/bslib-page-navbar-dynamically-show-hide-panels/207882) — nav_show/hide vs. nav_insert/remove tradeoffs, preserving module state
- [Shiny App Workflows: bslib](https://b-klaver.github.io/shinyWorkflows/bslib.html) — page_navbar patterns, sidebar integration

### MEDIUM Confidence (Academic Publication)

- [The R Journal: shinymgr](https://journal.r-project.org/articles/RJ-2024-009/) — Multi-step workflow framework, published 2025, Volume 16 Issue 1
- [shinymgr CRAN](https://cran.r-project.org/web/packages/shinymgr/index.html) — Version 1.1.0, May 10, 2024

## Decision Matrix

| Requirement | bslib nav_show/hide | shinymgr | shinyjs div wrapping |
|-------------|---------------------|----------|----------------------|
| Gated tab navigation | ✅ Native support | ✅ But heavyweight | ❌ Breaks structure |
| Preserve module state | ✅ Yes | ⚠️ Complex | ⚠️ Unclear |
| No new dependencies | ✅ Already installed | ❌ Requires shinydashboard, DBI, RSQLite, renv | ✅ shinyjs exists |
| Accessibility | ✅ Proper ARIA | ✅ If implemented correctly | ❌ Poor |
| Complexity | ✅ Low - 3-5 observers | ❌ High - SQLite registry | ⚠️ Medium but wrong |
| Maintenance | ✅ Official RStudio support | ⚠️ Single maintainer, 2024 | ❌ Deprecated pattern |
| Fits existing app | ✅ Perfect fit | ❌ Architectural mismatch | ❌ Requires refactor |

**Recommendation:** Use bslib `nav_show()`/`nav_hide()` with `nav_panel_hidden()`. This is the modern, lightweight, officially supported approach that integrates seamlessly with the existing codebase.

---
*Stack research for: ChemReg gated multi-tab curation workflow*
*Researched: 2026-02-26*
*Confidence: HIGH — All core recommendations verified via Context7 and official documentation*
