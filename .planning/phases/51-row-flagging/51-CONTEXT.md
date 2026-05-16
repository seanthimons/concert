# Phase 51: Row Flagging - Context

**Gathered:** 2026-05-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Add BAD, FOLLOW-UP, and VERIFIED labels to the existing Review Results workflow. Users can flag individual rows from the row review modal, batch-flag explicitly selected visible rows from the Review Results table, retain flags during the session, and export a dedicated flag column. This phase does not change consensus scoring, auto-resolution, WQX review logic, or detection thresholds.

</domain>

<decisions>
## Implementation Decisions

### Flag Semantics
- **D-01:** Row flags are human annotations, separate from system-generated `needs_review`.
- **D-02:** `needs_review` remains a computed workflow/export signal for system uncertainty or unresolved rows. `row_flag` captures user judgment: `BAD`, `FOLLOW-UP`, `VERIFIED`, or blank.
- **D-03:** Setting `BAD` does not mutate `consensus_status` and does not automatically set `needs_review = TRUE`. Exports include both fields so downstream users can filter system-review rows and human-marked rows independently.

### Individual Flag Control
- **D-04:** Individual row flags are set and cleared from the existing row review modal, not from an inline table dropdown.
- **D-05:** The Review Results table may display flag state for scanning if useful, but the edit surface is modal-only.

### Batch Flagging
- **D-06:** Batch flagging applies to selected visible rows in Review Results. Filters/search can narrow what the user sees, but the batch action only changes rows the user explicitly selects.
- **D-07:** Batch flagging should follow the existing selected-row and bulk-action patterns in `mod_review_results.R`, with clear confirmation/notification behavior.

### Export Shape
- **D-08:** Export a simple `row_flag` column containing `BAD`, `FOLLOW-UP`, `VERIFIED`, or blank.
- **D-09:** Do not add flag metadata columns such as timestamp, flag method, or free-text notes in this phase.

### Codex's Discretion
- Exact modal control layout for flag buttons/dropdown.
- Whether the table shows a read-only flag chip/column, as long as editing remains modal-only.
- Internal function names and whether helpers live in `R/consensus.R`, `R/mod_review_results.R`, or a small new helper file.
- Exact button placement for the batch flag action, provided it uses selected visible rows only.

</decisions>

<specifics>
## Specific Ideas

- Conceptual split: `needs_review` is CONCERT's judgment that a row cannot be confidently finalized; `row_flag` is a human curation label that may apply even to otherwise resolved rows.
- Example: a row can have `consensus_status = "agree"` and `needs_review = FALSE`, but still be marked `BAD` if the user determines the source data is invalid.
- Example: a row can be unresolved by the system and have `needs_review = TRUE`, while the user marks it `FOLLOW-UP` rather than `BAD`.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` -- FLAG-01, FLAG-02, and FLAG-03 define Phase 51 requirements.
- `.planning/ROADMAP.md` -- Phase 51 goal and success criteria.

### Prior Phase Context
- `.planning/phases/50-auto-resolve-suggest/50-CONTEXT.md` -- current Review Results resolution-state patterns, modal behavior, bulk accept pattern, and export conventions.
- `.planning/phases/49-conflict-scoring-engine/49-CONTEXT.md` -- Review Results table and modal context from scoring work.

### Review Results UI
- `R/mod_review_results.R` -- primary integration point for Review Results table, row review modal, selected-row handling, and bulk actions.
- `R/mod_review_results.R` -- existing selected-row flow around `getReactableState("curation_table", "selected")` and `selected_error_rows` is the model for batch flagging.
- `R/mod_review_results.R` -- existing modal resolution handlers are the model for per-row modal-only flag edits.

### Resolution State and Export
- `R/consensus.R` -- `init_resolution_state()`, `resolve_row()`, `apply_priority_chain()`, and `accept_all_suggestions()` show existing state mutation and bulk-action patterns.
- `R/export_helpers.R` -- `build_export_sheets()` computes `needs_review` and builds the Curated Data export sheet; add `row_flag` while keeping `needs_review` separate.
- `R/curate_headless.R` -- headless export path passes `resolution_state` into `build_export_sheets()` and should preserve the new `row_flag` column.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `data_store$resolution_state`: existing session state carrier for consensus status, pinned/manual state, suggested column, and resolution method/reason. Add `row_flag` here so flags survive tab navigation and re-render.
- `init_resolution_state()`: established place to ensure state columns exist. It can initialize `row_flag` to `NA_character_` or blank.
- Modal resolution flow in `R/mod_review_results.R`: existing review modal already identifies a row and mutates `resolution_state`; reuse that path for individual flagging.
- Reactable selection state in `R/mod_review_results.R`: existing selected-row machinery can support batch flagging selected visible rows.
- `build_export_sheets()`: existing export function already derives `needs_review`; it should export `row_flag` independently.

### Established Patterns
- State changes update `data_store$resolution_state` and then recalculate `data_store$consensus_summary` only when consensus counts change. Row flags should not change consensus counts.
- Bulk actions skip implicit broad mutations and report how many rows were affected.
- Internal state columns with dot prefixes are excluded from export when appropriate. `row_flag` is not internal and should be exported.
- Review Results uses modal actions for high-impact row decisions, which fits modal-only individual flagging.

### Integration Points
- Add `row_flag` initialization in `R/consensus.R`.
- Add modal controls and event handlers in `R/mod_review_results.R`.
- Add selected-visible-row batch flag action in `R/mod_review_results.R`.
- Preserve/export `row_flag` in `R/export_helpers.R`.
- Add focused tests around state initialization, modal/batch helper behavior if factored, and export shape.

</code_context>

<deferred>
## Deferred Ideas

- Flag timestamps, flag methods, and free-text flag notes are out of scope for Phase 51.
- Inline editable flag dropdowns/chips in the Review Results table are out of scope for Phase 51.
- Making `BAD` alter `needs_review` or `consensus_status` is out of scope for Phase 51.

</deferred>

---

*Phase: 51-row-flagging*
*Context gathered: 2026-05-16*
