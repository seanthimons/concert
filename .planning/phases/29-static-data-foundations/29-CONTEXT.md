# Phase 29: Static Data Foundations - Context

**Gathered:** 2026-04-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Create static data infrastructure for numeric/unit harmonization:
- Unit conversion RDS file (`inst/extdata/unit_conversion.rds`)
- ToxVal schema manifest (`inst/extdata/toxval_schema.rds`)
- `load_unit_map()` loader function in `R/cleaning_reference.R`

This phase delivers DATA-01, DATA-02, DATA-03 from requirements. No UI work — pure data infrastructure.

</domain>

<decisions>
## Implementation Decisions

### Unit Table Structure
- **D-01:** Use standard 6-column structure: `from_unit`, `to_unit`, `multiplier`, `category`, `confidence`, `source`
- **D-02:** Confidence column captures case-match quality (HIGH for exact case, LOW for case-insensitive fallback)
- **D-03:** Source column tracks provenance (ECOTOX, SSWQS, user_added)

### Claude's Discretion
- Category organization: Assess ECOTOX/SSWQS data structure and use flat list or two-level hierarchy based on what makes sense
- SSWQS merge strategy: Evaluate overlap with ECOTOX and choose appropriate deduplication approach
- ToxVal column source: Use hardcoded tibble or DB introspection based on practical offline/portability needs
- Audit columns (*_original): Include in manifest or generate dynamically based on ToxVal conventions
- Loader pattern: Use cache-or-fetch or direct readRDS based on consistency vs simplicity tradeoff
- Return value: Full tibble or optional filtering based on downstream usage patterns

### ToxVal Schema
- **D-04:** Include all 56 ToxVal columns in schema manifest from day one
- **D-05:** Use typed NA values (`NA_character_`, `NA_real_`) for unused columns to ensure parquet compatibility

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Patterns
- `R/cleaning_reference.R` — Reference list loader pattern with `load_or_fetch_reference()`, tibble structure
- `inst/extdata/reference_cache/` — 5 existing RDS files showing established file format

### Requirements
- `.planning/REQUIREMENTS.md` §Static Data Foundations — DATA-01, DATA-02, DATA-03 specs

### External Sources
- ECOTOX unit conversion tables from ComptoxR (to be lifted)
- SSWQS regulatory unit extensions (sample data in `uncurated_sswqs.csv`)
- ToxVal database schema (56-column structure)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `load_or_fetch_reference()` in `R/cleaning_reference.R:21-38` — generic cache-or-fetch pattern
- `inst/extdata/reference_cache/` — established cache directory with 5 RDS files
- Tibble provenance pattern: `(term, source, active)` columns for reference lists

### Established Patterns
- Loader functions: `load_X(cache_dir)` → `file.path(cache_dir, "X.rds")` → `load_or_fetch_reference(...)`
- All loaders return tibbles, not raw vectors
- Cache path uses `file.path()` for cross-platform compatibility
- Directory creation via `fs::dir_create(dirname(cache_path), recurse = TRUE)`

### Integration Points
- New loader will be added to `R/cleaning_reference.R` alongside existing loaders
- New RDS files go in `inst/extdata/` (or subdirectory)
- Downstream Phase 31 (Unit Harmonization Engine) will consume `load_unit_map()` output

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches following existing codebase patterns.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 29-static-data-foundations*
*Context gathered: 2026-04-14*
