# Phase 30: Numeric Result Parser - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-14
**Phase:** 30-numeric-result-parser
**Areas discussed:** Non-numeric values, Range midpoint logic, Output integration, Error behavior

---

## Non-numeric Values

| Option | Description | Selected |
|--------|-------------|----------|
| Flag and NA | Parse as NA with parse_flag = "narrative", downstream filters | |
| Lookup table mapping | Map known terms (BDL, ND) to semantic values or half-detection-limit | |
| Pass-through with flag | Keep original string, set numeric_value = NA, let user decide later | ✓ |

**User's choice:** Pass-through with flag
**Notes:** Aligns with existing conservative pattern — don't auto-convert, preserve original, user handles downstream.

---

## Range Midpoint Logic

### 2a. Midpoint calculation

| Option | Description | Selected |
|--------|-------------|----------|
| Always 3 rows | low/mid/high for every range | ✓ |
| Just 2 rows | low/high only, midpoint calculated on demand | |
| Configurable | default to 3, allow toggle | |

**User's choice:** Always 3 rows

### 2b. One-sided ranges

| Option | Description | Selected |
|--------|-------------|----------|
| Single row with qualifier | numeric_value = 100, qualifier = ">", range_bin = "as_is" | ✓ |
| Treat as open range | >100 becomes low=100, mid=NA, high=NA/Inf | |
| Flag for review | parse_flag = "one_sided_range", user decides | |

**User's choice:** Single row with qualifier. Qualifiers and ranges are distinct concepts.

### 2c. Range row qualifiers (follow-up)

| Option | Description | Selected |
|--------|-------------|----------|
| Keep as-is | range_bin provides context, only midpoint gets ~ | |
| All range rows get ~ | Since original was range, all values are contextual | |
| Use >= / <= for bounds | Low = >=, Mid = ~, High = <= (semantic encoding) | ✓ |

**User's choice:** Semantic qualifiers for bounds. Low gets `>=` (at least this), high gets `<=` (at most this), mid gets `~` (derived).

---

## Output Integration

| Option | Description | Selected |
|--------|-------------|----------|
| New tibble | Parser returns standalone tibble with orig_row_id, caller joins | ✓ |
| Append columns | Parser modifies input tibble in place, handles row multiplication internally | |
| Column + expansion tibble | Return list with $parsed and $expanded separate tibbles | |

**User's choice:** Standalone parsed tibble with orig_row_id for linkage.
**Notes:** User confirmed qualifier should use toxvaldb conventions. From literature: valid qualifiers are `=`, `~`, `>`, `>=`, `<`, `<=`. 79% of ToxValDB records have no qualifier or `=`. No qualifier in source → empty string.

---

## Error Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Silent NA with flag | numeric_value = NA, parse_flag = "unparseable", pipeline continues | |
| Collect and warn | Same as above, but emit warning summarizing failure count | ✓ |
| Strict error | Stop pipeline if any value is unparseable | |

**User's choice:** Collect and warn

---

## Claude's Discretion

- Normalization order within PARS-01 chain
- Regex patterns for qualifier extraction and range detection
- Internal helper function organization
- Test case selection beyond requirements

## Deferred Ideas

None — discussion stayed within phase scope.
