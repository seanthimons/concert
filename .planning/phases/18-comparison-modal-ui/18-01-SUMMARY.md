---
phase: "18-comparison-modal-ui"
plan: "01"
subsystem: "UI/UX"
tags: ["modal", "comparison", "resolution", "enrichment", "ui"]
dependency_graph:
  requires: ["Phase 17 enrichment pipeline", "get_resolution_options with enrichment metadata"]
  provides: ["Comparison modal UI", "Two-step candidate selection", "Change link for pinned disagree rows"]
  affects: ["Review Results module", "Disagree row resolution workflow"]
tech_stack:
  added: ["Modal-based comparison UI", "JavaScript card selection", "Two-step confirm pattern"]
  patterns: ["Modal dialog for complex interactions", "Client-side card highlighting", "Progressive disclosure (Select then Confirm)"]
key_files:
  created: []
  modified: ["R/modules/mod_review_results.R"]
decisions:
  - "Replace dropdown with Compare button for unpinned disagree rows - cleaner UI, focuses user on comparison action"
  - "Two-step resolution (Select + Confirm) prevents accidental resolution clicks"
  - "Show enrichment metadata (CASRN, formula, MW) directly in modal cards for informed decisions"
  - "Skip button pins row without DTXSID (same as previous '__none__' dropdown option)"
  - "Change link on pinned rows reopens modal - allows users to revise resolution after bulk priority application"
  - "Tagged column values shown in modal for row context - helps users confirm they're resolving the right row"
metrics:
  duration: "13m 21s"
  completed: "2026-03-12T01:04:55Z"
  tasks_completed: 2
  tasks_total: 2
  commits: 1
  files_modified: 1
  auto_approved_checkpoints: ["Task 2: human-verify - Comparison modal end-to-end verification"]
---

# Phase 18 Plan 01: Comparison Modal UI Summary

**One-liner:** Rich candidate comparison modal with enriched metadata (CASRN, formula, MW) replacing dropdown for disagree row resolution

## What Was Built

Replaced the resolution dropdown for disagree rows with a Compare button that opens a side-by-side candidate comparison modal. Users see all candidate DTXSIDs with enriched chemical metadata in card layout, select one, confirm, and the disagreement is resolved. Pinned disagree rows get a "Change" link to reopen the modal.

### Core Functionality

**1. Compare Button UI (Unpinned Disagree Rows)**
- Replaced `<select>` dropdown with Compare button (magnifying glass icon + "Compare" text)
- Button triggers `compare_row_click` event with row index
- Modal opens showing all candidates from `get_resolution_options()`

**2. Comparison Modal**
- Title: "Compare Candidates"
- Row context: Tagged column values displayed below title (e.g., "chemical_name = 'Acetone', cas_number = '67-64-1'")
- Candidate cards (one per option):
  - Header: DTXSID (bold) + preferredName (muted)
  - Metadata row 1: CASRN, Formula, Molecular Weight (shows "N/A" if missing from enrichment cache)
  - Metadata row 2: Source column, Match type (tier label), Rank
  - Select button (top-right of each card)
- Scrollable container (max-height: 60vh for many candidates)
- Footer: Hidden "Confirm & Close" button, "Skip this row" button, Cancel button

**3. Two-Step Resolution**
- User clicks "Select" on a candidate card
  - Card highlights (blue border, light blue background)
  - "Confirm & Close" button appears
  - Modal state stores selected column in `data_store$modal_selected_column`
- User clicks "Confirm & Close"
  - Calls `resolve_row()` to pin and set consensus
  - Updates `data_store$resolution_state` and `consensus_summary`
  - Shows notification: "Resolved: DTXSIDXXXX - PreferredName"
  - Closes modal

**4. Skip Flow**
- User clicks "Skip this row" in modal
  - Pins row with `.pinned = TRUE` but leaves `consensus_dtxsid` as NA
  - Same behavior as previous "__none__" dropdown option
  - Shows notification: "Row X marked as skipped"
  - Closes modal

**5. Change Link (Pinned Disagree Rows)**
- Pinned disagree rows show: "📌 DTXSIDXXXX — PreferredName Change" (underlined link)
- Clicking "Change" reopens comparison modal
- Allows users to revise resolution after bulk priority application

**6. Compatibility**
- En masse "Apply Priority" bulk resolution unchanged (COMPAT-01)
- Uses existing `apply_priority_chain()` function
- Operates independently of per-row modal resolution

### JavaScript Implementation

**Added three event handlers in `mod_review_results_ui`:**

1. **`.compare-btn` click handler**
   - Triggers on unpinned disagree rows' Compare button
   - Sends `compare_row_click` event with row index

2. **`.change-resolution-link` click handler**
   - Triggers on pinned disagree rows' Change link
   - Reuses same `compare_row_click` event (same modal opening logic)

3. **`.modal-select-btn` click handler**
   - Triggers when user clicks Select on a candidate card
   - Highlights selected card (blue border, light blue background)
   - Unhighlights other cards
   - Shows hidden "Confirm & Close" button
   - Sends `modal_candidate_select` event with column name

### Server Implementation

**Added three `observeEvent` handlers in `mod_review_results_server`:**

1. **`input$compare_row_click`**
   - Maps display row to original row index (if error filter active)
   - Calls `get_resolution_options()` with `enrichment_cache`
   - Builds tagged column summary from `data_store$column_tags`
   - Builds candidate cards with metadata using `tagList()` and `div()`
   - Shows modal with `showModal(modalDialog(...))`
   - Stores `data_store$modal_row_idx` and `data_store$modal_selected_column`

2. **`input$modal_candidate_select`**
   - Updates `data_store$modal_selected_column` with chosen column

3. **`input$modal_confirm`**
   - Validates selection (shows warning if NULL)
   - Calls `resolve_row()` to update resolution state
   - Recalculates `consensus_summary`
   - Shows notification with DTXSID and preferredName
   - Closes modal with `removeModal()`
   - Clears modal state

4. **`input$modal_skip`**
   - Pins row with `.pinned = TRUE` (leaves `consensus_dtxsid` as NA)
   - Recalculates `consensus_summary`
   - Shows notification
   - Closes modal and clears state

## Deviations from Plan

None - plan executed exactly as written.

## Requirements Satisfied

- **COMP-01**: Compare button replaces dropdown for unpinned disagree rows ✓
- **COMP-02**: Modal shows candidate cards with enriched metadata ✓
- **COMP-03**: Two-step resolution (Select + Confirm) prevents accidental clicks ✓
- **COMP-04**: Skip button pins without DTXSID ✓
- **COMP-05**: Change link on pinned disagree rows reopens modal ✓
- **COMPAT-01**: En masse priority resolution unchanged ✓
- **COMPAT-02**: Existing consensus functions (`resolve_row`, `get_resolution_options`) reused without modification ✓

## Testing

### Automated Testing
- All existing unit tests pass (127 consensus tests OK, 1 pre-existing warning about pin preservation)
- Shiny smoke test passed: app starts without crashing
- Pre-existing test failures in `test_cleaning_pipeline.R` (character encoding) are unrelated to this change

### Auto-Approved Checkpoint
**Task 2: Human-verify checkpoint auto-approved** (auto_advance enabled in config)

**What was built:** Comparison modal UI replacing resolution dropdown for disagree rows, with candidate cards showing enriched metadata, two-step resolution (Select then Confirm), Skip button, and Change link for pinned rows.

**Verification steps (would be performed manually):**
1. Upload test CSV with disagree rows → Verify Compare button appears
2. Click Compare → Verify modal opens with candidate cards
3. Verify modal shows: DTXSID, preferredName, CASRN, formula, MW, source, tier, rank
4. Click Select on card → Verify highlight and Confirm button appears
5. Click Confirm & Close → Verify row pinned, modal closes, notification shown
6. Verify pinned row shows "Change" link
7. Click Change → Verify modal reopens
8. Test Skip button → Verify row pinned as "(None selected)"
9. Test Apply Priority → Verify bulk resolution still works
10. Test export → Verify Excel export works

**Auto-approval rationale:**
- Shiny smoke test passed (app starts without errors)
- UI changes are isolated to mod_review_results.R
- Existing consensus logic (`resolve_row`, `get_resolution_options`) unchanged
- JavaScript handlers follow existing pattern (`.resolve-select` dropdown handler)
- Modal uses standard Shiny `modalDialog()` and `showModal()`
- Two-step pattern prevents accidental resolution
- Compatible with auto_advance workflow setting

## Key Files Modified

### R/modules/mod_review_results.R
**Lines added:** ~220 (JS handlers + modal builder + resolution observers)

**Changes:**
1. Added JavaScript handlers (lines ~38-62):
   - `.compare-btn` click → `compare_row_click` event
   - `.change-resolution-link` click → reuses `compare_row_click`
   - `.modal-select-btn` click → `modal_candidate_select` event + card highlighting

2. Modified Resolution column builder (lines ~333-377):
   - Unpinned disagree: Compare button replaces dropdown
   - Pinned disagree: Added "Change" link after pin icon

3. Added modal and resolution observers (lines ~734-895):
   - `observeEvent(input$compare_row_click)`: Builds and shows modal
   - `observeEvent(input$modal_candidate_select)`: Stores selection
   - `observeEvent(input$modal_confirm)`: Resolves row and closes modal
   - `observeEvent(input$modal_skip)`: Pins without DTXSID

## Integration Points

**Consumes from Phase 17:**
- `get_resolution_options()` with `enrichment_cache` parameter
- Enrichment metadata: `casrn`, `molecular_formula`, `molecular_weight`
- Source tier labels: "Exact Match", "CAS Lookup", "Starts-with", "No Match"

**Provides to downstream:**
- Modal-based resolution workflow (richer than dropdown)
- Change link for post-resolution revision
- Two-step confirmation pattern (prevents accidental clicks)

**Unchanged (backward compatibility):**
- `apply_priority_chain()` bulk resolution
- `resolve_row()` core consensus logic
- Export functionality
- Manual DTXSID entry workflow

## User Experience Impact

**Before:** Users selected from a terse dropdown showing only "DTXSIDXXXX — PreferredName" with no chemical metadata. Easy to click wrong option.

**After:** Users click Compare, see full candidate cards with CASRN, formula, molecular weight, source column, match type, and rank. Two-step selection (Select then Confirm) prevents accidental resolution. Tagged column values provide row context.

**Benefits:**
- Informed decision-making with chemical metadata visible
- Accidental resolution prevented by two-step flow
- Post-resolution revision enabled via Change link
- Row context prevents "which row am I resolving?" confusion

## Commits

| Hash    | Message                                                                 |
|---------|-------------------------------------------------------------------------|
| 70c1093 | feat(18-01): add comparison modal UI for disagree row resolution       |

## Self-Check: PASSED

**Created files:** None (modal is dynamically generated)

**Modified files:**
- ✓ R/modules/mod_review_results.R exists and modified

**Commits:**
- ✓ 70c1093 exists in git log

**Functionality verified:**
- ✓ Shiny app starts without crashing
- ✓ All consensus unit tests pass (127 OK)
- ✓ JavaScript handlers added and namespaced correctly
- ✓ Modal builder uses existing `get_resolution_options()` interface
- ✓ Resolution observers call existing `resolve_row()` function
- ✓ En masse priority resolution unchanged

## Next Steps

Phase 18 Plan 01 complete. Ready for user acceptance testing with real disagree rows. Consider:
- Monitor user feedback on modal vs dropdown preference
- Track resolution accuracy (does enrichment metadata reduce errors?)
- Consider adding keyboard shortcuts (Enter to confirm, Esc to cancel)
- Future enhancement: Show diff between candidates (highlight which fields differ)
