# Phase 11: CAS Pipeline - Context

**Gathered:** 2026-03-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement CAS-RN normalization, validation, rescue from name columns, and multi-CAS detection with UI preview. Users can see CAS-RNs cleaned, rescued CAS moved to new columns, multi-CAS rows flagged for user decision, and summary cards showing pipeline statistics. This phase also reorders the tab flow (Tag before Clean) and upgrades Phase 10's text summary to value boxes.

</domain>

<decisions>
## Implementation Decisions

### Data Shape: WIDE (not LONG)

**Critical decision — validated against production EPA workflow (PW_ChemicalCuration.R).**

- All CAS operations produce new columns, never new rows
- CAS rescue creates `cas_extract_{source_column_name}` columns (one per source column that yields CAS values)
- Multi-CAS cells are flagged (`multi_cas = TRUE` with count), NOT automatically split
- User-initiated split available as a UI action (creates new rows via rbind for specific flagged rows)
- Row count stays stable through the CAS pipeline unless user explicitly splits
- Cap at `cas_5` equivalent — overflow concatenated into `cas_overflow` text field with audit flag

**Why WIDE:**
- Preserves `map_results_to_rows()` row-count assertion in curation.R (no refactoring needed)
- Matches production EPA pattern: `dtxsid_by_name` / `dtxsid_by_casrn` side-by-side comparison
- QC tiers based on WIDE column comparison (agree/disagree/one-only/neither)
- DT display stays 1:1 with uploaded data — user mental model preserved
- Excel export matches user expectation (one row = one inventory record)
- Retry merge, audit trail row IDs, pinned rows all work unchanged

**Dedup refactoring required:** `deduplicate_tagged_columns()` must support column families — all `cas_*` and `cas_extract_*` columns pooled into one dedup group before API calls to prevent duplicate lookups.

### Tab Reordering: Tag Before Clean

- Flow becomes: Data Preview → **Tag Columns** → **Clean Data** → Run Curation → Review Results
- CAS pipeline knows which columns are CASRN/Chemical Name because tagging happened first
- Requires rewiring Phase 10 gating logic: Clean Data tab gated behind tags (not behind upload)
- Tag Columns tab gated behind upload (unchanged)

### CAS Normalization & Validation

- Use `ComptoxR::as_cas()` on all columns tagged as CASRN
- Valid CAS → normalized to canonical NNN-NN-N format
- Invalid/placeholder text ("no cas", "n/a", "proprietary", "-", etc.) → naturally becomes NA via as_cas()
- No separate placeholder detection step needed — as_cas() handles everything
- Audit trail logs ALL changes (normalizations AND NA conversions) with generic reason ("CAS normalized/invalidated via as_cas()")

### CAS Rescue from Names

- Scan ALL non-CASRN tagged columns (not just Chemical Name) with `ComptoxR::extract_cas()`
- Extracted CAS-RNs go into new columns named `cas_extract_{source_column_name}`
- Strip only the CAS portion (and surrounding parens/brackets) from the source text
- Leave non-CAS parentheticals for Phase 12 name cleaning
- New rescue columns auto-tagged as CASRN for downstream curation
- Audit trail logs each extraction

### Multi-CAS Handling: Flag + User Decision

- Detect cells with multiple CAS-RNs in CASRN columns AND rescue columns
- Flag rows with `multi_cas = TRUE` and `multi_cas_count` integer
- Do NOT automatically split — user decides whether it's a mixture (keep together) or data error (split)
- User-initiated split as UI action: select flagged row → "Split" button → creates new rows via rbind
- Validated by PW_ChemicalCuration.R (line 616): EPA team manually creates duplicate records for mixtures

### Row Lineage Tracking

- Add `original_row_id = 1:nrow(df)` at the start of the cleaning pipeline (before any transformations)
- Cheap insurance for user-initiated splits and Phase 12 name splitting
- Injected as first step of `run_cleaning_pipeline()` (small retroactive change to Phase 10 code)

### Summary Cards (Value Boxes)

- Use `bslib::value_box()` cards across top of Clean Data tab
- Replace Phase 10's text alert summary with value boxes (unified visual language)
- Cards: "CAS Rescued", "CAS Validated", "CAS Invalid → NA", "Multi-CAS Flagged", plus basic cleaning stats (unicode, trim)
- Displayed after cleaning runs; update on re-run

### Progress Indicator

- Single "Run Cleaning" button runs ALL steps: basic cleaning (unicode, trim) + CAS pipeline sequentially
- `withProgress()` showing per-step detail: "Converting unicode..." → "Trimming whitespace..." → "Normalizing CAS..." → "Rescuing CAS from names..." → "Detecting multi-CAS..." → "Validating checksums..."
- Matches existing "Run Curation" pattern on Run Curation tab

### Claude's Discretion

- Exact value box styling, colors, and icons
- How to handle the user-initiated split UI (modal? inline button? confirmation dialog?)
- Internal function organization within the CAS pipeline
- How to handle edge cases where no CAS columns are tagged (skip CAS steps gracefully)
- Whether `original_row_id` is visible in the DT display or hidden

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ComptoxR::as_cas()`: Normalizes + validates CAS in one call, returns NA for invalid — already used in R/curation.R:202
- `ComptoxR::extract_cas()`: Extracts CAS from freetext, validates via checksum — already prototyped in clean_chems.R:20
- `ComptoxR::is_cas()`: Boolean CAS validation — available for multi-CAS detection
- `R/cleaning_pipeline.R`: `run_cleaning_pipeline()`, `build_audit_trail()`, `clean_unicode_field()`, `clean_text_field()` — CAS steps extend this pipeline
- `R/modules/mod_clean_data.R`: Clean Data tab module — add value boxes, CAS progress steps, multi-CAS flag UI
- `bslib::value_box()`: Available in bslib — no new dependencies needed

### Established Patterns
- Module communication: shared `data_store` reactiveValues (Phase 9)
- Navigation callbacks as function parameters (Phase 9)
- `withProgress()` + `incProgress()` for pipeline UX (Phase 10, curation.R)
- `build_audit_trail()` for before/after diffing (Phase 10)
- Auto-source all R files recursively (Phase 9)
- `purrr::safely()` for operations that might fail (curation.R)

### Integration Points
- app.R navset_underline: Reorder Clean Data tab to come AFTER Tag Columns
- app.R gating logic: Clean Data gated behind tags existing (not behind upload)
- app.R sidebar toggle: Clean Data keeps sidebar hidden (already in curation_tabs list)
- R/cleaning_pipeline.R: Add CAS pipeline steps after basic cleaning, add original_row_id injection
- R/modules/mod_clean_data.R: Add value boxes, CAS progress detail, multi-CAS flag display
- R/curation.R `deduplicate_tagged_columns()`: Refactor to support column families for CAS dedup pooling

### Production Reference
- PW_ChemicalCuration.R (Kristin Isaacs, EPA): WIDE curation pattern with dtxsid_by_name/dtxsid_by_casrn, QC tiers 1-7, manual rbind for mixture splitting
- PW_FunctionCuration.R: Purpose splitting goes LONG then collapses back — validates that LONG is for truly separable dimensions, not CAS

</code_context>

<specifics>
## Specific Ideas

- Value boxes should match the clean, modern feel of bslib — not cluttered. Think "dashboard at a glance"
- The "Run Cleaning" button pattern should match "Run Curation" button for visual consistency (already established in Phase 10)
- Multi-CAS flagging should be visually distinct — consider a warning badge or colored row highlighting in the DT table
- Reference PW_ChemicalCuration.R's QC tier pattern (lines 517-528) as validation that WIDE column comparison is the standard approach in this domain
- The tab reordering (Tag → Clean) should feel natural — "tag your columns, then we clean them based on what you tagged"

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 11-cas-pipeline*
*Context gathered: 2026-03-05*
