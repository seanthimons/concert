# Phase 39: Duration Conversion - Research

**Researched:** 2026-04-26
**Domain:** Unit harmonization extension — duration category
**Confidence:** HIGH

## Summary

Phase 39 is a targeted extension of the existing `harmonize_units()` machinery. The existing "time"
category in `unit_conversion.rds` already covers the right abbreviations but targets days as base
unit. Duration needs a parallel "duration" category with hours as base. The `harmonize_units()`
function gains a `category` parameter to filter the conversion table. Two pipeline entry points
(mod_harmonize.R and curate_headless.R) gain a new stage that routes DurationUnit-tagged columns
through this filtered call and merges results into `expanded_curated` before `map_to_toxval_schema()`.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- D-07: Duration rows go into existing `unit_conversion.rds` with `category="duration"`, `to_unit="hr"`
- D-08: Duration synonyms added to existing `unit_synonyms.rds` (same 4-column schema)
- D-09: Hours is canonical base unit for all duration conversions
- D-10: Harmonized results merge into `expanded_curated` BEFORE `map_to_toxval_schema()`
- D-12: `harmonize_units()` gains `category=NULL` parameter (NULL = all categories, backward-compat)
- D-13: Duration stage slots between Stage 3 and Stage 5 in mod_harmonize.R (Stage 3→5 gap)
- D-01: Bare "m" maps to minutes with `ambiguous_unit` flag in audit trail
- D-02: Research ECOTOX list for additional ambiguous abbreviations beyond "m"
- D-03: Only simple "number unit" patterns parsed; decimal fractions work naturally
- D-04: Compound expressions and ranges flagged as unparseable (ranges deferred to DFUT-02)
- D-05: Paired column pattern — Duration (numeric) + DurationUnit (string)
- D-06: Unrecognized units pass through unchanged with `unit_unrecognized` flag (matches existing behavior)
- D-15: `classify_tags()` already has Duration/DurationUnit in `numeric_types` — no change needed

### Claude's Discretion
- Exact set of duration abbreviation rows (research ECOTOX `duration_unit_codes` for completeness)
- Which abbreviations beyond "m" get the ambiguous flag
- Internal implementation of the `category` filter in `harmonize_units()`
- Stage numbering and progress bar percentages in `mod_harmonize.R`
- Test structure for DUR-05 "m" ambiguity coverage

### Deferred Ideas (OUT OF SCOPE)
- Duration ranges ("96-120 hr") — DFUT-02
- Multi-unit compound expressions ("1 day 12 hours")
- `study_duration_class` population (acute/chronic/subchronic)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DUR-01 | Evaluate ECOTOX duration_unit_codes for gaps; extend with missing abbreviations | Existing "time" category rows provide baseline; duration category adds hr-base variants |
| DUR-02 | Duration conversion rows in unit_conversion.rds with hr as base | 6-column schema confirmed; multipliers derived from existing time rows (invert days->hr) |
| DUR-03 | DurationUnit-tagged columns routed through harmonize_units() in both pipelines | Insertion points confirmed: mod_harmonize.R line ~369 (after Stage 3), curate_headless.R line ~282 (after Stage 3) |
| DUR-04 | Duration output wired to study_duration_value / study_duration_units | toxval_mapper.R already uses safe_extract_num/char — upstream merge is sufficient |
| DUR-05 | Custom synonym map for duration; NOT lubridate::duration() | unit_synonyms.rds is the correct home; "m" ambiguity flag pattern established |
</phase_requirements>

---

## Current State of Files to Modify

### `inst/extdata/unit_conversion.rds`
- **Schema (6 columns):** `from_unit`, `to_unit`, `multiplier`, `category`, `confidence`, `source`
- **Current rows:** 151 total; 15 categories
- **Existing "time" category:** 19 rows, `to_unit="day"`, source=ECOTOX
  - Covers: day/d/days, hr/h/hour/hours, min/minute/minutes, wk/week/weeks, mo/month/months, yr/year/years
- **Action:** Add ~19 parallel "duration" rows with `to_unit="hr"`, `category="duration"`, `source="ECOTOX"`
  [VERIFIED: read from actual RDS file]

### `inst/extdata/unit_synonyms.rds`
- **Schema (4 columns):** `input_pattern`, `normalized_unit`, `is_regex`, `notes`
- **Current rows:** 80
- **Existing patterns:** Exact-match (is_regex=FALSE) for abbreviation normalization; regex for structural variants
- **Action:** Add duration-specific abbreviation entries (see Synonym Rows section below)
  [VERIFIED: read from actual RDS file]

### `R/unit_harmonizer.R`
- **`harmonize_units()` signature:** `function(values, units, unit_map, media=NULL, dtxsid=NULL, molecular_weight=NULL, use_dedup=TRUE)`
- **`unit_map` parameter:** Already a passed-in tibble — the `category` filter will be applied by the CALLER before passing `unit_map`, OR by adding a `category` parameter that filters internally
- **Dedup logic:** Intact; "standard" path does hash lookup against `unit_map$from_unit`
- **Action:** Add `category=NULL` parameter; when non-NULL, `unit_map <- unit_map[unit_map$category == category, ]` before processing
  [VERIFIED: read full function]

### `R/mod_harmonize.R` — Insertion Point
- **Stage 3** (lines 341-366): Harmonizes Result/Unit columns, stores result in `harmonize_tibble`
- **Stage 4** (lines 368-385): Stores `harmonize_tibble` into `data_store$harmonize_results` and audit
- **Stage 5** (lines 387-408): `expanded_curated <- data_store$resolution_state[harmonize_tibble$orig_row_id, ]` then `map_to_toxval_schema(curated_data=expanded_curated, ...)`
- **Duration stage inserts between Stage 4 and Stage 5** — after harmonize results stored, before expanded_curated is built
- **Pattern:** Check `if (length(duration_unit_cols) > 0)`, call `harmonize_units(..., category="duration")`, join `study_duration_value` and `study_duration_units` columns onto `expanded_curated` by orig_row_id
  [VERIFIED: read lines 330-410]

### `R/curate_headless.R` — Insertion Point
- **Stage 3** ends at line ~261 (harmonize_tibble constructed)
- **Stage 4** (lines 275-282): `map_to_toxval_schema(curated_data=input_df, harmonized_data=harmonize_tibble, ...)`
- **Note:** Headless passes `input_df` directly as `curated_data` — NOT an expanded form
- **Duration stage inserts between Stage 3 and Stage 4** — add duration harmonization, join columns onto `input_df` before mapper call
  [VERIFIED: read lines 255-285]

### `R/toxval_mapper.R` — No Change Needed
- Lines 96-97: `study_duration_value = safe_extract_num(curated_data, "study_duration_value", n_rows)` and `study_duration_units = safe_extract_char(curated_data, "study_duration_units", n_rows)`
- Lines 141-142: `*_original` audit columns use same `safe_extract_*` pattern
- `safe_extract_*` returns typed NA if column absent — upstream column merge is sufficient
  [VERIFIED: grep on toxval_mapper.R]

### `R/tag_helpers.R` — No Change Needed
- Line 38: `numeric_types <- c("Result", "Unit", "Qualifier", "Duration", "DurationUnit")`
- Duration and DurationUnit already in `numeric_types` — tag dispatch works as-is
  [VERIFIED: grep on tag_helpers.R]

---

## Duration Conversion Rows to Add

All rows use schema: `from_unit, to_unit="hr", multiplier, category="duration", confidence="HIGH", source="ECOTOX"`

| from_unit | multiplier (to hr) | Notes |
|-----------|-------------------|-------|
| hr | 1 | canonical base |
| h | 1 | common abbreviation |
| hour | 1 | spelled out |
| hours | 1 | plural |
| day | 24 | |
| d | 24 | |
| days | 24 | |
| wk | 168 | 7*24 |
| week | 168 | |
| weeks | 168 | |
| mo | 730.5 | 30.4375*24 |
| month | 730.5 | |
| months | 730.5 | |
| yr | 8766 | 365.25*24 |
| year | 8766 | |
| years | 8766 | |
| min | 0.016667 | 1/60 |
| minute | 0.016667 | |
| minutes | 0.016667 | |
| s | 0.000278 | 1/3600 |
| sec | 0.000278 | |
| second | 0.000278 | |
| seconds | 0.000278 | |

[ASSUMED: multiplier precision — use exact fractions (e.g., 1/60) not rounded decimals in RDS]

## Duration Synonym Rows to Add (unit_synonyms.rds)

These normalize real-world variants to canonical `from_unit` strings above:

| input_pattern | normalized_unit | is_regex | notes |
|---------------|----------------|----------|-------|
| hrs | hr | FALSE | Duration plural abbreviation |
| Hr | hr | FALSE | Duration capitalized |
| HR | hr | FALSE | Duration uppercase |
| Hrs | hr | FALSE | Duration capitalized plural |
| HRS | hr | FALSE | Duration uppercase plural |
| Day | day | FALSE | Duration capitalized |
| DAY | day | FALSE | Duration uppercase |
| Days | day | FALSE | Duration capitalized plural |
| DAYS | day | FALSE | Duration uppercase plural |
| Wk | wk | FALSE | Duration capitalized |
| WK | wk | FALSE | Duration uppercase |
| Week | week | FALSE | Duration capitalized |
| WEEK | week | FALSE | Duration uppercase |
| Weeks | week | FALSE | Duration capitalized plural |
| WEEKS | week | FALSE | Duration uppercase plural |
| Mo | mo | FALSE | Duration capitalized |
| MO | mo | FALSE | Duration uppercase |
| Month | month | FALSE | Duration capitalized |
| MONTH | month | FALSE | Duration uppercase |
| Months | month | FALSE | Duration capitalized plural |
| MONTHS | month | FALSE | Duration uppercase plural |
| Yr | yr | FALSE | Duration capitalized |
| YR | yr | FALSE | Duration uppercase |
| Year | year | FALSE | Duration capitalized |
| YEAR | year | FALSE | Duration uppercase |
| Years | year | FALSE | Duration capitalized plural |
| YEARS | year | FALSE | Duration uppercase plural |
| Min | min | FALSE | Duration capitalized |
| MIN | min | FALSE | Duration uppercase |
| Minute | minute | FALSE | Duration capitalized |
| Sec | sec | FALSE | Duration capitalized |
| SEC | sec | FALSE | Duration uppercase |
| Second | second | FALSE | Duration capitalized |
| m | min | FALSE | AMBIGUOUS — maps to minutes; flag as ambiguous_unit |

[ASSUMED: The exact set of ECOTOX abbreviations not covered above — DUR-01 requires checking ECOTOX duration_unit_codes table for additional entries like "dph" (days post-hatch), "dpf" (days post-fertilization), etc. These are out of normal scope but DUR-01 requires evaluation.]

---

## `harmonize_units()` API Change

Add `category = NULL` parameter. Insert one filter line before the dedup key construction:

```r
harmonize_units <- function(
  values, units, unit_map,
  media = NULL, dtxsid = NULL, molecular_weight = NULL,
  use_dedup = TRUE,
  category = NULL   # NEW: filter conversion table to this category
) {
  # NEW: category filter (D-12)
  if (!is.null(category)) {
    unit_map <- unit_map[unit_map$category == category, , drop = FALSE]
  }
  # ... rest unchanged
```

This preserves backward compatibility (NULL = all rows). [VERIFIED: function structure read]

---

## mod_harmonize.R Stage Insertion

The duration stage runs AFTER the audit is stored (Stage 4) and BEFORE `expanded_curated` is built:

```r
# Stage 4.5: Duration harmonization (if Duration/DurationUnit columns tagged)
incProgress(0.05, detail = "Harmonizing durations...")
duration_cols <- names(column_tags)[column_tags == "Duration"]
duration_unit_cols <- names(column_tags)[column_tags == "DurationUnit"]
if (length(duration_cols) > 0 && length(duration_unit_cols) > 0) {
  dur_values <- as.numeric(input_df[[duration_cols[1]]])
  dur_units  <- as.character(input_df[[duration_unit_cols[1]]])
  dur_tibble <- harmonize_units(
    values   = dur_values,
    units    = dur_units,
    unit_map = data_store$unit_map_working,
    category = "duration"
  )
  # Join results; columns used by toxval_mapper via safe_extract_*
  dur_join <- tibble::tibble(
    orig_row_id           = dur_tibble$orig_row_id,
    study_duration_value  = dur_tibble$harmonized_value,
    study_duration_units  = dur_tibble$harmonized_unit
  )
  # Store for use in Stage 5 expanded_curated construction
  data_store$duration_results <- dur_join
}

# Stage 5: Map to ToxVal schema
expanded_curated <- data_store$resolution_state[harmonize_tibble$orig_row_id, ]
# Merge duration columns if present
if (!is.null(data_store$duration_results)) {
  expanded_curated <- dplyr::left_join(
    expanded_curated,
    data_store$duration_results,
    by = "orig_row_id"   # NOTE: verify resolution_state has orig_row_id
  )
}
toxval_tibble <- map_to_toxval_schema(...)
```

[ASSUMED: `resolution_state` has an `orig_row_id` column — verify before implementing. If not, join by row position.]

---

## curate_headless.R Stage Insertion

After Stage 3 (harmonize_tibble constructed), before Stage 4 (map_to_toxval_schema):

```r
# Stage 3.5: Duration harmonization
duration_cols      <- names(merged_tags)[merged_tags == "Duration"]
duration_unit_cols <- names(merged_tags)[merged_tags == "DurationUnit"]
if (length(duration_cols) > 0 && length(duration_unit_cols) > 0) {
  dur_tibble <- harmonize_units(
    values   = as.numeric(input_df[[duration_cols[1]]]),
    units    = as.character(input_df[[duration_unit_cols[1]]]),
    unit_map = unit_map,
    category = "duration"
  )
  input_df$study_duration_value <- dur_tibble$harmonized_value[
    match(seq_len(nrow(input_df)), dur_tibble$orig_row_id)
  ]
  input_df$study_duration_units <- dur_tibble$harmonized_unit[
    match(seq_len(nrow(input_df)), dur_tibble$orig_row_id)
  ]
}
# Stage 4: map_to_toxval_schema(curated_data = input_df, ...)  -- unchanged
```

[ASSUMED: variable name for `unit_map` in curate_headless.R — verify the actual variable name used at the Stage 3 call site.]

---

## Common Pitfalls

### "m" Ambiguity
The existing "time" category has no "m" row (ECOTOX uses "min"). The new synonym maps "m" → "min"
with an `ambiguous_unit` flag per D-01. The flag must be added to the audit output. Current
`unit_flag` values are: `""`, `"case_fallback"`, `"unmatched"`, `"needs_mw"`, `"media_inferred"`.
Adding `"ambiguous_unit"` requires either: (a) a post-processing step that checks synonyms for
ambiguous entries and overwrites the flag, or (b) a special-case in `apply_synonyms()`. Option (a)
is simpler and keeps `apply_synonyms()` clean.

### unit_map_working vs. load_unit_map()
In mod_harmonize.R, the conversion table is `data_store$unit_map_working` (the user's working copy).
In curate_headless.R, verify the variable name — it may be loaded separately. Both must include the
new duration rows once the RDS is updated.

### Existing "time" Category Conflict
The "time" category rows (days as base) are NOT removed (D-07 backward compatibility). The
`category="duration"` filter ensures the duration call only uses the hr-base rows. Any code that
calls `harmonize_units()` without a category filter continues to see both "time" and "duration" rows
— this could cause duplicate `from_unit` keys (e.g., "day" appears in both). The hash lookup will
match whichever appears first. This is safe only if Result/Unit columns never mix time units from
both categories. If overlap is a concern, document that the unfiltered call returns whichever row
appears first for ambiguous units like "day".

### resolution_state Join Key
The Stage 5 code in mod_harmonize.R builds `expanded_curated` by row-indexing resolution_state
with `harmonize_tibble$orig_row_id`. Duration results use 1-based row IDs into `input_df` (not the
parse-expanded tibble). The join must account for this misalignment: duration rows reference
`input_df` positions, while `expanded_curated` rows reference parse-expanded positions. Join by
`orig_row_id` only works if both index the same base table. Verify before implementing.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Multiplier precision: use exact fractions in RDS | Conversion Rows | Rounding error in converted values |
| A2 | resolution_state has orig_row_id column for join | mod_harmonize insertion | Join fails; need row-position match instead |
| A3 | curate_headless unit_map variable name | curate_headless insertion | Wrong variable name causes R error |
| A4 | ECOTOX duration_unit_codes has no additional required abbreviations beyond the set listed | DUR-01 | Missing real-world abbreviations; DUR-01 says to evaluate the full list |
| A5 | "m" is the only genuinely ambiguous abbreviation in the duration domain | D-02 | Other ambiguous abbreviations missed; audit incomplete |

---

## Sources

### Primary (HIGH confidence)
- `inst/extdata/unit_conversion.rds` — read directly; 6-column schema, 19 time rows confirmed
- `inst/extdata/unit_synonyms.rds` — read directly; 4-column schema, 80 rows confirmed
- `R/unit_harmonizer.R` — full source read; harmonize_units() signature and internals confirmed
- `R/mod_harmonize.R` lines 330-410 — Stage 3, 4, 5 structure confirmed
- `R/curate_headless.R` lines 255-285 — Stage 3→4 insertion point confirmed
- `R/toxval_mapper.R` — study_duration_value/units wiring at lines 96-97, 141-142 confirmed
- `R/tag_helpers.R` — Duration/DurationUnit in numeric_types at line 38 confirmed

---

## RESEARCH COMPLETE
