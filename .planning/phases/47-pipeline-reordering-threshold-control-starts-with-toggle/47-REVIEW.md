---
phase: 47
reviewed: 2026-05-06T23:15:00-04:00
depth: standard
files_reviewed: 5
files_reviewed_list:
  - R/curation.R
  - R/curate_headless.R
  - R/mod_clean_data.R
  - R/mod_run_curation.R
  - tests/testthat/test-pipeline-reorder-toggle.R
findings:
  critical: 0
  high: 0
  medium: 0
  low: 2
  info: 2
  total: 4
status: clean
severity_counts:
  critical: 0
  high: 0
  medium: 0
  low: 2
  info: 2
---

# Phase 47: Code Review Report

**Reviewed:** 2026-05-06T23:15:00-04:00
**Depth:** standard
**Files Reviewed:** 5
**Status:** clean (no issues above info level that affect correctness)

## Summary

Phase 47 reorders the curation pipeline so WQX dictionary matching runs as Tier 3 (before CompTox starts-with at Tier 4), adds `wqx_threshold` and `starts_with` parameters to `run_curation_pipeline()` and `curate_headless()`, adds a "Search Settings" accordion panel to the pre-flight modal, and wires the new parameters through `data_store` to the curation module.

**Pipeline reorder correctness:** Verified. WQX receives `still_missed` (post-CAS tier, line 748). Starts-with receives `final_missed` (post-WQX remainder, line 774). Starts-with is gated by `if (starts_with && length(final_missed) > 0)` on line 773. The 3-character minimum filter applies only to starts-with, not WQX. All counter variables (`n_exact`, `n_starts_with`, `n_wqx`, `n_miss`) are initialized to 0 before the tier blocks and updated correctly within each tier's scope.

**Parameter threading:** `wqx_threshold` and `starts_with` flow correctly through three paths:
1. `curate_headless()` signature (line 77) -> `run_curation_pipeline()` call (line 182)
2. `mod_clean_data.R` UI inputs -> `build_mask_from_inputs()` / `run_all` mask -> `execute_pipeline()` -> `data_store` (line 386-387)
3. `mod_run_curation.R` reads `data_store$wqx_threshold %||% 0.85` and `isTRUE(data_store$starts_with)` (lines 165-166)

**Shiny namespacing:** All new inputs in the Search Settings accordion panel use `session$ns()` correctly (lines 313, 322, 335). The sync observers use `session` for `updateNumericInput` and `updateSliderInput`. The `%||%` fallback from rlang (confirmed in DESCRIPTION Imports) handles NULL data_store values safely.

**NULL safety:** `data_store$wqx_threshold` defaults via `%||% 0.85` in both `mod_run_curation.R` (line 165) and `execute_pipeline` (line 386). `data_store$starts_with` is wrapped in `isTRUE()` in both consumers, safely converting NULL to FALSE.

**Test coverage:** 5 test cases cover tier ordering (ORD-01), name exclusion (ORD-02), threshold passthrough (CONF-02), and toggle gating (TOG-02, both directions). The namespace-level mocking approach using `unlockBinding`/`assign` with `on.exit` restoration is justified given the `devtools::load_all()` namespace locking constraint.

No bugs, security issues, or correctness problems were found in the phase 47 changes.

## Low Issues

### LO-01: Stale tier number in comment for CASRN-column validation path

**File:** `R/curation.R:807`
**Issue:** Line 807 reads `# Tier 4: CAS validation for CASRN-tagged columns (separate path)`. After the reorder, the name tiers are: 1=Exact, 2=CAS-from-names, 3=WQX, 4=Starts-with. The "Tier 4" label now collides with the starts-with tier at line 772. The CASRN-column path is a separate parallel flow, not a sequential tier in the name waterfall.
**Fix:** Rename the comment to avoid tier number confusion:
```r
# CASRN-column validation (separate path, parallel to name tiers)
```

### LO-02: Pre-existing `ns()` vs `session$ns()` in `multi_cas_section` renderUI

**File:** `R/mod_clean_data.R:1275-1280`
**Issue:** Lines 1275 and 1277 use bare `ns()` inside a server-side `renderUI` block. Inside `moduleServer`, the correct pattern for dynamic UI is `session$ns()`. This is pre-existing code (not introduced by phase 47) and does not affect any phase 47 functionality. Flagged for awareness.
**Fix:** Replace `ns(...)` with `session$ns(...)` at lines 1275 and 1277:
```r
reactable::reactableOutput(session$ns("multi_cas_table")),
actionButton(
  session$ns("split_row"),
  "Split Selected Row",
  class = "btn-warning mt-2",
  icon = icon("scissors")
)
```

## Info

### IN-01: `run_all` mask deliberately reads search settings from inputs rather than hardcoding

**File:** `R/mod_clean_data.R:698-714`
**Note:** The `run_all` observer hardcodes all cleaning/harmonization steps to `TRUE` but reads `wqx_threshold` and `starts_with` from current input values (lines 711-712). This asymmetry is by design: "Run All" forces all cleaning steps on but respects the user's search sensitivity preferences. Correct behavior per the phase 47 design document.

### IN-02: Numeric input bounds guard prevents invalid slider sync

**File:** `R/mod_clean_data.R:373-382`
**Note:** The numeric-to-slider sync observer guards against out-of-range values with `val >= 0.50 && val <= 1.00` before calling `updateSliderInput`. This prevents a user typing an invalid numeric value from pushing the slider to an unexpected position. The slider-to-numeric direction does not need a guard because Shiny sliders enforce their own min/max bounds. Good defensive pattern.

---

_Reviewed: 2026-05-06T23:15:00-04:00_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
