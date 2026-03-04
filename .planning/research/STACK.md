# Technology Stack: v1.3 Data Cleaning Pipeline

**Project:** ChemReg
**Milestone:** v1.3 Data Cleaning Pipeline
**Researched:** 2026-03-04
**Overall Confidence:** HIGH

## Executive Summary

The v1.3 milestone requires **minimal new dependencies** — only 2 packages need to be added to support the new features. The existing stack (R/Shiny, bslib, DT, rio/readxl, ComptoxR, stringi via stringr/tidyverse) already provides most capabilities needed. The two additions are:

1. **openxlsx2** — For multi-sheet Excel export with metadata sheets (replaces writexl for export only)
2. **rhandsontable** — For editable reference lists UI (stop words, block lists, etc.)

All other requirements (unicode detection, progress tracking, re-import detection) are satisfied by existing packages or simple custom logic.

**What's new for v1.3:**
- Multi-sheet Excel export with audit trail, reference lists, and manifest (openxlsx2)
- Editable reference lists (stop words, block lists, functional categories, food names) via rhandsontable
- Re-import detection using existing readxl + custom manifest parsing
- Pipeline progress tracking using existing withProgress()
- Unicode detection using existing stringi (via tidyverse)

**What's NOT changing:**
- Core framework (R/Shiny, bslib, DT, ComptoxR)
- Import logic (readxl remains for reading Excel files)
- Progress tracking approach (withProgress() pattern already established)

---

## Recommended Stack Additions

### Excel Export: openxlsx2

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **openxlsx2** | Latest (≥1.13+) | Multi-sheet Excel export with metadata | **Only package that supports:** writing arbitrary metadata sheets (audit trail, reference lists, config), setting workbook properties (creator, title, description), and reading those sheets back on re-import. writexl only supports simple data frame → sheet mapping. |

**Installation:**
```r
pak::pkg_install("openxlsx2")
```

**Integration points:**
- Use **openxlsx2** for export only (app.R Excel download handler)
- Keep **readxl** for import (already handles multi-sheet reading via `readxl::excel_sheets()`)
- Keep **rio** as fallback reader for CSV/other formats
- **writexl** can be removed from dependencies (no longer needed)

**Key functions needed:**
```r
wb <- wb_workbook()                     # Create workbook object
wb <- wb_add_worksheet(wb, "Data")      # Add sheets
wb <- wb_add_data(wb, "Data", df)       # Write data frames
wb <- wb_set_properties(wb, creator = "ChemReg", title = "...", ...)  # Metadata
wb_save(wb, "file.xlsx")                # Save to disk or temp file for download
```

**Why NOT writexl for this use case:**
- writexl is faster but **only supports data frames → sheets** mapping
- writexl has **zero styling or metadata support** (by design — it's minimal on purpose)
- We need to write non-dataframe sheets (config lists, audit metadata) and set workbook properties for re-import detection

**Sources:**
- [openxlsx2 Package Manual](https://cran.r-universe.dev/openxlsx2/doc/manual.html)
- [R-bloggers: Comparing R Packages for Writing Excel Files](https://www.r-bloggers.com/2023/05/comparing-r-packages-for-writing-excel-files-an-analysis-of-writexl-openxlsx-and-xlsx-in-r/)
- [openxlsx2 Documentation](https://janmarvin.github.io/openxlsx2/)

---

### Editable Reference Lists: rhandsontable

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **rhandsontable** | Latest (≥0.3.8+) | Editable in-app reference lists (stop words, block lists, functional categories, food names) | **Excel-like editing UX** with add/remove rows, dropdown validation, inline editing. DT with `editable=TRUE` only supports cell replacement (no add/remove rows, no column-specific input types). |

**Installation:**
```r
pak::pkg_install("rhandsontable")
```

**Integration points:**
- New "Clean Data" tab UI for editing reference lists before/after running cleaning pipeline
- Four editable tables: stop words, block lists, functional categories, food names
- User can add/remove entries, then re-run cleaning with updated lists

**Key functions needed:**
```r
# UI
rHandsontableOutput("stop_words_table")

# Server
output$stop_words_table <- renderRHandsontable({
  rhandsontable(data.frame(word = cleaning_stop_words()), rowHeaders = NULL) %>%
    hot_col("word", type = "text")
})

# Capture edits
updated_df <- hot_to_r(input$stop_words_table)
```

**Why NOT DT with editable=TRUE:**
- DT `editable=TRUE` only allows **replacing cell values** (double-click, type, enter)
- DT does **not** support user-initiated add/remove rows in editable mode
- DT does **not** support column-specific input validation (e.g., dropdown for categories)
- rhandsontable provides **spreadsheet-like UX** users expect for managing reference lists
- Performance: rhandsontable renders slower than DT, but reference lists are small (<100 rows), so this is acceptable

**When to use DT vs rhandsontable going forward:**
| Use Case | Package | Reason |
|----------|---------|--------|
| Display-only tables with sorting/filtering | **DT** | Fast rendering, built-in search/filter, column visibility |
| Editable reference lists (add/remove rows, validation) | **rhandsontable** | Excel-like editing, dropdown/autocomplete, row operations |
| Large result tables (>1000 rows) | **DT** | Performance (DT renders 10x faster than rhandsontable on large data) |
| Small lookup tables user needs to edit | **rhandsontable** | Better UX for managing lists |

**License consideration:**
- rhandsontable uses Handsontable.js **v6.2.2** (last version before Handsontable went commercial-restricted in v7+)
- v6.2.2 is still **MIT licensed** and free for all use
- rhandsontable maintainer has committed to **not updating beyond v6.2.2** to avoid license issues
- **This is acceptable** for ChemReg (internal use, not distributing the package itself)

**Sources:**
- [rhandsontable Documentation](https://jrowen.github.io/rhandsontable/)
- [Comparing DT vs rhandsontable - Posit Community](https://forum.posit.co/t/package-replacement-of-rhanfsontable-or-dt-in-r-shiny-to-create-editable-table-with-dropdown-list/59639)
- [Appsilon: Better Than Excel - Use These R Shiny Packages Instead](https://appsilon.com/forget-about-excel-use-r-shiny-packages-instead/)
- [rhandsontable GitHub](https://github.com/jrowen/rhandsontable)

---

## Capabilities Already Satisfied by Existing Stack

### Unicode Detection: stringi (via tidyverse)

| Requirement | Package | Function | Notes |
|-------------|---------|----------|-------|
| Detect non-ASCII characters | **stringi** | `stri_enc_isascii(x)` | Returns `TRUE`/`FALSE` per element. Already available (stringi is imported by stringr, which is in tidyverse). |
| Clean Unicode → ASCII | **ComptoxR** | `clean_unicode(df)` | Already using this. 100+ character mappings (Greek, math symbols, smart quotes, etc.). |
| Detect encoding | **stringi** | `stri_enc_detect(x)` | Returns guessed encoding + confidence. Useful for import diagnostics but not needed for core pipeline. |

**No new packages needed.**

ComptoxR's `clean_unicode()` is already comprehensive. For post-curation QC, `stringi::stri_enc_isascii()` verifies nothing remains. stringi is already in the dependency tree (via stringr → tidyverse), so no explicit install needed.

**Sources:**
- [stringi Encoding Detection](https://github.com/gagolews/stringi/blob/master/R/encoding_detection.R)
- [stringi Documentation](https://stringi.gagolewski.com/)

---

### Progress Tracking: Shiny's withProgress (Built-in)

| Requirement | Package | Function | Notes |
|-------------|---------|----------|-------|
| Pipeline step-by-step progress | **shiny** (built-in) | `withProgress(expr, { incProgress(amount, detail = "...") })` | Already used in R/curation.R (line 954+). Works for sequential pipelines. |
| Async progress (optional) | **progressr** | `withProgressShiny()` | **Not needed.** Pre-curation pipeline is synchronous (runs on main thread). progressr is for async/parallel tasks. |
| Spinner overlays (optional) | **waiter** | `Waitress$new()` | **Not needed.** withProgress() notification-based progress is sufficient and consistent with existing UX. |

**No new packages needed.**

The pre-curation pipeline (21 functions) and post-curation QC can use the same `withProgress()` + `incProgress()` pattern already implemented for the tiered curation search. Each cleaning step calls `incProgress(1/21, detail = "Normalizing CAS-RNs...")`.

**Alternative considered and rejected:**
- **progressr**: Adds complexity for async progress tracking. Pre-curation is fast (<2 seconds for 200 rows) and synchronous. Not worth the overhead.
- **waiter**: Different UX pattern (full-page spinner vs. notification-based progress). Would create inconsistency with existing curation progress UI.

**Sources:**
- [Shiny withProgress Documentation](https://shiny.posit.co/r/reference/shiny/latest/withprogress.html)
- [Mastering Shiny - User Feedback Chapter](https://mastering-shiny.org/action-feedback.html)
- [progressr withProgressShiny](https://progressr.futureverse.org/reference/withProgressShiny.html)

---

### Re-Import Detection: readxl + Custom Logic

| Requirement | Package | Function | Notes |
|-------------|---------|----------|-------|
| Detect sheet names in uploaded Excel file | **readxl** (existing) | `excel_sheets(path)` | Returns character vector of sheet names. Already used for multi-sheet import. |
| Read specific sheet | **readxl** (existing) | `read_excel(path, sheet = "Manifest")` | Already used for data import. |
| Detect ChemReg manifest signature | **Custom logic** | Check for "Manifest" sheet + required columns | Simple conditional: `if ("Manifest" %in% excel_sheets(path)) { ... }` |

**No new packages needed.**

**Re-import detection workflow:**
1. User uploads file → `validate_file()` checks extension (already exists)
2. If `.xlsx`, call `readxl::excel_sheets(path)` to get sheet list
3. If `"Manifest"` sheet exists:
   - Read it with `readxl::read_excel(path, sheet = "Manifest")`
   - Check for required columns: `export_timestamp`, `chemreg_version`, `data_sheet`, `audit_sheet`, `reference_sheets`
   - If valid → extract sheet names and hot-load state
   - If invalid → treat as new upload
4. If not a ChemReg export → normal upload flow

**Manifest sheet structure (written by openxlsx2 on export):**
```r
manifest <- data.frame(
  key = c("export_timestamp", "chemreg_version", "data_sheet", "audit_sheet", "reference_sheets"),
  value = c(Sys.time(), "1.3.0", "Clean_Data", "Audit_Trail", "Stop_Words,Block_List,Functional_Categories,Food_Names")
)
```

**Sources:**
- [readxl: List all sheets - excel_sheets](https://readxl.tidyverse.org/reference/excel_sheets.html)
- [readxl Workflows](https://readxl.tidyverse.org/articles/readxl-workflows.html)

---

## Supporting Libraries (No Changes Needed)

| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| **tidyverse** | Latest | String manipulation (stringr), data manipulation (dplyr, tidyr), functional programming (purrr) | **Keep.** Used throughout for `str_detect()`, `str_replace()`, `mutate()`, `unnest_longer()`, `safely()`, etc. |
| **janitor** | Latest | Column name cleaning, empty row/column removal | **Keep.** `clean_names()` and `remove_empty()` used in post-detection cleanup. |
| **ComptoxR** | v1.4.0+ | CAS validation/extraction, Unicode cleaning, formula extraction, mixture detection | **Keep.** Core dependency for chemical data cleaning. See PRE_POST_CURATION_PLAN.md for 9 ComptoxR functions used. |
| **DT** | Latest | Display-only tables with sorting/filtering | **Keep.** Still used for Review Results table, Detection Info comparison, and other read-only tables. |
| **shinyjs** | Latest | JavaScript helpers for UI interactions | **Keep.** Used for enabling/disabling inputs, hiding/showing elements based on state. |
| **bslib** | Latest | Bootstrap 5 theming, layout primitives | **Keep.** Existing UI theme and tab structure. |
| **readxl** | Latest | Excel import (multi-sheet detection and reading) | **Keep.** Handles all import needs. |
| **rio** | Latest | Fallback reader for CSV and other formats | **Keep.** Universal import wrapper with automatic format detection. |

---

## Packages to REMOVE

| Package | Reason |
|---------|--------|
| **writexl** | Replaced by openxlsx2 for export. writexl cannot write metadata sheets or set workbook properties. Can be removed from load_packages.R. |

---

## Installation Updates

**Updated `load_packages.R` booster_pack (lines 49-155):**

```r
booster_pack <- c(
  ### IO ----
  'fs',
  'here',
  'janitor',
  'rio',
  'readxl',      # Excel file reading (multi-sheet support)
  'openxlsx2',   # NEW: Excel file writing with metadata sheets
  # 'writexl',   # REMOVED: replaced by openxlsx2
  'tidyverse',
  'mirai',
  'parallel',
  'digest',

  ### Shiny ----
  'shiny',
  'bslib',
  'bsicons',
  'DT',
  'shinyjs',
  'rhandsontable',  # NEW: Editable reference lists

  ### Testing ----
  'testthat',

  ### Misc ----
  'devtools',
  'remotes'
)
```

**GitHub packages (unchanged):**
```r
github_packages <- c(
  "seanthimons/ComptoxR"  # v1.4.0+
)
```

---

## Integration Checklist

### openxlsx2 Integration

- [ ] Add `openxlsx2` to booster_pack in load_packages.R
- [ ] Remove `writexl` from booster_pack
- [ ] Update Excel export handler in app.R (download button server logic)
  - [ ] Create workbook: `wb <- wb_workbook()`
  - [ ] Add data sheet: `wb_add_worksheet(wb, "Clean_Data") %>% wb_add_data("Clean_Data", data_store$clean)`
  - [ ] Add audit trail sheet: `wb_add_worksheet(wb, "Audit_Trail") %>% wb_add_data("Audit_Trail", audit_df)`
  - [ ] Add reference list sheets (4 sheets): stop words, block lists, functional categories, food names
  - [ ] Add manifest sheet with metadata
  - [ ] Set workbook properties: `wb_set_properties(wb, creator = "ChemReg", title = "...", ...)`
  - [ ] Save to temp file and serve for download
- [ ] Update re-import detection logic (file upload observer)
  - [ ] Check for "Manifest" sheet using `readxl::excel_sheets()`
  - [ ] If found, read manifest and extract sheet references
  - [ ] Hot-load reference lists from embedded sheets
  - [ ] Display notification: "ChemReg export detected — state restored"

### rhandsontable Integration

- [ ] Add `rhandsontable` to booster_pack in load_packages.R
- [ ] Create new "Clean Data" tab UI (between Data Preview and Tag Columns)
- [ ] Add four expandable accordion sections for reference lists:
  - [ ] Stop Words: `rHandsontableOutput("stop_words_table")`
  - [ ] Block List: `rHandsontableOutput("block_list_table")`
  - [ ] Functional Categories: `rHandsontableOutput("functional_categories_table")`
  - [ ] Food Names: `rHandsontableOutput("food_names_table")`
- [ ] Server logic for each table:
  - [ ] Render initial table from `R/cleaning_reference.R` functions
  - [ ] Observe table edits: `updated_df <- hot_to_r(input$table_id)`
  - [ ] Store updated lists in reactive values
  - [ ] Wire updated lists into pre-curation pipeline when "Run Cleaning" button clicked
- [ ] Add "Reset to Defaults" button per table (restores original reference lists)
- [ ] Add "Re-run Cleaning" button (re-executes pipeline with current reference lists)

---

## What NOT to Add

| Package | Why NOT Needed |
|---------|----------------|
| **xlsx** | Deprecated. Requires Java. Slower than openxlsx2 and writexl. No advantages. |
| **openxlsx** (v1, not v2) | Predecessor to openxlsx2. Slower, less maintained. openxlsx2 is the modern fork. |
| **progressr** | Async progress tracking. Pre-curation pipeline is synchronous and fast (<2 seconds). Adds complexity without benefit. |
| **waiter** | Full-page spinner overlay. Inconsistent with existing notification-based progress UI. No advantage over withProgress(). |
| **shinyWidgets** | Not needed. bslib provides all UI primitives needed. Adding shinyWidgets would increase bundle size for no clear benefit. |
| **DTedit** | Third-party wrapper around DT for CRUD operations. Overkill for reference list editing. rhandsontable provides better UX for this use case. |
| **editData** | Another editable table package. Less mature than rhandsontable, fewer features. |

---

## Architecture Notes

### Why Two Packages for Tables?

**DT** and **rhandsontable** serve **different use cases**:

| Use Case | Package | Reason |
|----------|---------|--------|
| Display curation results (500-5000 rows) | **DT** | Fast rendering, built-in sorting/filtering/search, column visibility controls. User needs to analyze data, not edit it. |
| Edit reference lists (10-50 rows) | **rhandsontable** | Excel-like editing UX (add/remove rows, inline edit, validation). User expects spreadsheet interaction. |

**Performance:**
- DT renders **10x faster** than rhandsontable on tables >100 rows
- rhandsontable renders **slower** but provides **better editing UX**

**Solution:** Use each package where it excels. DT for display, rhandsontable for editing small reference lists.

### Why openxlsx2 for Export but readxl for Import?

**Export needs:**
- Write arbitrary metadata sheets (audit trail, config, reference lists)
- Set workbook properties (creator, title, description) for re-import detection
- Only openxlsx2 supports this

**Import needs:**
- Read multi-sheet Excel files
- Detect sheet names
- Read specific sheets by name
- readxl already handles this perfectly and is faster than openxlsx2 for reading

**Solution:** Use openxlsx2 for export, readxl for import. They complement each other.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| openxlsx2 for multi-sheet export | **HIGH** | Official CRAN package (v1.13+ as of Jan 2026), active maintenance, comprehensive documentation. Used in production by many projects. |
| rhandsontable for editable lists | **MEDIUM-HIGH** | Mature package (v0.3.8+), but stuck on Handsontable.js v6.2.2 due to license change. License is safe (MIT), but package won't receive JS library updates. This is acceptable for our use case (simple editing, no advanced features needed). |
| stringi for Unicode detection | **HIGH** | Core R package, widely used, comprehensive ICU integration. Already in dependency tree. |
| withProgress for pipeline tracking | **HIGH** | Built-in Shiny feature, already used in existing codebase for curation pipeline. Well-documented. |
| readxl for re-import detection | **HIGH** | tidyverse package, stable, fast, handles all Excel reading needs. |

**Overall confidence:** **HIGH** — only 2 new packages needed, both are mature and well-documented.

---

## Timeline Implications

**Minimal risk from new dependencies:**
- openxlsx2 and rhandsontable are both stable CRAN packages
- No breaking changes expected
- Integration is straightforward (documented APIs, similar to existing patterns)

**Migration from writexl → openxlsx2:**
- Low effort: export logic is isolated to one download handler
- No import changes needed (readxl stays)
- Opportunity to improve export UX with styled headers, frozen panes (bonus features openxlsx2 provides)

**rhandsontable learning curve:**
- Simple API: `renderRHandsontable()` + `hot_to_r()`
- Similar reactive pattern to DT (output → input$table_id)
- Estimated integration: 2-3 hours for 4 reference list tables

---

## Sources Summary

**Editable Tables:**
- [DT in Shiny - RStudio](https://rstudio.github.io/DT/shiny.html)
- [Comparing DT vs rhandsontable - Posit Community](https://forum.posit.co/t/package-replacement-of-rhanfsontable-or-dt-in-r-shiny-to-create-editable-table-with-dropdown-list/59639)
- [rhandsontable Documentation](https://jrowen.github.io/rhandsontable/)
- [Appsilon: Better Than Excel - Use R Shiny Packages](https://appsilon.com/forget-about-excel-use-r-shiny-packages-instead/)

**Excel Packages:**
- [R-bloggers: Comparing writexl, openxlsx, and xlsx](https://www.r-bloggers.com/2023/05/comparing-r-packages-for-writing-excel-files-an-analysis-of-writexl-openxlsx-and-xlsx-in-r/)
- [openxlsx2 Package Manual](https://cran.r-universe.dev/openxlsx2/doc/manual.html)
- [openxlsx2 Documentation](https://janmarvin.github.io/openxlsx2/)
- [readxl Documentation](https://readxl.tidyverse.org/)
- [readxl excel_sheets](https://readxl.tidyverse.org/reference/excel_sheets.html)

**Progress & Unicode:**
- [Shiny withProgress Documentation](https://shiny.posit.co/r/reference/shiny/latest/withprogress.html)
- [Mastering Shiny - User Feedback](https://mastering-shiny.org/action-feedback.html)
- [stringi Encoding Detection](https://github.com/gagolews/stringi/blob/master/R/encoding_detection.R)
- [stringi Documentation](https://stringi.gagolewski.com/)
- [progressr withProgressShiny](https://progressr.futureverse.org/reference/withProgressShiny.html)

---

*Stack research for: ChemReg v1.3 Data Cleaning Pipeline*
*Researched: 2026-03-04*
*Confidence: HIGH — All recommendations verified via official documentation and community sources*
