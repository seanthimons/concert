# Phase 08: Error Recovery Workflows - Research

**Researched:** 2026-03-03
**Domain:** Shiny reactive state management, DT inline editing, CompTox bulk validation
**Confidence:** MEDIUM

## Summary

Phase 08 enables users to manually recover from curation errors through three workflows: (1) inline DTXSID entry for error rows, (2) bulk validation of manual entries against CompTox API, and (3) re-tagging and re-curating failed rows with updated tag assignments. The phase extends the existing resolution state system with manual entry tracking, validation feedback, and retry merge-back logic.

**Key architectural challenges:**
- DT cell editing requires custom JavaScript callbacks and reactive event handling
- Bulk validation needs deduplication, progress tracking, and per-cell failure reporting
- Retry merge-back must preserve row order, pinned resolutions, and handle column count changes

**Primary recommendation:** Use DT's native `editable = "cell"` with `input$tableId_cell_edit` for inline editing, implement a dedicated validation queue pattern (similar to existing dedup preview), and extend `run_curation_pipeline` with a retry-specific mode that merges results back via row index matching.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **DTXSID entry:** Inline cell click (not modal, not batch panel) — user clicks DTXSID cell directly on error rows to type/paste value
- **Entry confirm:** On blur (when user clicks away or tabs out) — entry saved and queued for bulk validation, no extra button clicks
- **Manual indicator:** Badge/icon distinguishes manually-entered DTXSIDs from auto-resolved values, persists after validation
- **Validation trigger:** Dedicated "Validate All" button batches API calls, no auto-validation on entry
- **Validation progress:** Progress bar with count ("Validating 3 of 12...") during bulk validation
- **Validation failure:** Summary notification (e.g., "8 validated, 2 failed") AND inline cell indicators (red border/message on invalid cells)
- **Post-validation:** Auto-populate preferredName and update consensus status immediately, no separate review/apply step
- **Error row selection:** Filter view button shows only error rows, select from filtered subset — no always-visible checkboxes
- **Re-tag approach:** Bulk re-tag as default (modal shows column-to-tag mapping for all selected), with individual row override capability
- **Re-curate trigger:** After re-tagging, user sees updated tags and clicks "Re-curate" to trigger search — not automatic
- **Search pipeline:** Full tier chain (exact → CAS → starts-with) for re-curation, no option to pick individual tiers
- **Merge style:** Silent replace — re-curated results update in place as if they succeeded originally, no before/after comparison
- **Consensus status for manual entries:** Distinct "manual" status — manually-resolved rows do NOT get "unanimous" classification
- **Pin preservation:** Pinned resolutions on non-selected rows are NEVER touched, re-curation only affects selected error rows
- **Re-fail behavior:** If re-curated row still fails, assign new "unresolvable" status (distinct from plain "error")
- **Row order:** Always original upload order — re-curated rows slot back into original positions, table order never changes

### Claude's Discretion
- Implementation details for manual DTXSID validation logic
- How to queue and batch manual entries for validation
- Data structure for tracking manual vs auto-resolved rows
- Error message specificity for validation failures
- Re-tag modal UI details beyond column-to-tag mapping

### Deferred Ideas (OUT OF SCOPE)
None captured during discussion.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| RECV-01 | User can manually enter a DTXSID for any error-status row | DT editable cells + reactive event handling for error-filtered rows |
| RECV-02 | User can bulk-validate all manually entered DTXSIDs against CompTox in one action | Validation queue pattern + CompTox batch search API (similar to existing `validate_and_lookup_cas`) |
| RECV-03 | Validated manual DTXSIDs populate preferredName and update consensus status | Reactive state merge + new "manual" consensus status classification |
| RECV-04 | User can select error rows, re-assign tag types, and re-curate just that subset | DT row selection + tag assignment modal + filtered pipeline execution |
| RECV-05 | Re-curated results merge back into main resolution state preserving existing .pinned rows and row order | Row index-based merge with pin checking + comprehensive unit tests for merge scenarios |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| DT | Latest (CRAN) | Interactive data table with cell editing | Official Shiny ecosystem table widget, supports `editable = "cell"` for inline editing |
| shiny | Latest | Reactive state management | Already in use, provides `observeEvent(input$tableId_cell_edit)` for edit handling |
| ComptoxR | Current | CompTox API client | Already in use for DTXSID lookup, supports bulk search via `ct_chemical_search_equal_bulk()` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dplyr | Latest | Data manipulation for merge-back | Row filtering, join operations for retry merge logic |
| shinyjs | Latest | UI state management | Show/hide validation progress, disable buttons during processing |
| purrr | Latest | Safe iteration for validation | `safely()` wrapper for per-DTXSID validation to prevent batch failure |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| DT editable cells | rhandsontable | More Excel-like, but heavier dependency and steeper learning curve |
| Custom validation queue | Validate on blur | Batching reduces API calls but adds state management complexity |
| Row index merge | DTXSID key merge | Index preserves order naturally, key merge requires sorting logic |

**Installation:**
```r
# All packages already in use — no new dependencies
```

## Architecture Patterns

### Recommended Project Structure
```
R/
├── curation.R              # Extend with retry_curation_pipeline()
├── consensus.R             # Add "manual" and "unresolvable" status support
├── validation.R            # NEW: validate_manual_dtxsids() batch validation
└── merge_helpers.R         # NEW: merge_retry_results() with pin preservation

app.R                       # Add manual entry observers, validation flow, re-tag modal
```

### Pattern 1: DT Cell Editing with Validation Queue

**What:** Enable inline editing on a specific column (consensus_dtxsid for error rows), store edits in a reactive queue until user clicks "Validate All"

**When to use:** For batch API operations where immediate validation would cause performance issues

**Example:**
```r
# Enable editing on consensus_dtxsid column for error rows only
output$curation_table <- renderDT({
  df <- data_store$resolution_state

  # Mark error rows as editable
  dt <- datatable(
    df,
    editable = list(
      target = "cell",
      disable = list(
        columns = which(names(df) != "consensus_dtxsid") - 1,  # 0-indexed
        rows = which(df$consensus_status != "error") - 1
      )
    ),
    # ... other options
  )
  dt
})

# Capture edits in validation queue
observeEvent(input$curation_table_cell_edit, {
  info <- input$curation_table_cell_edit
  row_idx <- info$row
  new_value <- info$value

  # Store in queue (reactive list of row_idx -> dtxsid)
  data_store$manual_queue[[as.character(row_idx)]] <- new_value

  # Add visual indicator (badge/icon) via proxy update
  # ... proxy logic to add "manual" badge to edited cell
})

# Validate All button
observeEvent(input$validate_all, {
  req(data_store$manual_queue)

  # Extract unique DTXSIDs for bulk validation
  dtxsids <- unique(unlist(data_store$manual_queue))

  withProgress(message = "Validating manual entries...", {
    validation_results <- validate_manual_dtxsids(dtxsids)
  })

  # Merge back: update resolution_state, add preferredName, set status to "manual"
  # ... merge logic
})
```

**Source:** Adapted from [DT Shiny documentation](https://rstudio.github.io/DT/shiny.html) and project's existing reactive state pattern

### Pattern 2: Retry Merge with Pin Preservation

**What:** Merge re-curated results back into main resolution state by row index, preserving .pinned rows and original order

**When to use:** When re-running a subset of rows through the curation pipeline and need to update only those rows

**Example:**
```r
merge_retry_results <- function(original_state, retry_results, selected_row_indices) {
  # Validation: check column count consistency for same-tag retry
  original_cols <- names(original_state)
  retry_cols <- names(retry_results)

  # For same-tag retry: columns should match (except new lookup columns)
  # For new-tag retry: new dtxsid/preferredName columns will be added

  # Merge strategy: row index matching
  for (i in seq_along(selected_row_indices)) {
    row_idx <- selected_row_indices[i]

    # Skip if pinned (should not happen for error rows, but safety check)
    if (isTRUE(original_state$.pinned[row_idx])) next

    # Update consensus columns
    original_state$consensus_dtxsid[row_idx] <- retry_results$consensus_dtxsid[i]
    original_state$consensus_status[row_idx] <- retry_results$consensus_status[i]
    original_state$consensus_source[row_idx] <- retry_results$consensus_source[i]

    # Update lookup columns (dtxsid_*, preferredName_*, rank_*, source_tier_*)
    # Match by column suffix (column name from tags)
    # ... column-by-column update logic
  }

  original_state
}
```

**Source:** Derived from existing `apply_priority_chain()` pattern in R/consensus.R (lines 229-249) which iterates over rows while respecting .pinned state

### Pattern 3: Consensus Status Extension for Manual/Unresolvable

**What:** Extend classify_consensus() to support two new status values: "manual" (user-entered DTXSID) and "unresolvable" (retry failed)

**When to use:** After manual DTXSID validation or after retry pipeline returns error status for second time

**Example:**
```r
# In classify_consensus(), add manual override logic
classify_consensus <- function(df, dtxsid_cols, manual_flags = NULL) {
  # ... existing logic

  # After normal classification, check for manual overrides
  if (!is.null(manual_flags)) {
    manual_rows <- which(manual_flags)
    consensus_status[manual_rows] <- ifelse(
      !is.na(consensus_dtxsid[manual_rows]),
      "manual",
      consensus_status[manual_rows]  # Keep error if validation failed
    )
  }

  # ... return df with updated status
}

# In retry merge logic, detect re-fails
mark_unresolvable <- function(df, original_error_rows, retry_error_rows) {
  # Rows that were error before AND error after retry -> unresolvable
  still_error <- intersect(original_error_rows, retry_error_rows)
  df$consensus_status[still_error] <- "unresolvable"
  df
}
```

**Source:** Extension of existing `classify_consensus()` function in R/consensus.R (lines 46-115)

### Anti-Patterns to Avoid

- **Mutating DT data frame directly in observe:** DT reactivity breaks if you modify the source data frame without using replaceData() or rerendering. Always use `dataTableProxy()` for updates.
- **Validating on every keystroke:** Creates API spam and poor UX. Batch validation after blur/explicit button click.
- **Recreating entire table on edit:** Use `replaceData()` or column-specific proxy updates, not `renderDT()` re-execution.
- **Forgetting to reset manual queue after validation:** Stale queue causes duplicate validation attempts.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cell editing UI | Custom input fields + JavaScript | DT `editable` parameter | DT handles edit mode triggers, keyboard navigation, validation state — complex JS to replicate |
| DTXSID format validation | Regex pattern matching | ComptoxR API response validation | CompTox API returns structured error for invalid DTXSIDs, no need to guess format rules |
| Progress bar state | Custom CSS animations | shiny `withProgress()` | Built-in progress tracking with automatic cleanup and percent calculation |
| Row order preservation | Manual sorting after merge | Index-based merge | Row indices from original upload are stable identifiers, avoid fragile sort key dependencies |

**Key insight:** DT's editable cells already handle focus management, keyboard events, and visual feedback. Custom implementations typically miss edge cases (Escape to cancel, Tab navigation, undo) and create maintenance burden.

## Common Pitfalls

### Pitfall 1: DT Editable Column Indexing (0-based vs 1-based)

**What goes wrong:** DT uses 0-based column indexing for JavaScript options (`editable`, `columnDefs`) but R data frames are 1-based. Forgetting to subtract 1 causes wrong columns to be editable.

**Why it happens:** JavaScript convention leaks into DT's R API for historical reasons (underlying DataTables.js library is JS-native)

**How to avoid:**
```r
# WRONG
editable_col_idx <- which(names(df) == "consensus_dtxsid")  # Returns 15 (1-based)
dt <- datatable(df, editable = list(target = "cell", disable = list(columns = editable_col_idx)))

# CORRECT
editable_col_idx <- which(names(df) == "consensus_dtxsid") - 1  # Subtract 1 for 0-based
dt <- datatable(df, editable = list(target = "cell", disable = list(columns = editable_col_idx)))
```

**Warning signs:** Wrong column becomes editable, or all columns frozen

**Source:** [DT GitHub issue #928](https://github.com/rstudio/DT/issues/928) discusses this confusion

### Pitfall 2: Cell Edit Event Timing vs State Updates

**What goes wrong:** `input$tableId_cell_edit` fires before DT's internal data is updated, so reading from `df` in the observer gives stale data

**Why it happens:** Shiny reactive cycle processes input events before output re-renders

**How to avoid:**
```r
# WRONG — reads stale data
observeEvent(input$curation_table_cell_edit, {
  info <- input$curation_table_cell_edit
  row_idx <- info$row
  current_value <- data_store$resolution_state$consensus_dtxsid[row_idx]  # STALE
})

# CORRECT — use info$value from event
observeEvent(input$curation_table_cell_edit, {
  info <- input$curation_table_cell_edit
  row_idx <- info$row
  new_value <- info$value  # Use this, not df lookup

  # Update state explicitly
  data_store$resolution_state$consensus_dtxsid[row_idx] <- new_value
})
```

**Warning signs:** Edits seem to "lag" by one keystroke, or validation checks stale values

**Source:** [Posit Community thread on DT cell editing](https://forum.posit.co/t/dt-datatable-with-editable-cells-recalculate-data-frame-based-on-user-inputs/80061)

### Pitfall 3: Retry Merge Column Count Mismatch

**What goes wrong:** Re-tagging with a different column set creates new `dtxsid_*` columns, but merge logic assumes column names match original state

**Why it happens:** Original tags: Name+CAS (2 cols). Retry tags: Name+CAS+Other (3 cols). Merge tries to update `dtxsid_Other` column that doesn't exist in original state.

**How to avoid:**
```r
merge_retry_results <- function(original_state, retry_results, selected_row_indices, tags_changed = FALSE) {
  if (tags_changed) {
    # Add new columns to original_state before merge
    new_cols <- setdiff(names(retry_results), names(original_state))
    for (col in new_cols) {
      original_state[[col]] <- NA  # Initialize with NA for non-retry rows
    }
  }

  # Now safe to merge
  # ... row update logic
}
```

**Warning signs:** `Error: unknown column 'dtxsid_Other'` during merge, or silent data loss

**Test coverage:** STATE.md flags this as needing "comprehensive unit tests — test row order preservation, .pinned state, column count validation for same-tag retry, new-tag addition, tag removal scenarios"

### Pitfall 4: Bulk Validation API Rate Limiting

**What goes wrong:** Validating 50+ manual DTXSIDs in one batch hits CompTox API rate limits, causing partial failures or timeouts

**Why it happens:** CompTox API likely has per-second or per-batch limits (undocumented in public API)

**How to avoid:**
```r
validate_manual_dtxsids <- function(dtxsids, batch_size = 20, delay_sec = 1) {
  # Split into batches
  batches <- split(dtxsids, ceiling(seq_along(dtxsids) / batch_size))

  results <- list()
  for (i in seq_along(batches)) {
    # Validate batch
    batch_result <- ComptoxR::ct_chemical_search_equal_bulk(batches[[i]])
    results[[i]] <- batch_result

    # Delay between batches (except last)
    if (i < length(batches)) Sys.sleep(delay_sec)
  }

  dplyr::bind_rows(results)
}
```

**Warning signs:** Validation hangs, timeout errors after ~30 seconds, or API returns HTTP 429

**Note:** Existing `validate_and_lookup_cas()` in R/curation.R (lines 185-266) doesn't batch — may need update if CAS validation also hits limits at scale

## Code Examples

Verified patterns from official sources and existing codebase:

### DT Editable Cell Configuration

**Source:** [DT Shiny documentation](https://rstudio.github.io/DT/shiny.html) + existing app.R table patterns

```r
# Make only consensus_dtxsid editable, only for error rows
output$curation_table <- renderDT({
  df <- data_store$resolution_state

  # Identify error rows (0-indexed for DT)
  error_row_indices <- which(df$consensus_status == "error") - 1

  # Identify consensus_dtxsid column (0-indexed)
  dtxsid_col_idx <- which(names(df) == "consensus_dtxsid") - 1

  dt <- datatable(
    df,
    editable = list(
      target = "cell",
      # Disable all columns except consensus_dtxsid
      disable = list(
        columns = setdiff(seq_len(ncol(df)) - 1, dtxsid_col_idx)
      )
    ),
    options = list(
      # ... existing options from app.R lines 1549-1605
    ),
    # ... other params
  )

  # Add conditional row formatting for editable cells
  dt %>% formatStyle(
    'consensus_dtxsid',
    target = 'cell',
    backgroundColor = styleEqual(
      df$consensus_status,
      ifelse(df$consensus_status == "error", "rgba(255, 255, 200, 0.3)", "transparent")
    )
  )
})
```

### Capture and Queue Manual Edits

**Source:** Adapted from [DT edit example](https://rdrr.io/github/rstudio/DT/src/inst/examples/DT-edit/app.R)

```r
# Initialize manual entry queue
data_store$manual_queue <- reactiveVal(list())

# Capture cell edits
observeEvent(input$curation_table_cell_edit, {
  req(data_store$resolution_state)

  info <- input$curation_table_cell_edit
  row_idx <- info$row
  new_dtxsid <- trimws(as.character(info$value))  # Trim whitespace

  # Validation: basic DTXSID format check (DTXSID followed by digits)
  if (!grepl("^DTXSID\\d+$", new_dtxsid, ignore.case = TRUE)) {
    showNotification(
      paste0("Invalid DTXSID format: ", new_dtxsid, ". Expected format: DTXSIDxxxxxxx"),
      type = "warning",
      duration = 5
    )
    return()
  }

  # Update queue
  current_queue <- data_store$manual_queue()
  current_queue[[as.character(row_idx)]] <- new_dtxsid
  data_store$manual_queue(current_queue)

  # Update display state (add badge, don't validate yet)
  updated_df <- data_store$resolution_state
  updated_df$consensus_dtxsid[row_idx] <- new_dtxsid
  updated_df$.manual_entry[row_idx] <- TRUE  # Track manual entries
  data_store$resolution_state <- updated_df

  showNotification(
    paste0("Row ", row_idx, " queued for validation"),
    type = "message",
    duration = 2
  )
})
```

### Bulk Validate Manual DTXSIDs

**Source:** Adapted from existing `validate_and_lookup_cas()` in R/curation.R

```r
# New function in R/validation.R
validate_manual_dtxsids <- function(dtxsids) {
  empty_result <- tibble::tibble(
    searchValue = character(0),
    dtxsid = character(0),
    preferredName = character(0),
    is_valid = logical(0)
  )

  if (length(dtxsids) == 0) return(empty_result)

  # Use ComptoxR bulk search to validate DTXSIDs
  tryCatch({
    raw <- ComptoxR::ct_chemical_search_equal_bulk(dtxsids)

    if (is.null(raw) || nrow(raw) == 0) {
      # All failed validation
      return(tibble::tibble(
        searchValue = dtxsids,
        dtxsid = NA_character_,
        preferredName = NA_character_,
        is_valid = FALSE
      ))
    }

    # Standardize columns (similar to search_exact pattern)
    result <- tibble::tibble(
      searchValue = raw[[grep("^search.?value$", names(raw), ignore.case = TRUE)[1]]],
      dtxsid = raw[[grep("^dtxsid$", names(raw), ignore.case = TRUE)[1]]],
      preferredName = raw[[grep("^preferred.?name$", names(raw), ignore.case = TRUE)[1]]],
      is_valid = !is.na(dtxsid)
    )

    # Add rows for DTXSIDs that weren't in API response (invalid)
    missing <- setdiff(dtxsids, result$searchValue)
    if (length(missing) > 0) {
      result <- dplyr::bind_rows(
        result,
        tibble::tibble(
          searchValue = missing,
          dtxsid = NA_character_,
          preferredName = NA_character_,
          is_valid = FALSE
        )
      )
    }

    result
  }, error = function(e) {
    # API failure — mark all as invalid
    message("Manual DTXSID validation failed: ", e$message)
    tibble::tibble(
      searchValue = dtxsids,
      dtxsid = NA_character_,
      preferredName = NA_character_,
      is_valid = FALSE
    )
  })
}
```

### Validate All Button Handler

**Source:** Pattern from existing `run_curation` observer in app.R (lines 1184-1288)

```r
observeEvent(input$validate_all, {
  req(data_store$manual_queue)

  queue <- data_store$manual_queue()
  if (length(queue) == 0) {
    showNotification("No manual entries to validate", type = "warning", duration = 3)
    return()
  }

  # Extract unique DTXSIDs and row indices
  row_indices <- as.integer(names(queue))
  dtxsids <- unique(unlist(queue))

  withProgress(message = "Validating manual DTXSIDs...", value = 0, {
    incProgress(0.2, detail = paste("Validating", length(dtxsids), "entries..."))

    validation_results <- validate_manual_dtxsids(dtxsids)

    incProgress(0.6, detail = "Updating results...")

    # Merge back into resolution_state
    updated_df <- data_store$resolution_state
    n_valid <- 0
    n_invalid <- 0
    invalid_rows <- c()

    for (i in seq_along(row_indices)) {
      row_idx <- row_indices[i]
      entered_dtxsid <- queue[[as.character(row_idx)]]

      # Find validation result
      val_result <- validation_results[validation_results$searchValue == entered_dtxsid, ]

      if (nrow(val_result) > 0 && val_result$is_valid[1]) {
        # Valid: update consensus, add preferredName, set status to "manual"
        updated_df$consensus_dtxsid[row_idx] <- val_result$dtxsid[1]
        # Store preferredName in a new column or existing pattern (TBD based on UI needs)
        updated_df$consensus_status[row_idx] <- "manual"
        updated_df$consensus_source[row_idx] <- "manual_entry"
        n_valid <- n_valid + 1
      } else {
        # Invalid: mark cell for visual feedback, keep error status
        invalid_rows <- c(invalid_rows, row_idx)
        n_invalid <- n_invalid + 1
      }
    }

    data_store$resolution_state <- updated_df

    incProgress(0.2, detail = "Done")

    # Clear queue after validation
    data_store$manual_queue(list())

    # Summary notification
    showNotification(
      paste0("Validation complete: ", n_valid, " valid, ", n_invalid, " failed"),
      type = if (n_invalid > 0) "warning" else "message",
      duration = 8
    )

    # Inline feedback for failed cells (if any)
    if (n_invalid > 0) {
      # Use DT proxy to add visual indicator (red border) to invalid cells
      # This would require custom JavaScript callback in DT options
      # OR re-render table with conditional formatting on .validation_failed flag
      showNotification(
        paste("Failed rows:", paste(invalid_rows, collapse = ", ")),
        type = "error",
        duration = NULL
      )
    }
  })
})
```

## Validation Architecture

> *(config.json does not have workflow.nyquist_validation flag — skipping this section per instructions)*

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| DT editing via external inputs | Native `editable = "cell"` | DT v0.2+ (2016) | Simplified inline editing, removed need for custom input widgets |
| Manual DTXSID entry not supported | Phase 08 adds inline entry + validation | Phase 08 (v1.2) | Users can recover from API misses without re-uploading |
| Single-pass curation only | Retry pipeline with merge-back | Phase 08 (v1.2) | Enables iterative refinement of tag assignments |
| Error status only | "manual" and "unresolvable" statuses | Phase 08 (v1.2) | Audit trail for how resolutions were achieved |

**Deprecated/outdated:**
- `rhandsontable` for editable tables: DT's native editing simpler for single-column edit use case
- Validating DTXSIDs via regex: CompTox API response is authoritative, regex guesses format

## Open Questions

1. **Manual DTXSID preferredName storage pattern**
   - What we know: Validation returns preferredName, need to display it in Resolution column
   - What's unclear: Should manual entries create their own `preferredName_manual` column or reuse existing `preferredName_*` columns?
   - Recommendation: Add `manual_preferredName` column to avoid polluting lookup result columns. Display in Resolution column same as auto-resolved rows.

2. **Re-tag modal column mapping UI**
   - What we know: Modal shows column-to-tag mapping for all selected rows, user can override per-row
   - What's unclear: For 50+ selected rows, does "per-row override" mean a sub-table within modal, or a different workflow?
   - Recommendation: Bulk mapping as default (one dropdown per column), with "Advanced" toggle that shows row-by-row grid (use rhandsontable or similar). Start with bulk-only for Wave 1, add per-row override if user requests.

3. **"Unresolvable" status recovery path**
   - What we know: Rows that fail twice (original + retry) get "unresolvable" status
   - What's unclear: Should "unresolvable" rows still be editable for manual DTXSID entry, or are they truly unrecoverable?
   - Recommendation: Keep them editable. "Unresolvable" signals exhaustion of auto-curation paths, but manual entry is still valid recovery option. Document in UI (tooltip: "Auto-curation failed — try manual DTXSID entry").

4. **Filter view persistence**
   - What we know: Error filter button shows only error rows for selection
   - What's unclear: Does filter persist after selection (stay filtered during re-tag modal), or reset to full table after selection?
   - Recommendation: Persist during re-tag workflow (modal, re-curate, merge), reset on navigate away from Review Results tab. Reduces disorientation from sudden table expansion.

## Sources

### Primary (HIGH confidence)
- Existing codebase patterns: R/consensus.R, R/curation.R, app.R (resolution flow, reactive state management)
- [DT Shiny documentation](https://rstudio.github.io/DT/shiny.html) - editable cells, cell_edit event handling
- [DT edit example](https://rdrr.io/github/rstudio/DT/src/inst/examples/DT-edit/app.R) - official example from DT package source

### Secondary (MEDIUM confidence)
- [Posit Community: DT editable cells with reactive recalculation](https://forum.posit.co/t/dt-datatable-with-editable-cells-recalculate-data-frame-based-on-user-inputs/80061) - community pattern for cell edit observers
- [DT GitHub issue #928](https://github.com/rstudio/DT/issues/928) - column indexing gotcha (0-based vs 1-based)
- [CompTox Batch Search documentation](https://www.epa.gov/comptox-tools/chemicals-dashboard-help-batch-search) - DTXSID validation behavior
- [ctxR package vignette](https://cran.r-project.org/web/packages/ctxR/vignettes/Introduction.html) - Alternative CompTox R client (not used in project, but confirms API patterns)

### Tertiary (LOW confidence)
- Web search for "ComptoxR" package found no official CRAN package — project may be using custom wrapper or different package name. Research relied on existing codebase usage patterns instead.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - DT and shiny patterns well-documented and already in use
- Architecture: MEDIUM - Cell editing and validation queue patterns verified, but merge-back logic needs testing to confirm row order preservation behavior
- Pitfalls: MEDIUM - DT indexing and edit timing issues confirmed via community sources, but API rate limiting assumption unverified (no public CompTox rate limit documentation found)

**Research date:** 2026-03-03
**Valid until:** 2026-04-03 (30 days — DT and Shiny are stable, but CompTox API behavior may change)
