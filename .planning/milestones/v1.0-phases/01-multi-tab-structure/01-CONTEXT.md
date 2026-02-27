# Phase 1: Multi-Tab Structure - Context

**Gathered:** 2026-02-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Extract the current stacked curation cards (Tag Columns, Run Curation, Review Results) into 3 separate top-level tabs with full-width layouts. The existing upload/detection tabs remain. Gated visibility is Phase 2 — all tabs are visible in this phase.

</domain>

<decisions>
## Implementation Decisions

### Tag Columns Layout
- Table-based interface: one row per uploaded column, with a dropdown to assign type (Chemical Name, CASRN, Other)
- Show column names only — no data preview/sample values in the tagging table
- Apply Tags button positioned top-right in a header area above the table
- Empty state: centered message with icon ("Upload a file to start tagging columns")

### Curation Feedback
- Spinner with status text during CompTox lookup (CompTox outputs to console — capture and display)
- Pre-curation summary shows which columns are tagged as what (e.g., "Chemical Name: column_a, CASRN: column_b")
- Start Curation button disabled until prerequisites are met (grayed out with tooltip)
- After curation completes, auto-navigate to Review Results tab

### Review Results Layout
- Value boxes row at top using bslib value_box() for statistics (CAS validated, names matched, etc.)
- Focused results table showing: user's original input (submitted name, submitted CASRN) alongside CompTox output (preferred name, CASRN, DTXSID)
- Match status visual treatment deferred — depends on curation pipeline design (not in scope for this phase)
- Download Excel button positioned top-right above the results table

### Tab Visual Design
- Icons + labels on all tabs (using bsicons)
- Single tab bar containing both existing tabs (Data Preview, Detection Info, Raw Data) and new curation tabs
- Full-stretch content width (100% of available space, no max-width container)
- Sidebar hidden on curation tabs (Tag Columns, Run Curation, Review Results) for maximum space; sidebar visible on upload/detection tabs

### Claude's Discretion
- Specific bsicons icon choices for each tab
- Spacing, padding, and typography within tabs
- Sidebar show/hide implementation approach
- Loading skeleton or transition animations between tabs
- Exact tooltip text for disabled Start Curation button

</decisions>

<specifics>
## Specific Ideas

- Action buttons (Apply Tags, Download Excel) consistently placed top-right across all curation tabs
- CompTox console output captured as spinner status text during lookup
- Results table intentionally narrow: only preferred name + CASRN + DTXSID from CompTox, paired with user's original input — supports future curation workflow

</specifics>

<deferred>
## Deferred Ideas

- Match status row highlighting (matched vs unmatched) — depends on curation pipeline design, not this phase
- Gated tab visibility (tabs hidden until prerequisites met) — Phase 2
- Progress indicators showing workflow step numbers — v2 requirements (PROG-01, PROG-02)

</deferred>

---

*Phase: 01-multi-tab-structure*
*Context gathered: 2026-02-26*
