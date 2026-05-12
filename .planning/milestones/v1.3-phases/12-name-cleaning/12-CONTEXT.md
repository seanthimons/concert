# Phase 12: Name Cleaning - Context

**Gathered:** 2026-03-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Clean chemical names via parenthetical extraction, synonym splitting, quality adjective stripping, and before/after comparison UI. Users can see names cleaned and split with full audit trail visibility. No formula flagging (Phase 13), no reference list editing (Phase 13), no export (Phase 14).

</domain>

<decisions>
## Implementation Decisions

### Synonym Splitting: NEW ROWS (LONG)

**Critical decision — differs from Phase 11's WIDE CAS pattern.**

- Comma/semicolon-separated synonyms auto-split into new rows (no flag-and-confirm like multi-CAS)
- Primary name (first value) keeps the original row; synonyms get new rows with `original_row_id` tracking
- Synonym rows get NA for CAS columns — avoids wrong CAS-to-name pairing. Each name curated independently
- IUPAC comma protection: digit-comma-digit regex (e.g., `2,2-dimethyl` and `butane, 2,2-dimethyl` inverted forms). Simple regex, covers 95%+ of cases
- No existing library handles this — custom implementation required. Neither clean_chems.py nor ComptoxR has synonym splitting
- Classification descriptors like `"Hydrocarbons, C12-C16, isoalkanes"` may get split, but that's acceptable — they fail curation anyway

### Parenthetical Stripping

- Strip terminal parentheticals and brackets from chemical names
- Protect parentheticals containing "yl" (chemical name fragments like "methyl", "ethyl")
- Exception words for "yl" protection: 'density', 'probably', 'average', 'combination' (from clean_chems.py `term_parenth`)
- Stripped content preserved in a `formula_extract_{source}` column (low cost, useful for Phase 13 formula flagging)
- CAS numbers inside parentheticals handled by existing Phase 11 `extract_cas` — no duplication needed

### Quality Adjective & Salt Stripping

- Strip quality adjectives: 'pure', 'purified', 'tech', 'grade', 'chemical' (from clean_chems.py `drop_text`)
- Strip salt references: 'and its salts', 'and its [X] salts' (from clean_chems.py `drop_salts`)
- Strip 'unspecified' suffixes: terminal `[punct] unspecified` patterns (from clean_chems.py `terminal_unspecified`)
- All stripped content logged to audit trail with reason

### Formula Handling: No Special Detection

- Bare formulas as chemical names (e.g., "H2O") go through curation as regular strings — CompTox API resolves them
- ComptoxR::extract_formulas() only works for formulas inside parens/brackets — not useful for bare detection
- Bare formula flagging (FILT-04: name set to NA) deferred to Phase 13 reference filters
- Parenthetical formula content (e.g., "NaCl" from "(NaCl)") preserved in formula_extract column for Phase 13

### Pipeline Step Order

Order within name cleaning (runs AFTER Phase 10 unicode/trim and Phase 11 CAS pipeline):

1. **Strip parentheticals** — Remove bracketed noise first, preserve content in column
2. **Strip quality adjectives/salt refs/unspecified** — Clean remaining text
3. **Synonym split** — Must run LAST (after parentheticals removed to avoid splitting on commas inside parens)
4. **Final string cleanup** — Trim orphaned punctuation/whitespace from all steps

### Before/After Comparison UI (UIUX-03)

- Audit trail table shown in an **accordion (collapsed by default)** below the cleaned data table
- DT table with columns: row_id, field, original_value, new_value, reason
- Users expand accordion to see what changed; collapse to focus on cleaned data
- For synonym splits: audit logs BOTH the original row ("split into N synonyms") AND each new synonym row created ("synonym from row X"). Full traceability via original_row_id

### Value Box Dashboard Extension

- Add 3-4 new value boxes for name cleaning stats: Parentheticals Stripped, Synonyms Split, Adjectives Removed, Names Cleaned
- Extends Phase 11's existing 6 value boxes (CAS Rescued, CAS Normalized, CAS Invalid, Multi-CAS Flagged, Unicode Cleaned, Fields Trimmed)
- Same bslib::layout_columns pattern, responsive grid

### Step-by-Step Progress Extension

- Extend Phase 11's incProgress() pattern with name cleaning steps
- Full sequence: unicode → trim → normalize CAS → rescue CAS → detect multi-CAS → **strip parentheticals → strip adjectives → split synonyms → finalize**

### Claude's Discretion

- Exact regex patterns for adjective/salt/unspecified stripping (use clean_chems.py as reference)
- How to handle edge cases where synonym splitting produces empty strings
- Whether formula_extract column is auto-tagged for curation or left as informational
- Value box themes, icons, and layout for the new name cleaning boxes
- Accordion styling and default state

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `R/cleaning_pipeline.R`: inject_row_lineage, normalize_cas_fields, rescue_cas_from_text, detect_multi_cas, build_audit_trail — all extend with name cleaning functions
- `R/modules/mod_clean_data.R`: Value box dashboard, step-by-step progress, multi-CAS section — extend with name cleaning boxes and audit accordion
- `clean_chems.py`: Reference implementation for term_parenth (line 164), term_bracket (line 205), drop_text/quality adjectives (line 495), drop_salts (line 557), terminal_unspecified (line 348)
- `ComptoxR::extract_cas()`: Already used in Phase 11 for CAS in parentheticals — no need to duplicate
- `ComptoxR::extract_formulas()`: Available for embedded formulas in parens, but not needed for Phase 12 (bare formula detection deferred to Phase 13)

### Established Patterns
- Tag map pattern: Named list mapping column names to types (CASRN, Name, Other) — name cleaning operates on Name-tagged columns
- Pipeline functions return list(cleaned_data, audit_trail, new_tags) for composability
- Value box dashboard with bslib::layout_columns for responsive grid
- incProgress() between pipeline stages for step-by-step progress
- build_audit_trail() for before/after diffing (character column comparison)

### Integration Points
- `R/cleaning_pipeline.R`: Add name cleaning functions after CAS pipeline functions
- `run_cleaning_pipeline()`: Extend with name cleaning steps after CAS steps (when tag_map has Name columns)
- `R/modules/mod_clean_data.R`: Add name cleaning value boxes, audit trail accordion, extend progress steps
- `data_store$cleaned_data`: Synonym splitting changes row count — downstream modules (tag_columns, run_curation) must handle this
- `data_store$column_tags`: formula_extract columns may need auto-tagging

### Production Reference
- clean_chems.py pipeline order (lines 800-822): unicode → formula → parenthetical → FC → food → stop → adjective → unspecified → salt → parenthetical (again) → string clean → CAS extraction
- clean_chems.py does NOT handle synonym splitting — this is new capability

</code_context>

<specifics>
## Specific Ideas

- Synonym splitting is the highest-risk operation — PRE_POST_CURATION_PLAN.md estimates 8%+ of rows (1,000+ records) affected
- The digit-comma-digit IUPAC protection is custom — no library exists for this. Research should verify the regex covers edge cases from the test dataset
- clean_chems.py runs parenthetical stripping twice (before and after other steps) — evaluate during planning whether this is needed or if once suffices
- Row count changes from synonym splitting will propagate to curation — ensure deduplicate_tagged_columns() and map_results_to_rows() handle the new row count

</specifics>

<deferred>
## Deferred Ideas

- Bare formula detection and flagging (FILT-04) — Phase 13
- Functional category filtering — Phase 13
- Food name filtering — Phase 13
- Stop word filtering — Phase 13
- Upstream improvements to ComptoxR::extract_formulas() — separate from CONCERT phases

</deferred>

---

*Phase: 12-name-cleaning*
*Context gathered: 2026-03-06*
