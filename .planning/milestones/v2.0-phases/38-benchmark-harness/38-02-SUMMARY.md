---
phase: 38-benchmark-harness
plan: "02"
subsystem: benchmark
tags: [benchmark, bench-press, dedup, use_dedup, performance]
dependency_graph:
  requires: [38-01-use_dedup-parameter-on-run_cleaning_pipeline, 38-01-use_dedup-parameter-on-harmonize_units]
  provides: [benchmark-pipeline-script, benchmark-results-template]
  affects: [scripts/benchmark_pipeline.R, docs/benchmark_results.md]
tech_stack:
  added: []
  patterns: [bench-press-grid, curate_dataset-structure, dedup-toggle-comparison]
key_files:
  created:
    - scripts/benchmark_pipeline.R
    - docs/benchmark_results.md
decisions:
  - "CASRN excluded from benchmark tag_map to prevent normalize_cas_fields network calls per D-06"
  - "unit_map sourced from ref_lists$unit_map (load_all_reference_lists output) rather than unit_table.csv — unit_table.csv does not exist in inst/extdata; unit_conversion.rds is the actual artifact"
  - "docs/benchmark_results.md committed as a template with [auto-populated] placeholders — script overwrites at runtime with real data"
metrics:
  duration_minutes: 20
  completed_date: "2026-04-24"
  tasks_completed: 2
  files_modified: 2
---

# Phase 38 Plan 02: Benchmark Pipeline Script Summary

**One-liner:** Standalone `scripts/benchmark_pipeline.R` measuring dedup speedup via `bench::press()` across 1K/10K/100K grid with `use_dedup = TRUE/FALSE`, cold-start isolation, uniqueness rates, and committed Markdown summary template.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create scripts/benchmark_pipeline.R | 455cf66 | scripts/benchmark_pipeline.R |
| 2 | Auto-approved checkpoint; create docs/benchmark_results.md template | 9371a20 | docs/benchmark_results.md |

## What Was Built

**Task 1 — benchmark_pipeline.R (466 lines):**

The script follows the `curate_dataset.R` pattern exactly (section headers, `message()` progress, `stopifnot()` guards). Sections 0-10:

- **Section 0:** Configuration — `library()`, `CONCERT_ROOT`, `source()` for cleaning_pipeline, cleaning_reference, unit_harmonizer
- **Section 1:** Input data — auto-detects first CSV/XLSX in `data/benchmark/`, enforces >= 100K row guard
- **Section 2:** Tag map and reference lists — auto-detects "name/chemical/compound/substance" columns as Name; excludes CASRN to avoid network calls per D-06; loads `ref_lists` via `load_all_reference_lists(inst/extdata)`
- **Section 3:** Pre-generate subsets — `set.seed(42)` + `dplyr::slice_sample()` for 1K, 10K, 100K outside any bench call (Pitfall 2)
- **Section 4:** Uniqueness rates — `compute_uniqueness()` function, reports per subset size per BENCH-02
- **Section 5:** Cold-start — separate `bench::mark(min_iterations=1, max_iterations=1, check=FALSE)` per BENCH-02
- **Section 6:** Cleaning pipeline `bench::press()` — `n = c(1000L, 10000L, 100000L)` x `use_dedup = c(TRUE, FALSE)`, `min_iterations=3, check=FALSE` per D-07/Pitfall 1
- **Section 7:** Harmonization `bench::press()` — same grid, uses `unit_map` from `ref_lists$unit_map`, graceful skip if unavailable
- **Section 8:** Save raw results — `dplyr::mutate` + `dplyr::select` to tidy both result frames, `write_csv` to `data/benchmark/results.csv`
- **Section 9:** Markdown generation — `compute_speedup()` via `pivot_wider`, `format_results_table()`, `build_md_table()`, writes `docs/benchmark_results.md` with speedup table
- **Section 10:** Done — prints speedup values at 100K for cleaning and harmonization

Key properties:
- `check = FALSE` on all three `bench::mark()` calls (cold-start, cleaning inner, harmonization inner)
- No `source(R/curation.R)` — no CompTox API surface (D-06)
- `set.seed(42)` used twice: Section 3 for subsets, inside harmonization `bench::press()` for reproducible test vectors
- Speedup = `dedup_FALSE / dedup_TRUE` per BENCH-03
- `n_itr` column preserved in tidy output for raw CSV

**Task 2 — docs/benchmark_results.md template:**

Committed Markdown document with the full table structure (uniqueness, cold-start, cleaning, harmonization, speedup, methodology) using `[auto-populated]` placeholders. The script overwrites this file with real data at runtime. Template demonstrates the output format and documents the methodology section permanently.

## Deviation from Plan

**1. [Rule 2 - Missing Critical Detail] unit_table.csv does not exist; used unit_conversion.rds**

- **Found during:** Task 1, Section 7 implementation
- **Issue:** Plan references `unit_table.csv` in `inst/extdata/` for the harmonization benchmark. The file does not exist — the actual artifact is `inst/extdata/unit_conversion.rds` loaded via `load_unit_map()` (which is also included in `load_all_reference_lists()` output as `ref_lists$unit_map`).
- **Fix:** Unit map for harmonization is obtained from `ref_lists$unit_map` (populated by `load_all_reference_lists`). Fallback path tries `load_unit_map(inst/extdata)` directly. This is correct per the actual codebase API.
- **Files modified:** scripts/benchmark_pipeline.R
- **Commit:** 455cf66

**2. [Rule 2 - D-06 compliance] CASRN excluded from tag_map**

- **Found during:** Task 1, Section 2 implementation
- **Issue:** Plan's tag_map auto-detection included CAS column detection (`grep("cas", ...)`) which would tag CASRN columns. The `normalize_cas_fields()` function (called inside `run_cleaning_pipeline()` when CASRN columns are tagged) may make local ComptoxR calls. Per D-06, no API calls allowed.
- **Fix:** Removed `cas_candidates` grep from tag_map auto-detection. Only Name-role columns are tagged in the benchmark. Comment explains the reason.
- **Files modified:** scripts/benchmark_pipeline.R
- **Commit:** 455cf66

## Verification Results

```
SCRIPT EXISTS: TRUE
Lines: 466 (> 120 minimum)
bench::press calls: 2 (cleaning + harmonization)
bench::mark calls: 3 (cold-start + cleaning inner + harmonization inner)
check = FALSE: FOUND
set.seed: FOUND
min_iterations: FOUND
use_dedup: FOUND
slice_sample: FOUND
NO CURATION REFS: GOOD
results.csv: FOUND
benchmark_results.md: FOUND
compute_uniqueness: FOUND
max_iterations = 1: FOUND (cold-start)
speedup: FOUND
min_iterations = 3: FOUND
Speedup in docs/benchmark_results.md: FOUND
```

## Known Stubs

`docs/benchmark_results.md` contains `[auto-populated]` placeholders throughout. This is intentional — the file is a committed template. The benchmark script overwrites it with real data when the user runs `source("scripts/benchmark_pipeline.R")` with a real regulatory dataset in `data/benchmark/`. The stubs do not prevent the plan's goal (a ready-to-run benchmark script) from being achieved.

## Threat Surface Scan

No new network endpoints, auth paths, or schema changes introduced. The script reads from `data/benchmark/` (gitignored, user-provided) and writes:
- `data/benchmark/results.csv` — gitignored per T-38-04 mitigation
- `docs/benchmark_results.md` — committed, contains only aggregate statistics per T-38-04 mitigation

No threat flags beyond the existing T-38-03 through T-38-05 entries in the plan.

## Self-Check: PASSED

- `scripts/benchmark_pipeline.R` — FOUND at expected path
- `docs/benchmark_results.md` — FOUND at expected path
- Commit `455cf66` — verified (feat(38-02): create standalone benchmark_pipeline.R script)
- Commit `9371a20` — verified (docs(38-02): add benchmark_results.md template)
