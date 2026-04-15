# Phase 31: Unit Harmonization Engine - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-15
**Phase:** 31-unit-harmonization-engine
**Areas discussed:** Unmatched unit handling, Normalization strategy, Target unit selection, Audit trail structure

---

## Unmatched Unit Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Pass-through with flag | Keep original value and unit, set flag, conversion_factor = NA | |
| Pass-through with factor=1 | Keep original value and unit, set flag, conversion_factor = 1 | ✓ |
| NA value with flag | Set harmonized_value = NA, forces explicit handling | |
| Error collection | Accumulate and warn, like Phase 30 unparseable | |

**User's choice:** Pass-through with flag, but conversion_factor = 1 (not NA) so downstream arithmetic doesn't break.

**Notes:** User refinement: "Conversion factor can resolve to '1' so downstream conversion doesn't break."

---

## Normalization Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Full NFKC normalization | Use Unicode NFKC form, handles micro symbols but may mangle other chars | |
| Targeted micro replacement | Replace U+00B5, U+03BC → "u" specifically | ✓ |
| Expand table variants | Keep adding rows for each spelling variant | |

**User's choice:** Targeted normalization chain: trim → micro symbols → collapse spaces → case-sensitive lookup → case-insensitive fallback

**Notes:** User requested research on improvements. Research showed NFKC can have side effects; targeted replacement is safer. User noted ComptoxR unicode map already exists, but prefers defensive redundancy.

### Research Tangent: Units Package

User asked about using R `units` package to avoid table maintenance.

**Findings:**
- `units` package recognizes 70% of current table (101/145 units)
- Gaps: molarity (M, mM), turbidity (NTU), microbial (CFU), dose rates (mg/kg bw/day)
- Custom units can be registered via `install_unit()`
- UCUM 2.2 adds NTU and FNU

**User decision:** Defer to Phase 31.5. Created handover document with full research.

---

## Target Unit Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Implicit from table | Lookup from_unit, use to_unit from that row | ✓ |
| Explicit target parameter | Caller specifies desired target | |
| Category-based defaults | Engine detects category, uses hardcoded default | |

**User's choice:** Implicit from table — simplest approach, table already maintains consistency.

**Notes:** User asked if current canonical units are wrong. Analysis revealed:
- Most are correct (mg/L, mg/kg bw/day, etc.)
- Issues found: mg/m³ → mg/L conflates air/water, molarity entries have multiplier 1.0 (wrong)
- User confirmed they have air concentration and molarity data
- Decision: basic table lookup for Phase 31, fix issues in Phase 31.5

---

## Audit Trail Structure

| Option | Description | Selected |
|--------|-------------|----------|
| ToxVal-aligned columns | orig_row_id, orig_unit, harmonized_value, harmonized_unit, conversion_factor, unit_flag | ✓ |
| Minimal (value + flag only) | Just harmonized_value and unit_flag | |
| Extended with confidence | Add confidence column separate from flag | |

**User's choice:** ToxVal-aligned 6-column structure

**Notes:** Structure matches ToxVal schema columns (toxval_units, toxval_units_original, conversion_factor, unit_flag).

---

## Claude's Discretion

- Internal helper function organization
- Regex patterns for normalization
- Warning/logging verbosity
- Test case selection beyond requirements

---

## Deferred Ideas

### Phase 31.5: Units Package Assimilation
- Replace manual table with `units` package + registrations
- Reduces maintenance from 151 rows to ~90 (registrations + synonyms)
- Full research captured in `31.5-UNITS-ASSIMILATION-HANDOVER.md`

### Phase 31.5: Context-Aware Conversions
- Molarity → mg/L with MW lookup via CompTox API
- Media inference from column tags (exposure_route = inhalation → air)
- ppm/ppb routing based on media context
- Separate air_concentration category with target mg/m³

### Table Fixes (Phase 31.5)
- Fix broken molarity entries
- Add air_concentration category
- Resolve dimensionless inconsistency (6 targets → 1)
