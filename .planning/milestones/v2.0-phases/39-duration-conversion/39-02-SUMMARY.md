---
phase: 39-duration-conversion
plan: "02"
subsystem: harmonization-pipeline
tags: [duration, toxval, shiny, headless, unit-harmonization]
dependency_graph:
  requires:
    - 39-01  # harmonize_units(category="duration") and duration unit_map entries
  provides:
    - DUR-03  # Duration harmonization wired into both pipeline paths
    - DUR-04  # study_duration_value/units merged into curated data before ToxVal mapping
  affects:
    - R/mod_harmonize.R
    - R/curate_headless.R
tech_stack:
  added: []
  patterns:
    - category-filtered harmonize_units() call with category="duration"
    - row-position indexing for duration merge into expanded_curated
    - match(seq_len(nrow()), orig_row_id) for headless duration column merge
key_files:
  created: []
  modified:
    - R/mod_harmonize.R
    - R/curate_headless.R
decisions:
  - "Use row-position indexing (not left_join) for duration merge into expanded_curated — expanded_curated has no orig_row_id column, mirroring how it is built from resolution_state[harmonize_tibble$orig_row_id, ]"
  - "Use match(seq_len(nrow(input_df)), dur_tibble$orig_row_id) in headless path — headless has no range expansion for duration, match ensures correct alignment if future changes introduce reordering"
  - "Stage 3 incProgress reduced from 0.30 to 0.25 to free 0.05 for Stage 4.5, keeping total at 1.00"
  - "Use tag_map (not merged_tags) for Duration/DurationUnit lookup in headless — consistent with existing Result/Unit lookup pattern at lines 203-204"
metrics:
  duration: "~25 minutes"
  completed_date: "2026-04-26"
  tasks: 2
  files_modified: 2
---

# Phase 39 Plan 02: Duration Pipeline Wiring Summary

**One-liner:** Wired duration harmonization into both Shiny (mod_harmonize.R Stage 4.5) and headless (curate_headless.R Stage 3.5) pipelines so DurationUnit-tagged columns produce study_duration_value/study_duration_units in ToxVal export.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Insert duration harmonization stage in mod_harmonize.R | 33d57cc | R/mod_harmonize.R |
| 2 | Insert duration harmonization stage in curate_headless.R | 1aa793c | R/curate_headless.R |

## What Was Built

### Task 1: mod_harmonize.R — Shiny path

Two insertion points in the FULL MODE `withProgress(...)` block:

**Stage 4.5** (after Stage 4 "Store results", before Stage 5 "Map to ToxVal schema"):
- Looks up Duration/DurationUnit-tagged columns from `numeric_tags_vec`
- Calls `harmonize_units(..., category="duration")` if both column types are tagged
- Stores result in `data_store$duration_results` as a tibble with `orig_row_id`, `study_duration_value`, `study_duration_units`, `duration_unit_flag`
- Sets `data_store$duration_results <- NULL` when columns not tagged (clean state)

**Duration merge** (after `expanded_curated <- data_store$resolution_state[harmonize_tibble$orig_row_id, ]`):
- If `data_store$duration_results` is non-NULL, maps duration values through the same `harmonize_tibble$orig_row_id` indexing used to build `expanded_curated`
- Assigns `expanded_curated$study_duration_value` and `expanded_curated$study_duration_units` before `map_to_toxval_schema()` is called
- `safe_extract_num(curated_data, "study_duration_value", n_rows)` in toxval_mapper.R picks these up automatically

**Progress bar adjustment:** Stage 3 `incProgress(0.30)` reduced to `incProgress(0.25)` to accommodate new `incProgress(0.05)` at Stage 4.5. Total remains 1.00: 0.15 + 0.30 + 0.25 + 0.15 + 0.05 + 0.10 = 1.00.

### Task 2: curate_headless.R — headless path

**Stage 3.5** inserted between harmonize audit construction (line 273) and Stage 4 ToxVal mapping (line 275):
- Looks up Duration/DurationUnit-tagged columns from `tag_map` (consistent with Result/Unit lookup pattern)
- Calls `harmonize_units(..., unit_map = unit_map, category = "duration")` — uses `unit_map` loaded at line 192, not `unit_map_working`
- Merges `study_duration_value` and `study_duration_units` directly onto `input_df` via `match(seq_len(nrow(input_df)), dur_tibble$orig_row_id)`
- `map_to_toxval_schema(curated_data = input_df, ...)` on the next line picks up the new columns automatically

## Verification

- `R/mod_harmonize.R` contains `Stage 4.5: Duration harmonization` — PASS
- `R/mod_harmonize.R` contains `category = "duration"` inside harmonize_units() — PASS
- `R/mod_harmonize.R` contains `data_store$duration_results <- tibble::tibble(` — PASS
- `R/mod_harmonize.R` contains `expanded_curated$study_duration_value <-` — PASS
- `R/mod_harmonize.R` contains `expanded_curated$study_duration_units <-` — PASS
- incProgress fractions in FULL MODE sum to 1.0 (0.15+0.30+0.25+0.15+0.05+0.10) — PASS
- `R/curate_headless.R` contains `Stage 3.5: Duration harmonization` — PASS
- `R/curate_headless.R` contains `category = "duration"` inside harmonize_units() — PASS
- `R/curate_headless.R` contains `input_df$study_duration_value <-` — PASS
- `R/curate_headless.R` contains `input_df$study_duration_units <-` — PASS
- `R/curate_headless.R` uses `unit_map` (not `unit_map_working`) — PASS
- `R/curate_headless.R` uses `tag_map` (not `merged_tags`) for Duration/DurationUnit lookup — PASS
- `air format` passed cleanly on both files — PASS
- `jarl check` findings on both files are pre-existing (lines 31, 126 in mod_harmonize.R; line 223 in curate_headless.R) — PASS (no new issues)
- `devtools::test()` — 3 failures (identical pre-existing failures, no new regressions) — PASS
- Shiny cold boot — app starts and shows "Listening on http://127.0.0.1:3840" — PASS

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. Duration columns are wired end-to-end: tag -> harmonize -> merge -> ToxVal export.

## Threat Flags

No new security-relevant surface introduced. Duration column values enter via `as.numeric()` coercion (T-39-04: NA for non-numeric, handled by existing harmonize_units() empty-input path). No new network endpoints or auth paths.

## Self-Check: PASSED

- `R/mod_harmonize.R` — exists and contains all required strings
- `R/curate_headless.R` — exists and contains all required strings
- Commit 33d57cc — present in git log
- Commit 1aa793c — present in git log
