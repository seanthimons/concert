# Phase 49: Conflict Scoring Engine - Context

**Gathered:** 2026-05-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Compute a Jaro-Winkler-based similarity score for each candidate in disagree rows, incorporating CompTox synonym lists and rank data. Display scores in the Review Results table and comparison modal. No auto-resolution or flagging (those are Phases 50-51).

</domain>

<decisions>
## Implementation Decisions

### Synonym Data Sourcing
- **D-01:** Expand `enrich_candidates()` to also call `ct_chemical_synonym_search_bulk()` during enrichment. Synonym data is cached alongside CASRN/formula/MW in the enrichment cache. Score computation reads from cache only — no API calls at score time.
- **D-02:** `ct_chemical_synonym_search_bulk()` returns synonym tiers (valid, good, other, beilstein, alternate). All tiers are stored in the cache for potential future use, but scoring treats all synonyms equally.

### Score Formula
- **D-03:** Score formula: `score = max(JW(input, preferredName), JW(input, synonym_1), ..., JW(input, synonym_N))`. If candidate rank ≤ 3, add +0.05 bonus. Clamp final score to [0, 1].
- **D-04:** All synonym tiers treated equally for JW comparison — no tier-based weighting.

### Score Display
- **D-05:** New "Sim. Score" column in Review Results table, matching the existing WQX Conf. pattern: 2-decimal right-aligned format, blank for non-disagree rows.
- **D-06:** Table column shows the **best** candidate's score for that row. Individual per-candidate scores are shown in the existing comparison modal.

### Scoring Targets
- **D-07:** The input string is always the user's original chemical name from the row. Each candidate (regardless of whether it was found via Name or CAS column) is scored by comparing that name against the candidate's preferredName + all synonyms for that DTXSID.
- **D-08:** CAS-sourced candidates are scored the same way — the CAS resolves to a DTXSID with a preferredName, and the user's name is compared against that preferredName and its synonyms.

### Claude's Discretion
- Prototype script structure and test case selection
- Enrichment cache schema extension details (how synonym strings are stored)
- Whether to batch synonym fetches or fetch all at once
- Score function naming and file placement (new file vs. extending consensus.R)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Curation Pipeline
- `R/curation.R` §960-1010 — `enrich_candidates()` function (will be expanded with synonym fetch)
- `R/consensus.R` §190-258 — `get_resolution_options()` (provides per-candidate data for scoring)

### Review Results UI
- `R/mod_review_results.R` §765-788 — WQX Conf. column pattern (model for Sim. Score column)
- `R/mod_review_results.R` §1180, §1309 — enrichment_cache usage in resolution modal

### String Distance
- `R/wqx_matching.R` §101-120 — Existing Jaro-Winkler usage via `stringdist::stringdistmatrix()`
- `DESCRIPTION` — `stringdist` already listed as dependency

### CompToxR Synonym API
- `ct_chemical_synonym_search_bulk()` — Returns tibble with columns: dtxsid, valid, good, other, deleted, beilstein, alternate, pcCode. Coverage varies by DTXSID.

### Requirements
- `.planning/REQUIREMENTS.md` — SCORE-01 (similarity score visible), SCORE-02 (incorporates synonyms + rank)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `stringdist` package: Already a dependency, used in `R/wqx_matching.R` for Jaro-Winkler fuzzy matching
- `enrich_candidates()`: Incremental caching pattern — filters out already-cached DTXSIDs, fetches only new ones. Same pattern applies to synonym fetch.
- `get_resolution_options()`: Returns per-candidate metadata (dtxsid, preferredName, rank, source_column, enrichment data). Natural place to inject scores.
- WQX Conf. column: `reactable::colDef` with `formatC(value, digits = 2, format = "f")` — exact pattern to reuse for Sim. Score.

### Established Patterns
- Enrichment cache is a tibble stored on `data_store$enrichment_cache` (reactiveValues)
- Scores in table use `colDef` with NA → blank rendering and right-alignment
- `grep("^wqx_confidence", ...)` pattern for finding score columns across single/multi-tag modes — similar pattern needed for similarity score columns

### Integration Points
- `enrich_candidates()` in `R/curation.R` — expand to also fetch and cache synonyms
- `R/consensus.R` — new scoring function, called after enrichment, before Review Results render
- `R/mod_review_results.R` — add Sim. Score colDef, inject per-candidate scores into comparison modal
- `R/mod_run_curation.R` §229 — enrichment call site, synonym cache flows through here
- `R/export_helpers.R` — include similarity score in export output

</code_context>

<specifics>
## Specific Ideas

- CompToxR's `ct_chemical_synonym_search_bulk()` returns categorized synonyms (valid, good, other, beilstein). Store all categories but flatten for JW comparison.
- The `dss_synonyms()` function (local DSSTOX) returned empty results in testing — use the API bulk endpoint instead.
- Some DTXSIDs return no synonym data from the API (e.g., DTXSID7020006 for Acetone returned 0 rows). Score function must handle missing synonyms gracefully — fall back to preferredName-only comparison.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 49-conflict-scoring-engine*
*Context gathered: 2026-05-08*
