# Phase 5: Shiny Integration - Context

**Gathered:** 2026-02-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Production-ready pipeline orchestration integrated into Shiny app. Replaces old R/curation.R with the prototype pipeline (dedup -> tiered search -> CAS validation) and consensus logic (classify + resolve). Wires consensus display and conflict resolution controls into the Review Results tab. The full workflow (upload -> tag -> curate -> resolve -> export) must work end-to-end without errors.

</domain>

<decisions>
## Implementation Decisions

### Curation Progress UX
- Step-by-step status text updates as each pipeline tier completes
- Show counts at each stage (e.g., "Exact match: 37/42 found, 5 falling back...")
- Progress text appears below the Start Curation button, inline on the tab
- Start Curation button disabled during pipeline run (no cancel button needed)

### Consensus Results Display
- Both color-coded row backgrounds AND status badge column in the results table
  - Green for agree, yellow for agree_caveat, red for disagree, gray for single/error
  - Colored badges in a dedicated status column
- DT built-in column dropdown filter on consensus_status is sufficient (no extra filter buttons)
- Consensus-focused value boxes above table: Agree count, Disagree count, Needs Review count, overall match rate
- Condensed default view: show original values, consensus_dtxsid, consensus_status, qc_tier
  - Per-column detail (dtxsid per tagged column, source_tier, rank) available in export but hidden from default table view

### Conflict Resolution UX
- Per-row resolution: inline dropdown in a "Resolution" column for disagree rows
  - Dropdown shows available DTXSIDs by source column name
  - Row updates immediately on selection
- En masse resolution: priority controls above the results table
  - Tagged columns listed with up/down buttons to set priority order
  - "Apply Priority" button resolves all non-pinned disagree rows
- Pinned rows are sacred: individual per-row picks persist even if en masse priority is re-applied
- Pin icon/badge indicator on manually resolved rows to distinguish from auto-resolved

### Pipeline Wiring
- Old R/curation.R replaced entirely with new orchestration function
- Migrate needed functions from R/prototype_pipeline.R into new R/curation.R (keep prototype_pipeline.R as historical reference)
- Run Curation tab shows dedup preview after tags are applied (e.g., "42 unique names, 15 unique CAS to look up") before user hits Start
- Deduplication runs immediately when tags are applied to generate the preview counts
- Full export: original data + per-column DTXSID results + consensus status + resolution choices + QC tier (full audit trail)

### Claude's Discretion
- Exact color shades for row tinting (subtle enough to not overwhelm, distinct enough to scan)
- Pin icon choice (Bootstrap icon from bsicons)
- Priority reordering implementation (sortable.js vs simple up/down buttons)
- How to structure the new curation.R orchestrator function signature
- Reactive data flow design for resolution state management in Shiny

</decisions>

<specifics>
## Specific Ideas

- Dedup preview gives users a sense of scale before committing to API calls
- Condensed table view keeps the default readable; full detail goes in the Excel export
- Status text with counts builds user confidence during the wait ("I can see it's working and finding things")

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 05-shiny-integration*
*Context gathered: 2026-02-27*
