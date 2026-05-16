# Phase 51: Row Flagging - Research

**Date:** 2026-05-16
**Status:** Complete

## Goal

Plan the smallest safe implementation path for BAD, FOLLOW-UP, and VERIFIED row annotations in Review Results, with session persistence and export persistence.

## Existing Architecture

`R/consensus.R` owns row-level resolution state initialization and mutation helpers. `init_resolution_state()` already adds session-carried internal columns such as `.pinned`, `.manual_entry`, `.resolution_method`, and `.resolution_reason`. Adding `row_flag` there is the right foundation because all Shiny and headless paths normalize through resolution state.

`R/mod_review_results.R` owns Review Results display, row modals, selected-row handling, and bulk actions. The module already tracks selected visible reactable rows through `reactable::getReactableState("curation_table", "selected")`, maps representative display rows back to source rows through `data_store$display_row_map`, and expands deduplicated groups through `get_group_rows()`.

`R/export_helpers.R` builds the Curated Data export sheet from `resolution_state`, excludes only internal dot-prefixed columns, and derives `needs_review` independently from consensus status. A public `row_flag` column can flow through export, but should be explicitly relocated near `needs_review`/consensus columns so users can find it.

`R/curate_headless.R` already passes `resolution_state` to `build_export_sheets()`, so headless export should inherit `row_flag` if the export helper preserves the column.

## Implementation Findings

### State

- `row_flag` should be a public character column, not a dot-prefixed internal column.
- Valid values are `BAD`, `FOLLOW-UP`, `VERIFIED`, and blank/`NA`.
- State helpers should normalize invalid/missing values rather than letting UI handlers duplicate validation.
- `row_flag` must not mutate `consensus_status`, `.pinned`, `.resolution_method`, or `needs_review`.

### UI

- Individual flag editing belongs in the existing comparison/review modal per context D-04/D-05.
- A read-only table flag chip is useful for scanability and does not violate the modal-only edit decision.
- Batch flagging should use selected visible rows only. The existing selected-row observer is error-filter-specific for re-tagging, so Phase 51 should add a separate selected-row store for all Review Results selections, not overload `selected_error_rows`.
- Batch apply/clear can use a compact action row: a select input for flag value plus an Apply button. The handler must no-op with a warning if no visible rows are selected.

### Export

- `row_flag` should remain in Curated Data and should not be excluded with dot-prefixed columns.
- Export should include `row_flag` even when older resolution states lack it, to keep the output shape stable.
- `needs_review` remains computed from system state only; `BAD` does not force `needs_review = TRUE`.

## Recommended Plan Split

1. **State and Export Foundation:** Add validation helpers, initialize `row_flag`, preserve it in Excel/headless export, and add focused unit tests.
2. **Review Results UI:** Add table flag display, modal flag controls, selected-visible-row batch flagging, and UI helper tests where practical.

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Batch flagging accidentally changes filtered-out rows | Use `getReactableState("curation_table", "selected")` plus `display_row_map`; never infer rows from current filters alone. |
| Flags disappear when resolution state is reinitialized | Add `row_flag` in `init_resolution_state()` and preserve existing values. |
| Human flags get conflated with system review state | Keep `needs_review` computation unchanged and add tests that `BAD` does not change it. |
| Deduplicated display rows only flag one backing row | Expand selected representative rows through `get_group_rows()` like existing modal and retag flows. |

## Verification Strategy

- Unit test `init_resolution_state()` adds and preserves `row_flag`.
- Unit test flag helper accepts only valid values and supports clearing.
- Unit test `build_export_sheets()` includes `row_flag` and keeps `needs_review` independent.
- Load the package with `devtools::load_all()`.
- Run focused tests for consensus, export/import, and Review Results helpers.

## Research Complete

Phase 51 can be implemented without new dependencies or architecture changes.
