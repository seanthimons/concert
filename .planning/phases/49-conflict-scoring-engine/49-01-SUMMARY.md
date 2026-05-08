---
phase: 49-conflict-scoring-engine
plan: "01"
subsystem: scoring-backend
tags: [scoring, synonyms, jaro-winkler, enrichment, consensus]
dependency_graph:
  requires: [R/curation.R enrich_candidates pattern, R/consensus.R get_resolution_options pattern, stringdist package]
  provides: [enrich_synonyms(), flatten_synonym_tiers(), score_one_candidate(), compute_similarity_scores()]
  affects: [R/curation.R, R/consensus.R, tests/testthat/test-enrichment.R, tests/testthat/test-consensus.R]
tech_stack:
  added: []
  patterns: [incremental-caching, pipe-joined-string-storage, O(1)-named-lookup, D-03-score-formula]
key_files:
  created: []
  modified:
    - R/curation.R
    - R/consensus.R
    - tests/testthat/test-enrichment.R
    - tests/testthat/test-consensus.R
decisions:
  - "enrich_synonyms() returns full enrichment cache (all existing columns + synonyms), not a separate synonym-only cache (D-01)"
  - "All synonym tiers flattened equally into pipe-joined string (D-04)"
  - "score_one_candidate() is standalone helper for reuse in modal card rendering (Plan 02)"
  - "Pre-built stats::setNames() lookup for O(1) dtxsid->synonyms access in compute_similarity_scores()"
  - "Test fixed: JW(Silica, Estradiol) = 0.50 not 0.35 as in research doc; used Testosterone pair instead"
  - "Pre-existing redundant_equals warnings in curation.R fixed via jarl --fix (5 instances, lines 316/402/460/736/834)"
metrics:
  duration: "~25 minutes"
  completed: "2026-05-08"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 4
requirements:
  - SCORE-01
  - SCORE-02
---

# Phase 49 Plan 01: Scoring Backend — Summary

**One-liner:** JW similarity scoring engine with CompTox synonym caching — `enrich_synonyms()` fetches and pipe-joins synonym tiers, `compute_similarity_scores()` computes max-JW score per disagree row using D-03 formula.

## What Was Built

### Task 1: enrich_synonyms() and flatten_synonym_tiers() in R/curation.R

`flatten_synonym_tiers(row)` (unexported helper) flattens all CompTox synonym tiers (`valid`, `good`, `other`, `deleted`, `beilstein`, `alternate`, `pcCode`) from a single API response row into a pipe-joined character string, returning `NA_character_` when no synonyms exist.

`enrich_synonyms(dtxsids, existing_cache = NULL)` (exported) mirrors the incremental caching pattern of `enrich_candidates()`:
- Skips DTXSIDs already in the cache when a `synonyms` column exists
- Treats all DTXSIDs as needing fetch when the `synonyms` column is absent (backward-compat)
- Calls `ComptoxR::ct_chemical_synonym_search_bulk()` for new DTXSIDs
- Stores `NA_character_` for DTXSIDs with no API synonym data
- Returns the FULL enrichment cache with `synonyms` column added/updated (preserving `casrn`, `molecular_formula`, `molecular_weight`)
- Gracefully handles API failures — returns existing_cache unchanged with `failed_dtxsids` populated

5 new tests added to `test-enrichment.R` (mocked via `local_mocked_bindings`):
- Returns cache with synonyms column containing pipe-joined values
- Stores NA when API returns 0 rows
- Merges into existing cache preserving all original columns
- Skips already-cached DTXSIDs (verified via call_args capture)
- Handles API failure gracefully preserving existing_cache

### Task 2: score_one_candidate() and compute_similarity_scores() in R/consensus.R

`score_one_candidate(input_name, preferred_name, synonyms_str, rank)` (exported pure function):
- Implements D-03 formula: `max(JW(input, preferredName, syn_1, ..., syn_N))`
- Splits `synonyms_str` on `|` (fixed), concatenates with `preferred_name`
- Calls `stringdist::stringdist(..., method = "jw")` once over the full name vector (vectorized)
- Adds +0.05 rank bonus when `rank <= 3`, clamps result to `[0, 1]`
- Returns `NA_real_` for empty input or when no valid comparison names exist

`compute_similarity_scores(resolution_state, enrichment_cache, dtxsid_cols, column_tags)` (exported):
- Pre-builds `stats::setNames()` lookup for O(1) dtxsid→synonyms access
- Identifies Name-tagged column from `column_tags` (D-07: input is always user's original name)
- Iterates only `disagree` rows; non-disagree rows get `NA_real_`
- Scores each candidate DTXSID per row via `score_one_candidate()`, takes `max()` across candidates
- Writes `similarity_score` column onto `resolution_state` and returns it
- Gracefully handles missing `synonyms` column — falls back to `preferredName`-only comparison

10 new tests added to `test-consensus.R`:
- **score_one_candidate (6 tests):** exact synonym match ≥ 0.95, dissimilar name < 0.5, rank bonus exactly +0.05, clamped to 1.0, NA input returns NA, no valid names returns NA
- **compute_similarity_scores (4 tests):** disagree rows get numeric score / others NA, best candidate selected, missing synonyms column falls back to preferredName, no Name-tagged column returns all NA

## Test Results

| File | Tests Before | Tests After | Result |
|------|-------------|-------------|--------|
| test-enrichment.R | 54 | 59 | PASS (0 failures) |
| test-consensus.R | 138 | 148 | PASS (0 failures, 1 pre-existing warning) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] JW similarity assertion corrected (Silica vs Estradiol = 0.50 not 0.35)**
- **Found during:** Task 2 test run
- **Issue:** Research doc stated JW("Silica", "Estradiol") ≈ 0.35 — actual runtime value is 0.50 (> 0.5 threshold)
- **Fix:** Changed test to use `Testosterone` as the dissimilar reference (JW = 0.4167, verified at runtime)
- **Files modified:** tests/testthat/test-consensus.R
- **Commit:** 75e0ff2

**2. [Rule 2 - Pre-existing lint] Fixed 5 redundant_equals warnings in curation.R**
- **Found during:** Task 1 jarl check
- **Issue:** 5 pre-existing `== TRUE` comparisons on logical vectors at lines 316, 402, 460, 736, 834
- **Fix:** Applied `jarl check --fix --allow-dirty`; auto-removed redundant `== TRUE`
- **Files modified:** R/curation.R
- **Commit:** b2a4bd5 (merged into Task 1 commit as it touched the same file)

## Known Stubs

None — all functions are fully wired. Synonym fetch calls real `ct_chemical_synonym_search_bulk()` at runtime (mocked only in tests). Score computation consumes the cache column directly.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries introduced. Synonym strings from CompTox API are treated as display-only data; `nchar()` guards and `!is.na()` filters prevent malformed input from causing errors (T-49-01). Explicit `na.rm = TRUE` in `max(sims)` prevents NA leakage (T-49-02).

## Self-Check: PASSED

| Item | Status |
|------|--------|
| R/curation.R exists | FOUND |
| R/consensus.R exists | FOUND |
| tests/testthat/test-enrichment.R exists | FOUND |
| tests/testthat/test-consensus.R exists | FOUND |
| .planning/phases/49-conflict-scoring-engine/49-01-SUMMARY.md exists | FOUND |
| commit b2a4bd5 (Task 1) | FOUND |
| commit 75e0ff2 (Task 2) | FOUND |
