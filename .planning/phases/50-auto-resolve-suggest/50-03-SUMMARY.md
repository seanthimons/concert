---
phase: 50-auto-resolve-suggest
plan: "03"
subsystem: export
tags: [export, resolution-audit, summary-counts, smoke-test, auto-resolve, suggest]
dependency_graph:
  requires:
    - R/consensus.R (init_resolution_state adds .resolution_method, .resolution_reason, .suggested_column — from Plan 01)
    - R/mod_run_curation.R (classify_auto_resolve wired — from Plan 02)
    - R/mod_review_results.R (UI for auto_resolved/suggested statuses — from Plan 02)
  provides:
    - .resolution_method and .resolution_reason columns in exported Curated Data sheet (after consensus_source)
    - .suggested_column excluded from export (internal state column)
    - Consensus - Auto-Resolved and Consensus - Suggested rows in Summary sheet
    - Verified clean app startup with all Phase 50 changes integrated
  affects:
    - Excel export produced by build_export_sheets()
tech_stack:
  added: []
  patterns:
    - dplyr::relocate() with tidyselect::any_of() for column positioning (same as existing needs_review relocate)
    - tidyselect::any_of() exclusion list extension for internal-state columns
    - Direct consensus_status equality checks in summary tibble (same as existing n_agree/n_disagree pattern)
key_files:
  created: []
  modified:
    - R/export_helpers.R
decisions:
  - ".resolution_method and .resolution_reason flow through automatically (not explicitly selected) — only .suggested_column needs exclusion as internal-only state"
  - "Column positioning via dplyr::relocate() uses any_of() so it is a no-op when columns are absent (safe for pre-Phase-50 exports)"
  - "Summary counts read directly from resolution_state$consensus_status at export time (not from consensus_summary) — ensures accuracy even if consensus_summary is stale"
metrics:
  duration: "2 minutes"
  completed: "2026-05-11"
  tasks_completed: 1
  files_modified: 1
---

# Phase 50 Plan 03: Export Audit Columns and Smoke Test Summary

**One-liner:** Export extended to include .resolution_method/.resolution_reason audit columns positioned after consensus_source, .suggested_column excluded, and Auto-Resolved/Suggested summary counts; app starts cleanly with all Phase 50 changes.

## What Was Built

### Task 1: Export Changes (R/export_helpers.R)

Three targeted changes to `build_export_sheets()`:

**Change 1 — Exclusion list extended:**
Added `.suggested_column` to the `dplyr::select(-tidyselect::any_of(...))` call. This internal column (set by `classify_auto_resolve()` to track which dtxsid column was the best candidate) is not meaningful to end users and is excluded alongside `.pinned` and `.manual_entry`. Updated the comment to document which columns flow through vs are excluded.

**Change 2 — Column positioning:**
Added a `dplyr::relocate()` call after the exclusion and enrichment join steps to position `.resolution_method` and `.resolution_reason` immediately after `consensus_source`. Uses `tidyselect::any_of()` on both sides so it is a no-op when these columns are absent (backward-compatible for exports from pre-Phase-50 sessions).

**Change 3 — Summary sheet counts:**
Added two new rows to the Metric/Value tibble in Sheet 3:
- `"Consensus - Auto-Resolved"` with `sum(resolution_state$consensus_status == "auto_resolved", na.rm = TRUE)`
- `"Consensus - Suggested"` with `sum(resolution_state$consensus_status == "suggested", na.rm = TRUE)`

Inserted before `"Match Rate (%)"` per the plan spec.

### Task 2: Smoke Test (checkpoint:human-verify)

Ran `concert::run_app(port=3839, launch.browser=FALSE)` from the worktree. Output:

```
Listening on http://127.0.0.1:3839
```

No errors, no warnings about missing icons, broken module wiring, or reactive state issues. The app loaded all reference caches cleanly and reached the listening state with all Phase 50 changes integrated (R/consensus.R, R/mod_run_curation.R, R/mod_review_results.R, R/export_helpers.R).

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. All export changes write real data from `resolution_state$consensus_status` and `resolution_state$.resolution_method`/`.resolution_reason`. The `any_of()` guards handle the case where Phase 50 columns are absent gracefully.

## Threat Surface Scan

| Flag | File | Description |
|------|------|-------------|
| threat_flag: information-disclosure | R/export_helpers.R | `.resolution_reason` (score=X, gap=Y, threshold=Z) written to user-downloadable Excel — mitigated per T-50-07: contains only numeric scores from user's own data, no secrets or PII |
| threat_flag: tampering | R/export_helpers.R | `.suggested_column` excluded via `any_of()` exclusion — mitigated per T-50-08: internal column reference not visible to user |

Both threats are handled per the plan's threat model. No new unplanned surface introduced.

## Self-Check

- [x] R/export_helpers.R line 47: contains `".suggested_column"` in exclusion list
- [x] R/export_helpers.R lines 61-65: contains `dplyr::relocate(` with `any_of(c(".resolution_method", ".resolution_reason"))`
- [x] R/export_helpers.R line 81: contains `"Consensus - Auto-Resolved"`
- [x] R/export_helpers.R line 82: contains `"Consensus - Suggested"`
- [x] R/export_helpers.R exclusion line 47: does NOT contain `.resolution_method`
- [x] `devtools::load_all()` succeeds
- [x] Smoke test: `Listening on http://127.0.0.1:3839` with no errors

**Commits:**
- `43f787f`: feat(50-03): extend export with resolution audit columns and summary counts

## Self-Check: PASSED
