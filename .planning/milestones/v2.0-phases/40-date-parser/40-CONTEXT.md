# Phase 40: Date Parser - Context

**Gathered:** 2026-04-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can tag columns as StudyDate and have the harmonization pipeline parse mixed-format date strings into ISO-8601 structured output with ambiguity flagging. The result populates `original_year` in the ToxVal schema via `date_year`. No new UI tab, no date range parsing (DFUT-01), no duration changes (Phase 39 complete), no media harmonization (Phase 41).

</domain>

<decisions>
## Implementation Decisions

### Format Priority & Parse Order
- **D-01:** Parse order is YMD → MDY → DMY (plus SAS/year-only formats). ISO formats get priority, then US convention, then European. This is the `orders` argument to `lubridate::parse_date_time()`.
- **D-02:** For non-ISO slash-separated dates, fallback after YMD is MDY then DMY. '01/02/2024' parses as MDY (January 2nd) since YMD fails on it and MDY comes before DMY in the order.

### Partial Date Handling
- **D-03:** Year-only entries (e.g., "2015") impute to January 1st: `parsed_date = "2015-01-01"`, `date_year = 2015`, `date_flag = "partial"`. Missing day/month components default to 1.
- **D-04:** Month-year entries (e.g., "Jan 2015", "2015-03") impute day to 1st of month: `parsed_date = "2015-01-01"` or `"2015-03-01"`, `date_year = 2015`, `date_flag = "partial"`. Same imputation rule as year-only.
- **D-05:** `date_year` is always populated from whatever year information is available, even when `parsed_date` gets a partial flag. This is the primary field feeding ToxVal `original_year`.

### Ambiguity Surfacing
- **D-06:** Ambiguous dates (day <= 12 AND month <= 12, per DATE-03) surface in the QC dashboard as a value box count alongside existing QC metrics. Also exported in the harmonization audit sheet. Advisory only — does not gate export. Matches the existing `unit_flag` surfacing pattern from unit harmonization.
- **D-07:** No new column in the ToxVal schema. The `date_flag` lives in the audit/QC layer, not in the 56-column schema output.

### 2-Digit Year Handling
- **D-08:** 2-digit years use a custom cutoff via lubridate's `cutoff_2000` parameter. Claude selects the specific threshold value during implementation based on regulatory data ranges.
- **D-09:** ALL dates parsed from 2-digit year inputs receive `date_flag = "inferred_format"` regardless of the cutoff logic. Belt-and-suspenders: the cutoff provides the best guess, the flag ensures downstream review.

### Unparseable & Empty Handling
- **D-10:** Unparseable strings ("N/A", "ongoing", "not reported", "TBD", empty, NA) produce `parsed_date = NA`, `date_year = NA`, `date_flag = "unparseable"`. Raw string preserved in audit trail for traceability.
- **D-11:** Consistent with `harmonize_units()` behavior for unrecognized units — pass-through with flag, no data loss, no type-breaking mixed columns.

### Dedup Eligibility
- **D-12:** `parse_dates()` is dedup-eligible. Wrap with `dedup_step()` at the orchestrator level (same pattern as cleaning pipeline steps per Phase 37 D-11). Date strings are highly duplicative in regulatory datasets — many rows share study dates.

### Tag Classification
- **D-13:** New `study_types` group in `classify_tags()` containing `"StudyDate"`. Separate from `numeric_types` (Result, Unit, Qualifier, Duration, DurationUnit) and `metadata_types` (Species, ExposureRoute). Phase 41's Media tag will also go in `study_types`.
- **D-14:** Tag Columns dropdown gets a third optgroup label (e.g., "Study/Contextual") for the new group.

### Tag Style
- **D-15:** StudyDate is a single tag — no companion format hint tag. User tags one column, parser auto-detects format using the YMD→MDY→DMY order. Simplest UX, matches how dates appear in regulatory data.

### Pipeline Wiring (Carried Forward)
- **D-16:** Harmonization results merge into `expanded_curated` BEFORE `map_to_toxval_schema()` — same pattern as duration (Phase 39 D-10/D-11). `date_year` populates `original_year` via existing `safe_extract_num(curated_data, "year", n_rows)` in the mapper.
- **D-17:** Date parsing slots in as a new stage in the harmonization pipeline (after duration harmonization, before ToxVal mapping). Stage numbering at Claude's discretion.
- **D-18:** `curate_headless()` gains Stage 3c conditional call for StudyDate-tagged columns, mirroring the duration Stage 3.5 pattern.

### Claude's Discretion
- Exact `orders` vector for `lubridate::parse_date_time()` (must include ymd, mdy, dmy, dBY for SAS, Y for year-only, Ym for month-year, plus any other needed formats)
- Specific 2-digit year cutoff value for `cutoff_2000` parameter
- Stage numbering and progress bar percentages in `mod_harmonize.R`
- Internal implementation of `parse_dates()` — vectorized vs. row-level detection of ambiguity
- Test structure for DATE-03 ambiguity detection and DATE-02 output schema
- QC dashboard value box placement and label text
- How `study_types` integrates with the optgroup rendering in `mod_tag_columns.R`

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` — DATE-01 through DATE-06 requirements
- `.planning/ROADMAP.md` — Phase 40 success criteria (4 criteria)

### Research & Pitfalls
- `.planning/research/STACK.md` §1 "lubridate — Date/Study Date Parsing" — verified format coverage, datefixR rejection rationale
- `.planning/research/PITFALLS.md` §"v2.0 Pitfall 3" — ambiguous date format silent wrong-month parsing, mitigation strategies
- `.planning/research/SUMMARY.md` — lubridate → Imports decision, datefixR rejection

### Phase 39 Context (Duration Pattern)
- `.planning/phases/39-duration-conversion/39-CONTEXT.md` — D-10/D-11 (merge before mapper), D-12/D-13 (stage insertion), D-01 (ambiguity flag pattern)

### Phase 37 Context (Dedup Architecture)
- `.planning/phases/37-performance-architecture/37-CONTEXT.md` — D-11 (dedup as orchestrator wrapper), D-12 (short-circuit orchestrator-only)

### Tag System
- `R/tag_helpers.R` — `classify_tags()` with current `numeric_types` and `metadata_types` groups (line 38-39). StudyDate needs new `study_types` group.
- `R/tag_dispatch.R` — Tag dispatch helpers, single source of truth for tag classification

### ToxVal Schema
- `R/toxval_mapper.R` — `map_to_toxval_schema()` with `original_year = safe_extract_num(curated_data, "year", n_rows)` (line 153). Date parser output needs to feed this.
- `inst/extdata/toxval_schema.rds` — 56-column schema manifest (no changes needed — original_year already exists)

### Pipeline Integration Points
- `R/mod_harmonize.R` — Stage 4.5 duration harmonization (line 387-429) as template for date stage insertion. `expanded_curated` construction (line 415-429).
- `R/curate_headless.R` — Stage 3.5 duration harmonization (line 275-295) as template for headless date path.

### Tag Columns UI
- `R/mod_tag_columns.R` — Tag dropdown rendering, optgroup structure. Needs third optgroup for study_types.

### Existing Tests
- `tests/testthat/test-tag-dispatch.R` — Tag classification tests (line 20-21, 140-141)
- `tests/testthat/test-toxval-mapper.R` — original_year tests (line 244-252)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `harmonize_units()`: Full normalize→synonym→convert pipeline with dedup. Date parsing is a NEW function (`parse_dates()`) but follows the same integration pattern.
- `safe_extract_num()` / `safe_extract_char()`: ToxVal mapper helpers. `original_year` already wired via `safe_extract_num(curated_data, "year", n_rows)` — date output needs to populate a "year" column or rename the extraction.
- `dedup_step()` + `remap_audit_to_parent()`: Phase 37 infrastructure. Date parsing gets this wrapping at the orchestrator level.
- Duration wiring in `mod_harmonize.R` (Stage 4.5, lines 387-429) and `curate_headless.R` (Stage 3.5, lines 275-295): Direct template for date stage insertion.

### Established Patterns
- Single-column tagging for dates (unlike paired Duration/DurationUnit). `classify_tags()` returns index lists per group — new `study_types` group follows same structure.
- Stage-based pipeline in `mod_harmonize.R`: corrections → parse → harmonize → duration → ToxVal map. Date parsing slots in after duration.
- `expanded_curated` construction from `resolution_state` via `orig_row_id` indexing. Date results merge into this before the mapper call.
- QC dashboard value boxes in mod_harmonize.R for existing flags — date ambiguity count adds another box.

### Integration Points
- `mod_harmonize.R` after duration stage: Date stage inserts here
- `curate_headless.R` after Stage 3.5: Same insertion point for headless path
- `classify_tags()`: Gains `study_types` group with StudyDate
- `mod_tag_columns.R`: Gains third optgroup in dropdown for study_types
- `R/date_parser.R`: New file — `parse_dates()` function
- DESCRIPTION: `lubridate` added to Imports

</code_context>

<specifics>
## Specific Ideas

- YMD-first parse order reflects user preference for ISO standard priority, with MDY as fallback matching EPA/ECOTOX dominant format
- Imputation rule (missing components → 1) is consistent and predictable: "2015" → Jan 1 2015, "Mar 2015" → Mar 1 2015
- The `study_types` tag group creates a clean home for both StudyDate (Phase 40) and Media (Phase 41) — avoids overloading numeric_types or metadata_types
- 2-digit year belt-and-suspenders: custom cutoff gives best-guess interpretation, `inferred_format` flag ensures visibility regardless

</specifics>

<deferred>
## Deferred Ideas

- Date range parsing ("1990-1995", "Jan-Mar 2020") → DFUT-01 (future milestone)
- DateFormat companion tag for per-dataset format override → could be added later if auto-detection proves insufficient for specific datasets
- `study_duration_class` population (acute/chronic based on parsed dates and durations) → not in Phase 40 scope

None — discussion stayed within phase scope

</deferred>

---

*Phase: 40-date-parser*
*Context gathered: 2026-04-26*
