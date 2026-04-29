# Phase 40: Date Parser - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-26
**Phase:** 40-date-parser
**Areas discussed:** Format priority & default interpretation, Partial date handling, Ambiguity surfacing, Tag classification placement, 2-digit year cutoff, Unparseable & empty handling, Dedup eligibility, Single column vs paired

---

## Format Priority & Default Interpretation

| Option | Description | Selected |
|--------|-------------|----------|
| MDY-first (Recommended) | US/EPA convention. '01/02/2024' → January 2nd. Matches dominant format in ECOTOX, ToxVal, SSWQS datasets. | |
| YMD-first (ISO standard) | Prioritizes ISO-8601 unambiguous formats, then falls back to MDY for slash-separated. | ✓ |
| No default — NA with flag | Ambiguous dates get parsed_date = NA. Forces downstream resolution. | |

**User's choice:** YMD-first (ISO standard)
**Notes:** User prefers ISO standard priority over US convention.

### Follow-up: Fallback Order

| Option | Description | Selected |
|--------|-------------|----------|
| YMD → MDY → DMY (Recommended) | ISO first, then US convention, then European. | ✓ |
| YMD → DMY → MDY | ISO first, then European, then US. | |

**User's choice:** YMD → MDY → DMY
**Notes:** None — straightforward selection.

---

## Partial Date Handling

### Year-only entries

| Option | Description | Selected |
|--------|-------------|----------|
| Impute Jan 1st + 'partial' flag (Recommended) | parsed_date = '2015-01-01', date_year = 2015, date_flag = 'partial'. | ✓ |
| NA parsed_date, populate date_year only | Safer but loses date field. ToxVal original_year still works. | |
| You decide | Claude picks based on existing patterns. | |

**User's choice:** Impute Jan 1st + 'partial' flag
**Notes:** None.

### Month-year entries

| Option | Description | Selected |
|--------|-------------|----------|
| Impute 1st of month + 'partial' flag (Recommended) | Same pattern as year-only. Missing components default to 1. | ✓ |
| NA parsed_date, populate date_year only | Loses month information. | |
| You decide | Claude picks based on lubridate capabilities. | |

**User's choice:** Impute 1st of month + 'partial' flag
**Notes:** Consistent imputation rule across all partial date types.

---

## Ambiguity Surfacing

| Option | Description | Selected |
|--------|-------------|----------|
| QC dashboard + audit export (Recommended) | Count in QC dashboard value box. Exported in audit sheet. Advisory only. | ✓ |
| Exportable column in ToxVal output | Add date_flag to 56-column schema. Schema change. | |
| Audit trail only (quiet) | Only in audit tibble/Sheet 2. Easy to miss. | |

**User's choice:** QC dashboard + audit export
**Notes:** Matches existing unit_flag surfacing pattern. No ToxVal schema change.

---

## Tag Classification Placement

| Option | Description | Selected |
|--------|-------------|----------|
| New 'study_types' group (Recommended) | Third group for dates and future Media tag. Clean separation. | ✓ |
| In numeric_types | Alongside Result, Unit, Duration. Groups by pipeline destination. | |
| In metadata_types | Alongside Species, ExposureRoute. Study-level attributes. | |

**User's choice:** New 'study_types' group
**Notes:** Creates a home for both Phase 40 StudyDate and Phase 41 Media tags.

---

## 2-Digit Year Cutoff

| Option | Description | Selected |
|--------|-------------|----------|
| Custom cutoff at 2029 (Recommended) | 00-29 → 2000-2029, 30-99 → 1930-1999. | |
| lubridate default (68/69 boundary) | 00-68 → 2000-2068, 69-99 → 1969-1999. | |
| Always flag as ambiguous | Custom cutoff + inferred_format flag for ALL 2-digit year dates. | ✓ |
| You decide | Claude picks based on regulatory data patterns. | |

**User's choice:** Always flag as ambiguous
**Notes:** Belt-and-suspenders: use custom cutoff for best guess AND flag all 2-digit years as inferred_format.

---

## Unparseable & Empty Handling

| Option | Description | Selected |
|--------|-------------|----------|
| NA output + 'unparseable' flag (Recommended) | parsed_date = NA, date_year = NA, date_flag = 'unparseable'. Raw string in audit. | ✓ |
| Pass-through raw string in parsed_date | Keeps raw value visible but breaks column type. | |
| You decide | Claude picks based on existing patterns. | |

**User's choice:** NA output + 'unparseable' flag
**Notes:** Consistent with harmonize_units() behavior for unrecognized units.

---

## Dedup Eligibility

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, dedup-eligible (Recommended) | Wrap with dedup_step() at orchestrator level. Date strings highly duplicative. | ✓ |
| No dedup — lubridate is fast enough | lubridate vectorized in C. Simpler code path. | |
| You decide | Claude benchmarks and decides. | |

**User's choice:** Yes, dedup-eligible
**Notes:** Same pattern as cleaning pipeline steps per Phase 37.

---

## Single Column vs Paired

| Option | Description | Selected |
|--------|-------------|----------|
| Single tag only (Recommended) | One column tagged StudyDate. Auto-detect format. Simplest UX. | ✓ |
| Paired with DateFormat hint | StudyDate + DateFormat tags. User override for format. More control, more complexity. | |
| You decide | Claude picks based on UX tradeoff. | |

**User's choice:** Single tag only
**Notes:** Dates are self-contained strings, unlike Duration/DurationUnit paired columns.

---

## Claude's Discretion

- Exact lubridate `orders` vector composition
- Specific 2-digit year cutoff value
- Stage numbering and progress bar percentages
- Internal parse_dates() implementation details
- Test structure and QC dashboard layout

## Deferred Ideas

- Date range parsing ("1990-1995") → DFUT-01
- DateFormat companion tag → future if auto-detection insufficient
- study_duration_class from parsed dates/durations → not in scope
