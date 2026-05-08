---
phase: 49-conflict-scoring-engine
verified: 2026-05-08T14:00:00Z
status: human_needed
score: 4/4
overrides_applied: 0
gaps:
  - truth: "Score computation runs without additional API calls (uses data already fetched during enrichment)"
    status: resolved
    reason: "NAMESPACE regenerated via devtools::document() — all three functions now exported. Fixed in commit 4b488a3."
    artifacts:
      - path: "NAMESPACE"
        issue: "Missing export() entries for enrich_synonyms, score_one_candidate, and compute_similarity_scores — @export tags exist in source but document() was never run"
    missing:
      - "Run devtools::document() to regenerate NAMESPACE, then verify all three functions appear in export() list"
human_verification:
  - test: "Upload a test file that produces disagree rows and run curation"
    expected: "Console shows [synonyms] fetch messages; Review Results table shows 'Sim. Score' column with 2-decimal values for disagree rows and blank for agree/single rows; Clicking a disagree row shows modal cards with blue bg-info badge showing per-candidate JW score; Exported file contains similarity_score column"
    why_human: "Visual column rendering, modal badge appearance, and export file contents cannot be verified programmatically without a running Shiny session and real data upload"
---

# Phase 49: Conflict Scoring Engine — Verification Report

**Phase Goal:** Users can see a similarity score for each candidate in disagree rows, computed from CompTox synonym lists and rank data
**Verified:** 2026-05-08T14:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Prototype produces a numeric similarity score (0-1) for each candidate name against the input string for a known disagree row | VERIFIED | `score_one_candidate()` in R/consensus.R (line 276) implements max-JW formula with rank bonus; `compute_similarity_scores()` (line 313) iterates disagree rows and writes `similarity_score` column; 10 unit tests pass covering exact match, dissimilar name, rank bonus, clamp, NA cases |
| 2 | Scoring uses CompTox synonym list and rank data — lower-rank synonyms and closer JW distance produce higher scores | VERIFIED | `enrich_synonyms()` fetches all synonym tiers via `ct_chemical_synonym_search_bulk()` and stores pipe-joined string in `enrichment_cache$synonyms`; `score_one_candidate()` splits on `\|` and computes `1 - stringdist::stringdist(..., method="jw")` over full name vector; rank bonus of +0.05 applied when `rank <= 3`; result clamped to [0,1] |
| 3 | Review Results table shows a similarity score column for disagree rows, blank for agree/single rows | VERIFIED | R/mod_review_results.R line 791: `if ("similarity_score" %in% names(df_display))` presence gate; colDef at line 792: `name = "Sim. Score"`, `minWidth = 80`, `align = "right"`, `formatC(value, digits = 2, format = "f")`; cell renders `""` for `is.na(value)` (non-disagree rows have `NA_real_`); `compute_similarity_scores()` only writes numeric values for `consensus_status == "disagree"` rows |
| 4 | Score computation runs without additional API calls (uses data already fetched during enrichment) | FAILED | NAMESPACE not regenerated: `enrich_synonyms`, `score_one_candidate`, and `compute_similarity_scores` are absent from NAMESPACE despite `@export` tags in source. The package will not build from source without running `devtools::document()`. Functions work under `devtools::load_all()` (development mode) but are not formally exported. |

**Score:** 3/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `R/curation.R` | `enrich_synonyms()` and `flatten_synonym_tiers()` | VERIFIED | Both functions present at lines 1074 and 1105; `enrich_synonyms` has `@export` tag; `flatten_synonym_tiers` has `@noRd`; implements incremental caching pattern mirroring `enrich_candidates()` |
| `R/consensus.R` | `compute_similarity_scores()` and `score_one_candidate()` | VERIFIED | Both present at lines 276 and 313; both have `@export` tags; `stringdist::stringdist(..., method = "jw")` at line 289; `min(1.0, base_score + bonus)` at line 293 |
| `R/mod_run_curation.R` | Synonym fetch + score computation wiring after enrichment | VERIFIED | `enrich_synonyms()` call at lines 258-262 inside existing tryCatch; `compute_similarity_scores()` call at lines 271-276 with guard checks; `data_store$enrichment_cache <- synonym_result$cache` at line 262; `data_store$resolution_state <- compute_similarity_scores(` at line 271 |
| `R/mod_review_results.R` | Sim. Score colDef and modal per-candidate score badges | VERIFIED | `col_defs[["similarity_score"]]` at line 792; `name = "Sim. Score"` at line 793; presence gate at line 791; `score_one_candidate(` at line 1250 in modal card builder; `class = "badge bg-info"` at line 1273; `sprintf("%.2f", candidate_sim_score)` at line 1275 |
| `R/export_helpers.R` | similarity_score flows through export | VERIFIED | Comment at line 45 confirms `similarity_score` is not in `select(-tidyselect::any_of(...))` exclusion list; flows through to Curated Data sheet automatically |
| `tests/testthat/test-enrichment.R` | enrich_synonyms() unit tests with mocked ComptoxR | VERIFIED | 5 new tests in Test Group 7; `local_mocked_bindings(ct_chemical_synonym_search_bulk = ...)` used throughout; covers: synonyms column presence, NA for 0-row API response, merge into existing cache, skip cached DTXSIDs, API failure handling |
| `tests/testthat/test-consensus.R` | compute_similarity_scores() and score_one_candidate() unit tests | VERIFIED | 10 new tests (6 score_one_candidate + 4 compute_similarity_scores); covers: exact match ≥ 0.95, dissimilar name < 0.5, rank bonus exactly +0.05, clamp to 1.0, NA propagation, disagree-only scoring, best candidate selection, missing synonyms fallback, no Name-tagged column |
| `NAMESPACE` | export entries for new functions | FAILED | `enrich_synonyms`, `score_one_candidate`, `compute_similarity_scores` absent; `enrich_candidates` and all prior functions from same files ARE present, confirming `devtools::document()` was not re-run after Phase 49 additions |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `R/consensus.R` | `R/curation.R` | `enrichment_cache$synonyms` consumed by `compute_similarity_scores()` | VERIFIED | Line 333-335: `has_synonyms` checks `"synonyms" %in% names(enrichment_cache)`; line 339: `stats::setNames(enrichment_cache$synonyms, enrichment_cache$dtxsid)` builds O(1) lookup |
| `R/consensus.R` | `stringdist` package | `stringdist::stringdist(..., method = "jw")` | VERIFIED | Line 289: `sims <- 1 - stringdist::stringdist(tolower(input_name), tolower(all_names), method = "jw")` |
| `R/mod_run_curation.R` | `R/curation.R` | `enrich_synonyms()` call after `enrich_candidates()` | VERIFIED | Lines 257-263: synonym fetch block inside enrichment tryCatch; assigns result back to `data_store$enrichment_cache` |
| `R/mod_run_curation.R` | `R/consensus.R` | `compute_similarity_scores()` call after synonym fetch | VERIFIED | Lines 265-276: scoring block with NULL guards; reads `data_store$resolution_state`, `data_store$dtxsid_cols`, `data_store$column_tags` |
| `R/mod_review_results.R` | `R/consensus.R` | `score_one_candidate()` called in modal card builder | VERIFIED | Lines 1247-1255: `candidate_sim_score <- score_one_candidate(input_name, pref_name, synonyms_str, rank_val)`; precomputed `modal_synonym_map` (O(1) named vector) outside lapply |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `R/mod_review_results.R` (table) | `df_display$similarity_score` | `data_store$resolution_state$similarity_score` written by `compute_similarity_scores()` | Yes — numeric JW score derived from live API data in enrichment cache | FLOWING |
| `R/mod_review_results.R` (modal) | `candidate_sim_score` | `score_one_candidate()` called with `modal_synonym_map[opt$dtxsid]` from `data_store$enrichment_cache` | Yes — reads from synonym cache populated by `enrich_synonyms()` at curation time | FLOWING |
| `R/export_helpers.R` | `curated_data_sheet$similarity_score` | `resolution_state` passed directly; `similarity_score` not excluded by `select(-any_of(...))` | Yes — passthrough confirmed at line 45-46 | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| score_one_candidate() is callable | `node -e` check not applicable; verified via grep | Function body present at line 276, uses `stringdist::stringdist` | PASS |
| compute_similarity_scores() only scores disagree rows | Source review | `disagree_idx <- which(resolution_state$consensus_status == "disagree")` at line 326; non-disagree remain `NA_real_` | PASS |
| enrich_synonyms() skips already-cached DTXSIDs | Test coverage | Test "enrich_synonyms skips already-cached DTXSIDs" verifies via call_args capture | PASS |
| Score clamped to [0,1] | Source review | `min(1.0, base_score + bonus)` at line 293 | PASS |
| devtools::load_all() succeeds | SUMMARY-02 confirms | "load_all OK" message verified; 2118 tests passing, 3 pre-existing failures | PASS |
| NAMESPACE exports new functions | NAMESPACE file | enrich_synonyms, score_one_candidate, compute_similarity_scores absent | FAIL |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| SCORE-01 | 49-01, 49-02 | User can see a similarity score between original input and each candidate name in disagree rows | PARTIAL | Scoring engine built and wired; Sim. Score column present in Review Results; NAMESPACE regeneration needed for full package integrity; visual confirmation needed |
| SCORE-02 | 49-01, 49-02 | Similarity scoring incorporates CompTox synonym lists and rank data to weight candidates | VERIFIED | `enrich_synonyms()` fetches synonym tiers; `score_one_candidate()` uses JW distance over all synonyms + preferredName + rank bonus for rank ≤ 3 |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `NAMESPACE` | — | Missing export() entries for 3 new exported functions | Warning | Functions callable via `load_all()` in development; package will fail `R CMD CHECK` and formal build without `devtools::document()` |

### Human Verification Required

#### 1. End-to-End Scoring Visual Verification

**Test:** Upload a test file that produces disagree rows. Run curation. Open Review Results tab.
**Expected:** "Sim. Score" column visible in table; disagree rows show 2-decimal numeric values (e.g., "0.87"); agree and single rows show blank (empty cell); clicking a disagree row opens modal with blue "0.XX" badge on each candidate card next to the Select button; exporting results produces a file containing a `similarity_score` column.
**Why human:** Column rendering, badge visibility, and export file contents require a running Shiny session with real data. Automated checks verified all code paths but cannot substitute for visual confirmation of the UI layout and formatted display.

### Gaps Summary

**One real gap identified:** NAMESPACE was not regenerated after adding the three new exported functions. All `@export` roxygen2 tags are in source, but `devtools::document()` was not run. This means:

- `enrich_synonyms`, `score_one_candidate`, and `compute_similarity_scores` do not appear in `NAMESPACE`
- The package passes `devtools::load_all()` (development mode bypasses NAMESPACE) but would fail `R CMD CHECK` or a clean package install
- Every other function from the same files that predates Phase 49 IS correctly exported in NAMESPACE, confirming this is a process gap (document() not run) not a code error

**Fix required:** Run `devtools::document()` from the project root and verify the three functions appear in NAMESPACE. This is a one-command fix.

**Human verification also needed** for the visual scoring display — automated checks confirm all code paths are present and wired, but the Review Results table Sim. Score column and modal badge rendering require a live Shiny session to confirm.

---

_Verified: 2026-05-08T14:00:00Z_
_Verifier: Claude (gsd-verifier)_
