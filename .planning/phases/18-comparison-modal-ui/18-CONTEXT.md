# Phase 18: Comparison Modal UI - Context

**Gathered:** 2026-03-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can open a side-by-side comparison modal for any unresolved disagree row, see all candidates with enriched metadata, and resolve directly from the modal. The modal replaces the inline dropdown as the resolution mechanism for disagree rows. Existing bulk priority resolution remains available. Enrichment data comes from Phase 17's `enrichment_cache`.

</domain>

<decisions>
## Implementation Decisions

### Compare button placement
- Replace the resolution dropdown entirely for unresolved disagree rows — modal is the only per-row resolution path
- Button is icon + text: magnifying glass icon + "Compare" (styled as a small button in the Resolution cell)
- For already-pinned (resolved) disagree rows, show a "Change" link next to the pin icon to reopen the modal
- En masse priority "Apply Priority" button remains for bulk resolution — different use case from per-row modal

### Modal candidate layout
- Side-by-side vertical cards in a horizontally scrollable container
- Each card represents one candidate DTXSID
- Full metadata per card: DTXSID, preferredName, CASRN, molecular formula, molecular weight, source column, search tier, rank
- No difference highlighting between candidates — plain display, user compares by reading
- Missing enrichment data shows "N/A" for absent fields

### Row context in modal
- Modal title: "Compare Candidates" (no row number)
- Below the title, inline summary of original tagged column values: e.g., "chemical_name = 'Acetone', cas_number = '67-64-1'"
- Only tagged columns shown, not full row data

### Resolution flow inside modal
- Clicking "Select" on a card highlights that card visually (selected state)
- A "Confirm & Close" button appears after selection — user must click it to finalize
- Confirming pins the row, updates resolution_state, closes the modal, and shows a notification
- Notification includes DTXSID + preferredName: "Resolved: DTXSID0001 — Acetone"
- "Skip this row" button at the bottom of the modal — equivalent to old "None" dropdown option, pins the row without setting a DTXSID

### Claude's Discretion
- Card styling details (border, shadow, spacing, colors)
- Scrollable container CSS implementation
- Selected card highlight style (border color, background tint)
- "Confirm & Close" button positioning and styling
- "Change" link styling for pinned rows
- Modal size (large vs extra-large)

</decisions>

<specifics>
## Specific Ideas

- Replace the dropdown entirely rather than adding a Compare button alongside it — cleaner, forces users into the richer modal experience
- Two-step resolution (Select then Confirm) provides a safety net against accidental clicks
- "Change" link on pinned rows allows corrections without needing to undo/reset

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `get_resolution_options()` in `R/consensus.R:156-224`: Already returns all needed metadata (dtxsid, preferredName, rank, source_column, source_tier, casrn, molecular_formula, molecular_weight) — can be called directly from modal handler
- `resolve_row()` in `R/consensus.R:237-263`: Existing resolution logic that pins rows and sets consensus — reuse for modal resolution
- `init_resolution_state()` in `R/consensus.R:132-140`: Ensures `.pinned` column exists
- `recalc_consensus_summary()` in `mod_review_results.R:5-15`: Must be called after modal resolution to update value boxes
- `data_store$enrichment_cache`: Tibble with (dtxsid, casrn, molecular_formula, molecular_weight) — populated by Phase 17

### Established Patterns
- DT `escape=FALSE` + JS `Shiny.setInputValue` for inline interactive controls (Resolution column, line 26-33 of mod_review_results.R)
- `showModal(modalDialog(...))` pattern for complex dialogs (re-tag modal at line 999)
- Resolution handler at `observeEvent(input$resolve_row_choice, ...)` line 685 — similar pattern needed for modal resolution
- Column tag dropdown pattern in re-tag modal — modal content built from R with `tagList()`

### Integration Points
- Resolution column builder (`mod_review_results.R:311-406`): Must be modified to emit Compare button HTML instead of dropdown for unresolved disagree rows
- Pinned disagree display (`mod_review_results.R:333-349`): Must add "Change" link
- New JS handler needed for Compare button click → triggers `Shiny.setInputValue` with row index
- New `observeEvent` for modal resolution (parallel to existing `input$resolve_row_choice` handler)
- `recalc_consensus_summary()` call after modal resolution

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 18-comparison-modal-ui*
*Context gathered: 2026-03-11*
