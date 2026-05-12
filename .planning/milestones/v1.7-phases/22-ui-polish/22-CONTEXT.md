# Phase 22: UI Polish - Context

**Gathered:** 2026-04-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix column header truncation in Review Results reactable table, remove the explicit widget ID causing `renderWidget` warnings, and silence the `jsonlite` named vector deprecation warning. Pure bug-fix/polish — no new features.

</domain>

<decisions>
## Implementation Decisions

### Column Header Wrapping (UIPOL-01)
- **D-01:** Change `wrap = FALSE` to `wrap = TRUE` in the reactable call at `R/modules/mod_review_results.R:754` so column headers display full text on multiple lines instead of truncating with ellipsis.

### renderWidget Warning (UIPOL-02)
- **D-02:** Remove the explicit `elementId = table_id` from the reactable call at `R/modules/mod_review_results.R:758`. The namespace-based `table_id` is currently used by JavaScript filter functions (`Reactable.setFilter`) — those references need to be updated to use the auto-generated widget ID or an alternative approach.

### jsonlite Deprecation Warning (UIPOL-03)
- **D-03:** The jsonlite warning does not originate from CONCERT code directly — no `jsonlite` calls exist in `R/`. The warning comes from a dependency (likely reactable, htmlwidgets, or rhandsontable) passing a named vector where a named list is now required. Runtime tracing (`options(warn = 2)` or `withCallingHandlers`) needed to identify the exact call site and determine whether the fix is in CONCERT code (converting a named vector to a list before passing it downstream) or requires a package update.

### Claude's Discretion
- Approach for tracing the jsonlite warning source (runtime debugging vs. package version check)
- Whether to add CSS styling for wrapped headers (e.g., smaller font, vertical alignment) — use judgment based on how it looks

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Core Implementation File
- `R/modules/mod_review_results.R` — Contains the reactable table definition (line ~745), column definitions, and JavaScript filter functions that reference the widget ID

### Requirements
- `.planning/REQUIREMENTS.md` §v1.7 — UIPOL-01, UIPOL-02, UIPOL-03 acceptance criteria

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- reactable is used across multiple modules (mod_data_preview, mod_raw_data, mod_clean_data, mod_review_results) — any header wrapping pattern should be consistent
- `reactable.extras` dependency already loaded (line 101) for extended functionality

### Established Patterns
- All tables use reactable (not DT) with consistent options: `filterable = TRUE`, `compact = TRUE`, `bordered = TRUE`, `highlight = TRUE`
- JavaScript interop uses `Reactable.setFilter()` with explicit table IDs — this is the coupling point for UIPOL-02
- Column definitions use `reactable::colDef()` with custom cell renderers and filter inputs

### Integration Points
- The `table_id` variable (`session$ns("curation_table")`) is used in:
  - `elementId` parameter of the reactable call (line 758)
  - `make_select_filter()` helper function (line 558) for `Reactable.setFilter()` calls
  - JavaScript filter methods in column definitions
- Removing `elementId` requires updating all `Reactable.setFilter()` references to use the auto-generated ID or finding an alternative namespacing approach

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

*Phase: 22-ui-polish*
*Context gathered: 2026-04-01*
