# Phase 4: Consensus Logic - Context

**Gathered:** 2026-02-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Row-level DTXSID consensus comparison across all tagged columns with conflict resolution controls. Takes Phase 3's lookup results (one DTXSID per column per row) and classifies rows, then lets users resolve conflicts via inline dropdowns and priority-chain en masse preference.

</domain>

<decisions>
## Implementation Decisions

### Classification Rules
- Each row gets exactly one DTXSID per tagged column from Phase 3 (multiple hits per column = data error, not a resolution case)
- **agree**: All tagged columns returned the same DTXSID
- **agree (with caveat)**: Some columns returned a DTXSID and agreed, but other columns were unmatched — flag that not all columns were verified
- **disagree**: Two or more columns returned different DTXSIDs — goes to resolution queue
- **single**: Only one tagged column returned a DTXSID — informational only, auto-accepted as consensus, no user action needed
- **error**: All tagged columns failed to return any DTXSID — complete miss
- Just flag disagree status; individual column results are visible in per-column DTXSID columns (no need to duplicate which columns disagree in the status)

### QC Tier System
- Numeric QC case scaled to K (number of tagged columns)
- Case 1 = all K agree (perfect consensus), incrementing through partial/disagree combinations, Case K-1 = total disagreement, Case K = no data (error)
- Disagreements rank worse than unmatched columns (active conflict > missing data)
- QC tier is a metadata column alongside status labels — both coexist
- Status labels for quick scanning, QC tier for precise sorting/filtering

### Resolution Interaction
- **Per-row**: Inline dropdown in the results table showing only columns that have data (hide unmatched columns)
- **En masse**: Priority chain — user sets ranked column preference order (e.g., CAS > Name > Formula), auto-applies to all disagreement rows based on availability
- Per-row overrides stick — once a user explicitly overrides a row, en masse changes don't touch it (pinned rows)
- Single-source rows are informational only — no user action required

### Output Structure
- Consensus DTXSID column (empty for unresolved disagree rows until user resolves)
- Status label (agree/agree-caveat/disagree/single/error) + numeric QC tier
- Source column indicating which tagged column the consensus DTXSID came from (or 'consensus' if all agreed)
- Per-column DTXSID columns (e.g., dtxsid_cas, dtxsid_name) showing what each column resolved to
- Search tier metadata from Phase 3 (exact/starts-with/CAS) included alongside per-column DTXSIDs
- Full metadata exported — original data + all consensus columns for complete audit trail

### Claude's Discretion
- Exact QC tier formula/numbering scheme (as long as it follows the ranking: all-agree best, disagree worse than unmatched, error worst)
- How the priority chain UI is presented (drag-and-drop vs numbered dropdowns)
- How "pinned" per-row overrides are visually indicated
- Internal data structures for tracking resolution state

</decisions>

<specifics>
## Specific Ideas

- Each lookup should return at most one DTXSID per column per row — multiple hits indicates a data issue upstream
- The inline dropdown for resolution should dynamically show only columns with actual data for that row
- Priority chain for en masse: user ranks columns in preference order, system fills consensus DTXSID based on availability per that ranking
- User wants a clear extension point in the pipeline for custom cleaning functions — currently noted as a Phase 3 enhancement (post-dedup, pre-API hook)

</specifics>

<deferred>
## Deferred Ideas

- **Pre-API cleaning hook** (Phase 3 enhancement): Extension point post-deduplication but before API requests are sent, where user-written cleaning functions can transform values. Add `#NOTE` comment block in Phase 3 pipeline code as placeholder for later.
- **Auto-resolution rules** (v2 - CONS-05): e.g., always prefer CAS over name when CAS is valid
- **Resolution audit trail** (v2 - CONS-06): tracking who picked which column

</deferred>

---

*Phase: 04-consensus-logic*
*Context gathered: 2026-02-27*
