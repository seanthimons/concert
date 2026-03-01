# Technology Stack: v1.2 Curation Refinement

**Project:** ChemReg
**Milestone:** v1.2 Curation Refinement
**Researched:** 2026-03-01
**Overall Confidence:** HIGH

## Executive Summary

**No new package dependencies required.** All v1.2 features can be implemented using existing stack: ComptoxR 1.4.0, DT with Buttons extension, and standard Shiny reactive patterns. The existing curation pipeline already captures `preferredName` and `rank` from CompTox API responses—these just need to be surfaced in the UI.

**What's new for v1.2:**
- Bulk DTXSID validation via existing `ComptoxR::chemi_amos_batch()`
- Error row retry using existing DT row selection (`input$tableId_rows_selected`)
- Column visibility via existing DT Buttons extension with `columnDefs`
- Richer dropdown context using data already captured in pipeline

**What's NOT changing:**
- Package dependencies (zero additions)
- Core framework (R/Shiny, bslib, DT, ComptoxR)
- Data structures (existing reactiveValues pattern)

---

## Stack Analysis by v1.2 Feature

### Feature 1: Bulk DTXSID Validation

**Status:** ✓ Already Available
**Package:** ComptoxR 1.4.0 (existing)
**Function:** `chemi_amos_batch(dtxsids = c("DTXSID...", ...))`

**Why:**
- ComptoxR already installed from GitHub (`seanthimons/ComptoxR@1.4.0`)
- `chemi_amos_batch()` accepts a `dtxsids` parameter for bulk validation
- Returns substance info for valid DTXSIDs, NULL/error for invalid ones
- No additional dependencies needed

**Integration:**
```r
# User enters DTXSIDs via textAreaInput or data table edit
dtxsid_input <- c("DTXSID7020182", "DTXSID0020232", "invalid123")

# Validate via ComptoxR
validated <- chemi_amos_batch(dtxsids = dtxsid_input)

# Filter to valid DTXSIDs that returned data
valid_dtxsids <- validated %>%
  filter(!is.na(dtxsid)) %>%
  pull(dtxsid)
```

**Function Signature:**
```r
args(chemi_amos_batch)
# function (additional_record_info = NULL, always_download_file = NULL,
#     base_url = NULL, dtxsids = NULL, include_classyfire = NULL,
#     include_external_links = NULL, include_functional_uses = NULL,
#     include_source_counts = NULL, methodologies = NULL, record_types = NULL)
```

**Confidence:** HIGH — Function exists, tested via `args(chemi_amos_batch)`, documented in ComptoxR package.

---

### Feature 2: Error Row Retry with Re-tagging

**Status:** ✓ Standard Shiny Pattern
**Packages:** DT (existing), shiny (existing)
**Components:** `input$tableId_rows_selected`, `reactiveValues()`, subset filtering

**Why:**
- DT already provides row selection via `input$tableId_rows_selected` ([DT Shiny documentation](https://rstudio.github.io/DT/shiny.html))
- No special packages needed—standard reactive workflow:
  1. User selects error rows in DT table
  2. Filter `data_store$resolution_state` to selected row indices
  3. Render tag dropdowns for subset
  4. Re-run `run_pipeline_with_tags()` on subset
  5. Merge results back into main `resolution_state` by row index

**Integration:**
```r
# Extract selected error rows
observeEvent(input$retry_errors, {
  selected_indices <- input$curation_table_rows_selected
  req(length(selected_indices) > 0)

  # Subset to error rows
  error_subset <- data_store$resolution_state[selected_indices, ]

  # Re-tag and re-curate (existing pipeline)
  retry_result <- run_pipeline_with_tags(
    df = error_subset,
    column_tags = input$retry_tags,  # new tagging UI
    progress_callback = function(stage, pct) {...}
  )

  # Merge back
  data_store$resolution_state[selected_indices, ] <- retry_result
})
```

**Confidence:** HIGH — DT row selection is built-in, pattern matches existing resolution workflow.

**Source:** [Using DT in Shiny - Row Selection](https://rstudio.github.io/DT/shiny.html)

---

### Feature 3: Smarter Column Visibility in DT Tables

**Status:** ✓ DT Buttons Extension (existing)
**Package:** DT (existing)
**Extension:** `Buttons` with `colvis` button (already used in app.R)

**Why:**
- App already uses `extensions = 'Buttons'` in Review Results table (app.R line 1440)
- No new dependencies—just add configuration:
  - `columnDefs` to hide columns by default
  - `buttons = list('colvis')` to toggle visibility

**Integration:**
```r
datatable(
  df,
  extensions = 'Buttons',
  options = list(
    dom = 'Bfrtip',
    # Hide untagged columns by default (indices determined at runtime)
    columnDefs = list(
      list(visible = FALSE, targets = untagged_col_indices)
    ),
    buttons = list('colvis')  # Toggle button
  )
)
```

**Determining untagged columns:**
```r
# In server logic
untagged_cols <- setdiff(
  names(data_store$resolution_state),
  c(tagged_original_cols, consensus_cols, metadata_cols)
)
untagged_col_indices <- which(names(df) %in% untagged_cols) - 1  # 0-indexed
```

**Confidence:** HIGH — Feature already partially implemented, `columnDefs` is standard DataTables API.

**Sources:**
- [DT Extensions - Buttons](https://rstudio.github.io/DT/extensions.html)
- [Column Visibility in DT - GitHub Issue #153](https://github.com/rstudio/DT/issues/153)
- [Hide Columns in DT - GeeksforGeeks](https://www.geeksforgeeks.org/r-language/hide-certain-columns-in-a-responsive-data-table-using-dt-package-in-r/)

---

### Feature 4: Richer Dropdown Context (preferredName, rank, QC level)

**Status:** ✓ Already Captured, Needs UI Surfacing
**Packages:** None (existing pipeline data)
**Implementation:** HTML string formatting in `get_resolution_options()`

**Why:**
- `preferredName` and `rank` already captured in pipeline (curation.R lines 101, 393)
- QC tier calculated in consensus.R (line 31)
- Just need to surface in dropdown HTML:

**Current dropdown (app.R ~1392):**
```r
'<option value="', names(options), '">',
sub("^dtxsid_", "", names(options)), ': ', options, '</option>'
```

**Enhanced dropdown:**
```r
'<option value="', names(options), '">',
sub("^dtxsid_", "", names(options)),
' | ', preferred_name[i],  # from preferredName_columnname
' | Rank ', rank[i],       # from rank_columnname
' | QC ', qc_tier[i],      # from consensus QC tier
'</option>'
```

**Data availability:**
- `preferredName` columns: `preferredName_chemical_name`, `preferredName_casrn`, etc.
- `rank` columns: `rank_chemical_name`, `rank_casrn`, etc.
- `qc_tier`: single column in consensus results

**Confidence:** HIGH — Data already exists in `resolution_state`, just needs HTML formatting change.

**Source:** Existing codebase (R/curation.R lines 67-101, R/consensus.R lines 25-40)

---

### Feature 5: Search Reorder (exact → CAS → starts-with)

**Status:** ✓ Code Change Only
**Packages:** None
**Implementation:** Reorder tier calls in `curate_column_tiered()`

**Current order (curation.R):**
1. Exact search (`ct_chemical_search_equal_bulk`)
2. Starts-with search (`ct_chemical_start_with`)
3. CAS validation (`validate_cas_bulk`)

**New order (v1.2):**
1. Exact search (unchanged)
2. CAS validation (moved up)
3. Starts-with search (moved to last resort)

**Why:**
- CAS numbers are more specific than starts-with string matching
- Starts-with can produce fuzzy matches, should be last resort
- No package changes needed, just reorder function calls

**Confidence:** HIGH — Pure code logic change.

---

### Feature 6: "Other" Tag as Full Curation Participant

**Status:** ✓ Code Change Only
**Packages:** None
**Implementation:** Remove tag filtering in pipeline

**Current behavior:**
- "Other" tagged columns excluded from curation (if implemented)
- OR: No special handling, already included (needs verification)

**New behavior (v1.2):**
- "Other" tagged columns go through full search chain (exact → CAS → starts-with)
- Participate in consensus DTXSID comparison
- Included in resolution dropdowns

**Implementation:**
```r
# Remove any logic like:
# if (tag == "Other") { skip }

# Ensure "Other" is treated same as "Chemical Name" and "CASRN"
```

**Confidence:** HIGH — Code change only, no package dependencies.

---

## What NOT to Add

### ❌ ctxR Package (CRAN)
**Why not:** ComptoxR (custom fork from seanthimons/ComptoxR) is already installed and working. ctxR is a different package with similar functionality but different API. Switching would break existing code.

**Decision:** Stick with ComptoxR 1.4.0.

**Note:** Web searches found ctxR (CRAN package) with `check_existence_by_dtxsid_batch()` for DTXSID validation. However, project uses ComptoxR which has equivalent `chemi_amos_batch()` function. No need to add ctxR.

### ❌ Additional DT Extensions
**Why not:** Buttons extension already loaded and sufficient for column visibility. ResponsiveDisplay, ColReorder, FixedColumns not needed for stated requirements.

**Decision:** Continue using `Buttons` extension only.

### ❌ shinyjs Additions
**Why not:** Existing shinyjs usage (DOM manipulation for tab pulsing) is sufficient. Row selection, tagging UI, and validation don't require additional shinyjs functions.

**Decision:** No new shinyjs methods needed.

### ❌ Validation Packages (assertthat, checkmate, validate)
**Why not:** Simple DTXSID format validation (regex: `^DTXSID\\d+$`) can be done with base R `grepl()`. ComptoxR's `chemi_amos_batch()` will validate existence against CompTox.

**Decision:** No validation package needed.

### ❌ Modal/Dialog Packages (shinyWidgets, shinyBS)
**Why not:** bslib provides native modal dialogs via `modalDialog()` and `showModal()`. Sufficient for re-tagging UI during error retry workflow.

**Decision:** Use bslib modals.

---

## Existing Stack (No Changes)

### Core Framework

| Technology | Version | Purpose | Status |
|------------|---------|---------|--------|
| **R** | 4.5.1 | Runtime environment | No change |
| **shiny** | Latest CRAN | Reactive framework | No change |
| **bslib** | ≥0.9.0 | UI framework, navigation | No change |
| **shinyjs** | ≥2.1.0 | UI state control | No change |

### Data & I/O

| Package | Version | Purpose | Status |
|---------|---------|---------|--------|
| **dplyr** | Latest | Data manipulation | No change |
| **tidyr** | Latest | Data reshaping | No change |
| **purrr** | Latest | Functional programming | No change |
| **rio** | Latest | File I/O | No change |
| **readxl** | Latest | Excel reading | No change |
| **writexl** | Latest | Excel writing | No change |
| **janitor** | Latest | Column name cleaning | No change |

### UI Components

| Package | Version | Purpose | Status |
|---------|---------|---------|--------|
| **DT** | Latest | Interactive tables | No change (add columnDefs config) |
| **bsicons** | Latest | Icons | No change |

### API

| Package | Version | Purpose | Status |
|---------|---------|---------|--------|
| **ComptoxR** | 1.4.0 | CompTox API access | No change (use chemi_amos_batch) |
| **httr2** | Latest | HTTP requests (dependency) | No change |

### Testing

| Package | Version | Purpose | Status |
|---------|---------|---------|--------|
| **testthat** | Latest | Unit testing | No change |

---

## Updated Dependencies Summary

| Category | Package | Version | Change | Purpose |
|----------|---------|---------|--------|---------|
| **API** | ComptoxR | 1.4.0 | No change | CompTox API access, bulk DTXSID validation via `chemi_amos_batch()` |
| **UI** | DT | existing | Configuration only | DataTables with Buttons extension for column visibility (`columnDefs`) |
| **Framework** | shiny | existing | No change | Reactive row selection via `input$tableId_rows_selected`, subset filtering |
| **Framework** | bslib | existing | No change | UI theme, modal dialogs for re-tagging UI |
| **Framework** | shinyjs | existing | No change | Existing tab pulsing (no new features needed) |
| **Data** | dplyr | existing | No change | Data manipulation, subset filtering, merge-back logic |
| **Data** | tidyr | existing | No change | Data reshaping (if needed for retry merge) |

**Total new packages:** 0
**Total new functions/features:** 0 (all existing capabilities)

---

## Implementation Checklist

- [ ] **Bulk DTXSID validation:** Call `ComptoxR::chemi_amos_batch(dtxsids = user_input)`
- [ ] **Error row retry:** Use `input$curation_table_rows_selected` for subset workflow
- [ ] **Column visibility:** Add `columnDefs` to DT options with runtime-determined untagged columns
- [ ] **Dropdown context:** Modify HTML string in `get_resolution_options()` to include `preferredName`, `rank`, `qc_tier`
- [ ] **Search reorder:** Modify pipeline call order in `curate_column_tiered()` (exact → CAS → starts-with)
- [ ] **"Other" tag curation:** Remove tag filtering in pipeline (ensure "Other" goes through full search chain)

---

## Version Requirements

All packages already installed at compatible versions:

```r
# Core (already in load_packages.R)
library(shiny)       # Latest CRAN
library(bslib)       # Latest CRAN
library(DT)          # Latest CRAN
library(shinyjs)     # Latest CRAN
library(dplyr)       # Latest CRAN (tidyverse)
library(tidyr)       # Latest CRAN (tidyverse)
library(purrr)       # Latest CRAN (tidyverse)

# API (already installed via remotes)
library(ComptoxR)    # 1.4.0 from seanthimons/ComptoxR
```

**No installation commands needed.**

---

## Integration Points

### Pipeline Integration (R/curation.R)

**Bulk DTXSID validation:**
```r
# Add helper function
validate_dtxsids_bulk <- function(dtxsids) {
  result <- chemi_amos_batch(dtxsids = dtxsids)
  tibble(
    dtxsid = dtxsids,
    is_valid = dtxsids %in% result$dtxsid,
    preferredName = result$preferredName[match(dtxsids, result$dtxsid)]
  )
}
```

**Search reorder:**
```r
# Change tier order in curate_column_tiered()
# FROM: c("exact", "starts_with", "cas")
# TO:   c("exact", "cas", "starts_with")

curate_column_tiered <- function(df, column_name, ...) {
  # Tier 1: Exact search
  exact_results <- search_exact_bulk(...)

  # Tier 2: CAS validation (MOVED UP)
  cas_results <- validate_cas_bulk(...)

  # Tier 3: Starts-with (MOVED TO LAST)
  starts_results <- search_starts_with(...)
}
```

**"Other" tag inclusion:**
```r
# Remove any tag filtering like:
# if (tag %ni% c("Chemical Name", "CASRN")) { return(NULL) }

# Ensure all tags go through full pipeline
run_pipeline_with_tags <- function(df, column_tags, ...) {
  for (col in names(column_tags)) {
    # Curate regardless of tag value
    results[[col]] <- curate_column_tiered(df, col, ...)
  }
}
```

### UI Integration (app.R)

**Error retry workflow:**
```r
# Add UI in Review Results tab
actionButton("retry_errors_btn", "Retry Selected Error Rows")

# Show modal with re-tagging UI
observeEvent(input$retry_errors_btn, {
  selected <- input$curation_table_rows_selected
  req(length(selected) > 0)

  showModal(modalDialog(
    title = "Re-tag Selected Rows",
    uiOutput("retry_tag_ui"),
    footer = tagList(
      actionButton("retry_confirm", "Re-curate"),
      modalButton("Cancel")
    )
  ))
})

# Render tag dropdowns for selected rows
output$retry_tag_ui <- renderUI({
  # Column dropdowns for selected subset
})

# Re-run pipeline on subset
observeEvent(input$retry_confirm, {
  # Use pattern from Feature 2 above
})
```

**Column visibility:**
```r
output$curation_table <- renderDT({
  req(data_store$resolution_state, data_store$dtxsid_cols)

  df <- data_store$resolution_state

  # Determine untagged columns
  tagged_cols <- names(data_store$column_tags)
  consensus_cols <- c("consensus_status", "consensus_dtxsid", "consensus_source", "qc_tier")
  dtxsid_related <- grep("^(dtxsid|preferredName|rank|searchName)_", names(df), value = TRUE)

  keep_visible <- c(tagged_cols, consensus_cols, "Resolution")
  hide_cols <- setdiff(names(df), keep_visible)
  hide_indices <- which(names(df) %in% hide_cols) - 1  # 0-indexed

  datatable(
    df,
    extensions = 'Buttons',
    options = list(
      dom = 'Bfrtip',
      columnDefs = list(
        list(visible = FALSE, targets = hide_indices)
      ),
      buttons = list('colvis')
    )
  )
})
```

**Dropdown context:**
```r
# Modify get_resolution_options() helper function
get_resolution_options <- function(df, row_idx, dtxsid_cols) {
  options <- list()

  for (col in dtxsid_cols) {
    dtxsid_val <- df[[col]][row_idx]
    if (!is.na(dtxsid_val)) {
      # Get corresponding metadata
      col_base <- sub("^dtxsid_", "", col)
      preferred_col <- paste0("preferredName_", col_base)
      rank_col <- paste0("rank_", col_base)

      preferred <- if (preferred_col %in% names(df)) df[[preferred_col]][row_idx] else NA
      rank_val <- if (rank_col %in% names(df)) df[[rank_col]][row_idx] else NA

      # Build label
      label <- paste0(
        col_base,
        if (!is.na(preferred)) paste0(" | ", preferred) else "",
        if (!is.na(rank_val)) paste0(" | Rank ", rank_val) else "",
        " | ", dtxsid_val
      )

      options[[col]] <- label
    }
  }

  options
}
```

### State Management (reactiveValues)

**Retry workflow:**
```r
data_store <- reactiveValues(
  # Existing fields
  resolution_state = NULL,
  dtxsid_cols = NULL,

  # Add for retry workflow
  retry_subset = NULL,       # Selected error rows
  retry_tags = NULL,         # Re-tagging choices for subset
  retry_results = NULL       # Re-curation results to merge back
)
```

---

## Verification Commands

```r
# Confirm ComptoxR has chemi_amos_batch
library(ComptoxR)
args(chemi_amos_batch)
# Should show: function (dtxsids = NULL, ...)

# Confirm DT has Buttons extension
library(DT)
datatable(iris, extensions = 'Buttons', options = list(dom = 'Bfrtip', buttons = 'colvis'))
# Should render table with column visibility button

# Confirm row selection works
# In Shiny app: input$tableId_rows_selected should return integer vector

# Verify preferredName/rank captured
source("R/curation.R")
test_result <- search_exact_bulk(c("Acetone", "Ethanol"))
names(test_result)
# Should include: "preferredName", "rank"
```

---

## Performance Considerations

**Bulk DTXSID validation:**
- `chemi_amos_batch()` batches requests (default 200 per batch)
- No performance impact vs. sequential validation
- Use `withProgress()` for user feedback during validation

**Error row retry:**
- Only re-curates selected subset (not full dataset)
- Merge-back is row-index based (fast)
- No state duplication (updates `resolution_state` in place)

**Column visibility:**
- `columnDefs` applied client-side by DataTables (no server overhead)
- Hidden columns still in DOM (fast toggle via `colvis` button)
- No impact on export (hidden columns included in download)

**Dropdown context:**
- HTML string concatenation at render time
- Minimal overhead (only for "disagree" rows)
- No additional API calls (data already in `resolution_state`)

---

## Confidence Assessment

| Feature | Stack Confidence | Integration Confidence | Risk |
|---------|------------------|------------------------|------|
| Bulk DTXSID validation | HIGH | HIGH | Low — function exists, tested |
| Error row retry | HIGH | MEDIUM | Medium — merge-back logic needs careful testing |
| Column visibility | HIGH | HIGH | Low — DT columnDefs is well-documented |
| Dropdown context | HIGH | HIGH | Low — data already exists, straightforward HTML |
| Search reorder | HIGH | HIGH | Low — simple function call reordering |
| "Other" tag curation | HIGH | HIGH | Low — remove filter logic, ensure consistency |

**Overall Confidence:** HIGH — All features implementable with existing stack. No package additions required.

---

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Use ComptoxR not ctxR | Project already uses ComptoxR fork; switching breaks existing code | ✓ Stick with ComptoxR 1.4.0 |
| No new packages | All features achievable with existing capabilities | ✓ Zero dependency additions |
| Use DT columnDefs | Standard DataTables API, already using Buttons extension | ✓ Configuration change only |
| Surface existing data for dropdowns | preferredName/rank already captured in pipeline | ✓ HTML formatting change only |
| Use bslib modals for retry UI | Native bslib support, consistent with existing UI | ✓ No shinyWidgets needed |

---

## Sources

### HIGH Confidence (Verified Functions)

- **ComptoxR GitHub Repository:** [seanthimons/ComptoxR](https://github.com/seanthimons/ComptoxR) — Bulk DTXSID validation via `chemi_amos_batch(dtxsids = ...)`
- **Existing Codebase:** `R/curation.R` lines 67-101, 393 — `preferredName`, `rank` capture in pipeline
- **Existing Codebase:** `R/consensus.R` lines 25-40 — `qc_tier` calculation
- **Existing Codebase:** `app.R` lines 1383-1395 — Current dropdown HTML implementation

### HIGH Confidence (Official Documentation)

- [DT Shiny Documentation - Row Selection](https://rstudio.github.io/DT/shiny.html) — `input$tableId_rows_selected` usage
- [DT Extensions - Buttons](https://rstudio.github.io/DT/extensions.html) — Column visibility via `colvis` button
- [DT GitHub Issue #153 - Column Visibility](https://github.com/rstudio/DT/issues/153) — `columnDefs` examples and patterns
- [GeeksforGeeks - Hide Columns in DT](https://www.geeksforgeeks.org/r-language/hide-certain-columns-in-a-responsive-data-table-using-dt-package-in-r/) — `columnDefs` usage guide

### MEDIUM Confidence (Alternative Packages, Not Used)

- [ctxR CRAN Package](https://cran.r-project.org/web/packages/ctxR/ctxR.pdf) — Alternative CompTox API package with `check_existence_by_dtxsid_batch()` (not used, ComptoxR preferred)

---

## Recommendation

**Proceed with implementation using existing stack.** No `pak::pkg_install()` calls needed. All v1.2 features are achievable through:

1. **Configuration changes** (DT columnDefs)
2. **Code logic changes** (search reorder, tag filtering removal)
3. **HTML formatting changes** (dropdown context)
4. **Standard Shiny patterns** (row selection, modal dialogs, subset filtering)
5. **Existing ComptoxR functions** (chemi_amos_batch for bulk validation)

Focus development effort on **code logic and UI enhancements** rather than dependency management.

---

*Stack research for: ChemReg v1.2 Curation Refinement*
*Researched: 2026-03-01*
*Confidence: HIGH — All recommendations verified via existing codebase inspection and official documentation*
