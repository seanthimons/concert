# Phase 50: Auto-Resolve & Suggest - Context

**Gathered:** 2026-05-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Consume similarity scores (from Phase 49's `compute_similarity_scores()`) to auto-resolve clear mismatches and surface a ranked best-match suggestion for ambiguous disagree rows. Adds new consensus statuses (AUTO-RESOLVED, SUGGESTED), audit trail columns, bulk accept, and override/reject flows. No new scoring logic (that's Phase 49). No row flagging (that's Phase 51).

</domain>

<decisions>
## Implementation Decisions

### Resolution Thresholds
- **D-01:** Auto-resolve threshold: score >= 0.95 AND gap >= 0.15 between best and second-best candidate. Both conditions must be met.
- **D-02:** Suggestion threshold: score >= 0.70 (and below auto-resolve threshold, or gap < 0.15). Rows with best score < 0.70 remain plain DISAGREE with no suggestion.
- **D-03:** Gap requirement: best candidate score minus second-best candidate score must be >= 0.15 for auto-resolution. If gap < 0.15 (even with score >= 0.95), row gets SUGGESTED instead.

### Status Chips & Visual Treatment
- **D-04:** New consensus_status values: `"auto_resolved"` and `"suggested"`. These are filterable status chips in the Review Results table, following the existing ERROR/DISAGREE chip pattern.
- **D-05:** AUTO-RESOLVED chip visually distinct from manual agree/resolve (different color). SUGGESTED chip visually distinct from DISAGREE.
- **D-06:** Auto-resolved rows are visually distinguishable from manually resolved rows via the AUTO-RESOLVED chip and the `.resolution_method` column.

### Suggestion UX
- **D-07:** Suggestion detail and accept button live inside the comparison modal, not inline in the table. Table shows only the SUGGESTED status chip for filtering/scanning.
- **D-08:** Inside the modal, the suggested candidate is highlighted with an "Accept Suggestion" button. User can also pick any other candidate manually.
- **D-09:** "Accept All Suggestions" bulk button appears when SUGGESTED rows exist, following the `apply_priority_chain()` pattern. Resolves all SUGGESTED rows to their best-scoring candidate. Skips already-pinned rows.
- **D-10:** Bulk accept resolves ALL SUGGESTED rows regardless of individual score (the threshold decision was already made at classification time).

### Auto-Resolution Tracking (Audit Trail)
- **D-11:** New columns on resolution_state: `.resolution_method` ('auto'|'suggested-accept'|'bulk-accept'|'manual'|NA) and `.resolution_reason` (e.g., 'score=0.98, gap=0.45, threshold=0.95').
- **D-12:** `.resolution_method` and `.resolution_reason` columns appear in the exported Excel data sheet. Users can filter/sort by how each row was resolved.
- **D-13:** Follows the existing `.pinned`/`.manual_entry` column pattern on resolution_state.

### Override & Reject Flow
- **D-14:** Override an auto-resolution: user clicks Compare button on the AUTO-RESOLVED row, sees all candidates with the auto-resolved one highlighted, picks a different candidate. `.resolution_method` changes to 'manual'.
- **D-15:** Reject a suggestion: dismisses the suggestion but the row stays SUGGESTED until the user manually resolves it or leaves it unresolved. No permanent "rejected" state.

### Claude's Discretion
- Chip colors for AUTO-RESOLVED and SUGGESTED (should be visually coherent with existing agree/disagree/error palette)
- Where the "Accept All Suggestions" button is placed in the UI
- Internal function naming and placement (new file vs extending consensus.R)
- Whether auto-resolution runs as part of `compute_similarity_scores()` or as a separate step after scoring
- Prototype script structure and test case selection

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scoring Infrastructure (Phase 49)
- `R/consensus.R` ~L276-294 -- `score_one_candidate()` (scoring formula, unchanged)
- `R/consensus.R` ~L313-381 -- `compute_similarity_scores()` (produces similarity_score column on resolution_state)

### Resolution Logic
- `R/consensus.R` ~L165-173 -- `init_resolution_state()` (adds .pinned, .manual_entry; extend with .resolution_method, .resolution_reason)
- `R/consensus.R` ~L395-421 -- `resolve_row()` (single-row resolution; model for auto-resolve)
- `R/consensus.R` ~L434+ -- `apply_priority_chain()` (bulk resolution pattern; model for "Accept All Suggestions")
- `R/consensus.R` ~L58-148 -- `classify_consensus()` (sets consensus_status; needs new 'auto_resolved'/'suggested' values)

### Review Results UI
- `R/mod_review_results.R` ~L271 -- `resolve_row_choice` input handler (modal resolution flow)
- `R/mod_review_results.R` ~L1139-1176 -- `observeEvent(input$resolve_row_choice)` (resolution event handler; model for accept-suggestion)
- `R/mod_review_results.R` ~L1186-1233 -- comparison modal rendering (inject suggestion highlight + accept button)

### Status Chip Rendering
- `R/mod_review_results.R` -- existing ERROR/DISAGREE/AGREE chip rendering (pattern for AUTO-RESOLVED/SUGGESTED chips)

### Export
- `R/export_helpers.R` -- resolution_state columns flow to export; add .resolution_method/.resolution_reason

### Requirements
- `.planning/REQUIREMENTS.md` -- SCORE-03 (auto-resolve with audit trail), SCORE-04 (suggested best match)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `resolve_row()`: Single-row resolution function — sets consensus_dtxsid, consensus_source, .pinned. Extend or wrap for auto-resolution.
- `apply_priority_chain()`: Bulk resolution by column priority — pattern for "Accept All Suggestions" (iterates non-pinned rows, applies resolution, skips pinned).
- `init_resolution_state()`: Adds state columns (.pinned, .manual_entry) — extend with .resolution_method and .resolution_reason.
- `compute_similarity_scores()`: Already computes per-row best score — classification logic (auto-resolve vs suggest vs leave) can run immediately after scoring.
- Status chip rendering in mod_review_results.R: Existing pattern for ERROR/DISAGREE/AGREE colored chips — add AUTO-RESOLVED and SUGGESTED variants.

### Established Patterns
- Resolution state is a data frame stored on `data_store$resolution_state` (reactiveValues)
- `.pinned = TRUE` marks manually resolved rows — auto-resolved rows should also set .pinned to prevent re-classification
- Comparison modal uses `Shiny.setInputValue` via JS in DT table buttons
- Bulk actions (priority chain) appear as UI elements in the Review Results module
- Export reads resolution_state columns directly — new columns flow through automatically

### Integration Points
- After `compute_similarity_scores()` in the pipeline — new classification step assigns auto_resolved/suggested status
- `classify_consensus()` — may need to be extended or a post-classification step added
- `init_resolution_state()` — add .resolution_method and .resolution_reason columns
- `R/mod_review_results.R` — new chip rendering, modal suggestion highlight, accept button, bulk accept button
- `R/export_helpers.R` — include .resolution_method and .resolution_reason in export

</code_context>

<specifics>
## Specific Ideas

- The gap requirement (D-03) prevents auto-resolving when two candidates score nearly the same (e.g., 0.96 vs 0.94) even though both are high — this correctly routes to SUGGESTED for user review.
- Bulk "Accept All Suggestions" follows the same skip-pinned pattern as `apply_priority_chain()` — already proven safe for bulk operations.
- Status chips should be filterable in the DT table — the existing ERROR/DISAGREE filter mechanism should extend to AUTO-RESOLVED and SUGGESTED.

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope.

</deferred>

---

*Phase: 50-auto-resolve-suggest*
*Context gathered: 2026-05-10*
