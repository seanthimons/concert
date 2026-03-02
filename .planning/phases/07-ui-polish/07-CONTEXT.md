# Phase 7: UI Polish - Context

**Gathered:** 2026-03-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Reduce cognitive load in the Review Results table and provide richer context for curation decisions. Covers: column visibility defaults, colvis toggle, resolution dropdown improvements, error row flagging, match type filtering with badges, and Excel export flagging. Does NOT add new curation capabilities — those are Phase 8.

</domain>

<decisions>
## Implementation Decisions

### Column Visibility Defaults
- Hide untagged data columns by default — users don't need to see columns they didn't tag
- Keep internal pipeline columns visible (source_tier_*, rank_*, preferredName_* per tag) — users need this info to make resolution decisions
- Add DT Buttons colvis toggle so users can show/hide untagged columns on demand
- Pipeline internal columns (source_tier_*, rank_*, searchName_*) stay permanently hidden from colvis — not useful for decision-making
- Excel export includes ALL columns (untagged, tagged, consensus, pipeline internals) — full data preservation

### Resolution Dropdown Context
- Dropdown options show: `DTXSID — preferredName` (no rank or QC level)
- Options sorted by rank (best match first, lowest rank number)
- Agree rows display static text (`DTXSID — Name` with checkmark), no dropdown
- Disagree rows include a "None" option for cases where user doesn't trust any result

### Error Row Flagging
- "Error" defined strictly as No Match rows (all tiers failed)
- Visual indicator: light red/pink row background highlight in Review Results table
- Excel export: dedicated `needs_review` column (TRUE/FALSE) — machine-readable, filterable
- Only No Match rows flagged in Excel — disagree rows are not flagged (they have DTXSIDs, just need user choice)

### Match Type Filtering & Badges
- match_type column gets DT column filter dropdown with choices: Exact Match, CAS Lookup, Starts-With, No Match
- match_type values displayed as color-coded badges: green (Exact), blue (CAS), yellow (Starts-With), red (No Match)
- consensus_status column also gets color-coded badges: green (agree), orange (disagree), gray (single)
- consensus_status column also gets DT column filter dropdown (agree/disagree/single)
- Both columns use consistent badge visual language

### Claude's Discretion
- Exact badge styling (border-radius, padding, font weight)
- DT filter implementation details (initComplete callback vs column-specific options)
- Row highlight CSS specificity and color values
- ColVis button placement and label text

</decisions>

<specifics>
## Specific Ideas

- Match type badge colors should match semantic meaning: green=good (exact), blue=info (CAS), yellow=caution (fuzzy), red=error (no match)
- Error row highlight should be subtle enough not to overwhelm but immediately scannable
- "None" option in disagree dropdown allows users to explicitly defer a row rather than being forced to pick a bad match

</specifics>

<deferred>
## Deferred Ideas

- Match type dropdown filtering was noted during Phase 6 UAT — now captured as part of this phase
- Future: allow filtering/sorting by multiple columns simultaneously (beyond single column filters)

</deferred>

---

*Phase: 07-ui-polish*
*Context gathered: 2026-03-01*
