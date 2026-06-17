---
# concert-bkp3
title: Round-trip re-import of finished CONCERT exports
status: todo
type: feature
priority: normal
tags:
    - source:github
    - github:issue
    - complexity:high
    - impact:high
    - priority:medium
    - round-trip-import
created_at: 2026-06-17T00:52:06Z
updated_at: 2026-06-17T01:14:59Z
parent: concert-txg1
---

GitHub: #31 https://github.com/seanthimons/concert/issues/31

Imported from GitHub issue #31 during todo sync on 2026-06-17.

---

## Problem Statement

After exporting a curated dataset from CONCERT, there is no way to re-upload that export to resume work. If a user discovers a single row needs correction, or wants to tweak cleaning options after reviewing results, they must start from scratch: re-upload the original raw file, re-tag columns, re-run the full pipeline, and redo all manual review edits. This is especially painful for large datasets where curation involves CompTox API calls that take minutes.

The export already contains everything needed to reconstruct the session -- raw data, curated results, cleaning audit, reference lists, column tags, pipeline config, and harmonization output -- but the app cannot consume its own output.

## Solution

When a user uploads an XLSX file via the main file upload input, CONCERT detects whether it is a previously exported CONCERT file (via the `concert_export=true` marker in the Pipeline Config sheet). If detected, a modal offers two choices:

1. **Fast-forward to Review Results** (default) -- Restores the full session state from the export and lands the user on the Review Results tab with all earlier tabs populated and navigable.
2. **Treat as raw data** -- Ignores the export metadata and processes the Raw Data sheet as a fresh upload.

All eight pipeline tabs are populated with restored state and fully navigable. If the user steps back to an earlier tab (e.g., Tag Columns) and makes changes, the existing cascade reset logic warns them and clears downstream state, then the pipeline re-runs from that point forward -- identical to a fresh session.

## User Stories

1. As a data curator, I want to upload a previously exported CONCERT file and land directly on Review Results, so that I can fix a single row without re-running the entire pipeline.
2. As a data curator, I want all earlier tabs (Data Preview, Detection Info, Tag Columns, Clean Data, etc.) populated after re-import, so that I can inspect what the original pipeline did.
3. As a data curator, I want to step back to the Tag Columns tab after re-import and change a column assignment, so that I can re-run the pipeline with corrected tags without starting from scratch.
4. As a data curator, I want the cleaning audit from my export displayed in the Clean Data tab after re-import, so that I can review what cleaning steps were applied.
5. As a data curator, I want harmonization results (ToxVal Output and Harmonization Audit) restored if they exist in the export, so that I don't have to re-run harmonization.
6. As a data curator, I want to be warned if the raw data dimensions don't match the curated data dimensions in my export, so that I know the export may be stale, but I still want to proceed if I choose.
7. As a data curator, I want the detection modal to clearly explain what "fast-forward" means, so that I understand the app will skip the pipeline and go straight to results.
8. As a data curator, I want to choose "treat as raw data" for a CONCERT export, so that I can re-process it from scratch if I want a clean run.
9. As a data curator, I want the consensus summary statistics (agree, disagree, error counts, etc.) restored from the export, so that the Review Results summary cards are accurate without recomputation.
10. As a data curator, I want internal state columns (.pinned, .manual_entry, .suggested_column) preserved through the export/re-import cycle, so that my review edits have full fidelity.
11. As a data curator, I want the reference lists from the export restored into the app, so that my custom stop words and functional categories are available if I step back and re-run cleaning.
12. As a data curator, I want the header row number preserved in the export, so that frontmatter detection is skipped on re-import and the exact same data extraction is reproduced.
13. As a data curator, I want my row flags (BAD, FOLLOW-UP, VERIFIED) preserved through the round-trip, so that I don't lose triage work.
14. As a data curator, I want the existing cascade reset behavior to apply after re-import, so that stepping back to an earlier phase and making changes properly invalidates downstream state.
15. As a data curator, I want a single upload input for both fresh files and CONCERT exports, so that I don't have to learn separate import workflows.

## Implementation Decisions

### Export format expansion

**Session State sheet**: A new sheet added to the export XLSX containing internal columns excluded from the human-facing Curated Data sheet. This includes `.pinned`, `.manual_entry`, `.suggested_column`, and any other internal state columns. The sheet uses the same row order as Curated Data so columns can be joined positionally.

**Consensus Summary in Session State**: The `consensus_summary` named list (n_agree, n_disagree, n_error, n_manual, n_wqx, n_auto_resolved, n_suggested, etc.) is serialized as key-value rows in a dedicated section of the Session State sheet, so it can be restored without recomputation.

**header_row in Pipeline Config**: The detected or manually specified header row number is added as a key-value pair in the Pipeline Config sheet, enabling exact reconstruction of the detection state on re-import.

### Import parser expansion

`parse_concert_export()` in `config_import.R` is expanded to read:
- Session State sheet (internal columns + consensus_summary)
- Cleaning Audit sheet
- ToxVal Output sheet (if not placeholder)
- Harmonization Audit sheet (if present)
- Pipeline Config expanded fields (header_row, pipeline_steps)
- All existing sheets (Raw Data, Curated Data, Reference Lists, Column Tags)

The return value becomes a comprehensive list containing all sheets data.

### State hydration function

A new `hydrate_session_state()` function in `config_import.R` takes the parsed export and returns a named list of values to assign to `data_store` reactive values. This function:

- Joins Curated Data with Session State internal columns
- Reconstructs detection metadata from Pipeline Config (header_row, method, confidence)
- Reconstructs `column_tags`, `numeric_tags`, `study_type_tags` from the Column Tags sheet (which stores all tag types)
- Restores reference_lists via the existing `merge_reference_lists()` function
- Restores cleaning_audit from the Cleaning Audit sheet
- Restores harmonize_results and harmonize_audit if present
- Restores consensus_summary from Session State
- Runs consistency validation (raw row count vs. curated row count) and returns warnings

This function is pure (no Shiny dependency) and fully testable in isolation.

### Detection and modal flow

In the file upload observer in `app.R` (or `mod_file_upload.R`), after a file is uploaded:

1. Check if the file is XLSX with a Pipeline Config sheet containing `concert_export=true`
2. If yes, show a modal with two buttons: "Resume Session" (default, fast-forwards) and "Treat as Raw Data" (processes normally)
3. If "Resume Session": call `hydrate_session_state()`, assign all values to `data_store`, show all tabs, navigate to Review Results
4. If "Treat as Raw Data": extract the Raw Data sheet, process it through normal frontmatter detection pipeline

### Tab visibility on restore

After fast-forward restore, all tabs are shown using the existing `nav_show()` / `show_tab_with_pulse()` mechanism. The app navigates to Review Results via `nav_select()`. The user can freely click any earlier tab -- all are populated with restored data.

### Cascade reset on step-back

No new logic needed. The existing cascade reset observers (`reset_all_downstream`, `reset_chemical_downstream`, `reset_numeric_downstream`) already fire when upstream reactive values change. If a user modifies tags after re-import, the existing warning modal appears and downstream state is cleared, exactly as in a fresh session.

### Consistency validation

On re-import, `hydrate_session_state()` compares `nrow(raw_data)` with the row count implied by `nrow(curated_data)` (accounting for synonym expansion via `synonym_count` column). If there is a mismatch, a warning notification is shown but the user is not blocked.

## Testing Decisions

Good tests for this feature verify external behavior (input to output contracts), not implementation details like internal reactive value assignment order.

### Modules to test

**1. Export round-trip (parse + restore)**
- `build_export_sheets()` to write XLSX to `parse_concert_export()` to verify all fields present and correctly typed
- `hydrate_session_state()` with synthetic export data to verify returned named list has correct structure, column names, row counts
- Consistency warning triggers when raw/curated row counts differ
- Graceful handling of exports missing optional sheets (Harmonization Audit, ToxVal Output)

**2. Session State sheet fidelity**
- Internal columns (.pinned, .manual_entry, .suggested_column) survive the export to re-import cycle with correct values
- consensus_summary key-value pairs round-trip correctly (including zero counts)
- header_row round-trips through Pipeline Config

**3. Shiny testServer() smoke test**
- Upload a CONCERT export file to verify all expected tabs become visible
- Verify `data_store$resolution_state` is populated after restore
- Verify `data_store$cleaning_audit` is populated after restore
- Verify navigation lands on Review Results tab

### Prior art
- Existing tests in `tests/test_data_detection.R` use synthetic data and `testthat` assertions
- The test pattern of creating synthetic tibbles, running functions, and checking output structure applies directly

## Out of Scope

- **Replay script re-import**: This PRD covers XLSX re-import only. Re-running a generated replay `.R` script to restore session state is a separate feature.
- **Diff view**: Showing what changed between the exported state and a re-run pipeline is not included.
- **Merge/conflict resolution**: If the user has both a CONCERT export and a modified raw file, merging them is not supported. The user chooses one path.
- **Version migration**: Handling exports from older CONCERT versions with different sheet schemas is not addressed. The Session State sheet is new, so old exports without it would fall back to the current partial restore (reference lists + column tags only).
- **Config import sidebar changes**: The existing config import sidebar input stays as-is. This feature only modifies the main file upload path.
- **Review override preservation on re-run**: If the user steps back and re-runs the pipeline, prior review edits are lost (same as current behavior). Automatic re-application of content-match overrides after a re-run is a separate feature.

## Further Notes

- **Backward compatibility**: Exports without the new Session State sheet (produced before this feature ships) will still work via the existing config import path. The fast-forward modal only appears when Session State is present. Consider showing a degraded modal for old exports: "This export does not include full session state. You can restore reference lists and column tags, or treat it as raw data."
- **Export size**: The Session State sheet adds minimal size since it only contains a few columns per row plus a small key-value section for consensus_summary. The header_row addition to Pipeline Config is a single row.
- **dedup_group_map and display_row_map**: These are derived from resolution_state during Review Results rendering, so they do not need to be stored in the export. They will be recomputed when the Review Results module initializes.
- **qc_results**: Can be recomputed from resolution_state on restore (run the same QC check that runs post-curation). Does not need to be stored in the export.
