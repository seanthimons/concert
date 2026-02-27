# Phase 1: Multi-Tab Structure - Research

**Completed:** 2026-02-26
**Status:** Ready for planning

## Current Architecture Analysis

### app.R Structure (lines 1-1127)
- **UI**: `page_sidebar()` layout with `navset_card_tab()` as main content container
- **Current tabs**: Data Preview, Detection Info, Raw Data, Curation (single tab with 3 stacked cards)
- **Sidebar**: Always visible, contains file upload, preview settings, column selection
- **Server**: Single monolithic `server` function with ~850 lines of reactive logic
- **State**: `reactiveValues()` data store with raw, clean, detection, file_info, selected_columns, column_tags, curation_results, curation_report, curation_status

### Current Curation Tab (app.R lines 198-273)
The existing Curation tab contains 3 stacked `card()` elements:
1. **Step 1: Tag Columns** - Column tagging dropdowns + Apply Tags button (card with bg-info header)
2. **Step 2: Run Curation** - Summary + Start Curation button + progress (card with bg-success header, uses `conditionalPanel` on `output.tags_applied`)
3. **Step 3: Review Results** - Stats + data table + download button (card with bg-warning header, uses `conditionalPanel` on `output.curation_completed`)

### Key UI Components to Migrate

| Component | Current Location | Target Tab | Input/Output IDs |
|-----------|-----------------|------------|------------------|
| Column tagging dropdowns | Curation card 1 | Tag Columns | `column_tagging_ui`, `tag_*` inputs |
| Apply Tags button | Curation card 1 | Tag Columns | `apply_tags` |
| Curation summary | Curation card 2 | Run Curation | `curation_summary` |
| Start Curation button | Curation card 2 | Run Curation | `run_curation` |
| Curation progress | Curation card 2 | Run Curation | `curation_progress` |
| Curation statistics | Curation card 3 | Review Results | `curation_stats` |
| Results data table | Curation card 3 | Review Results | `curation_table` |
| Download button | Curation card 3 | Review Results | `download_curated` |

### R/curation.R Module (lines 1-165)
- `validate_cas_numbers()` - CAS validation using ComptoxR
- `lookup_chemical_names()` - CompTox name search via `ct_search()`
- `curate_chemical_data()` - Main pipeline: processes CAS + Name columns, returns curated_data + report
- **No UI code** in this module - all UI is in app.R

## Technical Research

### bslib Tab Architecture

**Current**: `navset_card_tab()` wraps tabs in a card container (adds visual border + padding)

**Required**: `navset_tab()` or `navset_underline()` for full-width tabs without card wrapper. Per CONTEXT.md decision: "Full-stretch content width (100% of available space, no max-width container)" and "All tabs use full available space without nested card containers."

**Key insight**: `page_sidebar()` + `navset_card_tab()` nests content inside a card, which constrains width. Switching to `navset_tab()` removes the card wrapper. Alternative: use `navset_underline()` for a cleaner visual without card chrome.

### Sidebar Visibility Control

CONTEXT.md decision: "Sidebar hidden on curation tabs (Tag Columns, Run Curation, Review Results) for maximum space; sidebar visible on upload/detection tabs."

**Implementation approaches:**
1. **JavaScript-based**: Use `shinyjs::runjs()` to toggle sidebar visibility when tab changes. Observe `input$main_tabs` and show/hide sidebar via CSS class manipulation.
2. **bslib layout_sidebar**: Use `sidebar_toggle()` from bslib to programmatically open/close sidebar.
3. **CSS-only**: Use custom CSS with `display: none` on sidebar based on a body class.

**Recommended**: Use `sidebar_toggle()` from bslib (if available in v0.6+) combined with observing `input$main_tabs`. The sidebar already has show/hide behavior in bslib's `page_sidebar()`. We can call `sidebar_toggle("sidebar_id")` from server when tab switches. If `sidebar_toggle` is not available, fall back to JS approach with `shinyjs::toggle()` targeting the sidebar element.

### bsicons for Tab Icons

CONTEXT.md: "Icons + labels on all tabs (using bsicons)"

Available bsicons that fit:
- Tag Columns: `bs_icon("tags")` or `bs_icon("tag")`
- Run Curation: `bs_icon("play-circle")` or `bs_icon("gear")`
- Review Results: `bs_icon("clipboard-check")` or `bs_icon("bar-chart")`
- Data Preview: already uses `bs_icon("table")`
- Detection Info: already uses `bs_icon("search")`
- Raw Data: already uses `bs_icon("file-text")`

### Empty State Pattern

CONTEXT.md: "Empty state: centered message with icon ('Upload a file to start tagging columns')"

Pattern:
```r
div(
  class = "text-center text-muted py-5",
  bsicons::bs_icon("upload", size = "3em"),
  h4("Upload a file to start tagging columns"),
  p("Upload a CSV or XLSX file and it will appear here for tagging.")
)
```

### Tag Columns Layout Change

CONTEXT.md: "Table-based interface: one row per uploaded column, with a dropdown to assign type"

Current implementation uses vertical `selectInput()` list (one dropdown per column stacked vertically). Need to convert to a table layout where each row is: Column Name | Dropdown | (optional sample values).

CONTEXT.md also says: "Show column names only -- no data preview/sample values in the tagging table."

Implementation: Use a simple HTML table or `layout_columns()` grid. Each row: column name label + selectInput dropdown.

### Action Button Positioning

CONTEXT.md: "Apply Tags button positioned top-right in a header area above the table" and "Download Excel button positioned top-right above the results table."

Pattern: Use `div(class = "d-flex justify-content-between align-items-center mb-3")` to create a header row with title on left and button on right.

### Pre-curation Summary

CONTEXT.md: "Pre-curation summary shows which columns are tagged as what (e.g., 'Chemical Name: column_a, CASRN: column_b')"

This already exists as `output$curation_summary` (app.R lines 902-918). Needs reformatting to show actual column names mapped to types.

### Auto-navigation After Curation

CONTEXT.md: "After curation completes, auto-navigate to Review Results tab"

Implementation: In the `observeEvent(input$run_curation, ...)` handler, after successful curation, call `nav_select("main_tabs", "Review Results")` to programmatically switch tabs.

### Start Curation Button Disabled State

CONTEXT.md: "Start Curation button disabled until prerequisites are met (grayed out with tooltip)"

Use `shinyjs::disable("run_curation")` / `shinyjs::enable("run_curation")` based on tags state. Add tooltip via `bslib::tooltip()` or HTML title attribute.

### Value Boxes in Review Results

CONTEXT.md: "Value boxes row at top using bslib value_box() for statistics"

Already implemented as `output$curation_stats` (app.R lines 993-1017) with 2 value boxes. Move these out of the card wrapper into the tab's top-level layout.

### Focused Results Table

CONTEXT.md: "Focused results table showing: user's original input (submitted name, submitted CASRN) alongside CompTox output (preferred name, CASRN, DTXSID)"

Current curation_results from `curate_chemical_data()` returns: original_value, column_type, original_column, row_id, validated_cas, is_valid (for CAS), dtxsid, preferredName, casrn, match_status, match_confidence (for Names).

Need to reshape for display: select relevant columns only (original input + CompTox output).

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `navset_tab()` may not play well with `page_sidebar()` | UI breaks | Test minimal example first; fallback to `navset_card_tab()` with CSS overrides to remove card styling |
| Sidebar toggle may cause layout jumps | Poor UX | Use CSS transition for smooth show/hide; test on different screen sizes |
| Tab IDs change when moving from single Curation tab to 3 tabs | Server logic breaks | All input/output IDs stay the same; only the UI container changes |
| Dynamic dropdowns in table layout may have rendering issues | Tagging breaks | Test with varying column counts (1-20+); use `renderUI` as fallback |
| `nav_select()` for auto-navigation may not work with renamed tabs | Auto-nav fails | Use tab `value` parameter explicitly instead of relying on title matching |

## File Modification Map

| File | Changes | Scope |
|------|---------|-------|
| `app.R` (UI section) | Replace single Curation `nav_panel` with 3 new `nav_panel`s; change `navset_card_tab` to `navset_tab`; add sidebar toggle logic | Major |
| `app.R` (Server section) | Add sidebar toggle observer on `input$main_tabs`; add auto-navigate after curation; restructure curation progress UI; add disabled button logic | Moderate |
| `R/curation.R` | No changes needed - business logic stays the same | None |
| `R/file_handlers.R` | No changes needed | None |
| `R/data_detection.R` | No changes needed | None |

## Implementation Sequence

1. **Wave 1**: Restructure UI - Replace navset_card_tab with navset_tab/navset_underline, split Curation into 3 tabs, add icons
2. **Wave 2**: Wire up interactivity - Sidebar toggle, empty states, disabled button logic, auto-navigation, table-based tagging layout, action button positioning

Wave 1 is purely structural (move HTML around). Wave 2 adds behavioral polish. Both waves modify app.R only.

## RESEARCH COMPLETE
