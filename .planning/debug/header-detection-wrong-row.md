---
status: resolved
trigger: "When uploading a data set, the header detection algorithm is no longer finding the best row to set as the true header, defaulting to no row headers + Programmatic default row editors (v1, v2, v3...)"
created: 2026-04-29
updated: 2026-04-29
---

## Symptoms

- **Expected behavior**: Auto-detect header row — ensemble detection should identify the correct header row and skip frontmatter rows automatically
- **Actual behavior**: App defaults to V1, V2, V3... programmatic column headers instead of detecting the real header row
- **Error messages**: No errors — app loads fine, just picks wrong header row silently
- **Timeline**: Recently broke — was working before recent changes
- **Reproduction**: Upload `detections.csv` — header detection fails. Upload `detections_uat_sample_50.csv` — works correctly. File-specific regression.

## Current Focus

- hypothesis: detect_data_start_heuristic has a dead-code conditional on line 101 that always sets data_start_row == header_row, triggering the "no separate header" branch in extract_clean_data which returns raw V1/V2/V3 column names. This latent bug fires when heuristic wins the ensemble or when the gap with type_consistency narrows.
- test: Confirmed via script — heuristic returns header_row=1, data_start_row=1 (equal). extract_clean_data line 358 returns raw_df with V1/V2/V3 names when header_row == data_start_row.
- expecting: Fix data_start_row to always be header_row + 1 in detect_data_start_heuristic, and fix extract_clean_data to never silently discard header extraction when header_row == data_start_row.
- next_action: apply_fix
- specialist_hint: r

## Evidence

- timestamp: 2026-04-29T00:00:00
  file: R/data_detection.R
  lines: 99-105
  note: |
    detect_data_start_heuristic return block has dead-code conditional:
      data_start_row = if (header_row == data_start) data_start else data_start
    Both branches return `data_start` — the ternary is identical on both sides.
    Result: data_start_row always equals header_row (both = 1 for clean files).

- timestamp: 2026-04-29T00:01:00
  file: R/data_detection.R
  lines: 358-360
  note: |
    extract_clean_data: when header_row == data_start_row, it falls into the
    "No separate header row" branch and returns raw_df unchanged, preserving V1/V2/V3
    column names instead of extracting the header from row 1.

- timestamp: 2026-04-29T00:02:00
  note: |
    Confirmed by running detect_data_start against detections.csv (127k rows):
    - heuristic: header_row=1, data_start_row=1, confidence=0.937
    - type_consistency: header_row=1, data_start_row=2, confidence=0.947
    type_consistency currently wins by 0.01 margin, masking the heuristic bug.
    Any shift in confidence could cause heuristic to win and trigger V1/V2/V3 output.
    The bug also fires directly if heuristic is selected as winner.

- timestamp: 2026-04-29T00:03:00
  note: |
    Both CSV files (detections.csv and detections_uat_sample_50.csv) read identically
    at raw level — same column types, same row 1 header content. The regression is
    not in file reading. Source functions and installed package functions both show
    the same behavior. The issue is latent in heuristic logic.

## Eliminated

- File reading differences: both files parse to identical raw structure with col_names=FALSE
- Package install staleness: installed concert package and source functions behave identically
- Encoding or delimiter issues: UTF-8, comma-delimited, reads cleanly on both files

## Resolution

- root_cause: |
    detect_data_start_heuristic (R/data_detection.R line 101) has a dead-code conditional
    `data_start_row = if (header_row == data_start) data_start else data_start` — both branches
    return the same value, so data_start_row is always equal to header_row. When data starts
    on row 1, this sets data_start_row=1 == header_row=1, which triggers the "no separate header
    row" branch in extract_clean_data (line 358), returning the raw data frame with V1/V2/V3
    column names instead of extracting the real header.
- fix: |
    1. Line 101: changed `data_start_row = if (header_row == data_start) data_start else data_start`
       to `data_start_row = header_row + 1L` — ensures data always starts after header.
    2. Lines 358-362: removed dead `header_row == data_start_row` branch that skipped header
       extraction and returned raw V1/V2/V3 names. Now always extracts data rows and applies col_names.
- verification: |
    Tested with detections.csv (127k rows): heuristic returns header_row=1, data_start_row=2.
    extract_clean_data produces real column names (site_id, event_id, etc.). No V1/V2/V3.
    Shiny cold boot passes clean.
- files_changed: R/data_detection.R
