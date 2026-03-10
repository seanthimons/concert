# Phase 13: Reference Filters & Editable Lists - Context

**Gathered:** 2026-03-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can see reference-based flags on their cleaned data (functional categories as warnings, bare formulas as blocking) and edit all reference lists in-app via rhandsontable editors. Users can re-run cleaning with updated lists, triggering full cascade invalidation. No export (Phase 14), no post-curation QC (Phase 15).

</domain>

<decisions>
## Implementation Decisions

### Flag Matching: Exact-then-Substring with Confidence Labels

- Match names against reference lists using two passes: exact match first (high confidence), then substring match (lower confidence)
- Both match types labeled in the audit trail so users can trust exact matches more and scrutinize substring matches
- Flag TYPE (blocking vs warning) determined by which reference list matched, not by how it matched
- Match source (ComptoxR-seeded, user-added, app-default) recorded in audit trail reason field only — not displayed in main table
- Single `cleaning_flag` column in cleaned data: `BLOCK: bare formula` (red) or `WARN: functional category [exact]` (yellow) — severity + reason + match type in one scannable column

### Reference List Structure: Separate Lists with Provenance

- Separate lists per type: functional categories, stop words, block patterns (each gets its own editor)
- Each list entry carries provenance: term, source (`comptoxr` / `user` / `app_default`), active (`TRUE`/`FALSE`)
- Seeding uses existing `cleaning_reference.R` pattern — dynamic ComptoxR API + RDS cache (decided Phase 10, no changes needed)
- User additions tagged as source = `user`
- Soft delete for ComptoxR-seeded entries: set active = FALSE (suppressed, recoverable, baseline preserved)
- Hard delete for user-added entries

### Editor UX: Accordion Panels in Clean Data Tab

- One collapsible accordion panel per reference list type in Clean Data tab (below cleaned data table, alongside existing audit trail accordion)
- rhandsontable editors inside each accordion panel — users can add/remove/suppress entries inline
- Single CSV upload button with required `type` column to route entries to correct lists (functional_category, stop_word, block_pattern)
- Upload appends entries tagged as source = `user`
- Export in Phase 14 will include reference list state as a sheet — round-trip via re-import

### Re-run Flow: Explicit Button with Full Cascade Reset

- Explicit "Apply & Re-run" button after editing reference lists (no auto-re-run on edit)
- Re-run triggers full cascade invalidation: cleaned data, curation results, and resolution state all reset
- Matches existing cascade reset pattern on tag changes (established in v1.0)
- Debouncing not needed since re-run is user-initiated

### Bare Formula Detection: Reuse ComptoxR Validator

- Reuse `validator_regex` from ComptoxR's internal `create_formula_extractor_final()` — already has complete element list and formula grammar
- Apply validator directly to bare name strings (skip the parenthetical candidate extraction step that `extract_formulas()` uses)
- ~5-10 lines wrapping existing logic, not a new validator from scratch
- Blocking flag: bare formula name set to NA, formula value preserved in new `formula_blocked_{col}` column for potential future downstream curation
- Flag appears as `BLOCK: bare formula` in the `cleaning_flag` column

### Value Box Dashboard Extension

- Add flag statistics to existing value box dashboard: "Formulas Blocked", "Categories Flagged", "Stop Words Matched"
- Extends Phase 11/12 value box rows with same bslib::layout_columns pattern

### Pipeline Step Order

Flagging steps run AFTER all Phase 10-12 cleaning steps:
1. Unicode cleanup (Phase 10)
2. Text trimming (Phase 10)
3. CAS normalization + rescue + multi-CAS detection (Phase 11)
4. Parenthetical stripping + adjective stripping + synonym splitting (Phase 12)
5. **Bare formula detection** (new — Phase 13)
6. **Reference list flagging** (new — Phase 13: functional categories, stop words, block patterns)

### Claude's Discretion

- Exact accordion layout and ordering of reference list editors
- rhandsontable column configuration (editable columns, read-only source column, checkbox for active)
- How to handle the CSV upload validation (missing type column, unknown types)
- Whether "Apply & Re-run" is a new button or repurposes the existing "Run Cleaning" button
- Value box themes, icons, and colors for flag statistics
- Internal function organization for flagging pipeline

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `R/cleaning_reference.R`: `load_or_fetch_reference()`, `load_stop_words()`, `load_block_patterns()`, `load_functional_categories()` — extend with provenance columns and active flag
- `ComptoxR:::create_formula_extractor_final()`: Contains `validator_regex` and complete `elements_list` — reuse for bare formula detection
- `R/modules/mod_clean_data.R`: Value box dashboard, audit accordion, step-by-step progress — extend with flag stats and reference list editors
- `R/cleaning_pipeline.R`: Pipeline functions with audit trail pattern — add flagging functions in same style
- `bslib::accordion()`: Already used for audit trail — same pattern for reference list editors
- `rhandsontable`: Approved dependency for editable tables (project-level decision)

### Established Patterns
- Pipeline functions return `list(cleaned_data, audit_trail, new_tags)` for composability
- `build_audit_trail()` for before/after diffing
- Value box dashboard with `bslib::layout_columns` responsive grid
- `incProgress()` between pipeline stages
- Cascade reset on upstream changes (tag changes reset curation)
- `data_store` reactiveValues for shared state across modules

### Integration Points
- `R/cleaning_reference.R`: Add provenance columns to reference list data structures
- `R/cleaning_pipeline.R`: Add `detect_bare_formulas()` and `flag_reference_matches()` functions after name cleaning steps
- `R/modules/mod_clean_data.R`: Add accordion panels for reference list editors, CSV upload, "Apply & Re-run" button, flag value boxes
- `app.R`: No changes expected — module handles everything internally
- `data_store$reference_lists`: New reactive slot for editable reference list state (separate from cached baseline)

</code_context>

<specifics>
## Specific Ideas

- The `validator_regex` reuse from ComptoxR is the key insight — avoids maintaining a separate element list
- Reference list editors should feel lightweight — users should be able to quickly suppress a false-positive category match without leaving the Clean Data tab
- The single `cleaning_flag` column keeps the DT table scannable — users can sort/filter by flag to review all flagged rows at once
- CSV upload with type column enables bulk enrichment from external lists (e.g., lab-specific functional categories)
- Soft delete preserves the ability to see "what would the baseline catch?" by re-enabling suppressed entries

</specifics>

<deferred>
## Deferred Ideas

- Food name reference list (FOOD-01) — deferred to v1.4+ requirements
- Post-curation functional use enrichment via DTXSID — Phase 15 / v1.4+
- Reference list versioning / history tracking — future enhancement
- Drag-and-drop pipeline builder for custom flagging order — out of scope (project-level decision)

</deferred>

---

*Phase: 13-reference-filters-editable-lists*
*Context gathered: 2026-03-06*
