---
phase: 50-auto-resolve-suggest
plan: "01"
subsystem: consensus
tags: [consensus, classification, auto-resolve, suggest, resolution-state]
dependency_graph:
  requires:
    - R/consensus.R (compute_similarity_scores, score_one_candidate, init_resolution_state, resolve_row, get_resolution_options)
  provides:
    - classify_auto_resolve (exported)
    - accept_all_suggestions (exported)
    - Extended init_resolution_state (.resolution_method, .resolution_reason columns)
    - Extended resolve_row (accepts auto_resolved/suggested statuses, sets .resolution_method='manual')
    - Extended get_resolution_options (accepts auto_resolved/suggested statuses)
  affects:
    - R/mod_review_results.R (Plan 02 will wire UI for new statuses)
    - R/export_helpers.R (.resolution_method/.resolution_reason flow through automatically)
tech_stack:
  added: []
  patterns:
    - Pre-allocated named vector for O(1) syn_lookup (same as compute_similarity_scores)
    - Vectorized pinned-check via !is.na(x) & x instead of isTRUE(x) for column vectors
    - Pre-built source_names map to avoid repeated sub() calls in classify loop
key_files:
  created: []
  modified:
    - R/consensus.R
    - tests/testthat/test-consensus.R
decisions:
  - "classify_auto_resolve runs as separate step after compute_similarity_scores, not integrated into it — cleaner separation of scoring vs. classification"
  - "accept_all_suggestions does NOT change consensus_status from 'suggested' to 'agree' — status stays 'suggested' but .pinned=TRUE indicates resolution. Matches existing disagree-pinned pattern."
  - "isTRUE() is scalar-only; vectorized pinned filtering uses !is.na(x) & x form throughout"
  - "jarl unused_function warning for accept_all_suggestions is a false positive for exported package functions — suppressed with --ignore unused_function"
metrics:
  duration: "6 minutes"
  completed: "2026-05-11"
  tasks_completed: 2
  files_modified: 2
---

# Phase 50 Plan 01: Backend Classification and Resolution Functions Summary

**One-liner:** Auto-resolve and suggest classification using D-01/D-02/D-03 score+gap thresholds on disagree rows, with bulk-accept and manual-override flows.

## What Was Built

Two new exported functions and four extended existing functions in `R/consensus.R`, plus 13 new test blocks covering all threshold logic and status transitions.

### New Exported Functions

**`classify_auto_resolve(resolution_state, enrichment_cache, dtxsid_cols, column_tags, auto_threshold=0.95, gap_threshold=0.15, suggest_threshold=0.70)`**
- Runs after `compute_similarity_scores()` on the resolution state
- For each non-pinned disagree row: collects per-candidate scores via `score_one_candidate()`, computes best score and gap to second-best
- D-01: `best >= 0.95 AND gap >= 0.15` → `"auto_resolved"` (pinned, `.resolution_method="auto"`)
- D-02: `best >= 0.70` (but not auto-resolve eligible) → `"suggested"` (not pinned, `.resolution_method=NA`)
- D-03: `best < 0.70` → row left as `"disagree"` (no change)
- Sets `.suggested_column` to the winning dtxsid column name for downstream use
- Sets `.resolution_reason` with numeric diagnostics (score, gap, threshold)
- Adds `.suggested_column` column to resolution_state if not present

**`accept_all_suggestions(df, dtxsid_cols)`**
- Follows `apply_priority_chain()` loop pattern exactly
- For each non-pinned `"suggested"` row: resolves to the candidate in `.suggested_column`
- Sets `.resolution_method="bulk-accept"` and `.pinned=TRUE`
- Preserves existing `.resolution_reason` from `classify_auto_resolve()`

### Extended Existing Functions

**`init_resolution_state(df)`**
- Added two new column guards: `.resolution_method` (NA_character_) and `.resolution_reason` (NA_character_)
- Existing guards for `.pinned` and `.manual_entry` unchanged

**`resolve_row(df, row_idx, chosen_column, dtxsid_cols)`**
- Status guard changed from `!= "disagree"` to `!%in% c("disagree", "auto_resolved", "suggested")`
- Now sets `.resolution_method[row_idx] <- "manual"` after consensus assignment (D-14 override flow)

**`get_resolution_options(df, row_idx, dtxsid_cols, ...)`**
- Status guard extended to allow `"auto_resolved"` and `"suggested"` rows (D-08 modal override)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed vectorized pinned check in classify_auto_resolve**
- **Found during:** Task 2 test execution
- **Issue:** `!isTRUE(resolution_state$.pinned)` is scalar-only — `isTRUE()` on a logical vector always returns `FALSE`, causing the filter to include all rows (including pre-pinned ones)
- **Fix:** Replaced with `pinned_vec <- !is.na(resolution_state$.pinned) & resolution_state$.pinned` (vectorized)
- **Files modified:** R/consensus.R
- **Commit:** b1635cb (included in Task 2 commit alongside test additions)

**2. [Rule 1 - Bug] Fixed redundant_equals lint in pinned_vec expression**
- **Found during:** jarl post-fix lint pass
- **Issue:** `resolution_state$.pinned == TRUE` flagged as redundant comparison on a logical vector
- **Fix:** `jarl check --fix` auto-resolved to `resolution_state$.pinned` (direct logical use)
- **Files modified:** R/consensus.R
- **Commit:** b1635cb

## Test Coverage Added

13 new test blocks across 4 test groups:

| Group | Tests | What's Verified |
|-------|-------|----------------|
| 16 | 1 | `init_resolution_state` adds `.resolution_method` and `.resolution_reason` as NA_character_ |
| 17 | 6 | `classify_auto_resolve`: auto_resolved path, suggested path, disagree path, score>=0.95 but gap<0.15 → suggested, pinned rows skipped, non-disagree rows untouched |
| 18 | 2 | `accept_all_suggestions`: bulk resolve + pinned-row skip |
| 19 | 2 | `resolve_row` accepts auto_resolved/suggested statuses, sets `.resolution_method="manual"` |
| 20 | 2 | `get_resolution_options` returns candidates for auto_resolved and suggested rows |

**Total test assertions:** 185 passing (was 172 before this plan), 0 failures, pre-existing warning count unchanged.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries introduced. New columns (`.resolution_method`, `.resolution_reason`, `.suggested_column`) are derived from existing classification data and flow through the existing export pipeline automatically. Thresholds are function parameters with safe defaults, not user-controllable from UI (T-50-01 mitigated per plan threat model).

## Self-Check

<files_check>
- R/consensus.R: exists and contains classify_auto_resolve, accept_all_suggestions
- tests/testthat/test-consensus.R: exists and contains all 13 new test blocks
- .planning/phases/50-auto-resolve-suggest/50-01-SUMMARY.md: this file
</files_check>

<commits_check>
- 0e4b459: feat(50-01): add classify_auto_resolve and accept_all_suggestions
- b1635cb: test(50-01): add 13 tests for classify_auto_resolve and accept_all_suggestions
</commits_check>

## Self-Check: PASSED

All files exist. All commits verified. 185 test assertions pass. `devtools::load_all()` succeeds. `classify_auto_resolve` and `accept_all_suggestions` are exported and callable.
