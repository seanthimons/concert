# Phase 15: Post-Curation QC - Context

**Gathered:** 2026-03-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Flag remaining non-ASCII characters in the final curated output after curation completes. Replace custom unicode cleaning with ComptoxR's chemistry-specific clean_unicode(). Integrate QC results into Review Results tab as advisory (non-blocking) checks. No new cleaning steps, no enrichment, no session persistence.

</domain>

<decisions>
## Implementation Decisions

### CAS Re-Validation: Not Needed
- POST-01 is already satisfied by the existing pipeline: pre-curation CAS cleaning (Phase 11) validates user-uploaded CAS values, and CompTox API returns are authoritative (server-side validated, never ships invalid CAS-RNs)
- No post-curation CAS re-validation step needed
- Mark POST-01 as covered by existing Phases 11 + curation pipeline

### Unicode Function Swap
- Replace custom `clean_unicode_field()` (stringi transliteration) with `ComptoxR::clean_unicode()` throughout the pre-curation pipeline
- ComptoxR's function is chemistry-specific: Greek letters become `.alpha.`, `.beta.` notation (not `a`, `b`); trademark/registered/copyright symbols are removed (not expanded to `(TM)`, `(R)`, `(C)`)
- ComptoxR has 157 mapped entries in its unicode_map, purpose-built for chemical data
- This affects both `R/cleaning_pipeline.R` and `R/modules/mod_clean_data.R` where `clean_unicode_field()` is currently called

### Post-Curation QC Check
- After curation completes, run `ComptoxR::clean_unicode()` on the final curated output as a QC pass
- Flag only — do not modify post-curation data; user sees what remains and decides
- Surface `ComptoxR:::check_unhandled()` warnings: specific unmapped characters shown to user (not just console output)

### QC Trigger & Timing
- QC runs automatically when curation completes (no extra user action)
- "Re-run QC" button available next to the export button for after manual resolutions
- Re-run only on explicit button click (not after every resolution change)
- QC is advisory only — does not gate the export button; user can export with QC warnings present (matches existing pattern where needs_review rows can be exported)

### Results Display: Three Layers
1. **Value boxes** at top of Review Results alongside existing consensus stats:
   - "X rows with non-ASCII" value box
   - "Y unhandled characters" value box (from check_unhandled)
2. **Inline DT flags** on affected rows using WARN style (yellow), labeled `QC: non-ASCII` — consistent with Phase 13 warning flag pattern
3. **QC summary card** above the export button:
   - Lists specific unhandled characters with unicode codepoint and row count (e.g., "U+27E8 found in 3 rows")
   - Actionable detail so user knows exactly what's in their data

### Claude's Discretion
- Exact value box placement relative to existing consensus value boxes
- How to capture check_unhandled() output (intercept warnings vs. custom detection)
- QC summary card styling and layout details
- Whether to add QC results to the multi-sheet export (e.g., QC sheet or flags in existing sheets)
- Test strategy for the unicode function swap (update existing tests vs. new test file)

</decisions>

<specifics>
## Specific Ideas

- ComptoxR::clean_unicode() uses a 157-entry unicode_map with chemistry-correct mappings; our custom function uses generic stringi transliteration — the swap improves data quality for the entire pipeline, not just QC
- check_unhandled() is an internal ComptoxR function that warns about characters with no mapping — surfacing these in the UI gives users visibility into data quality gaps
- The "Re-run QC" button next to export creates a natural pre-export workflow: resolve issues → re-run QC → export

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ComptoxR::clean_unicode()`: S3 generic with character method, uses internal unicode_map (157 entries) + check_unhandled() for unmapped characters
- `ComptoxR:::check_unhandled()`: Internal function that warns about unicode characters not in the map
- `R/cleaning_pipeline.R:28-32`: Current `clean_unicode_field()` — replace calls to this with `ComptoxR::clean_unicode()`
- `R/cleaning_pipeline.R:1131-1139`: Pre-curation pipeline unicode step — swap function here
- `R/modules/mod_clean_data.R:98`: Inline unicode cleaning — swap function here
- `R/modules/mod_review_results.R`: Review Results module — add QC value boxes, DT flags, summary card, and re-run button

### Established Patterns
- Value box dashboard (Phase 11): `bslib::value_box()` with icons and conditional color
- DT conditional formatting (Phase 13): JavaScript-based BLOCK/WARN prefix matching for row highlighting
- Flag taxonomy (Phase 13): WARN = yellow advisory, BLOCK = red blocking — QC uses WARN
- `withProgress()` for pipeline operations with `incProgress()` between steps
- `downloadHandler` placement in Review Results for export button — QC button goes adjacent

### Integration Points
- `R/cleaning_pipeline.R`: Replace `clean_unicode_field()` definition and all internal calls
- `R/modules/mod_clean_data.R`: Replace inline `clean_unicode_field()` call with `ComptoxR::clean_unicode()`
- `R/modules/mod_review_results.R`: Add QC value boxes row, DT qc_flag column, summary card, and re-run button
- `tests/test_cleaning_pipeline.R`: Update unicode tests to match ComptoxR behavior (`.alpha.` not `a`)
- `app.R` server: Wire QC auto-run after curation completes and re-run button observer

</code_context>

<deferred>
## Deferred Ideas

- ENRCH-01: Functional use category enrichment via CompTox API — v1.4+
- ENRCH-02: Safety flag enrichment via CompTox API — v1.4+
- FOOD-01: Food name reference category — v1.4+

</deferred>

---

*Phase: 15-post-curation-qc*
*Context gathered: 2026-03-09*
