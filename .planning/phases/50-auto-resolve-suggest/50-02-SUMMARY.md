---
phase: 50-auto-resolve-suggest
plan: "02"
subsystem: ui
tags: [ui, review-results, curation-pipeline, auto-resolve, suggest, modal, bulk-accept, value-boxes]
dependency_graph:
  requires:
    - R/consensus.R (classify_auto_resolve, accept_all_suggestions — from Plan 01)
    - R/mod_run_curation.R (compute_similarity_scores call site)
    - R/mod_review_results.R (derive_resolution_html, recalc_consensus_summary, compare modal, value boxes)
  provides:
    - classify_auto_resolve wired into curation pipeline after scoring
    - AUTO-RESOLVED and SUGGESTED status chips with correct colors
    - Resolution column HTML for auto_resolved and suggested rows
    - Accept Suggestion modal button for suggested rows
    - Accept All Suggestions bulk button (hidden when no suggestions)
    - Auto-Resolved and Suggested value boxes in curation stats
    - Modal candidate highlight (blue/amber) for suggested/auto_resolved rows
  affects:
    - R/mod_run_curation.R (pipeline now calls classify_auto_resolve)
    - R/mod_review_results.R (full UI layer for new statuses)
tech_stack:
  added: []
  patterns:
    - Pre-computed search_icon variable hoisted above all blocks that use it (vectorized reuse)
    - Vectorized auto_badge_vec and compare_btn_vec built once, indexed by mask (avoids per-row paste)
    - Vectorized pinned check in show/hide observer (!is.na(x) & x form, consistent with Plan 01)
    - shinyjs::hidden() + observeEvent show/hide pattern for conditional bulk accept button
key_files:
  created: []
  modified:
    - R/mod_run_curation.R
    - R/mod_review_results.R
decisions:
  - "Accept All Suggestions button placed after Show Errors in action row per UI-SPEC layout"
  - "Modal footer builds accept_suggestion_btn conditionally on row_status == suggested — no footer shown for auto_resolved (already resolved)"
  - "suggested_col retrieved inside compare_row_click observeEvent to avoid closure capture issues"
  - "search_icon pre-computation moved before all blocks (was inside disagree-not-pinned block) to enable reuse by auto_resolved and suggested blocks"
  - ".resolution_method=manual in modal_confirm loop is safety reinforcement — Plan 01 resolve_row already sets it, but explicit assignment ensures override flow is unambiguous"
metrics:
  duration: "6 minutes"
  completed: "2026-05-11"
  tasks_completed: 2
  files_modified: 2
---

# Phase 50 Plan 02: Pipeline Wiring and Review Results UI Summary

**One-liner:** Pipeline wired to classify_auto_resolve after scoring; Review Results gains auto_resolved/suggested chips, modal highlights, Accept Suggestion, Accept All Suggestions, and two new value boxes.

## What Was Built

### Task 1: Pipeline Wiring (R/mod_run_curation.R)

Added `classify_auto_resolve()` call immediately after `compute_similarity_scores()` inside the existing enrichment `tryCatch`, guarded by the same non-null check:

```r
data_store$resolution_state <- classify_auto_resolve(
  resolution_state = data_store$resolution_state,
  enrichment_cache = data_store$enrichment_cache,
  dtxsid_cols = data_store$dtxsid_cols,
  column_tags = data_store$column_tags
)
n_auto <- sum(data_store$resolution_state$consensus_status == "auto_resolved", na.rm = TRUE)
n_sugg <- sum(data_store$resolution_state$consensus_status == "suggested", na.rm = TRUE)
message(sprintf("[auto-resolve] %d auto-resolved, %d suggested", n_auto, n_sugg))
```

Failures are non-fatal (inside existing tryCatch). Classification runs every time enrichment runs.

### Task 2: Review Results UI (R/mod_review_results.R) — 8 changes

**Change 1 — recalc_consensus_summary:** Added `n_auto_resolved` and `n_suggested` to the returned list. Both now flow into consensus_summary for value box display.

**Change 2 — derive_resolution_html:** 
- Moved `search_icon` pre-computation before all blocks that use it.
- Added `auto_resolved` block: checkmark + DTXSID + pref_name + blue AUTO chip (with `.resolution_reason` tooltip) + Compare button. Vectorized `auto_badge_vec` and `compare_btn_vec` built once, indexed by mask.
- Added `suggested` (not pinned) block: cyan "Review Suggestion" `btn-outline-info` button.
- Added `suggested + pinned` block: accepted display with teal "accepted" badge + Compare button.

**Change 3 — status_levels/status_colors:** Added `"auto_resolved"` and `"suggested"` to both the `intersect()` vector and `status_colors` map (`#0D6EFD` blue and `#0DCAF0` cyan respectively). Both appear in the filter dropdown when present.

**Change 4 — row_bg_colors:** Added `"auto_resolved" = "rgba(13, 110, 253, 0.08)"` and `"suggested" = "rgba(13, 202, 240, 0.08)"` for table row background tints.

**Change 5 — curation_stats value boxes:** Extended resolved count to include `n_auto_resolved`. Changed layout from 4-column (3,3,3,3) to 6-column (2,2,2,2,2,2). Added "Auto-Resolved" (`bs_icon("magic")`, primary theme) and "Suggested" (`bs_icon("lightbulb")`, info theme) value boxes after "Disagree".

**Change 6 — Accept All Suggestions button:** Added `shinyjs::hidden()` button with `icon("wand-magic-sparkles")`, class `btn-sm btn-primary`, after "Show Errors" in the action row.

**Change 7 — Show/hide observer + bulk accept handler:** Observer checks for non-pinned suggested rows using vectorized `!is.na(x) & x` pinned check. `accept_all_suggestions()` handler calls Plan 01 function, updates resolution_state and consensus_summary, shows notification with count. Both wrapped in `tryCatch` with user-facing error notification.

**Change 8 — Comparison modal:** 
- `row_status` and `suggested_col` extracted from resolution_state at modal open.
- Candidate cards get conditional border style: blue (`#0D6EFD`) for suggested candidate, amber (`#FFC107`) for auto_resolved candidate, default grey otherwise.
- Candidate badge added: "Suggested" (`badge bg-primary`) or "Auto-Selected" (`badge bg-warning text-dark`).
- Modal footer gains "Accept Suggestion" `btn btn-primary` button for suggested rows only (NULL for auto_resolved).
- `accept_suggestion` handler resolves via `resolve_row()`, sets `.resolution_method = "suggested-accept"`, propagates to group rows, cleans up modal state.
- `modal_confirm` loop reinforces `.resolution_method = "manual"` for all group rows.

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written. The `search_icon` relocation (from inside the disagree block to before all blocks) is explicitly specified in the plan.

## Known Stubs

None. All UI changes are wired to real data from `resolution_state`. The `auto_resolved` and `suggested` statuses are populated by `classify_auto_resolve()` (Plan 01). The modal highlights depend on `.suggested_column` column set by `classify_auto_resolve()`. All paths have fallback guards (`NA` checks).

## Threat Surface Scan

| Flag | File | Description |
|------|------|-------------|
| threat_flag: XSS | R/mod_review_results.R | `.resolution_reason` rendered as HTML `title` attribute — mitigated by `htmltools::htmlEscape()` wrapping (T-50-05) |
| threat_flag: input-validation | R/mod_review_results.R | `accept_suggestion` handler validates `suggested_col` is non-NA and `row_idx` is non-null before resolving (T-50-04) |

Both threats are mitigated per plan's threat model. No new unplanned surface introduced.

## Self-Check

- [x] R/mod_run_curation.R: contains `classify_auto_resolve(` at line 279 (after `compute_similarity_scores` at line 271)
- [x] R/mod_review_results.R: contains `n_auto_resolved`, `n_suggested` in recalc_consensus_summary
- [x] R/mod_review_results.R: contains `"auto_resolved" = "#0D6EFD"` in status_colors
- [x] R/mod_review_results.R: contains `"suggested".*"#0DCAF0"` in status_colors
- [x] R/mod_review_results.R: contains `"auto_resolved" = "rgba(13, 110, 253, 0.08)"` in row_bg_colors
- [x] R/mod_review_results.R: contains `accept_all_suggestions` (5 occurrences)
- [x] R/mod_review_results.R: contains `"Accept All Suggestions"` string
- [x] R/mod_review_results.R: contains `wand-magic-sparkles` icon
- [x] R/mod_review_results.R: contains `"Accept Suggestion"` string
- [x] R/mod_review_results.R: contains `accept_suggestion` input handler
- [x] R/mod_review_results.R: contains `"suggested-accept"` method
- [x] R/mod_review_results.R: contains `"Auto-Selected"` badge
- [x] R/mod_review_results.R: contains `bs_icon("magic")`
- [x] R/mod_review_results.R: contains `bs_icon("lightbulb")`
- [x] R/mod_review_results.R: contains "Review Suggestion" text (line 179)
- [x] `devtools::load_all()` succeeds
- [x] Smoke test: `classify_auto_resolve` callable, `accept_all_suggestions` callable, `recalc_consensus_summary` returns `n_auto_resolved` and `n_suggested` with correct counts

**Commits:**
- `4141a50`: feat(50-02): wire classify_auto_resolve into curation pipeline
- `2f2fdc8`: feat(50-02): update mod_review_results for auto-resolve and suggest UI

## Self-Check: PASSED
