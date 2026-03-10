# Phase 14: Multi-Sheet Export & Re-Import - Context

**Gathered:** 2026-03-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can export complete pipeline state as a multi-sheet Excel workbook from Review Results and import reference lists/config from a previous ChemReg export into a new dataset via a dedicated sidebar control. No post-curation QC (Phase 15), no new cleaning steps.

</domain>

<decisions>
## Implementation Decisions

### Sheet Structure: Replace Existing Export
- New multi-sheet export REPLACES the existing 3-sheet export in Review Results (not a separate button)
- Sheets in the workbook:
  1. **Raw Data** — original uploaded data as-is (complete audit trail from input to output)
  2. **Curated Data** — final curated data with consensus DTXSIDs, needs_review flag (existing Sheet 1, enhanced)
  3. **Summary** — curation statistics (existing Sheet 2, enhanced)
  4. **Cleaning Audit** — full per-row audit trail (row_id, field, step, original_value, new_value, reason)
  5. **Reference Lists** — combined single sheet with `type` column (functional_category/stop_word/block_pattern) + term, source, active columns (matches Phase 13 CSV upload format)
  6. **Column Tags** — existing Sheet 3 (column name → tag type mapping)
  7. **Pipeline Config** — app version, export timestamp, detection method, pipeline steps run, file info, `chemreg_export: true` marker

### Re-Import: Config Transfer to New Datasets
- Primary use case: carry reference lists and settings from a previous dataset to a NEW dataset (not session restore)
- No session restore — user always re-runs cleaning/curation on the new data
- Dedicated config import control in the **sidebar/upload area** (separate from main file upload)
- On config import: read Pipeline Config sheet, detect `chemreg_export` marker, load reference lists and column tags
- Confirmation modal with opt-out: "ChemReg export detected. Restore reference lists and column tags?" with checkboxes for each (default: restore all)
- Imported reference lists merge with existing (user additions tagged as source = `imported`)

### Export Placement & Trigger
- Export button stays in Review Results tab (current location)
- Export only available after curation is complete (matches current gating)
- Config import button in sidebar area, available after data upload

### Validation: Lightweight Guard
- Simple row count check before writing (guard against >1M rows, but this is a defensive check not a primary feature)
- Only validate curated data sheet size (audit trail unlikely to exceed limits for typical chemical inventory files)
- Block with clear error message if exceeded — no truncation or splitting

### Package: writexl
- Continue using writexl for Excel writing (already in use, simple, sufficient for data frame → sheet)
- No openxlsx2 — keeps dependencies minimal, no formatting needed beyond data tables

### Claude's Discretion
- Config import UI design in sidebar (button style, placement relative to file upload)
- How to handle merge conflicts when importing reference lists that overlap with current lists
- Exact confirmation modal layout and wording
- Pipeline Config sheet key-value format
- Whether to add sheet tab colors or formatting (writexl limitations may constrain this)
- Error handling for malformed ChemReg exports on import

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `mod_review_results.R:773-837`: Existing `downloadHandler` with 3-sheet `writexl::write_xlsx()` — extend to 7 sheets
- `data_store` reactiveValues: Already holds all needed state (raw, clean, cleaned_data, cleaning_audit, column_tags, reference_lists, resolution_state, consensus_summary, file_info)
- `R/cleaning_reference.R`: Reference list loaders with provenance columns (term, source, active) — reuse for import/export
- Phase 13 CSV upload pattern: Single file with `type` column routing to correct lists — same format for Reference Lists sheet

### Established Patterns
- `writexl::write_xlsx(list("Sheet1" = df1, "Sheet2" = df2))` for multi-sheet export
- `data_store$reference_lists$functional_categories` etc. — tibble format with term/source/active columns
- Cascade reset on upstream changes (tag changes reset curation)
- `showModal()` / `modalDialog()` for confirmation dialogs (used in re-upload confirmation)
- Sidebar `fileInput()` for file upload — add second input for config import

### Integration Points
- `R/modules/mod_review_results.R`: Replace `downloadHandler` content function with 7-sheet builder
- `app.R` sidebar: Add config import `fileInput` and handler
- `app.R` server: Add `observeEvent` for config import processing
- `data_store$reference_lists`: Write to this on config import (triggers reactive updates in Clean Data tab)

</code_context>

<specifics>
## Specific Ideas

- The combined Reference Lists sheet with `type` column creates a round-trip: export → edit in Excel → re-import via Phase 13 CSV upload OR via config import
- Config import in sidebar keeps it discoverable but not confused with main data upload
- Including raw data in the export makes it a standalone audit document — someone reviewing the export can see the full journey from input to output without needing the original file
- The `chemreg_export: true` marker in Pipeline Config sheet is the detection mechanism — simple and reliable

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 14-multi-sheet-export-re-import*
*Context gathered: 2026-03-07*
