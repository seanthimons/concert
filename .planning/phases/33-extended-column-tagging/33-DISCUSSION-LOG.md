# Phase 33: Extended Column Tagging - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-15
**Phase:** 33-extended-column-tagging
**Areas discussed:** Tag organization, Dispatch mechanism, Cascade reset rules, Tag validation

---

## Tag Organization

| Option | Description | Selected |
|--------|-------------|----------|
| Grouped by category (Recommended) | Optgroups: Chemical (Name, CASRN, Other) \| Numeric (Result, Unit, Qualifier) \| Study (Duration, DurationUnit, Species, ExposureRoute). Visual separation aids scanning. | Yes |
| Flat list alphabetical | All 10 options in one alphabetical list. Simpler but harder to scan as list grows. | |
| Flat list logical order | Chemical tags first, then numeric, then study metadata — no visual grouping, just ordering. | |

**User's choice:** Grouped by category (Recommended)
**Notes:** None

---

## Dispatch Mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| In mod_tag_columns (Recommended) | Apply Tags button partitions column_tags into chemical_tags, numeric_tags, metadata_tags. Downstream modules read the subset they need. Single source of truth. | Yes |
| In each downstream module | Each pipeline (curation, harmonization) filters column_tags for its relevant types. More flexible but duplicated logic. | |
| In app.R orchestration | Central routing in app.R decides which modules get which columns. Keeps modules simple but adds app.R complexity. | |

**User's choice:** In mod_tag_columns (Recommended)
**Notes:** None

---

## Cascade Reset Rules

| Option | Description | Selected |
|--------|-------------|----------|
| Independent cascades (Recommended) | Changing chemical tags resets curation only. Changing numeric tags resets harmonization only. Changing either resets toxval_output. Re-upload resets everything. | Yes |
| Full cascade always | Any tag change resets both curation AND harmonization results. Simpler but forces re-run of unaffected pipeline. | |
| No automatic reset | User manually triggers re-run. Risk of stale results but maximum control. | |

**User's choice:** Independent cascades (Recommended)
**Notes:** None

---

## Tag Validation

| Option | Description | Selected |
|--------|-------------|----------|
| Warning only (Recommended) | Show yellow warning if Result tagged without Unit (or vice versa). Allow proceeding — some datasets have unitless values (pH, ratios). Non-blocking. | Yes |
| Hard enforcement | Block Apply Tags if Result exists without Unit. Strict but may frustrate edge cases like pH columns. | |
| No validation | Accept any tag combination. Downstream harmonization handles missing units with NA. Maximum flexibility, risk of confusing errors later. | |

**User's choice:** Warning only (Recommended)
**Notes:** None

---

## Claude's Discretion

- Exact optgroup labels and ordering
- Warning message wording
- Internal helper function organization
- Test case selection beyond requirements

## Deferred Ideas

None — discussion stayed within phase scope
