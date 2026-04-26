# Phase 39: Duration Conversion - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can tag columns as Duration (numeric values) and DurationUnit (unit strings), and the harmonization pipeline converts duration values to hours as a common base unit. The result is wired into the ToxVal schema `study_duration_value` and `study_duration_units` fields. No new UI tab, no new pipeline steps beyond duration routing, no date parsing (Phase 40), no media harmonization (Phase 41).

</domain>

<decisions>
## Implementation Decisions

### "m" Ambiguity Strategy
- **D-01:** Bare "m" maps to minutes internally but receives an `ambiguous_unit` flag in the audit trail. Downstream consumers see the converted value AND the warning. Matches the date parser's ambiguity-flagging pattern (DATE-03).
- **D-02:** Claude evaluates the full ECOTOX abbreviation list during implementation and flags any genuinely ambiguous abbreviations beyond "m" — not limited to just "m" but surgical rather than blanket.

### Compound Duration Handling
- **D-03:** Only simple "number unit" patterns are parsed (e.g., "96 hr", "14 days", "0.5 yr"). Decimal fractions like "1.5 days" work naturally since they're still "number unit" format.
- **D-04:** Multi-unit compound expressions like "1 day 12 hours" or "2 weeks 3 days" are flagged as unparseable — not silently dropped, not parsed. Duration ranges ("96-120 hr") are deferred to DFUT-02.

### Input Format
- **D-05:** Paired columns following the existing Result/Unit pattern. User tags one column as Duration (numeric values like 96, 14) and another as DurationUnit (unit strings like "hr", "days"). Consistent with existing tagging UX and reuses `harmonize_units()` directly.

### Unrecognized Unit Behavior
- **D-06:** Unrecognized duration unit strings pass through unchanged with `conversion_factor = 1` and a `unit_unrecognized` flag. No data loss — original value and unit preserved, visible in QC dashboard. Matches existing `harmonize_units()` behavior for unknown concentration units.

### Unit Data Format
- **D-07:** New duration conversion rows go into the existing `inst/extdata/unit_conversion.rds` with `category = "duration"` and `to_unit = "hr"` (hours as base). The existing 19 "time" rows (category = "time", base = days) remain untouched for backward compatibility. One conversion table, two categories.
- **D-08:** Duration synonym entries added to `inst/extdata/unit_synonyms.rds` following existing schema (`input_pattern`, `normalized_unit`, `is_regex`, `notes`). Custom duration synonym map per DUR-05 — never `lubridate::duration()`.

### Base Unit
- **D-09:** Hours is the single canonical base unit for all duration conversions, regardless of whether the original is acute (hours) or chronic (days/months/years). Original values preserved in `*_original` audit columns. Hours enables numeric sorting/comparison across all study types. `study_duration_class` handles acute/chronic labeling separately.

### ToxVal Schema Wiring
- **D-10:** Harmonized duration results are merged into `expanded_curated` upstream (as `study_duration_value` and `study_duration_units` columns) BEFORE calling `map_to_toxval_schema()`. No mapper API change needed — `safe_extract_num(curated_data, "study_duration_value")` picks them up automatically. Wiring happens in `mod_harmonize.R` and `curate_headless.R` only.
- **D-11:** This sets the pattern for Phase 40 (dates → `original_year`) and Phase 41 (media → `media`) — all harmonization results merge into curated_data before the mapper.

### Harmonize Module Routing
- **D-12:** `harmonize_units()` gains a `category = NULL` parameter. When NULL, uses current behavior (all categories). When `"duration"`, filters the conversion table to duration rows only. Clean, minimal API change that also sets up Phase 41's media context routing.
- **D-13:** Duration harmonization slots in as a new stage between current Stage 3 (unit harmonization) and Stage 5 (ToxVal mapping). Checks if Duration/DurationUnit columns are tagged, calls `harmonize_units()` with `category = "duration"`, joins results into `expanded_curated`.

### Carried Forward
- **D-14:** Dedup is an orchestrator wrapper (Phase 37 D-11). Duration harmonization through `harmonize_units()` gets unit-key dedup (Phase 37 D-07) for free via the existing machinery.
- **D-15:** `classify_tags()` already includes "Duration" and "DurationUnit" in `numeric_types` (Phase 33). No tag classification changes needed.

### Claude's Discretion
- Exact set of duration abbreviation rows to add (research ECOTOX `duration_unit_codes` table for completeness)
- Which additional abbreviations beyond "m" get the ambiguous flag (if any)
- Internal implementation of the `category` filter in `harmonize_units()`
- Stage numbering and progress bar percentages in `mod_harmonize.R`
- Test structure for DUR-05 "m" ambiguity coverage

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` — DUR-01 through DUR-05 requirements
- `.planning/ROADMAP.md` — Phase 39 success criteria (4 criteria)

### Phase 37 Context (Dedup Architecture)
- `.planning/phases/37-performance-architecture/37-CONTEXT.md` — D-07 (unit-key dedup), D-11/D-12 (orchestrator wrappers)

### Unit Harmonization Code
- `R/unit_harmonizer.R` — `harmonize_units()` function, `normalize_unit_string()`, `apply_synonyms()`, unit-key dedup pattern
- `R/unit_extraction.R` — Unit string extraction helpers
- `inst/extdata/unit_conversion.rds` — Conversion table (151 rows, 6-column schema: from_unit, to_unit, multiplier, category, confidence, source). Existing "time" category has 19 rows with days as base.
- `inst/extdata/unit_synonyms.rds` — Synonym table (80 rows, 4-column schema: input_pattern, normalized_unit, is_regex, notes)

### Tag System
- `R/tag_helpers.R` — `classify_tags()` with Duration/DurationUnit already in `numeric_types` (line 38)

### ToxVal Schema
- `R/toxval_mapper.R` — `map_to_toxval_schema()` with `study_duration_value` (line 96), `study_duration_units` (line 97), and corresponding `*_original` audit columns (lines 141-142)
- `inst/extdata/toxval_schema.rds` — 56-column schema manifest

### Pipeline Integration Points
- `R/mod_harmonize.R` — Shiny module: Stage 3 unit harmonization (line 341-366), Stage 5 ToxVal mapping (line 387-408), `expanded_curated` construction (line 392)
- `R/curate_headless.R` — Headless path: Stage 4 ToxVal mapping (line 275-281)

### Tests
- `tests/testthat/test-unit-harmonizer.R` — Existing unit harmonization tests
- `tests/testthat/test-tag-dispatch.R` — Tag classification tests including Duration/DurationUnit (line 20-21, 140-141)
- `tests/testthat/test-toxval-mapper.R` — ToxVal schema tests including study_duration fields (line 43-44, 202-203)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `harmonize_units()`: Full normalize→synonym→convert pipeline with unit-key dedup. Duration reuses this directly with `category="duration"` filter.
- `normalize_unit_string()`: Handles micro symbols, whitespace trimming, slash collapsing. Works for duration units unchanged.
- `apply_synonyms()`: Hash-lookup exact match + regex rules. Duration synonym entries slot into existing `unit_synonyms.rds`.
- `safe_extract_num()` / `safe_extract_char()`: ToxVal mapper helpers that check for column existence — duration columns merge upstream, these pick them up automatically.
- Unit-key dedup pattern in `harmonize_units()`: Computes conversion factor once per distinct unit string, then broadcasts. Duration gets this for free.

### Established Patterns
- Paired column tagging: Result/Unit pattern. Duration/DurationUnit follows the same pattern.
- `unit_conversion.rds` 6-column schema: `from_unit`, `to_unit`, `multiplier`, `category`, `confidence`, `source`. New duration rows use this schema with `category = "duration"`.
- Stage-based pipeline in `mod_harmonize.R`: corrections → parse → harmonize → store → ToxVal map. Duration slots in as a new stage.
- `expanded_curated` construction from `resolution_state` via `orig_row_id` indexing (line 392). Duration results merge into this before the mapper call.

### Integration Points
- `mod_harmonize.R` Stage 3→5 gap: Duration stage inserts here
- `curate_headless.R` Stage 3→4 gap: Same insertion point for headless path
- `harmonize_units()` API: Gains `category` parameter (default NULL = current behavior)
- `unit_conversion.rds` / `unit_synonyms.rds`: Gain duration rows via build script or direct RDS update

</code_context>

<specifics>
## Specific Ideas

- User noted that benchmarks mix hours and days for acute vs chronic exposure — hours as canonical base enables cross-study comparison while `study_duration_class` handles the acute/chronic distinction
- Ambiguity flagging for "m" mirrors the date parser's ambiguity flagging (DATE-03) — consistent audit trail pattern across harmonization types
- The `category` parameter on `harmonize_units()` is designed to be reused: Phase 41 will use it for media-context routing of ppb/ppm conversions

</specifics>

<deferred>
## Deferred Ideas

- Duration ranges ("96-120 hr") → DFUT-02 (future milestone)
- Multi-unit compound expressions ("1 day 12 hours") ��� could be a future enhancement if real data demands it
- `study_duration_class` population (acute/chronic/subchronic classification) → not in Phase 39 scope, could be added later based on duration thresholds

None — discussion stayed within phase scope

</deferred>

---

*Phase: 39-duration-conversion*
*Context gathered: 2026-04-25*
