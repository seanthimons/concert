# Phase 10: Foundation & Clean Data Tab - Context

**Gathered:** 2026-03-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Add a new "Clean Data" tab to the gated workflow with audit trail infrastructure, reference data loaders (ComptoxR-seeded with local caching), and basic text cleaning (unicode→ASCII, punctuation/whitespace stripping). No CAS cleaning, no name cleaning, no summary cards, no reference list editing UI — those belong in Phases 11-13.

</domain>

<decisions>
## Implementation Decisions

### Cleaning Trigger & Flow
- Explicit "Run Cleaning" button on the Clean Data tab (matches existing "Run Curation" pattern)
- Before cleaning runs: empty state with friendly message + disabled button until data exists
- After cleaning runs: cleaned data auto-flows into data_store — no user confirmation step needed
- Cleaning is always re-runnable: button stays active, re-running cleans from raw data and resets all downstream state (tags, curation)
- Tag Columns tab is gated behind cleaning — must run cleaning before tagging is available

### Audit Trail Structure
- Separate audit tibble in data_store$cleaning_audit (not embedded in data columns)
- Columns: row_id, field, step, original_value, new_value, reason
- Full before/after detail for every transformation
- Re-running cleaning replaces the audit trail (fresh start from raw data each time)
- Audit trail is infrastructure only in this phase — no UI rendering yet (Phase 11+ adds visibility, Phase 14 exports it)

### Reference List Seeding
- ComptoxR-seeded at app startup with local disk caching
- Cache stored in data/reference_cache/ (git-ignored)
- If cache exists: load from disk instantly. If cache missing: download from ComptoxR, cache to disk
- User deletes cache → app re-downloads on next startup
- Silent loading with brief notification ("Reference lists loaded from cache" or "Downloading reference lists...")
- All three list types seeded in this phase: stop words, block list patterns, functional categories

### Tab Content & Layout
- Clean Data tab positioned after Data Preview, before Tag Columns in the nav
- Tab is gated — only visible after file upload (like Detection Info, Raw Data)
- Sidebar hides when Clean Data tab is active (like curation tabs)
- After cleaning: show cleaned data table (DT::datatable) + brief text summary above ("X rows cleaned, Y unicode chars fixed, Z fields trimmed")

### Claude's Discretion
- Exact empty state wording and icon
- DT table column formatting and pagination defaults
- Internal cleaning function organization (single function vs pipeline of small functions)
- How to handle edge cases where no transformations are needed (still show table, summary says "0 changes")
- Notification wording and duration

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `R/modules/mod_*.R` pattern: Each module has `mod_X_ui()` + `mod_X_server()` — new Clean Data tab follows same pattern as `mod_clean_data.R`
- Gated navigation: `nav_hide()`/`nav_show()` + `show_tab_with_pulse()` already in app.R — reuse for Clean Data tab gating
- `reset_all_downstream()` in app.R: Already resets tags, curation, etc. — extend to also reset cleaning_audit and cleaned data
- `data_store` reactiveValues: Already has raw/clean/detection/file_info — add cleaning_audit and cleaned_data fields
- `R/file_handlers.R`: `safely_read_file()` pattern for error handling — reuse for ComptoxR cache loading

### Established Patterns
- Module communication: shared `data_store` reactiveValues passed to modules (Phase 9 decision)
- Upload module owns data_store writes for raw/clean/detection (single writer pattern)
- Navigation callbacks as function parameters (on_tags_applied, on_curation_complete) — add on_cleaning_complete
- Auto-source all R files recursively from R/ directory
- `purrr::safely()` for operations that might fail

### Integration Points
- app.R line 79-105: navset_underline — insert new nav_panel for Clean Data between Data Preview and Tag Columns
- app.R line 111-119: data_store reactiveValues — add cleaning_audit, cleaned_data fields
- app.R line 122-128: gated nav_hide calls — add clean_data tab hiding
- app.R line 164-169: observe for showing tabs — modify to show Clean Data after upload, gate Tag Columns behind cleaning
- app.R line 172-176: sidebar toggle — add clean_data to curation_tabs list for sidebar hiding
- app.R line 186-191: mod_tag_columns_server wiring — gate behind data_store$cleaned_data existence

</code_context>

<specifics>
## Specific Ideas

- "Run Cleaning" button pattern should match "Run Curation" button on the Run Curation tab for visual consistency
- Reference list caching should be transparent — user shouldn't need to think about it unless they want to force a refresh (delete cache)
- The brief summary text above the cleaned data table should be simple counts, not cards (Phase 11 adds proper summary cards)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 10-foundation-clean-data-tab*
*Context gathered: 2026-03-05*
