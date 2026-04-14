# Phase 29: Static Data Foundations - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-14
**Phase:** 29-static-data-foundations
**Areas discussed:** Unit table structure, ToxVal schema scope, Loader function design

---

## Unit Table Structure

### Q1: Column Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal (4 cols) | from_unit, to_unit, multiplier, category — bare essentials for conversion arithmetic | |
| Standard (6 cols) | Add confidence (HIGH/LOW for case match) and source (ECOTOX/SSWQS/user) for audit trail | ✓ |
| Rich (8+ cols) | Add unit_class (mass, volume, concentration), synonyms, notes for complex decomposition | |

**User's choice:** Standard (6 cols)
**Notes:** Confidence and source columns provide audit trail without excessive complexity

### Q2: Category Organization

| Option | Description | Selected |
|--------|-------------|----------|
| Flat list | Single category column: 'mass', 'concentration', 'duration' — simple, no hierarchy | |
| Two-level hierarchy | category + subcategory: e.g., 'concentration' > 'mass/volume' vs 'mass/mass' | |
| You decide | Claude's discretion based on what ECOTOX/SSWQS data actually contains | ✓ |

**User's choice:** You decide
**Notes:** Claude will assess actual data structure and choose appropriate organization

### Q3: SSWQS Merge Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Append all | Add all SSWQS units with source='SSWQS'. Accept potential duplicates, dedupe later if needed | |
| Merge with precedence | ECOTOX takes precedence for shared units; SSWQS only adds new ones | |
| You decide | Claude's discretion — assess overlap when building the table | ✓ |

**User's choice:** You decide
**Notes:** Claude will evaluate overlap during implementation

---

## ToxVal Schema Scope

### Q1: Column Count

| Option | Description | Selected |
|--------|-------------|----------|
| All 56 columns | Full toxval schema from day one — typed NA for unused columns, maximizes compatibility | ✓ |
| Core subset (~20) | Prioritize v1.9 features: dtxsid, casrn, name, toxval_numeric, toxval_units, qualifier, species, study_type, source | |
| Show me the full list | Let me see all 56 columns before deciding | |

**User's choice:** All 56 columns
**Notes:** Full schema from day one ensures future compatibility

### Q2: Column List Source

| Option | Description | Selected |
|--------|-------------|----------|
| toxval.duckdb introspection | Query local toxval database for column names/types — guaranteed match | |
| Hardcoded in R | Explicit tibble definition with all 56 columns typed — version-controlled, works offline | |
| You decide | Claude's discretion based on what's most practical | ✓ |

**User's choice:** You decide
**Notes:** Claude will choose based on offline portability needs

### Q3: Audit Columns (*_original)

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, include *_original | toxval_numeric_original, toxval_units_original, etc. — audit trail built into schema | |
| No, add dynamically | Schema has base columns only; *_original columns created during transmutation step | |
| You decide | Claude's discretion based on ToxVal conventions | ✓ |

**User's choice:** You decide
**Notes:** Claude will follow ToxVal conventions

---

## Loader Function Design

### Q1: Pattern Choice

| Option | Description | Selected |
|--------|-------------|----------|
| Cache-or-fetch pattern | Reuse load_or_fetch_reference() — consistent with existing loaders | |
| Direct readRDS | Simple readRDS(system.file(...)) since data is pre-built static file | |
| You decide | Claude's discretion based on consistency vs. simplicity tradeoff | ✓ |

**User's choice:** You decide
**Notes:** Claude will balance consistency with simplicity

### Q2: Return Value

| Option | Description | Selected |
|--------|-------------|----------|
| Full tibble | Return all rows, let caller filter — simple, consistent with other loaders | |
| Optional filter param | load_unit_map(category = NULL) — filter by category when provided | |
| You decide | Claude's discretion | ✓ |

**User's choice:** You decide
**Notes:** Claude will assess downstream usage patterns

---

## Claude's Discretion

User deferred the following decisions to Claude:
- Unit table category organization (flat vs hierarchical)
- SSWQS merge strategy
- ToxVal column list source
- Audit columns (*_original) inclusion
- Loader pattern (cache-or-fetch vs direct readRDS)
- Return value filtering

## Deferred Ideas

None — discussion stayed within phase scope
