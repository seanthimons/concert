# Phase 44: Matching Engine + Prototype - Context

**Gathered:** 2026-05-05
**Status:** Ready for planning

<domain>
## Phase Boundary

The three-tier WQX matcher is validated against real training data before any pipeline wiring. This phase delivers the matching engine function and a standalone prototype script that proves it works. No Shiny integration, no pipeline wiring — those belong to Phase 45.

</domain>

<decisions>
## Implementation Decisions

### Fuzzy Matching Strategy
- **D-01:** Use Jaro-Winkler distance metric via `stringdist` package (new dependency). Best for name-like strings — weighs prefix matches heavily, well-suited to chemical names.
- **D-02:** Fixed acceptance threshold with `threshold` parameter defaulting to 0.85. Matches below threshold are rejected (returned as unresolved with nearest candidate + distance shown).
- **D-03:** `stringdist` must be added to DESCRIPTION Imports.

### Console Logging
- **D-04:** Add `cli` package as a new DESCRIPTION Import. Provides styled console output (colors, symbols) for match reporting.
- **D-05:** Default to summary-only logging (X exact, Y alias, Z fuzzy, W unresolved). Per-name verbose logging via `verbose = TRUE` parameter. Scales to production datasets without noise.

### Match Result Structure
- **D-06:** Function signature: `match_wqx(names, dictionary, threshold = 0.85, verbose = FALSE)` — accepts a character vector, returns a tibble.
- **D-07:** Return tibble columns per input name: `input_name`, `wqx_name` (canonical match or NA), `match_tier` (exact/alias/fuzzy/none), `match_distance` (NA for exact/alias, numeric for fuzzy), `alias_type` (synonym/standardize/retired or NA for non-alias matches).

### Search Performance
- **D-08:** Pre-build hash lookup structures (named vectors or environments) for tiers 1 and 2 at dictionary load time. Exact canonical and alias lookups are O(1) per name. Fuzzy tier (O(n×k) against ~13,800 canonical names) only runs on the unresolved remainder after tiers 1-2.

### Prototype Script
- **D-09:** Standalone script at `scripts/prototype_wqx_matching.R` — consistent with existing `scripts/benchmark_pipeline.R` and `scripts/build_wqx_dictionary.R`.
- **D-10:** Runs against `detections_uat_sample_50.csv` (50-row sample only). Prints accuracy report: tier breakdown (N exact, N alias, N fuzzy, N unresolved), fuzzy matches with distances for manual review.

### Claude's Discretion
- Internal hash structure choice (named character vector vs R environment vs data.table keyed join)
- How to handle NA/empty input names (skip silently or include in results with tier="none")
- Whether to tolower() input names once upfront or at each tier
- Test file organization and test case design

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 43 Dictionary (Dependency)
- `.planning/phases/43-wqx-dictionary/43-CONTEXT.md` — Dictionary structure decisions (D-01 through D-05), column schema, alias type parsing
- `R/cleaning_reference.R` lines 519-630 — `.build_wqx_dictionary()`, `load_wqx_dictionary()`, `refresh_wqx_cache()` implementations

### Requirements
- `.planning/REQUIREMENTS.md` §Matching — MATCH-01 through MATCH-04
- `.planning/REQUIREMENTS.md` §Integration — INTG-01 (prototype script)

### Training Data
- `detections_uat_sample_50.csv` — 50-row training dataset with `analyte` column containing names to match

### Existing Patterns
- `R/curation.R` — Tiered search pattern (exact → CAS → starts-with) for reference on multi-tier matching architecture
- `R/cleaning_reference.R` — `load_or_fetch_reference()` cache pattern and all existing loaders

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `load_wqx_dictionary(cache_dir)`: Returns combined tibble with ~13,800 canonical + ~145K alias rows. Columns: `name`, `canonical_name`, `cas_number`, `group_name`, `description`, `type`
- `inst/extdata/reference_cache/wqx_dictionary.rds`: Pre-built dictionary, ships with package
- `detections_uat_sample_50.csv`: Training data with `analyte` column

### Established Patterns
- Multi-tier search in `R/curation.R`: exact → CAS → starts-with. Same escalation pattern applies here (exact → alias → fuzzy)
- All R/ functions use explicit namespace prefixes (`dplyr::`, `stringr::`, etc.)
- Return structure: named lists or tibbles — `match_wqx()` follows the tibble pattern

### Integration Points
- New `R/wqx_matching.R` file for `match_wqx()` function (or added to `R/cleaning_reference.R`)
- New `scripts/prototype_wqx_matching.R` for standalone validation
- Phase 45 will call `match_wqx()` from within the curation pipeline for CompTox-failed names

</code_context>

<specifics>
## Specific Ideas

- Dictionary `type` column values: "canonical", "synonym", "standardize", "retired" — tiers 1 and 2 filter on these
- Tier 1 matches rows where `type == "canonical"` by `name` (case-insensitive)
- Tier 2 matches rows where `type %in% c("synonym", "standardize", "retired")` by `name`, resolves to `canonical_name`
- Tier 3 fuzzy matches only against canonical rows (~13,800 names), not the full 145K alias table
- `alias_type` in results captures which alias type resolved the match (useful for understanding match quality)

</specifics>

<deferred>
## Deferred Ideas

- Benchmarking fuzzy tier performance at scale (10K+ names) — defer to Phase 45 if performance issues arise
- Threshold tuning based on larger datasets — prototype uses default 0.85, adjust after real-world testing

</deferred>

---

*Phase: 44-matching-engine-prototype*
*Context gathered: 2026-05-05*
