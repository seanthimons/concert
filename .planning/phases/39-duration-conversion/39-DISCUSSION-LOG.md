# Phase 39: Duration Conversion - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-25
**Phase:** 39-duration-conversion
**Areas discussed:** "m" ambiguity strategy, Compound durations, Input format handling, Unrecognized unit behavior, Unit data format, ToxVal schema wiring, Harmonize module routing

---

## "m" Ambiguity Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Flag as ambiguous | Map "m" to minutes internally but add "ambiguous_unit" flag. Matches date parser's ambiguity pattern. | ✓ |
| Reject and require explicit | Refuse to convert bare "m" — user must fix to "min" or "mo" | |
| Default to minutes silently | Treat "m" as minutes without flagging | |

**User's choice:** Flag as ambiguous
**Notes:** Consistent with DATE-03 ambiguity flagging pattern.

### Follow-up: Other ambiguous abbreviations

| Option | Description | Selected |
|--------|-------------|----------|
| Only "m" | Surgical — "m" is the only genuinely dangerous abbreviation | |
| "m" and "s" | Flag both "m" and "s" | |
| You decide | Claude evaluates the full abbreviation list | ✓ |

**User's choice:** You decide
**Notes:** Claude evaluates ECOTOX list and flags genuinely ambiguous ones.

---

## Compound Durations

| Option | Description | Selected |
|--------|-------------|----------|
| Simple only | Only "number unit" patterns. Compound expressions flagged as unparseable. | |
| Parse compound expressions | Split "1 day 12 hours" into components, convert, sum. | |
| Decimal only | Handle "1.5 days" but NOT "1 day 12 hours". | ✓ |

**User's choice:** Decimal only
**Notes:** Decimals are just "number unit" format handled naturally. Multi-unit compounds deferred.

---

## Input Format Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Paired columns | Follow existing Result/Unit pattern. Duration = values, DurationUnit = unit strings. | ✓ |
| Combined string in single column | Parse "96 hr" from a single DurationUnit column. | |
| Support both | If only DurationUnit tagged, parse combined; if both tagged, use paired. | |

**User's choice:** Paired columns
**Notes:** Consistent with existing tagging UX.

---

## Unrecognized Unit Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Pass through with flag | Keep original value/unit, conversion_factor=1, "unit_unrecognized" flag. | ✓ |
| Convert to NA with flag | Set harmonized values to NA, flag as unrecognized. | |
| You decide | Follow whatever harmonize_units() already does. | |

**User's choice:** Pass through with flag
**Notes:** Matches existing harmonize_units() behavior. No data loss.

---

## Unit Data Format (pinch point)

### Discovery
Existing `unit_conversion.rds` has 19 "time" category rows converting to **days** as base unit. DUR-02 specifies hours. User provided domain context: benchmarks mix hours (acute) and days (chronic).

### Base unit decision

| Option | Description | Selected |
|--------|-------------|----------|
| Hours as base, originals preserved | Convert everything to hours. Originals in audit columns. study_duration_class for acute/chronic. | ✓ |
| Normalize to hours OR days by magnitude | < 7 days → hours, >= 7 days → days. Natural reading but complex downstream. | |
| Keep existing days base | Extend abbreviation coverage but leave base as days. Rewrite DUR-02 criteria. | |

**User's choice:** Hours as base, originals preserved

### RDS location decision

| Option | Description | Selected |
|--------|-------------|----------|
| Same RDS, new "duration" category | Add to unit_conversion.rds with category="duration", to_unit="hr". | ✓ |
| Separate duration_conversion.rds | New file. Clean separation but second lookup path. | |

**User's choice:** Same RDS, new category

---

## ToxVal Schema Wiring (pinch point)

User requested more information before deciding. Full data flow trace presented showing:
- `mod_harmonize.R`: expanded_curated built from resolution_state, passed to map_to_toxval_schema()
- `toxval_mapper.R`: study_duration_value pulled from curated_data via safe_extract_num()

| Option | Description | Selected |
|--------|-------------|----------|
| Merge upstream into curated_data | Join study_duration_value/units into expanded_curated before mapper call. No API change. | ✓ |
| Add duration_data parameter | New parameter on map_to_toxval_schema(). More explicit but grows API. | |
| You decide | Claude picks during implementation. | |

**User's choice:** Merge upstream into curated_data
**Notes:** Sets pattern for Phase 40 (dates) and Phase 41 (media).

---

## Harmonize Module Routing (pinch point)

| Option | Description | Selected |
|--------|-------------|----------|
| Add category parameter | harmonize_units(values, units, unit_map, category=NULL). Filter by category. | ✓ |
| Separate harmonize_durations() wrapper | Thin wrapper pre-filtering unit map. No API change to harmonize_units(). | |
| You decide | Claude picks during implementation. | |

**User's choice:** Add category parameter
**Notes:** Also sets up Phase 41's media context routing.

---

## Claude's Discretion

- Exact set of duration abbreviation rows (research ECOTOX table)
- Which additional abbreviations beyond "m" get ambiguous flag
- Internal category filter implementation in harmonize_units()
- Stage numbering and progress bar percentages
- Test structure for DUR-05 coverage

## Deferred Ideas

- Duration ranges ("96-120 hr") → DFUT-02
- Multi-unit compound expressions → future enhancement if needed
- study_duration_class population (acute/chronic) → not in Phase 39 scope
