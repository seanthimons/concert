---
phase: 27-headless-pipeline
plan: "01"
subsystem: pipeline
tags: [headless, export, curation, r-package]
dependency_graph:
  requires: [24-package-scaffolding, 25-clean-r-package, 26-app-relocation]
  provides: [curate_headless-function, headless-pipeline-entry-point]
  affects: [DESCRIPTION, NAMESPACE, R/curate_headless.R]
tech_stack:
  added: [tools (base R, for file_ext), writexl (promoted Imports)]
  patterns: [withCallingHandlers verbose suppression, invisible return, fail-fast validation]
key_files:
  created:
    - R/curate_headless.R
    - man/curate_headless.Rd
  modified:
    - DESCRIPTION
    - NAMESPACE
decisions:
  - "writexl promoted from Suggests to Imports — headless export requires it unconditionally"
  - "tools added to Imports for tools::file_ext() — avoids base-package ambiguity in R CMD check"
  - "skip_flags accepted but not forwarded — isotope_match handled internally by run_curation_pipeline(); reserved for future use"
  - "verbose=FALSE uses withCallingHandlers + invokeRestart(muffleMessage) — suppresses all messages without capturing stderr"
metrics:
  duration_seconds: 224
  completed_date: "2026-04-13"
  tasks_completed: 2
  files_created: 2
  files_modified: 2
---

# Phase 27 Plan 01: curate_headless() Entry Point Summary

**One-liner:** JWT-style single-entry pipeline function wiring safely_read_file → detect_data_start → run_cleaning_pipeline → run_curation_pipeline → build_export_sheets → writexl::write_xlsx into a scriptable curate_headless() export.

## What Was Built

Created `R/curate_headless.R` — a single exported function that runs the full ChemReg curation pipeline (file read, frontmatter detection, cleaning, CompTox API search, consensus classification, 7-sheet XLSX export) from a plain R script without launching the Shiny UI.

The function signature:
```r
curate_headless(input_path, output_path, tag_map, skip_flags = NULL,
                header_row = NULL, reference_lists = NULL, verbose = TRUE)
```

The 10-step pipeline inside:
1. Fail-fast input validation (`file.exists`, extension check)
2. Reference list loading from `system.file("extdata", "reference_cache", package = "chemreg")` or caller-supplied list
3. `safely_read_file()` (not `validate_file()` — avoids Shiny fileInput dependency)
4. `detect_data_start()` in auto or manual mode
5. `extract_clean_data()` → `handle_merged_cells()` → `janitor::clean_names()` → `janitor::remove_empty()`
6. `tag_map` column validation against normalized column names
7. `run_cleaning_pipeline()` + tag merge via `merged_tags <- c(tag_map, cleaning_result$new_tags)`
8. `run_curation_pipeline()` → `pipeline_result$results` as resolution_state
9. `build_export_sheets()` → `fs::dir_create()` → `writexl::write_xlsx()`
10. `invisible(list(data = resolution_state, audit_trail = cleaning_result$audit_trail))`

Verbose suppression uses `withCallingHandlers(pipeline(), message = function(m) invokeRestart("muffleMessage"))`.

## Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create curate_headless.R and update DESCRIPTION | b8df29f | R/curate_headless.R, DESCRIPTION, NAMESPACE, man/curate_headless.Rd |
| 2 | Smoke test (auto-approved) | — | — |

## Decisions Made

1. **writexl promoted to Imports** — headless users need XLSX export; no reason to keep optional.
2. **tools in Imports** — `tools::file_ext()` requires explicit import for R CMD check compliance.
3. **skip_flags not forwarded** — `run_curation_pipeline()` hardcodes `skip_flags = "isotope_match"` internally; parameter accepted for API forward-compatibility only.
4. **withCallingHandlers over `suppressMessages()`** — more idiomatic for message suppression in function bodies; avoids capturing condition handlers from callee stack.

## Deviations from Plan

None — plan executed exactly as written.

## Verification Results

- `devtools::document()` completed without errors
- NAMESPACE contains `export(curate_headless)`: PASS
- DESCRIPTION Imports contains `writexl`: PASS
- DESCRIPTION Imports contains `tools`: PASS
- `devtools::check()` result: 0 errors, 6 warnings, 4 notes (all pre-existing from Phase 26)
- All 15 implementation acceptance criteria verified programmatically
- Task 2 (smoke test checkpoint): auto-approved per `auto_advance: true`

## Known Stubs

None — all pipeline stages are wired to real functions. The function is complete and will call live CompTox API when `ctx_api_key` is set.

## Self-Check: PASSED

- R/curate_headless.R exists: FOUND
- man/curate_headless.Rd exists: FOUND
- commit b8df29f exists: FOUND
- NAMESPACE export(curate_headless): FOUND
