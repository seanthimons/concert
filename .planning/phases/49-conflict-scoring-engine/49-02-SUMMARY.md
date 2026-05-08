---
phase: 49-conflict-scoring-engine
plan: "02"
subsystem: scoring-ui
tags: [scoring, jaro-winkler, review-results, modal, export, shiny-wiring]
dependency_graph:
  requires: [enrich_synonyms() from R/curation.R (Plan 01), compute_similarity_scores() from R/consensus.R (Plan 01), score_one_candidate() from R/consensus.R (Plan 01)]
  provides: [similarity_score wired into curation pipeline, Sim. Score colDef in Review Results table, per-candidate score badges in comparison modal, similarity_score passthrough in export]
  affects: [R/mod_run_curation.R, R/mod_review_results.R, R/export_helpers.R]
tech_stack:
  added: []
  patterns: [presence-gated colDef, precomputed-named-lookup, non-fatal-tryCatch-extension, O(1)-synonym-lookup-in-modal]
key_files:
  created: []
  modified:
    - R/mod_run_curation.R
    - R/mod_review_results.R
    - R/export_helpers.R
decisions:
  - "Synonym fetch and scoring wired inside existing enrichment tryCatch -- failures are non-fatal, curation results remain valid"
  - "Sim. Score colDef presence-gated on 'similarity_score' %in% names(df_display) -- column only appears after compute_similarity_scores() has run"
  - "Modal synonym lookup precomputed as stats::setNames() named vector outside lapply -- O(1) per candidate, addresses complexity advisory"
  - "similarity_score flows through export_helpers.R automatically -- confirmed not in select(-any_of(...)) exclusion list"
metrics:
  duration: "~20 minutes"
  completed: "2026-05-08"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 3
requirements:
  - SCORE-01
  - SCORE-02
---

# Phase 49 Plan 02: Scoring UI Wiring — Summary

**One-liner:** Synonym fetch + similarity scoring wired into curation pipeline tryCatch; Review Results shows 2-decimal "Sim. Score" column; comparison modal cards show blue Jaro-Winkler badges per candidate; export passthrough verified.

## What Was Built

### Task 1: Wire synonym fetch and score computation into curation pipeline

Added two blocks inside the existing enrichment `tryCatch` in `R/mod_run_curation.R`, after the `enrich_candidates()` call completes:

**Synonym fetch block:** Calls `enrich_synonyms(dtxsids = all_unique_dtxsids, existing_cache = data_store$enrichment_cache)` and writes the updated cache back to `data_store$enrichment_cache`. Only executes when `all_unique_dtxsids` is non-empty.

**Similarity scoring block:** Calls `compute_similarity_scores(resolution_state, enrichment_cache, dtxsid_cols, column_tags)` and writes the result back to `data_store$resolution_state`. Guard checks ensure `resolution_state`, `dtxsid_cols`, and `column_tags` are all non-NULL before running.

Both blocks share the existing non-fatal `error = function(e)` handler — synonym/scoring failures log a warning and notify the user without blocking export or any other curation functionality.

Added a documentation comment to `R/export_helpers.R` near the `select(-any_of(...))` line confirming that `similarity_score` is not in the exclusion list and flows through automatically to the Curated Data sheet.

### Task 2: Add Sim. Score column and per-candidate modal badges

**Review Results table colDef (`R/mod_review_results.R`):**

Added `col_defs[["similarity_score"]]` presence-gated on `"similarity_score" %in% names(df_display)`. The colDef mirrors the WQX Conf. pattern exactly: `name = "Sim. Score"`, `minWidth = 80`, `align = "right"`, `formatC(value, digits = 2, format = "f")` for non-NA values, empty string for NA (non-disagree rows). The column only appears in the table when `compute_similarity_scores()` has populated the column.

**Comparison modal badge (`R/mod_review_results.R`):**

Added precomputed scoring context before the `lapply(names(options), ...)` card builder:
- `modal_input_name`: resolved once from the Name-tagged column at `row_idx`
- `modal_synonym_map`: `stats::setNames(ec$synonyms, ec$dtxsid)` — O(1) named vector lookup

Inside `lapply`, each candidate's score is computed via `score_one_candidate()` using the precomputed map. The score badge is rendered as `tags$span(class = "badge bg-info", title = "Similarity score (Jaro-Winkler)", sprintf("%.2f", candidate_sim_score))` inside a flex container alongside the Select button. Badge is only rendered when `candidate_sim_score` is non-NA.

### Task 3: Shiny smoke test

App started cleanly: `Listening on http://127.0.0.1:3838` confirmed. No R errors or warnings related to `enrich_synonyms`, `compute_similarity_scores`, or `score_one_candidate` during startup.

⚡ Auto-approved checkpoint (AUTO mode).

## Test Results

| Scope | Tests Before | Tests After | Result |
|-------|-------------|-------------|--------|
| Full suite | 2118 passed, 3 failed | 2118 passed, 3 failed | PASS (no regressions) |
| load_all() | OK | OK | PASS |
| air format | - | Clean | PASS |
| jarl check | - | All checks passed | PASS |

The 3 pre-existing failures are in `test-cleaning-reference.R` and `test-reference-provenance.R` (WQX dictionary structure tests) — confirmed pre-existing by baseline comparison before any changes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Performance] Precomputed modal synonym lookup outside lapply**
- **Found during:** Task 2 — complexity advisory triggered during edit
- **Issue:** Plan specified a `which(cache$dtxsid == opt$dtxsid)` linear scan inside `lapply` per candidate
- **Fix:** Precomputed `modal_synonym_map <- stats::setNames(ec$synonyms, ec$dtxsid)` before the `lapply`, reducing per-candidate lookup from O(n) to O(1); also extracted `modal_input_name` once outside the loop
- **Files modified:** R/mod_review_results.R
- **Commit:** 8e28364

## Known Stubs

None. All three pipeline connections are fully wired:
- `enrich_synonyms()` calls real `ct_chemical_synonym_search_bulk()` at runtime
- `compute_similarity_scores()` reads from cache populated by synonym fetch
- `score_one_candidate()` called directly in modal card builder from the same cache

## Threat Flags

None. The modal badge renders via `sprintf("%.2f", candidate_sim_score)` — numeric-only output, no raw synonym strings rendered. This satisfies T-49-04 (Tampering mitigation from plan threat model).

## Self-Check: PASSED

| Item | Status |
|------|--------|
| R/mod_run_curation.R contains `enrich_synonyms(` | FOUND (lines 257-263) |
| R/mod_run_curation.R contains `compute_similarity_scores(` | FOUND (lines 271-277) |
| R/mod_run_curation.R contains `data_store$enrichment_cache <- synonym_result$cache` | FOUND (line 262) |
| R/mod_run_curation.R contains `data_store$resolution_state <- compute_similarity_scores(` | FOUND (line 271) |
| R/export_helpers.R contains comment mentioning `similarity_score` | FOUND (line 45) |
| R/mod_review_results.R contains `col_defs[["similarity_score"]]` | FOUND |
| R/mod_review_results.R contains `name = "Sim. Score"` | FOUND |
| R/mod_review_results.R contains `if ("similarity_score" %in% names(df_display))` | FOUND |
| R/mod_review_results.R contains `score_one_candidate(` in modal builder | FOUND |
| R/mod_review_results.R contains `class = "badge bg-info"` | FOUND |
| R/mod_review_results.R contains `sprintf("%.2f", candidate_sim_score)` | FOUND |
| Commit 3bdb99a (Task 1) | FOUND |
| Commit 8e28364 (Task 2) | FOUND |
| Shiny app starts: Listening on http://127.0.0.1:3838 | CONFIRMED |
| .planning/phases/49-conflict-scoring-engine/49-02-SUMMARY.md exists | THIS FILE |
