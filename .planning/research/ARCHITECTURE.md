# Architecture Research: Curation Refinement Integration

**Domain:** Shiny Chemical Curation Application
**Researched:** 2026-03-01
**Confidence:** HIGH

## Current System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                          UI Layer (app.R)                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ Upload   │  │ Tag Cols │  │ Run Cure │  │ Review   │    │
│  │ Tab      │  │ Tab      │  │ Tab      │  │ Results  │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
│       │             │              │             │           │
│       ├─────────────┴──────────────┴─────────────┤           │
│       │         reactiveValues(data_store)       │           │
│       └──────────────────┬────────────────────────┘           │
├──────────────────────────┼──────────────────────────────────┤
│                  Processing Layer                            │
│  ┌────────────────────────┴──────────────────────────────┐   │
│  │                R/curation.R (624 lines)                │   │
│  │  deduplicate_tagged_columns → run_tiered_search       │   │
│  │  → map_results_to_rows → (calls consensus.R)          │   │
│  └───────────────────────┬────────────────────────────────┘   │
│                          │                                    │
│  ┌───────────────────────┴────────────────────────────────┐   │
│  │              R/consensus.R (229 lines)                  │   │
│  │  classify_consensus → init_resolution_state            │   │
│  │  resolve_row → apply_priority_chain                    │   │
│  └─────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                      External API                            │
│  ┌─────────────────────────────────────────────────────┐     │
│  │   CompToxR (ComptoxR:: calls via curation.R)        │     │
│  │   - ct_chemical_search_equal_bulk                   │     │
│  │   - ct_chemical_search_start_with                   │     │
│  │   - as_cas / is_cas                                 │     │
│  └─────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

## New Features Integration Analysis

### Feature 1: Search Chain Reordering (exact → CAS → starts-with)

**Current:** `run_tiered_search()` runs exact → starts-with → CAS (lines 274-363 in curation.R)

**Integration Point:** Modify `run_tiered_search()` tier execution order

**Components Modified:**
- `R/curation.R::run_tiered_search()` (main orchestrator)
- `R/curation.R::run_curation_pipeline()` (inline tier execution with progress callbacks, lines 451-540)

**Data Flow Change:**
```
BEFORE: unique_names → exact → (misses) → starts-with → [separate] unique_cas → CAS
AFTER:  unique_names → exact → (misses) → [check CAS] → (misses) → starts-with
```

**Key Considerations:**
- CAS columns are currently in `unique_cas` — need to treat them as name search candidates first
- Progress callbacks need reordering (lines 471-539)
- Source tier labels (`source_tier` column) remain stable (already has "cas" tier)
- Summary message (line 357-360) needs reordering

**New vs Modified:**
- **MODIFIED:** `run_tiered_search()` — reorder tier 2 and tier 3 blocks
- **MODIFIED:** `run_curation_pipeline()` — reorder inline tier execution
- **NEW:** None

---

### Feature 2: Other Tags as Full Curation Participants

**Current:** `deduplicate_tagged_columns()` only processes Name and CASRN tags (lines 16-58 in curation.R)

**Integration Point:** Expand deduplication and search to include "Other" tag type

**Components Modified:**
- `R/curation.R::deduplicate_tagged_columns()` — extract Other values into unique_names set
- `R/curation.R::map_results_to_rows()` — already handles all tagged columns via `dedup_key_map` (line 390)
- `R/consensus.R::classify_consensus()` — already uses `find_dtxsid_cols()` to auto-detect all dtxsid_* columns (line 53)

**Data Flow Change:**
```
BEFORE:
  Name cols → unique_names → search
  CASRN cols → unique_cas → validate
  Other cols → dedup_key_map only (no search)

AFTER:
  Name cols → unique_names → search
  CASRN cols → unique_cas → validate (then search if reordering)
  Other cols → unique_names → search (full chain participation)
```

**Key Considerations:**
- `dedup_key_map` already tracks all tag types (line 38)
- `map_results_to_rows()` already joins back ALL tagged columns (line 390: `tag_cols <- unique(enriched_keys$column_name)`)
- Consensus already auto-detects dtxsid_* columns via `find_dtxsid_cols()`
- **Minimal change:** Just add Other values to `unique_names` in deduplicate step

**New vs Modified:**
- **MODIFIED:** `deduplicate_tagged_columns()` — add Other to unique_names extraction (lines 43-46)
- **NEW:** None

---

### Feature 3: Hide Untagged Columns in Review Results

**Current:** `output$curation_table` (app.R lines 1370-1484) hides dtxsid_*, preferredName_*, searchName_*, rank_*, source_tier_*, and .pinned columns via `columnDefs: list(visible = FALSE, targets = hidden_indices)` (line 1437)

**Integration Point:** Add original untagged columns to `hidden_cols` vector

**Components Modified:**
- `app.R::output$curation_table` — extend `hidden_cols` to include original columns NOT in `data_store$column_tags`

**Data Flow Change:**
```
BEFORE: All original columns visible in DT, only lookup columns hidden
AFTER:  Only tagged original columns + consensus columns visible, untagged + lookup hidden
```

**Key Considerations:**
- Excel export (`output$download_curated`, lines 1659-1715) should still include ALL columns except `.pinned` (line 1675)
- `data_store$column_tags` is available (set in apply_tags observer, line 1100)
- Need to compute: `untagged_cols <- setdiff(names(df), names(data_store$column_tags))`
- Exclude consensus/resolution columns from hiding: `consensus_status`, `consensus_dtxsid`, `consensus_source`, `qc_tier`, `Resolution`

**New vs Modified:**
- **MODIFIED:** `app.R::output$curation_table` — expand `hidden_cols` logic (line 1413-1420)
- **NEW:** None

---

### Feature 4: Manual DTXSID Entry with Bulk Validation

**Integration Point:** Add UI and server logic to Review Results tab

**New Components:**
```
UI (app.R):
- Checkbox column in DT for row selection (error rows only)
- Input field for manual DTXSID entry
- "Validate & Apply" button

Server (app.R):
- observeEvent(input$validate_manual_dtxsid)
- Call new function: validate_dtxsid_bulk()
- Update resolution_state with validated DTXSID
```

**New Functions (R/curation.R):**
```r
validate_dtxsid_bulk <- function(dtxsid_vector) {
  # Call ComptoxR::ct_chemical_search_equal_bulk(dtxsid_vector)
  # Return tibble(input_dtxsid, is_valid, preferredName)
}

apply_manual_dtxsid <- function(df, row_indices, dtxsid, dtxsid_cols) {
  # Set consensus_dtxsid, consensus_status = "agree" (manual override)
  # Set .pinned = TRUE, consensus_source = "manual"
  # Return modified df
}
```

**Data Flow:**
```
User selects error rows → enters DTXSID → Validate button
  → validate_dtxsid_bulk() → CompToxR exact search
  → apply_manual_dtxsid() → update resolution_state
  → Recalculate consensus_summary
  → DT re-renders with updated status
```

**Key Considerations:**
- Error rows: `df$consensus_status == "error"` (line 1379)
- DT checkbox extension: `extensions = c('Buttons', 'Select')` and `select = 'multi'`
- Bulk validation via `ct_chemical_search_equal_bulk()` (same function as exact search)
- Manual entries should set `consensus_source = "manual"` to distinguish from API results
- Should allow overriding ANY row (not just error), but default UI to error rows only

**New vs Modified:**
- **NEW:** `R/curation.R::validate_dtxsid_bulk()` (~20 lines)
- **NEW:** `R/curation.R::apply_manual_dtxsid()` (~25 lines)
- **MODIFIED:** `app.R::nav_panel("Review Results")` — add manual entry UI (lines 298-345)
- **NEW:** `app.R::observeEvent(input$validate_manual_dtxsid)` (~50 lines)

---

### Feature 5: Error Row Retry with Re-tagging and Result Merging

**Integration Point:** Add workflow to Review Results tab that reruns curation on subset

**New Components:**
```
UI (app.R):
- "Retry Selected Rows" button (visible when error rows selected in DT)
- Modal dialog with column tagging interface for selected rows only
- "Re-curate Subset" button in modal

Server (app.R):
- observeEvent(input$retry_error_rows) — show modal with mini tag UI
- observeEvent(input$run_subset_curation) — run pipeline on subset
- Merge results back into resolution_state
```

**New Functions (R/curation.R):**
```r
run_curation_subset <- function(clean_data, row_indices, column_tags, progress_callback = NULL) {
  # Extract subset: clean_data[row_indices, ]
  # Run deduplicate → search → map → classify on subset
  # Return subset results with original row indices preserved
}

merge_subset_results <- function(original_df, subset_df, row_indices, dtxsid_cols) {
  # Replace rows in original_df with subset_df results
  # Preserve original columns, update dtxsid_* and consensus_* columns
  # Recalculate consensus_summary
  # Return modified original_df
}
```

**Data Flow:**
```
User selects error rows in DT → Retry button
  → Modal with tag dropdowns (pre-filled from data_store$column_tags)
  → User adjusts tags → Re-curate button
  → run_curation_subset(clean_data, row_indices, new_tags)
    → deduplicate → search → map → classify (on subset only)
  → merge_subset_results(resolution_state, subset_results, row_indices)
  → Update data_store$resolution_state
  → Recalculate consensus_summary
  → Close modal, DT re-renders
```

**Key Considerations:**
- Need original `data_store$clean` data (preserved throughout session, line 537)
- Row indices must be preserved through subset pipeline (`clean_data$.row_idx <- row_indices` before processing)
- Tag changes only apply to subset, not global `data_store$column_tags`
- Merged results may change consensus_status from "error" → "agree"/"disagree"/"single"
- Progress callback should work with subset (smaller n)

**New vs Modified:**
- **NEW:** `R/curation.R::run_curation_subset()` (~60 lines, adapted from run_curation_pipeline)
- **NEW:** `R/curation.R::merge_subset_results()` (~40 lines)
- **MODIFIED:** `app.R::nav_panel("Review Results")` — add retry UI elements
- **NEW:** `app.R::observeEvent(input$retry_error_rows)` — show modal (~30 lines)
- **NEW:** `app.R::observeEvent(input$run_subset_curation)` — execute subset pipeline (~70 lines)

---

## Suggested Build Order

### Phase 1: Search Chain Foundations (lowest risk, high value)
1. **Feature 1: Reorder search chain** (exact → CAS → starts-with)
   - Modify `run_tiered_search()` tier order
   - Update progress messages
   - Test with existing data
   - **Rationale:** Self-contained, no new UI, improves accuracy immediately

2. **Feature 2: Other tags as searchable**
   - Modify `deduplicate_tagged_columns()` to include Other in unique_names
   - Test consensus still auto-detects dtxsid_* columns
   - **Rationale:** Leverages existing map/classify logic, minimal change

### Phase 2: UI Refinements (medium complexity, polish)
3. **Feature 3: Hide untagged columns**
   - Extend `hidden_cols` logic in `output$curation_table`
   - Verify Excel export still includes all columns
   - **Rationale:** Simple DT configuration change, no backend changes

### Phase 3: Advanced Features (highest complexity, new workflows)
4. **Feature 4: Manual DTXSID entry**
   - Add `validate_dtxsid_bulk()` and `apply_manual_dtxsid()` functions
   - Add manual entry UI to Review Results
   - Add observeEvent for validation
   - Test with invalid/valid DTXSIDs
   - **Rationale:** New workflow, but single-direction (user → validation → update)

5. **Feature 5: Error row retry**
   - Add `run_curation_subset()` and `merge_subset_results()` functions
   - Add retry UI and modal dialog
   - Add subset curation observeEvent
   - Test merging logic thoroughly
   - **Rationale:** Most complex, requires subset pipeline + merge logic + modal UX

### Dependency Rationale

- **1 → 2:** Search reordering should stabilize before adding Other tags (both affect search tier distribution)
- **2 → 3:** Other tags need to work before hiding untagged (validates that tagged columns show correct consensus)
- **3 → 4:** Column hiding polish before adding manual entry (reduces visual clutter for manual workflow)
- **4 → 5:** Manual entry is simpler workflow (no modal, no merge), test before subset retry complexity

---

## Integration Patterns

### Pattern 1: Reactive Data Store Extensions

**What:** Adding new fields to `reactiveValues(data_store)` to support new features

**Current fields:**
```r
data_store <- reactiveValues(
  raw, clean, detection, file_info,       # Upload/detection
  selected_columns, column_tags,           # Tagging
  curation_results, curation_report, curation_status,  # Legacy
  dedup_preview, consensus_data, consensus_summary,    # Pipeline
  resolution_state, dtxsid_cols, priority_order        # Resolution
)
```

**New fields needed:**
- `selected_rows` (for manual DTXSID entry and retry workflows)
- `subset_tags` (for retry workflow, scoped to selected rows)

**When to use:** Any time a new workflow needs to preserve state between UI interactions

**Trade-offs:**
- **Pro:** Centralized state, survives tab switches
- **Con:** Large reactiveValues can trigger unnecessary re-renders (use `isolate()` when reading for non-reactive operations)

---

### Pattern 2: Function Composition in Curation Pipeline

**What:** New features reuse existing pipeline functions (deduplicate → search → map → classify)

**Example:**
```r
# Existing full pipeline
run_curation_pipeline(clean_data, column_tags, progress_callback)
  → deduplicate_tagged_columns()
  → run_tiered_search()
  → map_results_to_rows()
  → classify_consensus()

# New subset pipeline (Feature 5)
run_curation_subset(clean_data, row_indices, column_tags, progress_callback)
  → subset_data <- clean_data[row_indices, ]
  → deduplicate_tagged_columns(subset_data, column_tags)  # REUSE
  → run_tiered_search()                                    # REUSE
  → map_results_to_rows()                                  # REUSE
  → classify_consensus()                                   # REUSE
  → add original row_indices to result
```

**When to use:** When new workflow is a variant of existing pipeline (different input scope, same logic)

**Trade-offs:**
- **Pro:** DRY, reuses tested logic, consistent behavior
- **Con:** Functions must be pure (no side effects) to safely reuse in subset context

---

### Pattern 3: Progressive Disclosure in DT

**What:** Show/hide UI elements based on row selection and consensus_status

**Current usage:**
- Resolution dropdowns only appear for `consensus_status == "disagree"` rows (line 1384-1409)
- Pinned rows show pin icon instead of dropdown (line 1385-1388)

**New usage:**
- Manual DTXSID entry UI only enabled when error rows selected
- Retry workflow button only visible when rows selected in DT

**Implementation:**
```r
# In UI
conditionalPanel(
  condition = "output.has_selected_rows && output.all_selected_are_errors",
  actionButton("retry_error_rows", "Retry Selected Rows")
)

# In server
output$has_selected_rows <- reactive({
  length(input$curation_table_rows_selected) > 0
})
outputOptions(output, "has_selected_rows", suspendWhenHidden = FALSE)

output$all_selected_are_errors <- reactive({
  req(data_store$resolution_state, input$curation_table_rows_selected)
  selected_statuses <- data_store$resolution_state$consensus_status[input$curation_table_rows_selected]
  all(selected_statuses == "error")
})
outputOptions(output, "all_selected_are_errors", suspendWhenHidden = FALSE)
```

**Trade-offs:**
- **Pro:** Reduces UI clutter, guides user to valid actions
- **Con:** Requires reactive outputs for conditionalPanel (can't use `req()` in condition string)

---

## Data Flow: New Features

### Manual DTXSID Entry Flow

```
Review Results DT
  → User selects error rows (DT select extension)
  → User enters DTXSID in text input
  → Click "Validate & Apply"
    ↓
observeEvent(input$validate_manual_dtxsid)
  → dtxsid <- input$manual_dtxsid_input
  → selected_rows <- input$curation_table_rows_selected
    ↓
validate_dtxsid_bulk(dtxsid)
  → ComptoxR::ct_chemical_search_equal_bulk(dtxsid)
  → Returns: is_valid, preferredName
    ↓
If valid:
  apply_manual_dtxsid(data_store$resolution_state, selected_rows, dtxsid, dtxsid_cols)
    → Set consensus_dtxsid = dtxsid
    → Set consensus_status = "agree"
    → Set consensus_source = "manual"
    → Set .pinned = TRUE
    ↓
  Update data_store$resolution_state
  Update data_store$consensus_summary
  DT re-renders (updated row shows "agree" status)
```

### Subset Retry Flow

```
Review Results DT
  → User selects error rows
  → Click "Retry Selected Rows"
    ↓
showModal(modalDialog(
  title = "Re-tag and Re-curate Selected Rows",
  uiOutput("subset_tagging_ui"),  # Column tag dropdowns pre-filled
  actionButton("run_subset_curation", "Re-curate Subset")
))
    ↓
User adjusts tags in modal
  → Click "Re-curate Subset"
    ↓
observeEvent(input$run_subset_curation)
  → selected_rows <- input$curation_table_rows_selected
  → subset_tags <- collect tags from modal inputs
  → subset_data <- data_store$clean[selected_rows, ]
    ↓
run_curation_subset(subset_data, selected_rows, subset_tags, progress_callback)
  → deduplicate → search → map → classify (on subset only)
  → Returns: subset_results with .row_idx preserved
    ↓
merge_subset_results(data_store$resolution_state, subset_results, selected_rows, dtxsid_cols)
  → Replace dtxsid_*, preferredName_*, consensus_* columns for selected rows
  → Recalculate consensus_summary
  → Return updated df
    ↓
Update data_store$resolution_state
Update data_store$consensus_summary
removeModal()
DT re-renders (updated rows show new consensus)
```

---

## Anti-Patterns

### Anti-Pattern 1: Modifying Global column_tags in Subset Workflow

**What people might do:** Update `data_store$column_tags` when user re-tags subset rows

**Why it's wrong:**
- Global tags apply to ALL rows in next full curation run
- Subset re-tagging is row-specific override, not global preference change
- Would confuse users if they re-run full curation and see unexpected tags

**Do this instead:**
- Store subset tags in local variable or `data_store$subset_tags` (ephemeral)
- Pass subset tags ONLY to `run_curation_subset()`
- Do NOT update `data_store$column_tags`

---

### Anti-Pattern 2: Rerunning Full Pipeline for Manual DTXSID Entry

**What people might do:** Call `run_curation_pipeline()` after manual DTXSID entry to "refresh" results

**Why it's wrong:**
- Wastes API calls (re-searches all rows)
- Slow UX (user sees progress spinner for simple update)
- Overwrites manual entries (pipeline would re-classify and lose manual override)

**Do this instead:**
- Directly update `data_store$resolution_state` with manual DTXSID
- Set `.pinned = TRUE` to preserve manual entry
- Recalculate `consensus_summary` counts without re-running pipeline
- Only call API for validation (`validate_dtxsid_bulk()`), not full search

---

### Anti-Pattern 3: Losing Row Indices in Subset Pipeline

**What people might do:** Run pipeline on `clean_data[selected_rows, ]` without preserving original row indices

**Why it's wrong:**
- Subset results have row indices 1:n (where n = number of selected rows)
- Original data has row indices that may not be contiguous (e.g., c(5, 12, 47))
- Merge function needs original indices to update correct rows

**Do this instead:**
```r
# Before pipeline
subset_data <- clean_data[selected_rows, ]
subset_data$.original_row_idx <- selected_rows

# After pipeline
merge_subset_results(original_df, subset_df, subset_df$.original_row_idx, dtxsid_cols)
```

---

## Scaling Considerations

### Current Scale (v1.2)
- **Rows:** 10-10,000 rows per file (typical chemical inventory)
- **Columns:** 5-50 columns (1-10 tagged for curation)
- **API calls:** Deduplicated, typically 100-5,000 unique names/CAS per file

**Architecture is appropriate for scale:**
- Single-file uploads (no batch processing needed)
- In-memory processing (reactiveValues, no database)
- Synchronous API calls with progress feedback

### Future Bottlenecks (if scaling to 100k+ rows)

1. **DT rendering:** Large DT tables (>10k rows) may lag in browser
   - **Mitigation:** Server-side processing (`DT::renderDT(..., server = TRUE)`)
   - **When:** If users upload files with >10k rows regularly

2. **API rate limits:** CompToxR bulk endpoints may throttle
   - **Mitigation:** Batch API calls (already doing via `_bulk()` functions)
   - **When:** If unique names exceed API rate limits (check ComptoxR docs)

3. **Memory:** reactiveValues stores full dataset + results in session
   - **Mitigation:** Switch to database backend (DuckDB, SQLite)
   - **When:** If file sizes exceed 100MB or concurrent users stress server RAM

**Current v1.2 scope:** No scaling changes needed. Features 1-5 maintain current architecture.

---

## Sources

- **Existing codebase:** app.R (1,719 lines), R/curation.R (624 lines), R/consensus.R (229 lines)
- **Shiny patterns:** [Mastering Shiny - Reactivity](https://mastering-shiny.org/basic-reactivity.html) (MEDIUM confidence, year 2025)
- **DT extensions:** [DT package documentation - Select extension](https://rstudio.github.io/DT/extensions.html) (HIGH confidence, official docs)
- **ComptoxR API:** [ComptoxR GitHub](https://github.com/cran/ComptoxR) (HIGH confidence, package source)

---

*Architecture research for: ChemReg v1.2 Curation Refinement*
*Researched: 2026-03-01*
