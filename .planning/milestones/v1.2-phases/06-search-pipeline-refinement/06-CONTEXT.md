# Phase 6: Search Pipeline Refinement - Context

**Gathered:** 2026-03-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Improve curation accuracy by reordering search tiers (exact → CAS → starts-with) and enabling "Other" tagged columns to participate in CompTox search and consensus classification. Does not add new search types (molecular formula, mass) or change the UI layout — only pipeline behavior and a Match Type column.

</domain>

<decisions>
## Implementation Decisions

### "Other" Tag Behavior
- Treat "Other" column values as chemical names (search as Name type)
- Run full tier chain on Other values: exact → CAS → starts-with
- Multiple columns can be tagged as "Other" — each searched independently
- Other column misses handled identically to Name/CASRN misses (same error/unresolved status)
- Other column DTXSID results get equal vote weight in consensus classification

### Tier Reorder
- New order: exact → CAS → starts-with (CAS moves from tier 3 to tier 2)
- No migration or backward-compatibility handling — new order is strictly better
- All exact-miss values flow through CAS tier regardless of format (the CAS function already coerces and handles non-CAS values gracefully)
- Starts-with tier (now last resort) gets a 3-character minimum length filter — values shorter than 3 chars skip starts-with to avoid overly broad matches

### Search Feedback & Transparency
- Add a "Match Type" column to the results table showing which tier resolved each row
- Use friendly labels: "Exact Match", "CAS Lookup", "Starts-With", "No Match"
- Search summary (count breakdown by tier) shown as transient notification after search completes
- Match Type column shows tier only, not which tagged column produced the match

### Claude's Discretion
- Exact column placement of Match Type in results table
- Notification styling and duration for search summary
- Internal refactoring approach for tier reorder in `run_tiered_search()`

</decisions>

<specifics>
## Specific Ideas

- CAS tier should run on all misses without pre-filtering — the existing function coerces everything and handles non-CAS values gracefully, so no regex gate needed
- "Other" tag type treated as Name is a v1 approach — future iterations may add molecular formula, mass, and other search types as additional tier strategies

</specifics>

<deferred>
## Deferred Ideas

- Molecular formula search via Other columns — future phase (user mentioned having access to formula/mass searches)
- Mass-based search capability — future phase
- Badge/pill visual indicators for match tier — could replace or supplement the column approach later
- Persistent summary bar instead of notification — if users want always-visible tier breakdown

</deferred>

---

*Phase: 06-search-pipeline-refinement*
*Context gathered: 2026-03-01*
