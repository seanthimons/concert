---
phase: 47-pipeline-reordering-threshold-control-starts-with-toggle
verified: 2026-05-06T23:15:00-04:00
status: human_needed
score: 9/11 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Open pre-flight modal and confirm Search Settings accordion renders with slider at 0.85, numeric at 0.85, and starts-with checkbox unchecked"
    expected: "Third accordion section titled Search Settings visible with all three controls at correct defaults"
    why_human: "UI rendering and layout cannot be verified programmatically"
  - test: "Move WQX threshold slider to 0.70, confirm numeric input updates to 0.70. Type 0.90 into numeric input, confirm slider moves to 0.90"
    expected: "Slider and numeric input stay synchronized bidirectionally"
    why_human: "Shiny reactive sync behavior requires live browser interaction"
---

# Phase 47: Pipeline Reordering, Threshold Control & Starts-With Toggle Verification Report

**Phase Goal:** Users control the search chain precisely -- WQX fires before starts-with, fuzzy threshold is configurable in the pre-flight modal, and starts-with is off by default
**Verified:** 2026-05-06T23:15:00-04:00
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

Truths are merged from ROADMAP success criteria (SC-1 through SC-5) and PLAN frontmatter must_haves from both plans.

| # | Truth | Source | Status | Evidence |
|---|-------|--------|--------|----------|
| 1 | WQX matching tier runs before CompTox starts-with in run_curation_pipeline() | Plan-01 / SC-1 | VERIFIED | R/curation.R line 744: "Tier 3: WQX" comment; line 772: "Tier 4: Starts-with" comment. WQX block (lines 744-770) precedes starts-with block (lines 772-788). |
| 2 | CompTox starts-with fires only on names still unresolved after WQX matching | Plan-01 / SC-4 | VERIFIED | R/curation.R line 766: `final_missed <- setdiff(still_missed, wqx_matched_names)`. Line 773: starts-with receives `final_missed` (post-WQX remainder). Test "Names resolved by WQX never reach starts-with (ORD-02)" passes. |
| 3 | Pipeline passes user-configured threshold to match_wqx() instead of hardcoded default | Plan-01 / SC-2 | VERIFIED | R/curation.R line 748: `match_wqx(still_missed, wqx_dict, threshold = wqx_threshold, verbose = FALSE)`. Test "wqx_threshold parameter passes through to match_wqx (CONF-02)" passes with threshold=0.60. |
| 4 | Pipeline skips starts-with search when starts_with = FALSE | Plan-01 / SC-3 | VERIFIED | R/curation.R line 773: `if (starts_with && length(final_missed) > 0)`. Test "starts_with=FALSE skips starts-with entirely (TOG-02)" passes -- mock confirms search_starts_with never called. |
| 5 | curate_headless() exposes wqx_threshold and starts_with arguments and threads them to run_curation_pipeline() | Plan-01 / SC-5 | VERIFIED | R/curate_headless.R lines 76-77: `wqx_threshold = 0.85, starts_with = FALSE` in signature. Lines 178-183: `run_curation_pipeline(..., wqx_threshold = wqx_threshold, starts_with = starts_with)`. |
| 6 | Pre-flight modal contains a WQX fuzzy threshold slider (0.50-1.00, default 0.85) with companion numeric input | Plan-02 / SC-2 | VERIFIED | R/mod_clean_data.R lines 312-328: `sliderInput(session$ns("wqx_threshold"), ..., min = 0.50, max = 1.00, step = 0.01, value = 0.85)` and `numericInput(session$ns("wqx_threshold_num"), ..., value = 0.85)`. Properly namespaced with `session$ns()`. |
| 7 | Pre-flight modal contains a starts-with toggle switch that is off by default | Plan-02 / SC-3 | VERIFIED | R/mod_clean_data.R lines 332-334: `checkboxInput(session$ns("starts_with_enabled"), label = "Enable CompTox starts-with search", value = FALSE)`. Default is FALSE. |
| 8 | Slider and numeric input stay synchronized when either is changed | Plan-02 | HUMAN NEEDED | R/mod_clean_data.R lines 365-382: Two `observeEvent` blocks with `ignoreInit = TRUE`. Slider->numeric sync at line 368, numeric->slider sync with bounds guard at lines 376-378. Code is correct but runtime sync requires live browser interaction to confirm. |
| 9 | Run All Steps reads the current slider/toggle values (does not force starts-with on) | Plan-02 | VERIFIED | R/mod_clean_data.R lines 698-715: `run_all` observer mask includes `wqx_threshold = input$wqx_threshold` and `starts_with = isTRUE(input$starts_with_enabled)`. Values are READ from inputs, not hardcoded TRUE. |
| 10 | mod_run_curation.R passes wqx_threshold and starts_with from data_store to run_curation_pipeline() | Plan-02 | VERIFIED | R/mod_run_curation.R lines 160-167: `run_curation_pipeline(..., wqx_threshold = data_store$wqx_threshold %||% 0.85, starts_with = isTRUE(data_store$starts_with))`. Safe defaults applied. |
| 11 | Notification text includes WQX match count in the tier breakdown | Plan-02 | VERIFIED | R/mod_run_curation.R lines 267-274: `sprintf("Search complete: %d exact, %d CAS, %d WQX, %d starts-with, %d no match", ..., pipeline_result$search_summary$n_wqx, ...)`. |

**Score:** 9/11 truths verified (2 need human verification for runtime UI behavior)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `R/curation.R` | Reordered pipeline: WQX at Tier 3, starts-with at Tier 4 gated by flag; contains `threshold = wqx_threshold` | VERIFIED | Lines 629-635: signature has `wqx_threshold = 0.85, starts_with = FALSE`. Line 744: Tier 3 WQX. Line 772: Tier 4 starts-with gated. Line 748: `threshold = wqx_threshold`. |
| `R/curate_headless.R` | Headless API with wqx_threshold and starts_with params; contains `wqx_threshold = 0.85` | VERIFIED | Lines 76-77: `wqx_threshold = 0.85, starts_with = FALSE`. Lines 178-183: both threaded to `run_curation_pipeline()`. |
| `tests/testthat/test-pipeline-reorder-toggle.R` | Unit tests for tier ordering, threshold passthrough, and toggle; min 50 lines | VERIFIED | 235 lines. 5 test_that blocks covering ORD-01, ORD-02, CONF-02, TOG-02. All 7 expectations pass (FAIL 0, WARN 0, SKIP 0, PASS 7). |
| `R/mod_clean_data.R` | Search Settings accordion panel with slider, numeric input, checkbox; extended mask; sync observers; contains `Search Settings` | VERIFIED | Line 301: `"Search Settings"` accordion panel. Lines 312-341: slider + numeric + checkbox. Lines 360-362: mask extension. Lines 365-382: sync observers. Lines 386-387: data_store writes. |
| `R/mod_run_curation.R` | Pipeline call with wqx_threshold + starts_with from data_store; updated notification; contains `n_wqx` | VERIFIED | Lines 165-166: `wqx_threshold` and `starts_with` from data_store. Line 271: `pipeline_result$search_summary$n_wqx`. Line 268: `"%d WQX"` in notification string. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| R/curate_headless.R | R/curation.R | `run_curation_pipeline(wqx_threshold=, starts_with=)` | WIRED | Line 181: `wqx_threshold = wqx_threshold`, line 182: `starts_with = starts_with` in `run_curation_pipeline()` call |
| R/curation.R | R/wqx_matching.R | `match_wqx(threshold = wqx_threshold)` | WIRED | Line 748: `match_wqx(still_missed, wqx_dict, threshold = wqx_threshold, verbose = FALSE)`. match_wqx signature (wqx_matching.R line 21) accepts `threshold` parameter. |
| R/mod_clean_data.R | data_store$wqx_threshold | mask assignment in execute_pipeline | WIRED | Line 386: `data_store$wqx_threshold <- mask$wqx_threshold %||% 0.85`. Both `build_mask_from_inputs()` (line 360) and `run_all` observer (line 711) populate `mask$wqx_threshold`. |
| R/mod_run_curation.R | R/curation.R | `run_curation_pipeline(wqx_threshold=, starts_with=)` | WIRED | Lines 165-166: `wqx_threshold = data_store$wqx_threshold %||% 0.85, starts_with = isTRUE(data_store$starts_with)` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|----|
| R/curation.R | wqx_threshold | Function parameter from caller | Flows from UI slider through data_store to match_wqx(threshold=) | FLOWING |
| R/curation.R | starts_with | Function parameter from caller | Flows from UI checkbox through data_store to if-gate | FLOWING |
| R/mod_clean_data.R | input$wqx_threshold | Shiny sliderInput with default 0.85 | Written to data_store, read by mod_run_curation.R | FLOWING |
| R/mod_run_curation.R | data_store$wqx_threshold | Written by mod_clean_data.R execute_pipeline | Read and passed to run_curation_pipeline() | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| All 5 pipeline tests pass | `Rscript -e "devtools::load_all(); testthat::test_file('tests/testthat/test-pipeline-reorder-toggle.R')"` | FAIL 0, WARN 0, SKIP 0, PASS 7 | PASS |
| Package loads without error | `Rscript -e "devtools::load_all()"` | Loads successfully | PASS |
| run_curation_pipeline accepts new params | Verified via test execution with `wqx_threshold = 0.60` and `starts_with = TRUE/FALSE` | All param combinations work | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ORD-01 | 47-01 | WQX matching tier runs before CompTox starts-with in the curation search chain | SATISFIED | Tier 3 (WQX) at line 744, Tier 4 (starts-with) at line 772 in R/curation.R. Test "WQX tier resolves names before starts-with" passes. |
| ORD-02 | 47-01 | CompTox starts-with fires only on names still unresolved after WQX matching | SATISFIED | `final_missed <- setdiff(still_missed, wqx_matched_names)` at line 766. starts-with receives `final_missed`. Test "Names resolved by WQX never reach starts-with" passes. |
| CONF-01 | 47-02 | Pre-flight modal includes a WQX fuzzy threshold slider with numeric input (default 0.85) | NEEDS HUMAN | Code exists (lines 312-328 in mod_clean_data.R) with correct parameters. Visual rendering requires human confirmation. |
| CONF-02 | 47-01 | Pipeline passes user-configured threshold to match_wqx() instead of hardcoded default | SATISFIED | `threshold = wqx_threshold` at line 748 in R/curation.R. Test with threshold=0.60 confirms passthrough. |
| TOG-01 | 47-02 | Pre-flight modal includes a toggle to enable/disable CompTox starts-with tier (off by default) | NEEDS HUMAN | Code exists (lines 332-334 in mod_clean_data.R) with `value = FALSE`. Visual rendering requires human confirmation. |
| TOG-02 | 47-01 | Pipeline skips starts-with search when toggle is off | SATISFIED | `if (starts_with && length(final_missed) > 0)` at line 773. Test "starts_with=FALSE skips starts-with entirely" passes. |

No orphaned requirements. All 6 requirement IDs from REQUIREMENTS.md Phase 47 mapping (ORD-01, ORD-02, CONF-01, CONF-02, TOG-01, TOG-02) are claimed by plans and verified.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| R/mod_clean_data.R | 965 | `placeholder = "Type a term..."` | Info | Legitimate UI placeholder text for a search input, not a stub |
| R/curate_headless.R | 295 | `# No Unit column -- placeholder harmonize output` | Info | Legitimate comment about fallback behavior, not a stub |

No blockers or warnings found. All files are clean of TODO/FIXME/HACK markers relevant to Phase 47 changes.

### Human Verification Required

### 1. Pre-flight Modal Rendering

**Test:** Start the Shiny app, upload a file, tag columns, click "Run Pipeline" to open the pre-flight modal. Verify the modal shows three accordion sections: Cleaning Steps, Harmonization Steps, Search Settings. Verify Search Settings contains a slider at 0.85, a numeric input at 0.85, and an unchecked "Enable CompTox starts-with search" checkbox.
**Expected:** All three UI controls render correctly at their default values within the Search Settings accordion panel.
**Why human:** UI rendering, accordion layout, and visual control state cannot be verified programmatically.

### 2. Slider/Numeric Sync

**Test:** In the Search Settings panel, move the slider to 0.70. Then type 0.90 into the numeric input.
**Expected:** When slider moves to 0.70, numeric updates to 0.70. When 0.90 is typed, slider moves to 0.90.
**Why human:** Bidirectional Shiny reactive sync requires live browser interaction to confirm no infinite loops or lag.

### Gaps Summary

No code-level gaps found. All artifacts exist, are substantive, are properly wired, and data flows through the full chain. All 5 unit tests pass (7 expectations). All 6 requirement IDs are covered.

The only items requiring attention are the two human verification tests for UI rendering and slider/numeric sync behavior. These are standard Shiny UI verification items that cannot be confirmed through static analysis alone. The 47-02-SUMMARY.md reports that cold boot was confirmed ("Listening on" with no errors) and human verification was approved, but this verifier cannot attest to that independently.

---

_Verified: 2026-05-06T23:15:00-04:00_
_Verifier: Claude (gsd-verifier)_
