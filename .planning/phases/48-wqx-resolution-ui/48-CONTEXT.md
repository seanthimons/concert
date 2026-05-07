# Phase 48: WQX Resolution UI - Context

**Gathered:** 2026-05-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Add a WQX fuzzy confidence column to the Review Results table, provide a modal-based type-ahead search for overriding WQX matches, allow users to reject bad matches, and persist all overrides/rejections through export. This completes the WQX user-facing resolution workflow.

</domain>

<decisions>
## Implementation Decisions

### Confidence Display
- **D-01:** Add a dedicated `wqx_confidence` numeric column to the Review Results reactable. Shows the Jaro-Winkler similarity score (0.00–1.00) for WQX fuzzy matches only; blank (NA) for WQX exact and alias matches. Column is visible by default, hideable via colvis.
- **D-02:** The `match_distance` value from `match_wqx()` is currently discarded in `curation.R:754-761`. Pipeline must carry this value through to the resolution state so it reaches the Review Results table.

### Resolution Trigger
- **D-03:** A teal "Review" button appears on **all** WQX-resolved rows (exact, alias, and fuzzy) in the Resolution column. Clicking it opens a modal — consistent with the existing Compare button pattern for disagreements.
- **D-04:** The Review button follows the same JS `Shiny.setInputValue` pattern used by `.compare-btn` in `mod_review_results.R`.

### Reject & Override Flow
- **D-05:** The WQX Review modal shows three actions in one view:
  1. **Accept current** — close modal, keep WQX result as-is
  2. **Pick different** — user searches via type-ahead, selects a WQX canonical name, confirms
  3. **Reject** — mark the row unresolvable without selecting an alternative
- **D-06:** Type-ahead search is a `selectizeInput` with server-side rendering, searching the WQX dictionary (~124K rows). Results show canonical name with type (canonical vs alias) annotation.
- **D-07:** Modal displays context: the original input name, current WQX match name, match score (if fuzzy), and match type (exact/alias/fuzzy).

### Export Integration
- **D-08:** WQX overrides reuse existing consensus_status values — no new status values needed:
  - Type-ahead override → `consensus_status` stays "wqx", `preferredName` updated to the user's pick
  - Rejection → `consensus_status` changes to "unresolvable", `needs_review = TRUE`
- **D-09:** This means `export_helpers.R` and the value box summary logic require no changes for new status values.

### Claude's Discretion
- Internal wiring of how `match_distance` propagates through `run_curation_pipeline()` to `resolution_state`
- Whether selectizeInput uses `choices` or `options` with `server = TRUE` for the 124K-row dictionary
- Modal layout details (card styling, spacing, button placement)
- How the type-ahead result replaces the existing WQX match in `resolution_state` (direct column assignment vs helper function)
- Dedup group propagation for WQX overrides (should follow existing `get_group_rows()` pattern)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Review Results Module
- `R/mod_review_results.R` — Contains the Review Results UI and server logic. Lines 48-156: `derive_resolution_html()` builds the Resolution column (WQX rows at lines 143-153). Lines 260-287: Compare button JS pattern to replicate. Lines 1126-1270: Compare modal flow (the pattern to follow for the WQX Review modal).

### WQX Matching
- `R/wqx_matching.R` — `match_wqx()` returns `match_distance` (JW distance, line 202) which is the source for `wqx_confidence`. Currently 5 columns returned: `input_name`, `wqx_name`, `match_tier`, `match_distance`, `alias_type`.

### Pipeline Wiring
- `R/curation.R` — Lines 754-761: where `wqx_rows` tibble is built and `match_distance` is currently discarded. This is the primary change point for carrying confidence through.

### Consensus & Export
- `R/consensus.R` — Line 89-101: WQX guard assigns "wqx" status to rows with WQX source_tier.
- `R/export_helpers.R` — Lines 40-60: `needs_review` flag logic. Lines 83: unresolvable count in summary.

### Requirements
- `.planning/REQUIREMENTS.md` — CONF-03 (confidence column), RES-01 (type-ahead search), RES-02 (reject/re-pick), RES-03 (export persistence)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Compare modal pattern** (`mod_review_results.R:1126-1243`): Complete Select + Confirm flow with candidate cards, JS event wiring, and modal state management. WQX Review modal should follow this pattern closely.
- **`derive_resolution_html()`** (`mod_review_results.R:48-156`): Already renders WQX rows with teal badge. Extend to add Review button.
- **`get_group_rows()`** (`mod_review_results.R:173-183`): Propagates resolution to dedup siblings. WQX overrides must use this too.
- **JS event patterns**: `.compare-btn` click → `Shiny.setInputValue` → `observeEvent` → modal. Proven pattern for `.wqx-review-btn`.
- **`load_wqx_dictionary()`** (`R/wqx_matching.R` or `R/wqx_dictionary.R`): Returns the full dictionary needed for type-ahead search.

### Established Patterns
- Resolution changes go through `resolution_state` reactiveVal — all mutations update this single data frame
- Modal state tracked via `data_store$modal_row_idx` and `data_store$modal_selected_column`
- Colvis toggle already manages column visibility — new column fits into existing mechanism
- Reactable with `reactable.extras` for interactive column features

### Integration Points
- `curation.R:754-761` — Must add `match_distance` (as `wqx_confidence`) to the `wqx_rows` tibble so it flows into combined results
- `run_curation_pipeline()` return value — Must include wqx_confidence in the data that reaches `mod_review_results.R`
- `derive_resolution_html()` — Add Review button for WQX rows
- `mod_review_results_server()` — New `observeEvent` handlers for WQX review button click, type-ahead selection, accept, and reject actions

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 48-wqx-resolution-ui*
*Context gathered: 2026-05-07*
