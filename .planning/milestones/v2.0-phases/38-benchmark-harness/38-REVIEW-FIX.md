---
phase: 38-benchmark-harness
fixed_at: 2026-04-24T00:00:00Z
review_path: .planning/phases/38-benchmark-harness/38-REVIEW.md
iteration: 1
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Phase 38: Code Review Fix Report

**Fixed at:** 2026-04-24T00:00:00Z
**Source review:** .planning/phases/38-benchmark-harness/38-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 2
- Fixed: 2
- Skipped: 0

## Fixed Issues

### WR-01: `"soil"` passed to `harmonize_units()` but the API only recognises `"solid"`

**Files modified:** `scripts/benchmark_pipeline.R`
**Commit:** 0b9ba06
**Applied fix:** Changed the test media sample on line 235 from `"soil"` to `"solid"` so the harmonization benchmark correctly exercises the solid-media branch (`"mg/kg"` target) in `get_media_target()` instead of silently falling through to the default `"mg/L"` fallback.

### WR-02: `readxl::read_xlsx()` called without a `requireNamespace()` guard in standalone context

**Files modified:** `scripts/benchmark_pipeline.R`
**Commit:** 3d7ee44
**Applied fix:** Added a `readxl` guard to the `stopifnot()` block at lines 28-33, consistent with the existing `bench`, `dplyr`, and `readr` guards. The guard uses the same diagnostic message style (`"readxl package is required for XLSX input -- run: pak::pak('readxl')"`) so users running the script standalone get a clear error if `readxl` is not installed.

## Skipped Issues

None -- all in-scope findings were fixed.

---

_Fixed: 2026-04-24T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
