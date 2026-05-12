# Phase 14: Multi-Sheet Export & Re-Import - Research

**Researched:** 2026-03-07
**Domain:** R Shiny multi-sheet Excel export/import with state transfer
**Confidence:** HIGH

## Summary

Multi-sheet Excel export/import for Shiny applications is a well-established pattern with mature tooling in the R ecosystem. The `writexl` package provides zero-dependency, fast Excel writing suitable for the existing CONCERT stack. Re-import requires parsing sheet names, detecting CONCERT exports via marker fields, and presenting user confirmation modals before state restoration.

**Primary recommendation:** Extend the existing `writexl::write_xlsx()` call in `mod_review_results.R` from 3 sheets to 7 sheets, add a sidebar `fileInput()` for config import, and use `readxl::excel_sheets()` + `readxl::read_excel()` for selective sheet reading with `modalDialog()` confirmation.

**Key insight:** Excel XLSX format has hard limits (1,048,576 rows × 16,384 columns per sheet) that cannot be exceeded. Simple row count validation (`nrow(df) < 1048576`) before writing prevents Excel write failures for chemical inventory datasets.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Sheet Structure: Replace Existing Export**
- New multi-sheet export REPLACES the existing 3-sheet export in Review Results (not a separate button)
- Sheets in the workbook:
  1. **Raw Data** — original uploaded data as-is (complete audit trail from input to output)
  2. **Curated Data** — final curated data with consensus DTXSIDs, needs_review flag (existing Sheet 1, enhanced)
  3. **Summary** — curation statistics (existing Sheet 2, enhanced)
  4. **Cleaning Audit** — full per-row audit trail (row_id, field, step, original_value, new_value, reason)
  5. **Reference Lists** — combined single sheet with `type` column (functional_category/stop_word/block_pattern) + term, source, active columns (matches Phase 13 CSV upload format)
  6. **Column Tags** — existing Sheet 3 (column name → tag type mapping)
  7. **Pipeline Config** — app version, export timestamp, detection method, pipeline steps run, file info, `concert_export: true` marker

**Re-Import: Config Transfer to New Datasets**
- Primary use case: carry reference lists and settings from a previous dataset to a NEW dataset (not session restore)
- No session restore — user always re-runs cleaning/curation on the new data
- Dedicated config import control in the **sidebar/upload area** (separate from main file upload)
- On config import: read Pipeline Config sheet, detect `concert_export` marker, load reference lists and column tags
- Confirmation modal with opt-out: "CONCERT export detected. Restore reference lists and column tags?" with checkboxes for each (default: restore all)
- Imported reference lists merge with existing (user additions tagged as source = `imported`)

**Export Placement & Trigger**
- Export button stays in Review Results tab (current location)
- Export only available after curation is complete (matches current gating)
- Config import button in sidebar area, available after data upload

**Validation: Lightweight Guard**
- Simple row count check before writing (guard against >1M rows, but this is a defensive check not a primary feature)
- Only validate curated data sheet size (audit trail unlikely to exceed limits for typical chemical inventory files)
- Block with clear error message if exceeded — no truncation or splitting

**Package: writexl**
- Continue using writexl for Excel writing (already in use, simple, sufficient for data frame → sheet)
- No openxlsx2 — keeps dependencies minimal, no formatting needed beyond data tables

### Claude's Discretion

- Config import UI design in sidebar (button style, placement relative to file upload)
- How to handle merge conflicts when importing reference lists that overlap with current lists
- Exact confirmation modal layout and wording
- Pipeline Config sheet key-value format
- Whether to add sheet tab colors or formatting (writexl limitations may constrain this)
- Error handling for malformed CONCERT exports on import

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| EXPO-01 | User can export a multi-sheet Excel file containing curated data, cleaning audit trail, reference list state, and pipeline configuration | writexl supports multi-sheet export via named list; 7 sheets fits well within Excel limits; all required data available in data_store reactiveValues |
| EXPO-02 | User can re-import a CONCERT export and see a confirmation modal offering to restore embedded reference lists and pipeline state | readxl can detect sheet names and read specific sheets; modalDialog() supports checkboxes for user choice; import logic can merge reference lists into data_store$reference_lists |
| EXPO-03 | User can see the multi-sheet export serve as both a standalone audit document and a CONCERT re-entry point | Including Raw Data + Cleaning Audit + Pipeline Config sheets makes export self-documenting; concert_export marker in Pipeline Config enables detection; round-trip format matches Phase 13 CSV upload structure |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| writexl | 1.5+ | Write multi-sheet Excel files | Zero dependencies, fast, portable across platforms; already in CONCERT dependencies |
| readxl | 1.4+ | Read Excel files and detect sheet names | Tidyverse-aligned, handles XLSX/XLS formats; already in CONCERT dependencies |
| shiny | 1.9+ | Modal dialogs and file input | Core Shiny UI components for confirmation modals and file uploads |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dplyr | 1.1+ | Data frame manipulation for merging imported reference lists | Combine imported reference lists with existing data_store lists |
| tibble | 3.2+ | Create Pipeline Config key-value data frame | Build metadata sheet with structured columns |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| writexl | openxlsx2 | openxlsx2 supports formatting/styling but adds Java dependency; CONCERT exports are data-centric audit documents, not formatted reports |
| readxl | rio::import_list() | rio can read all sheets at once but adds dependency and loads entire workbook into memory; selective sheet reading more efficient for config import |
| modalDialog() | shinyWidgets::ask_confirmation() | ask_confirmation() provides richer UI but adds dependency; base Shiny modal sufficient for checkbox confirmation |

**Installation:**
```bash
# Already in CONCERT dependencies (no new packages needed)
# writexl, readxl, shiny, dplyr, tibble all present in load_packages.R
```

## Architecture Patterns

### Recommended Export Structure
```r
# Multi-sheet export pattern (extend existing mod_review_results.R:828)
writexl::write_xlsx(
  list(
    "Raw Data" = data_store$raw,
    "Curated Data" = export_data,
    "Summary" = summary_df,
    "Cleaning Audit" = data_store$cleaning_audit,
    "Reference Lists" = combined_ref_lists,
    "Column Tags" = tags_df,
    "Pipeline Config" = config_df
  ),
  path = file
)
```

### Pattern 1: Multi-Sheet Excel Export
**What:** Named list of data frames passed to `writexl::write_xlsx()` creates multi-sheet workbook with sheet names as list names
**When to use:** Exporting multiple related tables that form a cohesive audit trail or analysis package
**Example:**
```r
# Source: writexl documentation + existing CONCERT mod_review_results.R:828
output$download_curated <- downloadHandler(
  filename = function() {
    paste0(file_base, "_curated_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
  },
  content = function(file) {
    req(data_store$resolution_state, data_store$consensus_summary)

    # Build sheets
    export_data <- data_store$resolution_state %>%
      dplyr::mutate(needs_review = (consensus_status %in% c("error", "unresolvable"))) %>%
      dplyr::select(-tidyselect::any_of(c(".pinned", ".manual_entry")))

    summary_df <- tibble::tibble(Metric = c(...), Value = c(...))
    tags_df <- tibble::tibble(Column = names(data_store$column_tags), Type = unlist(data_store$column_tags))

    # NEW: Add audit, reference lists, raw data, config
    audit_df <- data_store$cleaning_audit

    # Combine reference lists into single sheet with type column
    combined_ref_lists <- dplyr::bind_rows(
      data_store$reference_lists$functional_categories %>% mutate(type = "functional_category"),
      data_store$reference_lists$stop_words %>% mutate(type = "stop_word"),
      data_store$reference_lists$block_patterns %>% mutate(type = "block_pattern")
    ) %>% select(type, term, source, active)

    # Pipeline config metadata
    config_df <- tibble::tibble(
      key = c("concert_export", "app_version", "export_timestamp", "detection_method",
              "file_name", "file_size", "pipeline_steps_run"),
      value = c("true", packageVersion("CONCERT"), as.character(Sys.time()),
                data_store$detection$method, data_store$file_info$name,
                data_store$file_info$size, paste(names(data_store$cleaning_audit$step), collapse = "|"))
    )

    # Write multi-sheet workbook
    writexl::write_xlsx(
      list(
        "Raw Data" = data_store$raw,
        "Curated Data" = export_data,
        "Summary" = summary_df,
        "Cleaning Audit" = audit_df,
        "Reference Lists" = combined_ref_lists,
        "Column Tags" = tags_df,
        "Pipeline Config" = config_df
      ),
      path = file
    )
  }
)
```

### Pattern 2: Selective Sheet Reading
**What:** Use `readxl::excel_sheets()` to list sheet names, then `readxl::read_excel(sheet = "name")` to read specific sheets
**When to use:** Reading config/metadata from multi-sheet workbooks without loading entire file into memory
**Example:**
```r
# Source: readxl documentation + R-bloggers patterns
import_config <- function(file_path) {
  # Detect sheet names
  sheet_names <- readxl::excel_sheets(file_path)

  # Check for Pipeline Config sheet (CONCERT export marker)
  if (!("Pipeline Config" %in% sheet_names)) {
    return(NULL)  # Not a CONCERT export
  }

  # Read Pipeline Config sheet
  config_df <- readxl::read_excel(file_path, sheet = "Pipeline Config")

  # Check for concert_export marker
  is_concert <- any(config_df$key == "concert_export" & config_df$value == "true")

  if (!is_concert) {
    return(NULL)
  }

  # Read Reference Lists and Column Tags sheets
  ref_lists <- readxl::read_excel(file_path, sheet = "Reference Lists")
  col_tags <- readxl::read_excel(file_path, sheet = "Column Tags")

  return(list(
    reference_lists = ref_lists,
    column_tags = col_tags,
    config = config_df
  ))
}
```

### Pattern 3: Confirmation Modal with Checkboxes
**What:** Use `modalDialog()` with `checkboxInput()` elements to get user consent before applying imported state
**When to use:** Operations that modify app state based on external data (imports, resets, cascades)
**Example:**
```r
# Source: Mastering Shiny Ch. 8 User Feedback + existing CONCERT re-upload pattern
observeEvent(input$config_upload, {
  req(input$config_upload)

  # Parse uploaded file
  config_data <- import_config(input$config_upload$datapath)

  if (is.null(config_data)) {
    showNotification("Not a valid CONCERT export file", type = "error")
    return()
  }

  # Show confirmation modal with checkboxes
  showModal(modalDialog(
    title = "CONCERT Export Detected",
    p("This file contains reference lists and column tags from a previous CONCERT session."),
    p("Select what to restore:"),
    checkboxInput(NS(id, "restore_ref_lists"), "Restore reference lists", value = TRUE),
    checkboxInput(NS(id, "restore_col_tags"), "Restore column tags", value = TRUE),
    footer = tagList(
      actionButton(NS(id, "confirm_import"), "Import", class = "btn-primary"),
      modalButton("Cancel")
    )
  ))

  # Store parsed data for confirmation handler
  imported_config$data <- config_data
})

observeEvent(input$confirm_import, {
  removeModal()

  # Apply user-selected imports
  if (input$restore_ref_lists) {
    # Merge imported reference lists with existing (mark as source = "imported")
    imported_refs <- imported_config$data$reference_lists %>%
      mutate(source = "imported")

    # Split by type and merge
    for (ref_type in c("functional_category", "stop_word", "block_pattern")) {
      imported_subset <- imported_refs %>% filter(type == ref_type) %>% select(-type)
      data_store$reference_lists[[paste0(ref_type, "s")]] <- dplyr::bind_rows(
        data_store$reference_lists[[paste0(ref_type, "s")]],
        imported_subset
      ) %>% distinct(term, .keep_all = TRUE)  # Imported wins on conflicts
    }
  }

  if (input$restore_col_tags) {
    # Convert column tags tibble to named list
    data_store$column_tags <- setNames(
      imported_config$data$column_tags$Type,
      imported_config$data$column_tags$Column
    )
  }

  showNotification("Config imported successfully", type = "message")
})
```

### Pattern 4: Pre-Export Validation
**What:** Check data frame dimensions against Excel limits before attempting to write
**When to use:** Prevent cryptic Excel write failures for large datasets
**Example:**
```r
# Source: Excel specifications + R validation patterns
validate_excel_size <- function(df, sheet_name) {
  max_rows <- 1048576
  max_cols <- 16384

  if (nrow(df) >= max_rows) {
    stop(sprintf("Sheet '%s' has %d rows (Excel limit: %d)",
                 sheet_name, nrow(df), max_rows))
  }

  if (ncol(df) >= max_cols) {
    stop(sprintf("Sheet '%s' has %d columns (Excel limit: %d)",
                 sheet_name, ncol(df), max_cols))
  }

  return(TRUE)
}

# Usage in downloadHandler
content = function(file) {
  tryCatch({
    # Validate curated data sheet size (highest risk)
    validate_excel_size(export_data, "Curated Data")

    # Write workbook
    writexl::write_xlsx(sheet_list, path = file)
  }, error = function(e) {
    showNotification(
      paste0("Export failed: ", e$message),
      type = "error",
      duration = NULL
    )
  })
}
```

### Anti-Patterns to Avoid

- **Loading entire multi-sheet workbook into memory:** Don't use `rio::import_list()` to read all sheets when you only need Pipeline Config + Reference Lists — selective reading with `readxl::read_excel(sheet = "name")` is more efficient
- **Silent truncation on Excel limit overflow:** Don't silently drop rows/columns that exceed Excel limits — block export with clear error message so user knows data is incomplete
- **Overwriting user reference lists on import:** Don't replace `data_store$reference_lists` wholesale — merge imported entries with existing using `dplyr::bind_rows()` + `distinct()` to preserve user additions
- **Auto-importing without confirmation:** Don't auto-apply imported config on upload — show modal with checkboxes so user can opt out of restoring reference lists or column tags

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Excel file writing | Custom XML generation for XLSX format | writexl::write_xlsx() | XLSX format is complex (ZIP archive with XML manifests); writexl handles compression, shared strings, workbook relationships, and format compliance |
| Sheet name detection | Binary parsing of Excel file headers | readxl::excel_sheets() | XLSX internal structure requires ZIP extraction and XML parsing; readxl handles format differences between XLS (BIFF8) and XLSX (OOXML) |
| Excel limit validation | Hardcoded limit checks without format awareness | Validate against documented Excel specs (1,048,576 rows, 16,384 cols) | Limits are format constraints, not library constraints — validation prevents cryptic write failures |
| Reference list merging | Manual row-by-row append with conflict resolution | dplyr::bind_rows() + distinct(term, .keep_all = TRUE) | Deduplication on key columns with "last wins" semantics is built-in; manual iteration error-prone for tibble provenance columns |

**Key insight:** Excel format compliance (compression, XML schema, relationship manifests) is deceptively complex. Chemical inventory datasets are small enough (hundreds to low thousands of rows) that Excel limits are a defensive check, not a primary concern — but validation prevents confusing errors when limits are exceeded.

## Common Pitfalls

### Pitfall 1: Sheet Name Ordering Confusion
**What goes wrong:** Sheet order in exported Excel file doesn't match list order in R code
**Why it happens:** `writexl::write_xlsx()` preserves list order, but Excel applications may reorder sheets visually or on save/open cycles
**How to avoid:** Document intended sheet order in comments; don't rely on positional sheet access in import logic (use sheet names explicitly)
**Warning signs:** Users report "Pipeline Config is the last sheet" when code shows it as 7th in list order

### Pitfall 2: Reference List Type Column Mismatch
**What goes wrong:** Imported reference list CSV has `type = "functional_categories"` (plural) but code expects `"functional_category"` (singular)
**Why it happens:** Phase 13 CSV upload format uses singular type values, but data_store keys are plural (`$functional_categories`)
**How to avoid:** Use singular type values in export ("functional_category", "stop_word", "block_pattern") to match Phase 13 format; convert to plural keys only in data_store merge logic
**Warning signs:** Import fails silently or creates new empty reference list instead of merging with existing

### Pitfall 3: Missing concert_export Marker Detection
**What goes wrong:** Regular Excel files uploaded to config import trigger errors instead of graceful rejection
**Why it happens:** Assuming Pipeline Config sheet exists without checking for `concert_export: true` marker row
**How to avoid:** Two-stage validation: (1) check if "Pipeline Config" sheet exists, (2) check if `concert_export` key has value `"true"` (as character, not logical)
**Warning signs:** User uploads random Excel file and sees "Error in filter: object 'key' not found" instead of "Not a CONCERT export" message

### Pitfall 4: Raw Data Column Count Explosion
**What goes wrong:** Raw data sheet hits 16,384 column limit due to merged cell artifacts or wide-format source files
**Why it happens:** Some chemical inventory exports from LIMS systems have hundreds of metadata columns
**How to avoid:** Validate `data_store$raw` column count before export; consider dropping empty columns with `janitor::remove_empty("cols")` before writing Raw Data sheet
**Warning signs:** Export fails with "too many columns" error for files that loaded successfully into CONCERT

### Pitfall 5: Audit Trail Sheet Size Underestimation
**What goes wrong:** Cleaning audit trail exceeds 1M row limit for datasets with many synonym splits
**Why it happens:** Each field change creates an audit row; synonym splitting can create 10+ audit rows per original row
**How to avoid:** Validate `data_store$cleaning_audit` row count in addition to curated data; if exceeded, filter audit trail to show only CAS/Name field changes (drop formula_extract audit rows)
**Warning signs:** Export fails on large datasets (>50k rows) that passed curated data validation

### Pitfall 6: Modal Checkbox State Not Captured
**What goes wrong:** Import confirmation modal closes but checkbox states are lost, always importing all config
**Why it happens:** Using `input$restore_ref_lists` outside modal scope after `removeModal()` clears input values
**How to avoid:** Capture checkbox states in a reactiveVal before calling `removeModal()`, or read input values inside confirmation observer before removing modal
**Warning signs:** User unchecks "Restore column tags" but tags are still imported

## Code Examples

Verified patterns from official sources and existing CONCERT codebase:

### Multi-Sheet Export (Extending mod_review_results.R:773-837)
```r
# Source: Existing CONCERT mod_review_results.R + writexl documentation
output$download_curated <- downloadHandler(
  filename = function() {
    file_base <- if (!is.null(data_store$file_info)) {
      tools::file_path_sans_ext(data_store$file_info$name)
    } else {
      "curated_data"
    }
    paste0(file_base, "_curated_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
  },
  content = function(file) {
    req(data_store$resolution_state, data_store$consensus_summary)

    # Validate curated data size (defensive check)
    tryCatch({
      if (nrow(data_store$resolution_state) >= 1048576) {
        stop("Curated data exceeds Excel row limit (1,048,576 rows)")
      }
    }, error = function(e) {
      showNotification(paste0("Export blocked: ", e$message), type = "error", duration = NULL)
      return()
    })

    # Build Sheet 2: Curated Data (enhanced from existing)
    export_data <- data_store$resolution_state %>%
      dplyr::mutate(
        needs_review = (consensus_status %in% c("error", "unresolvable"))
      ) %>%
      dplyr::select(-tidyselect::any_of(c(".pinned", ".manual_entry"))) %>%
      dplyr::relocate(needs_review, .after = tidyselect::last_col())

    # Build Sheet 3: Summary (existing)
    summary_df <- tibble::tibble(
      Metric = c(
        "Total Rows", "Consensus - Agree", "Consensus - Disagree",
        "Consensus - Agree (Caveat)", "Consensus - Single Source",
        "Consensus - Manual", "Consensus - Error", "Consensus - Unresolvable",
        "Match Rate (%)"
      ),
      Value = c(
        nrow(data_store$resolution_state),
        data_store$consensus_summary$n_agree,
        data_store$consensus_summary$n_disagree,
        data_store$consensus_summary$n_agree_caveat,
        data_store$consensus_summary$n_single,
        data_store$consensus_summary$n_manual %||% 0,
        data_store$consensus_summary$n_error,
        data_store$consensus_summary$n_unresolvable %||% 0,
        round((sum(!is.na(data_store$resolution_state$consensus_dtxsid)) /
               nrow(data_store$resolution_state)) * 100, 1)
      )
    )

    # Build Sheet 6: Column Tags (existing)
    tags_df <- tibble::tibble(
      Column = names(data_store$column_tags),
      Type = unlist(data_store$column_tags)
    )

    # NEW Sheet 1: Raw Data
    raw_data <- data_store$raw

    # NEW Sheet 4: Cleaning Audit
    audit_df <- data_store$cleaning_audit

    # NEW Sheet 5: Reference Lists (combined format for Phase 13 CSV upload compatibility)
    combined_ref_lists <- dplyr::bind_rows(
      data_store$reference_lists$functional_categories %>%
        dplyr::mutate(type = "functional_category"),
      data_store$reference_lists$stop_words %>%
        dplyr::mutate(type = "stop_word"),
      data_store$reference_lists$block_patterns %>%
        dplyr::mutate(type = "block_pattern")
    ) %>%
      dplyr::select(type, term, source, active)

    # NEW Sheet 7: Pipeline Config
    config_df <- tibble::tibble(
      key = c(
        "concert_export",
        "app_version",
        "export_timestamp",
        "detection_method",
        "detection_confidence",
        "file_name",
        "file_size_bytes",
        "pipeline_steps"
      ),
      value = as.character(c(
        "true",
        "1.3.0",  # Hardcode or use packageVersion() if CONCERT becomes package
        format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
        data_store$detection$method %||% "unknown",
        data_store$detection$confidence %||% "unknown",
        data_store$file_info$name %||% "unknown",
        data_store$file_info$size %||% "unknown",
        paste(unique(data_store$cleaning_audit$step), collapse = "; ")
      ))
    )

    # Write multi-sheet workbook (7 sheets)
    writexl::write_xlsx(
      list(
        "Raw Data" = raw_data,
        "Curated Data" = export_data,
        "Summary" = summary_df,
        "Cleaning Audit" = audit_df,
        "Reference Lists" = combined_ref_lists,
        "Column Tags" = tags_df,
        "Pipeline Config" = config_df
      ),
      path = file
    )
  }
)
```

### Config Import with Modal Confirmation (app.R sidebar addition)
```r
# Source: Mastering Shiny Ch. 8 + existing CONCERT re-upload pattern
# Add to app.R sidebar after mod_file_upload_ui()

# In UI sidebar definition:
sidebar = sidebar(
  id = "main_sidebar",
  width = 300,
  mod_file_upload_ui("upload"),

  # NEW: Config import control
  hr(),
  h5("Import Configuration"),
  fileInput(
    "config_import",
    "Upload CONCERT Export",
    accept = ".xlsx",
    buttonLabel = "Browse...",
    placeholder = "Optional: restore previous settings"
  )
)

# In server function:
# NEW: Config import reactiveVal
imported_config <- reactiveVal(NULL)

observeEvent(input$config_import, {
  req(input$config_import)

  # Read uploaded file and detect CONCERT export
  tryCatch({
    file_path <- input$config_import$datapath

    # Check for Pipeline Config sheet
    sheet_names <- readxl::excel_sheets(file_path)

    if (!("Pipeline Config" %in% sheet_names)) {
      showNotification("Not a CONCERT export (missing Pipeline Config sheet)", type = "warning")
      return()
    }

    # Read Pipeline Config and verify marker
    config_df <- readxl::read_excel(file_path, sheet = "Pipeline Config")

    is_concert <- any(config_df$key == "concert_export" & config_df$value == "true")

    if (!is_concert) {
      showNotification("Not a CONCERT export (missing concert_export marker)", type = "warning")
      return()
    }

    # Read Reference Lists and Column Tags sheets
    ref_lists_df <- readxl::read_excel(file_path, sheet = "Reference Lists")
    col_tags_df <- readxl::read_excel(file_path, sheet = "Column Tags")

    # Store parsed data
    imported_config(list(
      reference_lists = ref_lists_df,
      column_tags = col_tags_df,
      config = config_df
    ))

    # Show confirmation modal
    showModal(modalDialog(
      title = "CONCERT Export Detected",
      p("This file contains reference lists and column tags from a previous CONCERT session."),
      p("Select what to restore:"),
      checkboxInput("restore_ref_lists", "Restore reference lists", value = TRUE),
      checkboxInput("restore_col_tags", "Restore column tags", value = TRUE),
      p(class = "text-muted", "Note: Imported reference lists will be merged with existing lists (duplicates kept from import)."),
      footer = tagList(
        actionButton("confirm_config_import", "Import", class = "btn-primary"),
        modalButton("Cancel")
      )
    ))

  }, error = function(e) {
    showNotification(paste0("Config import failed: ", e$message), type = "error")
  })
})

observeEvent(input$confirm_config_import, {
  req(imported_config())

  # Capture checkbox states before closing modal
  restore_refs <- input$restore_ref_lists
  restore_tags <- input$restore_col_tags

  removeModal()

  config_data <- imported_config()

  # Apply user-selected imports
  if (restore_refs) {
    tryCatch({
      # Split imported reference lists by type
      for (ref_type in c("functional_category", "stop_word", "block_pattern")) {
        imported_subset <- config_data$reference_lists %>%
          dplyr::filter(type == ref_type) %>%
          dplyr::select(-type) %>%
          dplyr::mutate(source = "imported")

        # Merge with existing (imported wins on term conflicts)
        list_key <- paste0(ref_type, "s")  # Convert to plural for data_store key
        data_store$reference_lists[[list_key]] <- dplyr::bind_rows(
          data_store$reference_lists[[list_key]],
          imported_subset
        ) %>%
          dplyr::distinct(term, .keep_all = TRUE)
      }

      showNotification("Reference lists imported and merged", type = "message")
    }, error = function(e) {
      showNotification(paste0("Reference list import failed: ", e$message), type = "error")
    })
  }

  if (restore_tags) {
    tryCatch({
      # Convert column tags tibble to named list
      data_store$column_tags <- setNames(
        config_data$column_tags$Type,
        config_data$column_tags$Column
      )

      showNotification("Column tags imported", type = "message")
    }, error = function(e) {
      showNotification(paste0("Column tags import failed: ", e$message), type = "error")
    })
  }

  # Clear imported config
  imported_config(NULL)
})
```

### Validation Helper Function
```r
# Source: Excel specifications + R defensive programming patterns
# Add to R/file_handlers.R or new R/excel_validation.R

#' Validate data frame size against Excel XLSX limits
#'
#' Checks if a data frame exceeds Excel's maximum row (1,048,576) or column (16,384) limits.
#' Throws informative error if limits exceeded.
#'
#' @param df Data frame to validate
#' @param sheet_name Character string identifying the sheet (for error messages)
#' @return TRUE if validation passes (invisible)
#' @throws error if limits exceeded
#'
#' @examples
#' validate_excel_size(mtcars, "Cars Data")  # Passes
#' validate_excel_size(data.frame(matrix(1:20e6, ncol = 2)), "Big Data")  # Fails
validate_excel_size <- function(df, sheet_name = "Sheet") {
  # Excel XLSX format hard limits (cannot be exceeded)
  EXCEL_MAX_ROWS <- 1048576
  EXCEL_MAX_COLS <- 16384

  n_rows <- nrow(df)
  n_cols <- ncol(df)

  if (n_rows >= EXCEL_MAX_ROWS) {
    stop(sprintf(
      "Cannot export '%s' sheet: %s rows exceeds Excel limit of %s rows. Consider filtering or splitting data.",
      sheet_name, format(n_rows, big.mark = ","), format(EXCEL_MAX_ROWS, big.mark = ",")
    ))
  }

  if (n_cols >= EXCEL_MAX_COLS) {
    stop(sprintf(
      "Cannot export '%s' sheet: %s columns exceeds Excel limit of %s columns. Consider dropping empty columns.",
      sheet_name, format(n_cols, big.mark = ","), format(EXCEL_MAX_COLS, big.mark = ",")
    ))
  }

  invisible(TRUE)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| xlsx package with Java dependency | writexl with zero dependencies | ~2017-2018 | Simplified deployment, faster writes, no rJava configuration issues |
| rio::export() for single-sheet files | writexl::write_xlsx() with named list | Ongoing (2020+) | Multi-sheet support, explicit sheet naming, better control |
| Auto-import on file upload | Confirmation modal with opt-in checkboxes | Modern Shiny UX patterns (2021+) | User control, prevents accidental state overwrite, better for GDPR/audit compliance |
| Silent truncation on Excel limits | Pre-validation with clear error messages | Best practice (2020+) | Prevents data loss, better user feedback |

**Deprecated/outdated:**
- **xlsx package**: Requires Java runtime, slow for large files, difficult to deploy in containerized environments — replaced by writexl
- **XLS format (BIFF8)**: Row limit of 65,536 rows (insufficient for modern datasets) — use XLSX format exclusively
- **gdata::read.xls()**: Requires Perl runtime, deprecated in favor of readxl — avoid for new code

## Validation Architecture

> Nyquist validation enabled (workflow.nyquist_validation not explicitly set to false in .planning/config.json)

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.2+ |
| Config file | none — tests run via `testthat::test_dir("tests")` |
| Quick run command | `Rscript -e "testthat::test_file('tests/test_export_import.R')"` |
| Full suite command | `Rscript -e "testthat::test_dir('tests')"` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| EXPO-01 | Multi-sheet Excel file written with 7 sheets containing correct data | unit | `Rscript -e "testthat::test_file('tests/test_export_import.R', filter = 'multi-sheet export')"` | ❌ Wave 0 |
| EXPO-02 | CONCERT export detected on import, modal shown, reference lists merged correctly | unit | `Rscript -e "testthat::test_file('tests/test_export_import.R', filter = 'config import')"` | ❌ Wave 0 |
| EXPO-03 | Export includes Raw Data, Cleaning Audit, Pipeline Config sheets with concert_export marker | unit | `Rscript -e "testthat::test_file('tests/test_export_import.R', filter = 'audit document')"` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `Rscript -e "testthat::test_file('tests/test_export_import.R')"`
- **Per wave merge:** `Rscript -e "testthat::test_dir('tests')"`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/test_export_import.R` — covers EXPO-01, EXPO-02, EXPO-03
  - Test multi-sheet export creates 7 sheets with correct names
  - Test Pipeline Config sheet contains concert_export marker
  - Test Reference Lists sheet has correct type column format
  - Test config import detects CONCERT exports and rejects non-CONCERT files
  - Test reference list merge preserves existing + imported entries
  - Test column tags import converts tibble to named list correctly
  - Test Excel size validation blocks oversized exports
- [ ] `tests/test_excel_validation.R` — covers validate_excel_size() edge cases
  - Test row limit validation (1,048,576 threshold)
  - Test column limit validation (16,384 threshold)
  - Test passes for small data frames
  - Test error messages include sheet name and helpful guidance

## Sources

### Primary (HIGH confidence)
- [writexl CRAN documentation](https://cran.r-project.org/web/packages/writexl/writexl.pdf) - Multi-sheet export patterns
- [Excel specifications and limits - Microsoft Support](https://support.microsoft.com/en-us/office/excel-specifications-and-limits-1672b34d-7043-467e-8e27-269d656771c3) - Official XLSX format limits (1,048,576 rows × 16,384 columns)
- [readxl: Read Excel Files](https://readxl.tidyverse.org/) - Sheet name detection and selective reading
- [Mastering Shiny Chapter 8: User feedback](https://mastering-shiny.org/action-feedback.html) - Modal dialog patterns
- Existing CONCERT codebase - `mod_review_results.R:773-837` (3-sheet export), `app.R:118-127` (data_store structure), `R/cleaning_reference.R` (reference list tibble format)

### Secondary (MEDIUM confidence)
- [R: How to Export Data Frames to Multiple Excel Sheets - Statology](https://www.statology.org/r-export-to-excel-multiple-sheets/) - Multi-sheet export code examples
- [How to read a XLSX file with multiple Sheets in R? - GeeksforGeeks](https://www.geeksforgeeks.org/how-to-read-a-xlsx-file-with-multiple-sheets-in-r/) - readxl sheet reading patterns
- [R Shiny: How to get a list of sheet names from an .xlsx file uploaded to a Shiny app using fileInput? - Posit Community](https://forum.posit.co/t/r-shiny-how-to-get-a-list-of-sheet-names-from-an-xlsx-file-uploaded-to-a-shiny-app-using-fileinput/106354) - Shiny + readxl integration

### Tertiary (LOW confidence)
- [XLS and XLSX: Maximum Number of Columns and Rows - AskingBox](https://www.askingbox.com/info/xls-and-xlsx-maximum-number-of-columns-and-rows) - Excel limits (consistent with Microsoft docs, marked tertiary due to third-party source)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - writexl, readxl, shiny all in current dependencies; multi-sheet patterns well-documented
- Architecture: HIGH - Existing 3-sheet export in codebase provides proven foundation; patterns verified in official docs
- Pitfalls: MEDIUM - Based on common R + Shiny + Excel integration issues documented in community forums; no phase-specific pitfalls yet encountered
- Validation: HIGH - Excel format limits are hard constraints documented by Microsoft; testthat framework proven in Phases 10-13

**Research date:** 2026-03-07
**Valid until:** 2026-04-07 (30 days — stable domain, no fast-moving dependencies)
