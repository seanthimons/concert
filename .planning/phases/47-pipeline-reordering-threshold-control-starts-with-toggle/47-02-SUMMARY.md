---
phase: 47-pipeline-reordering-threshold-control-starts-with-toggle
plan: 02
status: complete
started: 2026-05-06T22:00:00-04:00
completed: 2026-05-06T22:30:00-04:00
---

## What was built

Added a "Search Settings" accordion panel to the pre-flight modal with a WQX fuzzy threshold slider (0.50–1.00, default 0.85) synced to a numeric input, plus a CompTox starts-with toggle (default OFF). Wired both values through `data_store` to `run_curation_pipeline()` in the curation module, and added WQX match count to the notification string.

## Key changes

- **R/mod_clean_data.R**: Third accordion panel "Search Settings" with `sliderInput`, `numericInput`, and `checkboxInput` — all properly namespaced with `session$ns()`. Two `observeEvent` sync observers keep slider and numeric in lockstep. `build_mask_from_inputs()` and `run_all` mask extended with `wqx_threshold` and `starts_with`. `execute_pipeline()` stores values into `data_store`.
- **R/mod_run_curation.R**: `run_curation_pipeline()` call reads `data_store$wqx_threshold` and `data_store$starts_with` with safe defaults (`%||% 0.85` and `isTRUE()`). Notification string updated to include `%d WQX` between CAS and starts-with counts.

## Key files

### Modified
- `R/mod_clean_data.R`
- `R/mod_run_curation.R`

## Self-Check: PASSED

- `devtools::load_all()` succeeds
- Shiny cold boot on port 4838 confirmed "Listening on" with no errors
- Human verification: approved
