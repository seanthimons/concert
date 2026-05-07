---
phase: 48-wqx-resolution-ui
plan: "01"
subsystem: review-results-ui
tags: [wqx, confidence, review-button, js-events, reactable]
dependency_graph:
  requires: []
  provides:
    - wqx_confidence column in curation pipeline output
    - wqx-review-btn HTML in Resolution column for all WQX rows
    - wqx_review_click JS event dispatched on Review button click
    - WQX Conf. colDef in reactable (2dp, right-aligned, blank for NA)
  affects:
    - R/curation.R
    - R/mod_review_results.R
    - tests/testthat/test-mod-review-helpers.R
tech_stack:
  added: []
  patterns:
    - Vectorized review_btn over row_indices then mask-subset (avoids per-row function calls)
    - ifelse(match_tier == "fuzzy", 1 - match_distance, NA_real_) for JW distance -> similarity
    - sprintf %s count verified against arg count after wqx_review_click addition
    - wqx_confidence colDef guarded by presence check for backward compat
key_files:
  created: []
  modified:
    - R/curation.R
    - R/mod_review_results.R
    - tests/testthat/test-mod-review-helpers.R
decisions:
  - wqx_confidence computed as 1 - match_distance (JW distance to similarity); ifelse guard is belt-and-suspenders since exact/alias already have NA match_distance
  - review_btn vectorized over all row_indices then subsetted by wqx_has_pref / wqx_mask masks, not a per-row function call
  - wqx_confidence colDef guarded by presence check so pre-Plan-48 sessions with no wqx_confidence column do not error
metrics:
  duration_minutes: 20
  completed: "2026-05-07"
  tasks_completed: 2
  files_modified: 3
---

# Phase 48 Plan 01: WQX Confidence Column and Review Button Summary

**One-liner:** Carry JW fuzzy match similarity (`1 - match_distance`) through curation pipeline as `wqx_confidence` and surface it in a "WQX Conf." reactable column, with a teal "Review" button on every WQX row wired to a new `wqx_review_click` Shiny input event.

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| RED | Failing tests for wqx_confidence and wqx-review-btn | efc1066 | tests/testthat/test-mod-review-helpers.R |
| 1 (GREEN) | wqx_confidence pipeline + Review button in derive_resolution_html | 12643c5 | R/curation.R, R/mod_review_results.R, tests/testthat/test-mod-review-helpers.R |
| 2 | JS wqx_review_click handler + wqx_confidence colDef | b40a7ab | R/mod_review_results.R |

---

## What Was Built

### R/curation.R
Extended `wqx_rows` tibble construction (lines 754-770) to carry `wqx_confidence`:
```r
wqx_confidence = ifelse(
  wqx_resolved$match_tier == "fuzzy",
  1 - wqx_resolved$match_distance,
  NA_real_
)
```
Non-WQX result tibbles in `all_results` lack `wqx_confidence`; `dplyr::bind_rows` fills them with `NA_real_` — correct behavior, no additional changes needed.

### R/mod_review_results.R — derive_resolution_html()
Added vectorized `review_btn` string vector over all `row_indices`, then subset by mask. Both WQX cases (with preferred name and without) now append the button:
```r
review_btn <- paste0(
  ' <button class="wqx-review-btn btn btn-sm btn-outline-success" data-row="',
  row_indices, '">Review</button>'
)
```

### R/mod_review_results.R — compare_js sprintf block
Added `.wqx-review-btn` click handler as 5th block inside the existing `sprintf(...)` string, with `ns("wqx_review_click")` as 5th argument. Total `%s` count (5) matches argument count (5).

### R/mod_review_results.R — renderReactable colDef
Added `wqx_confidence` colDef after the `n_rows` colDef, guarded by presence check:
```r
if ("wqx_confidence" %in% names(df_display)) {
  col_defs[["wqx_confidence"]] <- reactable::colDef(
    name = "WQX Conf.",
    minWidth = 80,
    align = "right",
    cell = function(value, index) {
      if (is.na(value)) return("")
      formatC(value, digits = 2, format = "f")
    }
  )
}
```
Column is not in `always_hidden` or `untagged_cols`, so it is visible by default and hideable via colvis.

---

## Verification Results

```
grep -c "wqx_confidence" R/curation.R       => 1 (PASS)
grep -c "wqx-review-btn" R/mod_review_results.R => 2 (PASS)
grep -c "wqx_review_click" R/mod_review_results.R => 1 (PASS)
grep -c "WQX Conf." R/mod_review_results.R  => 1 (PASS)
testthat::test_file(...) => 18/18 PASS
Shiny smoke test => Listening on http://127.0.0.1:3838 (PASS)
```

---

## TDD Gate Compliance

- RED commit: `efc1066` — test(48-01): failing tests for wqx_confidence and wqx-review-btn
- GREEN commit: `12643c5` — feat(48-01): wqx_confidence pipeline and Review button (Task 1)
- Task 2 commit: `b40a7ab` — feat(48-01): JS wqx_review_click handler and wqx_confidence colDef

RED gate: 2 tests failed before implementation (wqx-review-btn assertions). GREEN gate: all 18 tests pass after implementation.

---

## Deviations from Plan

None — plan executed exactly as written. The vectorized `review_btn` approach (pre-compute vector, subset by mask) matches the plan's Change Point 1 specification directly.

---

## Threat Flags

No new security surface introduced beyond the plan's threat model. The `wqx_review_click` input event carries a client-supplied row index; server-side bounds validation is deferred to Plan 02 modal observer per T-48-01 mitigation plan.

---

## Known Stubs

None. The Review button renders and fires `wqx_review_click`; the modal observer that consumes it is Plan 02's scope.

---

## Self-Check

Files created/modified:

- [x] R/curation.R — contains `wqx_confidence = ifelse(`
- [x] R/mod_review_results.R — contains `wqx-review-btn`, `wqx_review_click`, `WQX Conf.`
- [x] tests/testthat/test-mod-review-helpers.R — 18 tests pass

Commits:
- [x] efc1066 exists
- [x] 12643c5 exists
- [x] b40a7ab exists

## Self-Check: PASSED
