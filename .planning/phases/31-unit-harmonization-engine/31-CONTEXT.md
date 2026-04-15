# Phase 31: Unit Harmonization Engine - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Build pure R functions that take (numeric_value, unit_string) and return harmonized values using the unit conversion table from Phase 29. This phase delivers UNIT-01 through UNIT-05 with basic table-lookup approach.

Requirements covered:
- UNIT-01: Case-safe unit lookup (case-sensitive first, case-insensitive fallback)
- UNIT-02: Unit string normalization (micro symbols, whitespace, spacing)
- UNIT-03: Compound unit decomposition (explicit enumeration in table)
- UNIT-04: Unit conversion arithmetic (value × multiplier)
- UNIT-05: Harmonization result tibble structure

**Not in scope for Phase 31:** Context-aware conversions (molarity→mg/L with MW lookup, media-based routing for ppm/ppb, air vs aqueous distinction). These are deferred to Phase 31.5.

</domain>

<decisions>
## Implementation Decisions

### Unmatched Unit Handling
- **D-01:** Pass-through with flag. Unmatched units get:
  - `harmonized_value` = original value (unchanged)
  - `harmonized_unit` = original unit (pass-through)
  - `conversion_factor = 1` (not NA — keeps arithmetic clean downstream)
  - `unit_flag = "unmatched"`

### Normalization Strategy
- **D-02:** Normalize input strings BEFORE lookup, in this order:
  1. Trim whitespace
  2. Micro symbol normalization (U+00B5, U+03BC → "u")
  3. Collapse spaces around "/" ("mg / L" → "mg/L")
- **D-03:** After normalization, try case-sensitive lookup → `confidence = "HIGH"`
- **D-04:** If no match, try case-insensitive lookup → `confidence = "LOW"`, `unit_flag = "case_fallback"`
- **D-05:** If still no match → pass-through per D-01

### Target Unit Selection
- **D-06:** Implicit from table. Each `from_unit` row specifies its `to_unit`. The table maintains internal consistency per category (all concentration → mg/L, all dose → mg/kg bw/day, etc.)

### Audit Trail Structure
- **D-07:** Harmonization returns a tibble with columns:
  - `orig_row_id` (int) — links back to source row
  - `orig_unit` (chr) — original unit string before normalization
  - `harmonized_value` (dbl) — value × multiplier
  - `harmonized_unit` (chr) — canonical target unit
  - `conversion_factor` (dbl) — multiplier applied (1 for pass-through)
  - `unit_flag` (chr) — status: "", "unmatched", "case_fallback"

### Known Table Issues (defer to 31.5)
- **D-08:** Current table has issues that Phase 31 will NOT fix:
  - `mg/m³ → mg/L` conflates air/water (needs separate `air_concentration` category)
  - `mol/L, M, mM, µM → mg/L (x1.0)` is wrong (needs molecular weight)
  - `ppm/ppb` in both concentration and mass_fraction (needs media context)
- These require context-aware conversion logic deferred to Phase 31.5

### Claude's Discretion
- Internal helper function organization
- Regex patterns for normalization
- Warning/logging verbosity
- Test case selection beyond requirements

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 29 Foundation
- `.planning/phases/29-static-data-foundations/29-CONTEXT.md` — Unit table structure (D-01 through D-05)
- `R/cleaning_reference.R` — `load_unit_map()` function (lines 277-295)
- `inst/extdata/unit_conversion.rds` — 151-row unit table with 16 categories

### Phase 30 Parser
- `.planning/phases/30-numeric-result-parser/30-CONTEXT.md` — Parser output structure, `orig_row_id` pattern
- `R/numeric_parser.R` — `parse_numeric_results()` function

### Requirements
- `.planning/REQUIREMENTS.md` §Unit Harmonization — UNIT-01 through UNIT-05 specs

### ToxVal Conventions
- ToxValDB uses `mg/kg-day` for dose, `mg/L` for aqueous concentration, `mg/m³` for air
- Schema columns: `toxval_units`, `toxval_units_original`, `conversion_factor`, `unit_flag`

### Phase 31.5 Handover
- `.planning/phases/31-unit-harmonization-engine/31.5-UNITS-ASSIMILATION-HANDOVER.md` — Research on `units` package, context-aware conversions, table issues to fix

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `load_unit_map(cache_dir)` in `R/cleaning_reference.R` — returns unit conversion tibble
- `parse_numeric_results()` in `R/numeric_parser.R` — upstream parser, output feeds into harmonization
- Unicode normalization patterns from `R/cleaning_pipeline.R`

### Established Patterns
- Transformation functions return tibbles with `orig_row_id` for joining
- Audit trail via `*_original` columns
- Flags as character strings ("", "unmatched", etc.) not booleans
- `load_or_fetch_reference()` caching pattern

### Integration Points
- New file: `R/unit_harmonizer.R` (or add to existing module)
- Downstream Phase 32 (ToxVal Schema Mapper) consumes harmonized output
- Downstream Phase 34 (Harmonize Tab) wires into Shiny UI

</code_context>

<specifics>
## Specific Ideas

### Normalization Examples
```
Input: "µg/L"  (U+00B5) → normalize → "ug/L" → lookup → mg/L
Input: "μg/L"  (U+03BC) → normalize → "ug/L" → lookup → mg/L
Input: "mg / L"         → normalize → "mg/L" → lookup → mg/L
Input: "MG/L"           → case-sensitive miss → case-insensitive → mg/L (flagged)
```

### Output Example
```
orig_row_id | orig_unit | harmonized_value | harmonized_unit | conversion_factor | unit_flag
1           | ug/L      | 0.005            | mg/L            | 0.001             |
2           | µg/L      | 0.010            | mg/L            | 0.001             |
3           | MG/L      | 1.0              | mg/L            | 1.0               | case_fallback
4           | NTU       | 5.0              | NTU             | 1.0               | unmatched
```

</specifics>

<deferred>
## Deferred Ideas

### Phase 31.5: Units Package Assimilation
- Replace 151-row table with `units` package + ~90 rows (registrations + synonyms)
- Dimensional safety (can't convert mg/L to mg/kg)
- Automatic conversion factors via udunits algebra
- See: `31.5-UNITS-ASSIMILATION-HANDOVER.md`

### Phase 31.5: Context-Aware Conversions
- **Molarity → mg/L**: Fetch molecular weight via CompTox API, apply formula `mg/L = M × MW × 1000`
- **Media inference**: Derive from column tags (exposure_route = inhalation → air → mg/m³)
- **ppm/ppb routing**: Use inferred media to pick aqueous vs solid conversion
- **Air concentration category**: Separate from aqueous, target = mg/m³

### Table Fixes (Phase 31.5)
- Remove/fix broken molarity entries (mol/L, M, mM, µM, nM, pM with multiplier 1.0)
- Add `air_concentration` category
- Resolve dimensionless inconsistency (6 different targets → one canonical)

</deferred>

---

*Phase: 31-unit-harmonization-engine*
*Context gathered: 2026-04-15*
