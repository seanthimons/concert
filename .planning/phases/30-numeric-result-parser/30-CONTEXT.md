# Phase 30: Numeric Result Parser - Context

**Gathered:** 2026-04-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Parse messy numeric result strings into structured numeric values with qualifiers, ranges, and audit trail. Pure R functions — no UI work.

Requirements covered: PARS-01 through PARS-05
- Normalization chain (whitespace, `x10^`→`e`, Fortran exponents, commas)
- Qualifier extraction (`<`, `>`, `<=`, `>=`, `~`, `=`)
- Range splitting → low/mid/high rows with semantic qualifiers
- Output tibble: `numeric_value`, `qualifier`, `range_bin`, `parse_flag`
- `orig_result` capture as first step for audit trail

</domain>

<decisions>
## Implementation Decisions

### Non-numeric Value Handling
- **D-01:** Pass-through with flag. Values like "BDL", "ND", "trace", "non-detect" get `numeric_value = NA`, `parse_flag = "narrative"`, original preserved in `orig_result`. User handles downstream.

### Range Representation
- **D-02:** Always produce 3 rows for ranges: low / mid / high
- **D-03:** Semantic qualifiers encode range context:
  - `low` row → `qualifier = ">="` (value is at least this)
  - `mid` row → `qualifier = "~"` (derived approximation)
  - `high` row → `qualifier = "<="` (value is at most this)
- **D-04:** One-sided qualified values (`>100`, `<5`) are NOT ranges — single row with original qualifier, `range_bin = "as_is"`

### Qualifier Vocabulary (ToxValDB conventions)
- **D-05:** Valid qualifiers: `=`, `~`, `>`, `>=`, `<`, `<=`
- **D-06:** Normalize unicode variants: `≥` → `>=`, `≤` → `<=`
- **D-07:** No qualifier in source → empty string `""`
- **D-08:** Derived values (midpoints) get `qualifier = "~"`

### Output Integration
- **D-09:** Parser returns standalone tibble with columns: `orig_row_id`, `orig_result`, `numeric_value`, `qualifier`, `range_bin`, `parse_flag`
- **D-10:** Caller joins parsed tibble back to source data via `orig_row_id`
- **D-11:** Row multiplication from range splitting handled via `orig_row_id` linkage

### Error Behavior
- **D-12:** Collect and warn. Unparseable values get `numeric_value = NA`, `parse_flag = "unparseable"`, pipeline continues.
- **D-13:** Emit warning summarizing count of failed parses at end of parse operation.

### Claude's Discretion
- Normalization order within the chain (PARS-01 transformations)
- Regex patterns for qualifier extraction and range detection
- Internal helper function organization
- Test case selection beyond requirements

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Patterns
- `R/cleaning_pipeline.R` — Audit trail pattern via `build_audit_trail()`, `original_row_id` lineage tracking
- `R/cleaning_reference.R` — Loader function patterns, tibble return types

### Requirements
- `.planning/REQUIREMENTS.md` §Numeric Parsing — PARS-01 through PARS-05 specs

### ToxValDB Conventions
- Qualifier vocabulary from literature: `=`, `~`, `>`, `>=`, `<`, `<=`
- 79% of ToxValDB records have no qualifier or `=`
- Downstream phases handle qualifier interpretation (e.g., NOAEL + `<` → LOAEL conversion)

### Phase 29 Foundation
- `.planning/phases/29-static-data-foundations/29-CONTEXT.md` — Typed NA patterns, tibble conventions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `build_audit_trail()` in `R/cleaning_pipeline.R` — compare before/after, record changes
- `inject_row_lineage()` in `R/cleaning_pipeline.R` — adds `original_row_id` column
- Typed NA pattern: `NA_real_`, `NA_character_` for parquet compatibility

### Established Patterns
- Transformation functions return tibbles, not modified inputs
- Audit trail is separate from transformed data
- Unicode normalization via `stringr` (see existing cleaning steps)

### Integration Points
- New file: `R/numeric_parser.R` (or add to existing `R/cleaning_pipeline.R`)
- Downstream Phase 31 (Unit Harmonization) will consume parsed output
- Downstream Phase 32 (ToxVal Schema Mapper) needs `numeric_value` + `qualifier` columns

</code_context>

<specifics>
## Specific Ideas

### Range Example
Input: `"5-10"`
Output:
| orig_row_id | orig_result | numeric_value | qualifier | range_bin |
|-------------|-------------|---------------|-----------|-----------|
| 1           | 5-10        | 5             | >=        | low       |
| 1           | 5-10        | 7.5           | ~         | mid       |
| 1           | 5-10        | 10            | <=        | high      |

### Qualified Value Example
Input: `">100"`
Output:
| orig_row_id | orig_result | numeric_value | qualifier | range_bin |
|-------------|-------------|---------------|-----------|-----------|
| 1           | >100        | 100           | >         | as_is     |

### Narrative Value Example
Input: `"BDL"`
Output:
| orig_row_id | orig_result | numeric_value | qualifier | range_bin | parse_flag |
|-------------|-------------|---------------|-----------|-----------|------------|
| 1           | BDL         | NA            |           | as_is     | narrative  |

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 30-numeric-result-parser*
*Context gathered: 2026-04-14*
