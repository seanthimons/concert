# Phase 17: Enrichment Pipeline - Context

**Gathered:** 2026-03-11
**Status:** Ready for planning

<domain>
## Phase Boundary

After curation completes, enrich disagreement candidate DTXSIDs with CASRN, molecular formula, and molecular weight via CompTox API (`ct_details`). Extend `get_resolution_options()` with source attribution and enrichment metadata. Add enrichment columns to export. The comparison modal UI is Phase 18 — this phase is data/API only.

</domain>

<decisions>
## Implementation Decisions

### Cache & Triggering
- Enrichment fires automatically after `run_curation_pipeline` completes and disagree rows exist — no user action needed
- Cache stored as `data_store$enrichment_cache` — a tibble with one row per DTXSID (columns: dtxsid, casrn, molecular_formula, molecular_weight)
- Incremental caching on re-curation: only fetch DTXSIDs not already in the cache
- Show progress notification during enrichment (e.g., "Enriching 12 candidates...") and completion notification

### Source Attribution
- Derive source_column from the column suffix (e.g., `dtxsid_chemical_name` → source_column = "chemical_name") — no new storage needed
- Extend `get_resolution_options()` to return source_tier and enrichment metadata (casrn, formula, mw) alongside existing dtxsid/preferredName/rank
- Pass enrichment_cache as an explicit parameter to `get_resolution_options()` — no hidden state
- Display source_tier as human-readable labels: "Exact match", "CAS lookup", "Starts-with", "No match"

### Export Columns
- Add consensus_casrn, consensus_formula, consensus_mw to the Curated Data export sheet only
- Columns appended at the end of the export (after existing columns)
- All resolved rows get enrichment data — not just disagree rows
- Make an additional API call to enrich agree/single consensus DTXSIDs too (one extra call covers everything)

### API Failure Handling
- Total failure (API down, no key): warn via notification and continue — curation results still work, enrichment columns show NA in export
- Partial failure: cache successful results, store list of failed DTXSIDs for transparency
- No retry mechanism — re-running curation triggers incremental enrichment which re-attempts failed DTXSIDs

### Claude's Discretion
- Notification detail level for failed DTXSIDs (count vs specific IDs)
- Exact enrichment notification wording and duration
- Whether to batch DTXSID API calls or send all at once
- Internal error logging format

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `enrich_candidates()` in R/curation.R:736 — already calls `ComptoxR::ct_details` with configurable projection, returns raw tibble + queried DTXSIDs. Needs refactoring to return structured cache tibble instead of raw API response.
- `get_resolution_options()` in R/consensus.R:156 — returns dtxsid/preferredName/rank per column. Needs extension for source_tier + enrichment metadata.
- `source_tier_*` columns — already exist in mapped dataframe from `run_tiered_search()`. Values: "exact", "cas", "starts_with", "miss".
- `build_export_sheets()` in R/export_helpers.R — builds 7-sheet Excel export. Needs consensus_casrn/formula/mw columns added to Curated Data sheet.

### Established Patterns
- `purrr::safely()` wrapping for API calls (used throughout curation.R)
- `data_store` reactiveValues for state management (raw, clean, resolution_state, etc.)
- `showNotification()` for user feedback during long operations
- Progress callbacks in `run_curation_pipeline()` for stage-by-stage feedback

### Integration Points
- `run_curation_pipeline()` return value — enrichment should fire after this returns and disagree rows exist
- `data_store$enrichment_cache` — new reactive value, consumed by `get_resolution_options()` and `build_export_sheets()`
- `mod_review_results` server — calls `get_resolution_options()` when rendering disagree row dropdowns
- `mod_run_curation` server — where curation pipeline is triggered, enrichment should integrate here

</code_context>

<specifics>
## Specific Ideas

- Enrich ALL resolved rows for export (not just disagree) — agree/single consensus DTXSIDs also get a ct_details call
- The enrichment cache tibble should be the single source of truth for CASRN/formula/MW lookups across the app
- Failed DTXSIDs should be tracked so Phase 18 modal can show "Enrichment unavailable" vs empty fields

</specifics>

<deferred>
## Deferred Ideas

- Enrichment for non-disagree rows during curation (lower priority per REQUIREMENTS.md Future Requirements)
- Link to CompTox Dashboard page per candidate (Future Requirement)
- Molecular structure image display (Future Requirement)

</deferred>

---

*Phase: 17-enrichment-pipeline*
*Context gathered: 2026-03-11*
