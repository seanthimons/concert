---
phase: 39-duration-conversion
verified: 2026-04-26T22:00:00Z
status: human_needed
score: 8/9 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Tag a column as Duration and another as DurationUnit in the Harmonize tab, then run harmonization and export ToxVal CSV"
    expected: "study_duration_value and study_duration_units columns in the exported CSV are populated with hours-converted values matching the input"
    why_human: "End-to-end Shiny UI interaction with live file upload cannot be automated programmatically; requires visual confirmation that the tag dispatch, harmonize_units call, merge, and ToxVal mapper all produce populated fields in the final download"
---

# Phase 39: Duration Conversion — Verification Report

**Phase Goal:** Users can tag columns as DurationUnit and have the harmonization pipeline convert duration values to hours as a common base unit, with the result wired into the ToxVal schema study_duration fields.
**Verified:** 2026-04-26T22:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Duration strings like "96 hr", "14 days", "2 wk", "6 mo", "1 yr" all convert correctly to hours via harmonize_units() (SC-1) | VERIFIED | Section 17 tests pass: hr identity, day->hr (*24), wk->hr (*168), yr->hr (*8766). Section 16 confirms category filter; all 214 unit-harmonizer tests pass with 0 failures. |
| 2 | The unit table contains explicit entries for all common duration abbreviations (h/hr/hrs/hour, d/day/days, wk/week, mo/month, yr/year, min/minute, s/sec/second) with hours as base (SC-2) | VERIFIED | unit_conversion.rds has 23 duration rows (all to_unit=hr); "hrs" and case variants covered by unit_synonyms.rds (34 duration synonym rows). All required abbreviations from SC-2 are present in one of the two tables. |
| 3 | A column tagged DurationUnit in the Harmonize tab routes through duration harmonization and its output appears in study_duration_value / study_duration_units in the ToxVal export (SC-3) | VERIFIED (code path) | mod_harmonize.R Stage 4.5 present at line 387-430: looks up Duration/DurationUnit from numeric_tags_vec, calls harmonize_units(category="duration"), merges study_duration_value/study_duration_units into expanded_curated before map_to_toxval_schema(). toxval_mapper.R lines 96-97 consume these via safe_extract_num/safe_extract_char. Full end-to-end UI flow requires human verification (see Human Verification section). |
| 4 | The ambiguous "m" abbreviation is never silently treated as months — the custom synonym map resolves it to minutes and the pitfall is covered by a test (SC-4) | VERIFIED | unit_synonyms.rds has "m" -> "min" with notes "AMBIGUOUS". unit_harmonizer.R lines 622-626: ambiguous_originals <- c("m"), ambiguous_mask applied post-dedup, unit_flag set to "ambiguous_unit". Section 19 tests verify "m" produces flag "ambiguous_unit" while "min" does not. |
| 5 | harmonize_units() with category='duration' converts day values to hours (multiplier 24) | VERIFIED | unit_conversion.rds "day" row: to_unit=hr, multiplier=24. Section 17 test "day -> hr (* 24)": 14 day -> 336 hr. Passes in test suite. |
| 6 | harmonize_units() with category=NULL still works identically to before (backward compat) | VERIFIED | category parameter default is NULL (formals shows NULL). When NULL, no filter applied (lines 296-299 of unit_harmonizer.R: the if block only fires when !is.null(category)). Section 16 test "category=NULL uses all rows (backward compat)" explicitly covers this. |
| 7 | The synonym "m" normalizes to "min" and produces an "ambiguous_unit" flag in the output | VERIFIED | Directly covered by SC-4 evidence above. Section 19 test confirms 60 "m" -> 1 hr with flag "ambiguous_unit". |
| 8 | Unrecognized duration units like "dph" pass through unchanged with "unmatched" flag | VERIFIED | Section 16 test "unrecognized unit passes through with 'unmatched' flag (D-06)": 5 "dph" with duration map, category="duration" -> value=5, unit="dph", flag="unmatched". Passes. |
| 9 | curate_headless() with harmonize=TRUE and Duration/DurationUnit-tagged columns produces study_duration_value/study_duration_units in ToxVal output | VERIFIED (code path) | curate_headless.R Stage 3.5 at lines 275-293: looks up Duration/DurationUnit from tag_map, calls harmonize_units(unit_map=unit_map, category="duration"), merges into input_df before map_to_toxval_schema(curated_data=input_df). Requires human confirmation that a real headless run produces populated fields. |

**Score:** 8/9 truths verified programmatically. Truth 3 (SC-3 Shiny UI end-to-end) is structurally verified but requires human confirmation of the full UI flow.

---

### Deferred Items

None. All phase 39 scope items are addressed within this phase.

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `inst/extdata/unit_conversion.rds` | Duration conversion rows with hr as base unit | VERIFIED | 174 rows total (151 baseline + 23 duration). All 23 duration rows: category="duration", to_unit="hr". Exact fractions stored: min=1/60 (matches to floating point), s=1/3600 (matches). Confirmed via readRDS in temp R script. |
| `inst/extdata/unit_synonyms.rds` | Duration synonym normalization entries including ambiguous "m" | VERIFIED | 114 rows total (80 baseline + 34 duration synonyms). "m" -> "min" present with AMBIGUOUS notes. All 34 duration synonyms confirmed by pattern match. |
| `R/unit_harmonizer.R` | category parameter and ambiguous_unit flag logic | VERIFIED | `category = NULL` parameter in function signature (line 294). Category filter at lines 296-299. `ambiguous_originals <- c("m")` at line 622. `unit_flag[ambiguous_mask] <- "ambiguous_unit"` at line 625. Roxygen2 docs updated. |
| `tests/testthat/test-unit-harmonizer.R` | Duration-specific test sections 16-19 | VERIFIED | `make_duration_unit_map <- function()` present at line 32. SECTION 16 at line 976 (3 tests), SECTION 17 at line 1020 (6 tests), SECTION 18 at line 1063 (2 tests), SECTION 19 at line 1082 (2 tests). All 214 tests pass (0 failures, 0 warnings). |
| `R/mod_harmonize.R` | Stage 4.5 duration harmonization and Stage 5 duration merge | VERIFIED | "Stage 4.5: Duration harmonization" at line 387. harmonize_units(..., category="duration") at line 398. data_store$duration_results <- tibble::tibble() at line 400. expanded_curated$study_duration_value at line 428. expanded_curated$study_duration_units at line 429. incProgress fractions sum to 1.0 (0.15+0.30+0.25+0.15+0.05+0.10). |
| `R/curate_headless.R` | Stage 3.5 duration harmonization with input_df column merge | VERIFIED | "Stage 3.5: Duration harmonization" at line 275. harmonize_units(..., category="duration") at line 285. input_df$study_duration_value at line 288. input_df$study_duration_units at line 291. Uses `unit_map` (not unit_map_working) and `tag_map` (not merged_tags). |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `R/unit_harmonizer.R` | `inst/extdata/unit_conversion.rds` | unit_map parameter filtered by category | WIRED | Line 298: `unit_map[unit_map$category == category, , drop = FALSE]` filters to duration rows when category="duration" |
| `R/unit_harmonizer.R` | `inst/extdata/unit_synonyms.rds` | apply_synonyms() normalizes duration abbreviations | WIRED | get_unit_synonyms() loads unit_synonyms.rds via system.file(); apply_synonyms() called in harmonize_units(); confirmed at lines 39-46 of unit_harmonizer.R |
| `tests/testthat/test-unit-harmonizer.R` | `R/unit_harmonizer.R` | harmonize_units() calls with category="duration" | WIRED | 13 test_that blocks in sections 16-19 call harmonize_units with category="duration"; all pass |
| `R/mod_harmonize.R` | `R/unit_harmonizer.R` | harmonize_units(..., category='duration') | WIRED | Line 394-399: call confirmed with category="duration" inside Stage 4.5 block |
| `R/curate_headless.R` | `R/unit_harmonizer.R` | harmonize_units(..., category='duration') | WIRED | Lines 281-286: call confirmed with category="duration" inside Stage 3.5 block |
| `R/mod_harmonize.R` | `R/toxval_mapper.R` | study_duration_value/units merged into expanded_curated before map_to_toxval_schema() | WIRED | Lines 428-429 assign to expanded_curated BEFORE map_to_toxval_schema() call; toxval_mapper.R lines 96-97 consume via safe_extract_num/safe_extract_char |
| `R/curate_headless.R` | `R/toxval_mapper.R` | study_duration_value/units merged into input_df before map_to_toxval_schema() | WIRED | Lines 288-292 assign to input_df; Stage 4 map_to_toxval_schema(curated_data=input_df) follows immediately |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `R/mod_harmonize.R` (Stage 4.5) | study_duration_value | harmonize_units() called with user-uploaded column values and duration unit_map | Yes — harmonize_units() performs arithmetic conversion; values originate from user data in input_df | FLOWING |
| `R/curate_headless.R` (Stage 3.5) | study_duration_value | harmonize_units() called with input_df columns; unit_map loaded from package RDS | Yes — same conversion path; result written directly to input_df before mapper call | FLOWING |
| `R/toxval_mapper.R` | study_duration_value, study_duration_units | safe_extract_num/safe_extract_char from curated_data | Yes — columns populated upstream; safe_extract_* returns typed NA if absent (no stub) | FLOWING (conditional on duration columns being tagged by user) |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| 214 unit-harmonizer tests pass including sections 16-19 | devtools::test(filter='unit-harmonizer') | PASS 214, FAIL 0, WARN 0 | PASS |
| unit_conversion.rds has 23 duration rows all to_unit=hr | readRDS + sum(category=="duration") | 23, all to_unit=hr | PASS |
| unit_synonyms.rds has 114 rows with "m" -> "min" AMBIGUOUS | readRDS + grep | 114 rows, m->min with AMBIGUOUS notes | PASS |
| min multiplier matches 1/60 exactly | isTRUE(all.equal(mult, 1/60)) | TRUE | PASS |
| incProgress fractions in FULL MODE sum to 1.0 | Parse R source | 0.15+0.30+0.25+0.15+0.05+0.10 = 1.0 | PASS |
| harmonize_units() has category=NULL default | grep formals | category = NULL in signature | PASS |
| mod_harmonize.R Stage 4.5 strings present | grep | Stage 4.5 / category="duration" / study_duration_value all found | PASS |
| curate_headless.R Stage 3.5 strings present | grep | Stage 3.5 / category="duration" / input_df$study_duration_value all found | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| DUR-01 | 39-01 | Evaluate ECOTOX duration_unit_codes for gaps; extend with missing abbreviations | SATISFIED | 23 duration rows added covering seconds through years. ECOTOX time category (19 rows) used as baseline; all standard abbreviations present. RESEARCH.md documents assumption A4 (no additional ECOTOX-specific abbreviations required beyond the set defined). DUR-01 wording says "evaluate...and extend" — evaluation was done in research phase and findings incorporated into the 23-row set. |
| DUR-02 | 39-01 | Duration conversion rows in unit_conversion.rds with hr as base unit | SATISFIED | 23 rows confirmed: h/hr/hour/hours/d/day/days/wk/week/weeks/mo/month/months/yr/year/years/min/minute/minutes/s/sec/second/seconds all present with to_unit="hr". |
| DUR-03 | 39-02 | DurationUnit-tagged columns routed through harmonize_units() in both pipelines | SATISFIED | mod_harmonize.R Stage 4.5 and curate_headless.R Stage 3.5 both call harmonize_units(category="duration") when Duration/DurationUnit columns are tagged. |
| DUR-04 | 39-02 | Duration output wired to study_duration_value and study_duration_units in map_to_toxval_schema() | SATISFIED | Both pipelines merge study_duration_value/study_duration_units into curated data before map_to_toxval_schema() is called. toxval_mapper.R lines 96-97 consume via safe_extract_num/safe_extract_char. |
| DUR-05 | 39-01 | Custom duration synonym map; NOT lubridate::duration(); covers "m" ambiguity | SATISFIED | unit_synonyms.rds used (not lubridate). "m" -> "min" with AMBIGUOUS note. ambiguous_unit flag set in harmonize_units() post-dedup. Section 19 tests verify behavior. |

No REQUIREMENTS.md orphaned requirements for Phase 39 — all 5 DUR-xx IDs are claimed in plan frontmatter and verified above.

---

### Anti-Patterns Found

Scanned files: `R/unit_harmonizer.R`, `R/mod_harmonize.R`, `R/curate_headless.R`, `tests/testthat/test-unit-harmonizer.R`

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| None found in phase 39 additions | — | — | — |

No TODOs, FIXMEs, placeholder returns, or hardcoded empty stubs detected in the new code paths introduced by this phase. The pre-existing 3 test failures noted in the SUMMARY are unrelated to duration work (pre-existing regression, not introduced by this phase).

---

### Human Verification Required

#### 1. Shiny UI End-to-End Duration Export

**Test:** Upload a CSV that has a numeric duration column (e.g., "exposure_time") and a unit column (e.g., "time_unit"). In the Harmonize tab, tag "exposure_time" as Duration and "time_unit" as DurationUnit. Run harmonization. Download the ToxVal export.

**Expected:** The downloaded ToxVal CSV has non-NA values in `study_duration_value` (converted to hours) and `study_duration_units` (="hr") for rows where the input had recognized duration units like "day", "hr", or "wk". The conversion arithmetic matches: e.g., 14 "day" should yield study_duration_value = 336.

**Why human:** The Shiny tag dispatch (numeric_tags_vec lookup), Stage 4.5 execution inside the withProgress block, and the resulting ToxVal CSV download all involve live reactive state that cannot be exercised with grep or unit tests alone. The cold boot test confirms the app starts, but not that duration tagging flows through to export.

---

### Gaps Summary

No blocking gaps found. All artifacts exist and are substantive. All key links are wired. Data flows from user-tagged columns through harmonize_units(category="duration") to study_duration_value/units in the ToxVal schema via both pipeline paths.

The single human_needed item is the full UI flow confirmation — code inspection confirms every connection point is wired correctly, but the live Shiny interaction requires human confirmation that the reactive plumbing fires as expected when a user performs the tag-and-export workflow.

---

_Verified: 2026-04-26T22:00:00Z_
_Verifier: Claude (gsd-verifier)_
