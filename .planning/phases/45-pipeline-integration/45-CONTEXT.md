# Phase 45: Pipeline Integration - Context

**Gathered:** 2026-05-06
**Status:** Ready for planning

<domain>
## Phase Boundary

WQX matching fires automatically in the curation pipeline for names that failed CompTox. This phase wires the existing `match_wqx()` engine (Phase 44) into `run_curation_pipeline()` and `curate_headless()`. No new matching logic, no UI changes, no new dictionary work.

</domain>

<decisions>
## Implementation Decisions

### Pipeline Insertion Point
- **D-01:** WQX matching is a new tier inside `run_curation_pipeline()`, added after the starts-with tier and before consensus classification. The `final_missed` names (currently assigned `source_tier = "miss"`) become the input to `match_wqx()`. This keeps all search logic in one orchestrator.
- **D-02:** The WQX dictionary is loaded once at the start of the WQX tier via `load_wqx_dictionary()`. Dictionary loading uses the existing lazy cache pattern — no new loading infrastructure needed.

### Resolution Data Model
- **D-03:** WQX canonical name goes into the `preferredName` column — the same column CompTox results use. `dtxsid` stays `NA_character_` since WQX does not provide DTXSIDs. This satisfies INTG-02 (same output column as curated compound names).
- **D-04:** Rows resolved by WQX get `consensus_status = "wqx"` — a new value that distinguishes them from CompTox-resolved rows (agree/disagree/single/error). These rows skip DTXSID-based consensus classification since they have no DTXSID to compare.

### Source Tier Attribution
- **D-05:** WQX matches use split source_tier values mapping directly from `match_wqx()` match_tier: `wqx_exact`, `wqx_alias`, `wqx_fuzzy`. Names that fail all tiers including WQX retain `source_tier = "miss"`. This preserves match quality in the audit trail and is consistent with existing granularity (exact, cas, starts_with).

### Headless Pipeline
- **D-06:** `curate_headless()` requires no new arguments — WQX matching fires automatically inside `run_curation_pipeline()` which `curate_headless()` already calls. This satisfies INTG-04.

### Claude's Discretion
- How to convert `match_wqx()` tibble output into the `combined_results` format that `map_results_to_rows()` expects (searchValue, dtxsid, preferredName, searchName, rank, source_tier)
- Whether to pass `verbose = FALSE` or propagate a verbose flag from the pipeline
- How to handle the `progress_callback` reporting for the WQX tier
- Whether `final_missed` names need additional filtering before passing to `match_wqx()` (e.g., minimum length)
- Test organization and assertion design

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Dependencies
- `.planning/phases/43-wqx-dictionary/43-CONTEXT.md` — Dictionary structure (D-01 through D-05), column schema, alias type parsing
- `.planning/phases/44-matching-engine-prototype/44-CONTEXT.md` — Matching engine decisions (D-01 through D-10), function signature, return tibble schema

### Implementation Files
- `R/curation.R` lines 612-858 — `run_curation_pipeline()` orchestrator. WQX tier inserts after the starts-with tier (around line 730) and before consensus (line 812)
- `R/wqx_matching.R` — `match_wqx()` function to call. Returns tibble: input_name, wqx_name, match_tier, match_distance, alias_type
- `R/cleaning_reference.R` lines 519-630 — `load_wqx_dictionary()` for dictionary loading
- `R/curate_headless.R` line 176 — Where `run_curation_pipeline()` is called in the headless path
- `R/consensus.R` — `classify_consensus()` and `init_resolution_state()` — must handle new `"wqx"` consensus_status

### Requirements
- `.planning/REQUIREMENTS.md` §Integration — INTG-02, INTG-03, INTG-04

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `match_wqx(names, dictionary, threshold, verbose)`: Phase 44 engine, ready to call
- `load_wqx_dictionary(cache_dir)`: Returns combined tibble with ~13,800 canonical + ~145K alias rows
- `run_curation_pipeline()`: Existing tier pattern (exact → CAS → starts-with → miss) — WQX slots in before miss
- `map_results_to_rows()`: Maps search results back to original rows — WQX results must conform to its expected tibble schema

### Established Patterns
- Search tier results are tibbles with columns: searchValue, dtxsid, preferredName, searchName, rank, source_tier
- `final_missed` variable (line 731) holds names that failed all CompTox tiers — this becomes `match_wqx()` input
- `progress_callback("stage_name", message)` pattern for Shiny progress reporting
- `consensus_status` values: agree, disagree, agree_caveat, single, error — adding "wqx" as new value

### Integration Points
- `run_curation_pipeline()` around line 730: Insert WQX tier between starts-with results and miss-row creation
- `classify_consensus()` in `R/consensus.R`: Must either skip WQX rows or handle them as a special case
- `init_resolution_state()`: WQX rows need `resolved_dtxsid = NA`, `resolved_name = preferredName` (the WQX canonical name)
- `curate_headless()`: No changes needed — already calls `run_curation_pipeline()`
- Shiny `mod_run_curation.R` line 161: Also calls `run_curation_pipeline()` — gets WQX automatically

</code_context>

<specifics>
## Specific Ideas

- `match_wqx()` returns `match_tier` values: "exact", "alias", "fuzzy", "none". Map these to source_tier as: `paste0("wqx_", match_tier)` for resolved, keep "miss" for "none"
- The `searchValue` for WQX results is the original analyte name (same value that was in `final_missed`)
- `preferredName` for WQX results is the `wqx_name` from `match_wqx()` output
- `rank` can be NA or a synthetic value (e.g., 0) since WQX doesn't rank results
- `searchName` could be the WQX canonical name or NA

</specifics>

<deferred>
## Deferred Ideas

- Benchmarking fuzzy tier performance at scale (deferred from Phase 44 — revisit if performance issues arise)
- Threshold tuning based on larger datasets (Phase 44 deferred)
- Shiny UI surfacing of WQX match results (WFUT-03 — future requirement)

</deferred>

---

*Phase: 45-pipeline-integration*
*Context gathered: 2026-05-06*
