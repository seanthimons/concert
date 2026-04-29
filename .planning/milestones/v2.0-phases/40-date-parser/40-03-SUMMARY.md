---
phase: 40-date-parser
plan: "03"
subsystem: harmonization-pipeline
tags: [date-parsing, pipeline-wiring, shiny, headless, qc-dashboard, toxval]
dependency_graph:
  requires:
    - 40-01  # parse_dates() function in R/date_parser.R
    - 40-02  # StudyDate tag in classify_tags() and mod_tag_columns.R dropdown
  provides:
    - Stage 4.6 date parsing in mod_harmonize.R Shiny pipeline
    - Stage 3c date parsing in curate_headless.R headless pipeline
    - date_year -> expanded_curated$year -> ToxVal original_year population
    - QC dashboard date value boxes (Dates Parsed, Partial, Ambiguous, Unparseable)
    - StudyDate-only harmonize button enable gate
  affects:
    - R/mod_harmonize.R
    - R/curate_headless.R
tech_stack:
  added: []
  patterns:
    - Stage 4.6 mirrors Stage 4.5 duration block structural template
    - Stage 3c mirrors Stage 3.5 duration block structural template
    - harmonize_tibble$orig_row_id subscript for Shiny expanded_curated merge
    - match() join for headless input_df merge
    - tryCatch() with showNotification() for date stage error isolation
    - Identity harmonize_tibble for StudyDate-only pipeline path
key_files:
  created: []
  modified:
    - R/mod_harmonize.R
    - R/curate_headless.R
decisions:
  - "StudyDate-only path uses identity harmonize_tibble (1:1 rows, NA numerics) to allow ToxVal mapping without a Result column"
  - "Result-column guard relaxed: only blocks when numeric tags are present and Result is missing, not when StudyDate-only"
  - "req(data_store$numeric_tags) guard replaced with explicit has_numeric/has_study check to allow StudyDate-only pipeline runs"
  - "incProgress budget adjusted: Stage 3 reduced 0.25->0.20, Stage 4.6 receives 0.05 (total still 1.00)"
metrics:
  duration: "~20 minutes"
  completed: "2026-04-26"
  tasks_completed: 2
  tasks_total: 3
  files_modified: 2
---

# Phase 40 Plan 03: Pipeline Wiring — Date Parsing Integration Summary

**One-liner:** parse_dates() wired into both Shiny (Stage 4.6) and headless (Stage 3c) pipelines with date_year merged to expanded_curated$year for ToxVal original_year, 4-box date QC dashboard row, and StudyDate-only harmonize button enable gate.

## What Was Built

### Task 1: mod_harmonize.R — Stage 4.6 and QC Dashboard

Five modifications to `R/mod_harmonize.R`:

1. **`has_numeric_tags` reactive broadened** — now checks both `data_store$numeric_tags` and `data_store$study_type_tags`. Returns TRUE when either is non-empty. Keeps the existing output name to avoid touching UI conditionalPanel JavaScript.

2. **Button enable/disable observe broadened** — same `has_numeric || has_study` logic. StudyDate-only columns now enable the "Run Harmonization" button.

3. **Pipeline guard updated** — `req(data_store$clean, data_store$numeric_tags)` replaced with explicit guards. Result-column check only applies when numeric tags are present; StudyDate-only runs skip the numeric stage entirely using an identity harmonize_tibble.

4. **Stage 4.6 inserted** after Stage 4.5 duration block:
   - Reads `data_store$study_type_tags` for StudyDate columns
   - Calls `parse_dates()` wrapped in `tryCatch()` with `showNotification()` on failure
   - Stores result in `data_store$date_results`
   - Shows completion notification with parsed/ambiguous counts

5. **date_year merge** — after duration merge, before `map_to_toxval_schema()`:
   ```r
   year_expanded <- data_store$date_results$date_year[harmonize_tibble$orig_row_id]
   expanded_curated$year <- year_expanded
   ```
   Uses same subscript-indexing pattern as duration merge. `safe_extract_num(curated_data, "year", n_rows)` in toxval_mapper.R picks this up automatically.

6. **QC dashboard** — conditional second row of 4 date value boxes appended after existing 4-box row. Boxes only render when `data_store$date_results` is non-NULL.

### Task 2: curate_headless.R — Stage 3c

Single insertion after Stage 3.5 duration block:

```r
# Stage 3c: Date parsing (DATE-05, DATE-06)
message("[headless] Stage 3c: Parsing dates...")
date_cols <- names(tag_map)[tag_map == "StudyDate"]

if (length(date_cols) > 0) {
  date_tibble <- parse_dates(
    raw_dates = as.character(input_df[[date_cols[1]]]),
    orig_row_id = seq_len(nrow(input_df))
  )
  input_df$year <- date_tibble$date_year[
    match(seq_len(nrow(input_df)), date_tibble$orig_row_id)
  ]
}
```

Uses `tag_map` (not `merged_tags`) for StudyDate lookup, consistent with duration lookup at line 277. `match()` join ensures correct alignment. `map_to_toxval_schema()` reads `input_df$year` automatically via the existing `safe_extract_num()` call.

### Task 3: Shiny Cold Boot

App boots successfully (`Listening on http://127.0.0.1:3840`) with no errors, no missing icons, no source() failures, no module wiring crashes. Package version warnings (bslib, shiny, bsicons built under R 4.5.2/4.5.3) are benign environment artifacts.

## Acceptance Criteria Verification

| Criterion | Status |
|-----------|--------|
| `R/mod_harmonize.R` contains `# Stage 4.6: Date parsing` | PASS (line 442) |
| `R/mod_harmonize.R` contains `parse_dates(` call | PASS (line 454) |
| `R/mod_harmonize.R` contains `data_store$date_results <- date_tibble` | PASS (line 475) |
| `R/mod_harmonize.R` contains `expanded_curated$year <- year_expanded` | PASS (line 530) |
| `R/mod_harmonize.R` contains `has_study` in has_numeric_tags reactive | PASS (line 158) |
| `R/mod_harmonize.R` contains `"Dates Parsed"` value box | PASS (line 603) |
| `R/mod_harmonize.R` contains `"Ambiguous Dates"` value box | PASS (line 615) |
| `R/mod_harmonize.R` contains `"Partial Dates"` value box | PASS (line 609) |
| `R/mod_harmonize.R` contains `"Unparseable Dates"` value box | PASS (line 621) |
| `R/curate_headless.R` contains `# Stage 3c: Date parsing (DATE-05, DATE-06)` | PASS (line 296) |
| `R/curate_headless.R` contains `parse_dates(` call | PASS (line 301) |
| `R/curate_headless.R` contains `input_df$year <- date_tibble$date_year[` | PASS (line 306) |
| `R/curate_headless.R` uses `tag_map` for StudyDate lookup | PASS (line 298) |
| Full test suite no new failures | PASS (FAIL 3 pre-existing, PASS 1755) |
| Shiny cold boot passes | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] StudyDate-only pipeline path in FULL MODE**
- **Found during:** Task 1 implementation
- **Issue:** The original plan's Stage 4.6 code assumed a `result_cols[1]` would always exist to extract `result_values`. When only StudyDate columns are tagged (no numeric tags), `result_cols` is empty and the existing `result_values <- as.character(input_df[[result_cols[1]]])` call would crash with an index error.
- **Fix:** Added an `if (has_numeric) { ... } else { ... }` branch in FULL MODE. The `else` branch builds an identity `harmonize_tibble` (1:1 rows, NA numerics, no parsing) that lets Stage 4.5, 4.6, and ToxVal mapping proceed without a Result column. This is the correct behavior per CONTEXT.md D-17/D-18 — date parsing is a pipeline stage that runs independently of numeric parsing.
- **Files modified:** `R/mod_harmonize.R`
- **Commit:** 892b4b1

**2. [Rule 2 - Missing Critical Functionality] req() guard blocked StudyDate-only runs**
- **Found during:** Task 1 implementation
- **Issue:** `req(data_store$clean, data_store$numeric_tags)` would silently abort the pipeline when only StudyDate columns were tagged (`data_store$numeric_tags` would be NULL or empty).
- **Fix:** Replaced with `req(data_store$clean)` plus explicit `has_numeric/has_study` check with early return only when both are FALSE. Result-column guard now only fires when `has_numeric && length(result_cols) == 0`.
- **Files modified:** `R/mod_harmonize.R`
- **Commit:** 892b4b1

**3. [Rule 3 - Auto-fix Blocking Issue] incProgress budget recalculation**
- **Found during:** Task 1 — plan specified 0.25->0.20 adjustment for Stage 3 to fund Stage 4.6 at 0.05, but the StudyDate-only branch (60% fast-forward) also needed a valid budget.
- **Fix:** In the `has_numeric` branch, Stage 3 reduced from 0.25 to 0.20. The StudyDate-only `else` branch uses `incProgress(0.60, ...)` as a single fast-forward step. Both paths reach 1.00 total. Full mode: 0.15 + 0.30 + 0.20 + 0.15 + 0.05 + 0.05 + 0.10 = 1.00. StudyDate-only: 0.60 + 0.05 + 0.05 + 0.10 + 0.20 = ~1.00.
- **Files modified:** `R/mod_harmonize.R`
- **Commit:** 892b4b1

## Known Stubs

None — all wiring connects to real `parse_dates()` implementation from Plan 01 and real `data_store$study_type_tags` populated by Plan 02.

## Threat Flags

No new security-relevant surface introduced beyond what was declared in the plan's threat model. All three threat register entries (T-40-06, T-40-07, T-40-08) are properly mitigated:
- T-40-07 (DoS) mitigated: `parse_dates()` wrapped in `tryCatch()` with `showNotification()` — pipeline continues on date stage failure.

## Self-Check: PASSED

Files exist:
- `R/mod_harmonize.R` — FOUND
- `R/curate_headless.R` — FOUND

Commits exist:
- 892b4b1 (feat(40-03): wire date parsing stage and QC dashboard in mod_harmonize.R) — FOUND
- 48c385a (feat(40-03): wire date parsing stage in curate_headless.R) — FOUND
