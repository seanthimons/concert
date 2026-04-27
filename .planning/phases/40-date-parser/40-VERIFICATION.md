---
phase: 40-date-parser
verified: 2026-04-27T12:00:00Z
status: gaps_found
score: 10/12 must-haves verified
overrides_applied: 0
gaps:
  - truth: "curate_headless() with StudyDate-tagged columns produces year column in input_df before ToxVal mapping"
    status: failed
    reason: "curate_headless() has a hard stop at line 207 — stop('harmonize=TRUE requires at least one column tagged as Result') — that fires before the date stage is reached. A StudyDate-only invocation (no Result column) is a valid use case per the roadmap but produces an error in the headless path. The Shiny path handles StudyDate-only correctly via lines 397-418 identity tibble; curate_headless.R never received the same bypass."
    artifacts:
      - path: "R/curate_headless.R"
        issue: "Line 206-208: hard stop blocks StudyDate-only harmonize calls — missing identity parse/harmonize tibble branch for has_numeric=FALSE"
    missing:
      - "Mirror the Shiny module's StudyDate-only guard: check has_study = length(names(tag_map)[tag_map == 'StudyDate']) > 0, and if !has_numeric && has_study build identity parse/harmonize tibbles before proceeding to date stage"
      - "Update the stop() message to mention StudyDate as an alternative to Result"
  - truth: "curate_headless() with StudyDate-tagged columns and harmonize=TRUE produces identical output to Shiny interactive path"
    status: failed
    reason: "Follows from the gap above — since curate_headless() throws before reaching Stage 3c when no Result column is present, the headless and Shiny paths produce non-identical output for StudyDate-only runs. Additionally, 40-03-SUMMARY.md is absent, which is the documented artifact for Plan 03 completion."
    artifacts:
      - path: "R/curate_headless.R"
        issue: "StudyDate-only harmonize path not reachable"
      - path: ".planning/phases/40-date-parser/40-03-SUMMARY.md"
        issue: "File does not exist — Plan 03 SUMMARY was not created"
    missing:
      - "Fix the curate_headless() StudyDate-only gap (see gap above)"
      - "Create 40-03-SUMMARY.md documenting Plan 03 execution and outcomes"
deferred: []
human_verification:
  - test: "Shiny app cold boot"
    expected: "App starts without error and prints 'Listening on http://127.0.0.1:3838'; no missing icon errors, no source() failures, no module wiring crashes"
    why_human: "Cannot start a Shiny server in the verification environment; plan specified a human checkpoint for Task 3 of Plan 03"
  - test: "StudyDate tag dropdown in Tag Columns tab"
    expected: "Dropdown shows 'Study / Contextual' optgroup containing 'Study Date' entry; tagging a column and clicking Apply Tags populates study_type_tags in data_store"
    why_human: "UI rendering and interactive Shiny state cannot be verified programmatically"
  - test: "Harmonize button enable for StudyDate-only tagging"
    expected: "After tagging only a StudyDate column (no Result/Unit), the 'Run Harmonization' button becomes enabled"
    why_human: "Requires interactive session to verify the observe() enable/disable reactive fires correctly"
  - test: "QC dashboard date value boxes after harmonization"
    expected: "After clicking Run Harmonization with a StudyDate-tagged column, the QC dashboard shows a second row of four value boxes: Dates Parsed, Partial Dates, Ambiguous Dates, Unparseable Dates — with correct counts"
    why_human: "Requires running the full harmonization pipeline with test data against a live Shiny session"
---

# Phase 40: Date Parser Verification Report

**Phase Goal:** Users can tag columns as StudyDate and have the harmonization pipeline parse mixed-format date strings into ISO-8601 structured output with ambiguity flagging, wired to the ToxVal `original_year` field.
**Verified:** 2026-04-27T12:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

The roadmap defines four success criteria. The three plan frontmatter must-haves not already covered by roadmap SCs are merged in. All are assessed below.

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `parse_dates()` correctly parses ISO, MDY, DMY, SAS, YYYYMMDD, year-only, and 2-digit year formats from a single mixed-format column | VERIFIED | R/date_parser.R exists, 111 lines, ORDERS vector correct, train=FALSE present; 32 test_that blocks across 7 sections with format-family coverage; commit f5e05e4 |
| 2 | Dates where both day and month are <= 12 are flagged as "ambiguous" in the audit trail | VERIFIED | date_parser.R lines 88-91: is_ambiguous logic with !is_partial guard; test-date-parser.R Section 3 has three dedicated tests including "01/02/2015" -> ambiguous and "13/02/2015" -> not ambiguous |
| 3 | Dates where day <= 12 AND month <= 12 are NOT silently assigned — flagged as "ambiguous" | VERIFIED | Same as #2; dplyr::case_when() at lines 95-101 enforces flag priority; ambiguous flag correctly placed below partial and inferred_format in priority |
| 4 | A column tagged StudyDate in the Harmonize tab routes through parse_dates() in Stage 4.6 and its date_year output populates expanded_curated$year before ToxVal mapping | VERIFIED | mod_harmonize.R lines 442-501: Stage 4.6 block with parse_dates() call; lines 528-531: expanded_curated$year assignment from date_results$date_year; toxval_mapper.R line 153: original_year = safe_extract_num(curated_data, "year", n_rows) |
| 5 | curate_headless() with harmonize=TRUE and StudyDate-tagged columns processes dates and produces year column before ToxVal mapping | FAILED | curate_headless.R line 206-208: hard stop fires before Stage 3c if no Result column present — StudyDate-only invocation errors out. Stage 3c code at lines 296-309 is unreachable without a Result column. |
| 6 | curate_headless() with StudyDate-tagged columns produces identical output to the Shiny interactive path | FAILED | Shiny path (mod_harmonize.R lines 397-418) has explicit identity-tibble branch for StudyDate-only runs; curate_headless.R lacks this bypass. The paths diverge for StudyDate-only use cases. |
| 7 | classify_tags() returns a 4-element list with chemical_tags, numeric_tags, metadata_tags, and study_type_tags | VERIFIED | tag_helpers.R lines 88-94: 4-element return; lines 43-51: empty-input early return also includes study_type_tags; test-tag-dispatch.R lines 9 and 53: expect_named updated at both locations |
| 8 | A column tagged 'StudyDate' appears in the study_type_tags slot, not in numeric_tags or metadata_tags | VERIFIED | tag_helpers.R lines 41, 61, 82-86: study_types <- c("StudyDate"), study_type_idx partition, study_type_tags build; test-tag-dispatch.R lines 166-183: two new test_that blocks verify correct partition |
| 9 | The tag dropdown in mod_tag_columns.R shows 'Study Date' under a 'Study / Contextual' optgroup | VERIFIED | mod_tag_columns.R lines 87-94: "Study / Contextual" optgroup with "Study Date" = "StudyDate" entry present |
| 10 | data_store$study_type_tags is populated when tags are applied | VERIFIED | mod_tag_columns.R line 161: data_store$study_type_tags <- classified$study_type_tags in observeEvent(input$apply_tags) |
| 11 | The harmonize button enables when only StudyDate columns are tagged (no numeric tags required) | VERIFIED | mod_harmonize.R lines 156-160 (has_numeric_tags reactive) and 163-173 (observe enable/disable): both check has_study = !is.null(data_store$study_type_tags) && length(data_store$study_type_tags) > 0 and gate on has_numeric || has_study |
| 12 | Partial dates (year-only, month-year) impute missing components to 1 and are flagged 'partial' | VERIFIED | date_parser.R lines 76-79: is_partial detects year-only ^[0-9]{4}$, numeric month-year, named month-year; lubridate imputes missing day to 1; test-date-parser.R Sections 2+4: six tests covering all three partial patterns |

**Score:** 10/12 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `R/date_parser.R` | parse_dates() function for multi-format date parsing | VERIFIED | 111 lines; exports parse_dates(); train=FALSE, correct ORDERS vector, case_when flag priority, empty-input guard |
| `tests/testthat/test-date-parser.R` | Unit tests for all date format families, output schema, and flag logic | VERIFIED | 297 lines; 32 test_that blocks across 7 sections; covers all DATE-01/02/03 behaviors |
| `DESCRIPTION` | lubridate added to Imports | VERIFIED | lubridate present in Imports block between jsonlite and magrittr (alphabetical) |
| `R/tag_helpers.R` | classify_tags() with study_types group containing StudyDate | VERIFIED | study_types <- c("StudyDate") at line 41; study_type_idx and study_type_tags build present |
| `R/mod_tag_columns.R` | Optgroup renamed to 'Study / Contextual' with StudyDate entry; data_store$study_type_tags assignment | VERIFIED | Lines 87-94: "Study / Contextual" optgroup with "Study Date" = "StudyDate"; line 161: data_store$study_type_tags assignment |
| `tests/testthat/test-tag-dispatch.R` | Updated expect_named assertions and new StudyDate partition tests | VERIFIED | Lines 9 and 53 updated; two new test_that blocks at lines 166-183 |
| `R/mod_harmonize.R` | Stage 4.6 date parsing, date merge into expanded_curated, QC dashboard date boxes, updated has_numeric_tags gate | VERIFIED | Stage 4.6 at line 442; parse_dates() call at line 454; expanded_curated$year at line 530; four date QC value boxes at lines 603-627; broadened gate at lines 156-160 |
| `R/curate_headless.R` | Stage 3c date parsing, year column merge into input_df | PARTIAL | Stage 3c code at lines 296-309 exists and is correct — but is unreachable when no Result column is tagged because the hard stop at line 207 fires first |
| `.planning/phases/40-date-parser/40-03-SUMMARY.md` | Plan 03 execution summary | MISSING | File does not exist; Plans 01 and 02 have SUMMARY files; Plan 03 does not |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| R/date_parser.R | lubridate::parse_date_time() | train=FALSE with verified orders vector | VERIFIED | Line 54-59: parse_date_time(raw_dates, orders=ORDERS, train=FALSE, quiet=TRUE) |
| R/date_parser.R | tibble output contract | 5-column tibble: orig_row_id, raw_date, parsed_date, date_year, date_flag | VERIFIED | Lines 103-109: tibble::tibble() with all 5 columns, correct types via as.integer/as.character |
| R/tag_helpers.R | R/mod_tag_columns.R | classify_tags() return value destructured in observeEvent(input$apply_tags) | VERIFIED | mod_tag_columns.R line 133: classified <- classify_tags(col_tag_map); line 161: data_store$study_type_tags <- classified$study_type_tags |
| R/mod_tag_columns.R | data_store$study_type_tags | assignment in observeEvent(input$apply_tags) block | VERIFIED | Line 161 confirmed |
| R/mod_harmonize.R | R/date_parser.R | parse_dates() call in Stage 4.6 | VERIFIED | Line 454: parse_dates(raw_dates = as.character(input_df[[date_cols[1]]]), orig_row_id = seq_len(nrow(input_df))) |
| R/mod_harmonize.R | expanded_curated$year | date_year merge before ToxVal mapping | VERIFIED | Lines 528-531: year_expanded <- data_store$date_results$date_year[harmonize_tibble$orig_row_id]; expanded_curated$year <- year_expanded |
| R/curate_headless.R | R/date_parser.R | parse_dates() call in Stage 3c | PARTIAL | Code exists at lines 301-304 but is blocked by hard stop at line 207 for StudyDate-only calls |
| R/curate_headless.R | input_df$year | date_year merge before ToxVal mapping | PARTIAL | Code exists at lines 306-308 but unreachable for StudyDate-only use |
| expanded_curated$year / input_df$year | toxval_mapper.R original_year | safe_extract_num(curated_data, "year", n_rows) | VERIFIED | toxval_mapper.R line 153 confirmed; no change to toxval_mapper.R required |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| R/mod_harmonize.R (Stage 4.6) | data_store$date_results | parse_dates() call on input_df[[date_cols[1]]] | Yes — lubridate parse on real column data | FLOWING |
| R/mod_harmonize.R (ToxVal stage) | expanded_curated$year | date_results$date_year subscripted via harmonize_tibble$orig_row_id | Yes — passes real parsed years | FLOWING |
| R/curate_headless.R (Stage 3c) | input_df$year | date_tibble$date_year via match() | Yes — but stage is unreachable for StudyDate-only harmonize | BLOCKED |

---

### Behavioral Spot-Checks

Step 7b: SKIPPED — no runnable entry points that exercise the date pipeline without a Shiny session or a test dataset with a StudyDate column. The curate_headless() path throws before reaching the date stage for StudyDate-only calls; running the Shiny path requires an interactive session.

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| DATE-01 | 40-01-PLAN | parse_dates() handles ISO, MDY, DMY, SAS, YYYYMMDD, year-only, 2-digit year formats | SATISFIED | R/date_parser.R with 10-order ORDERS vector; 7 format-family test_that blocks |
| DATE-02 | 40-01-PLAN | Returns tibble with orig_row_id, raw_date, parsed_date, date_year, date_flag | SATISFIED | 5-column tibble with correct types; Section 1 schema tests |
| DATE-03 | 40-01-PLAN | Dates where day <= 12 AND month <= 12 flagged as "ambiguous" | SATISFIED | is_ambiguous logic with !is_partial guard; 3 dedicated tests |
| DATE-04 | 40-02-PLAN | StudyDate tag type added to classify_tags() | SATISFIED | study_types <- c("StudyDate"); study_type_tags slot; dropdown updated |
| DATE-05 | 40-03-PLAN | curate_headless() harmonize block gains Stage 3c conditional call for StudyDate-tagged columns | BLOCKED | Stage 3c code exists but is unreachable due to hard stop at line 207 for StudyDate-only calls |
| DATE-06 | 40-03-PLAN | map_to_toxval_schema() populates original_year from date_year output | SATISFIED (Shiny path) | Shiny: expanded_curated$year -> toxval_mapper.R line 153; Headless: blocked for StudyDate-only use |

**Notes on DATE-04 wording:** REQUIREMENTS.md states "StudyDate tag type added to classify_tags() numeric_types" — the implementation correctly placed StudyDate in a new `study_types` group (not numeric_types), which is a better design decision documented in 40-CONTEXT.md D-13. The functional intent of DATE-04 is satisfied.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| R/curate_headless.R | 207 | Hard stop blocks valid StudyDate-only harmonize path | Blocker | DATE-05 / SC-4 not achievable without a Result column; diverges from Shiny behavior |
| R/mod_tag_columns.R | 198-206 | tags_applied indicator only checks column_tags (chemical), not study_type_tags | Warning | StudyDate-only sessions may not enable downstream navigation that checks tags_applied |
| R/mod_tag_columns.R | 136 | validate_tag_pairing() result computed but never displayed | Warning | User never sees Result/Unit pairing warnings; silent UX gap |
| R/tag_helpers.R | 174-199 | Malformed roxygen block — detect_tag_changes docstring contains has_required_chemical_tags | Info | R CMD check NOTE/WARNING on documentation build |
| R/date_parser.R | 76-79 | is_partial uses trimws(raw_dates) inside grepl without explicit NA guard | Info | NA-passthrough is guarded by !is_unparseable in practice but is fragile and implicit |
| .planning/phases/40-date-parser/ | — | 40-03-SUMMARY.md absent | Warning | Plan 03 has no execution record; standard workflow artifact missing |

---

### Human Verification Required

#### 1. Shiny App Cold Boot

**Test:** Run `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "shiny::runApp('.', port=3838, launch.browser=FALSE)"` and wait for "Listening on" output.
**Expected:** App starts without error. No missing icon errors, no source() failures, no module wiring crashes.
**Why human:** Cannot start a Shiny server in this environment. Plan 03 Task 3 specified this as a blocking human checkpoint.

#### 2. StudyDate Tag Dropdown

**Test:** Upload a test file, navigate to Tag Columns tab, open the type dropdown for any column.
**Expected:** Dropdown shows "Study / Contextual" as an optgroup containing "Study Date" as a selectable entry. Selecting it and clicking Apply Tags shows success notification and does not error.
**Why human:** UI rendering requires an interactive Shiny session.

#### 3. Harmonize Button Enable for StudyDate-Only Session

**Test:** Tag exactly one column as "Study Date" (no Result, Unit, or other tags). Navigate to Harmonize tab.
**Expected:** "Run Harmonization" button is enabled (not grayed out). The empty-state "No columns tagged" message is not shown.
**Why human:** Requires reactive Shiny session to verify the observe() enable/disable logic fires correctly.

#### 4. QC Dashboard Date Value Boxes

**Test:** With a StudyDate column tagged, click "Run Harmonization" on a file that has mixed-format dates including at least one ambiguous date.
**Expected:** After completion, QC dashboard shows a second row of four value boxes: Dates Parsed (success theme), Partial Dates (info theme), Ambiguous Dates (warning theme with non-zero count), Unparseable Dates (danger theme). Counts match the actual data.
**Why human:** Requires live Shiny session with real data; conditional rendering of date_qc_row cannot be verified statically.

---

### Gaps Summary

Two gaps block full goal achievement:

**Gap 1 (Blocker): curate_headless() StudyDate-only path**

`curate_headless()` at line 207 hard-stops when `harmonize=TRUE` and no Result column is present. This fires before Stage 3c is reached. A user calling `curate_headless(tag_map = list(date_col = "StudyDate"), harmonize = TRUE)` receives an error: "harmonize=TRUE requires at least one column tagged as Result." The Shiny module correctly handles this case with an identity-tibble branch (mod_harmonize.R lines 397-418); curate_headless.R never received the equivalent bypass.

**Root cause:** Plan 03 Task 2 specified inserting Stage 3c after the duration block but did not update the `length(result_cols) == 0` guard upstream. The guard was written in the original harmonize pipeline before Phase 40 and was not relaxed to accommodate StudyDate-only runs.

**Fix required:** Mirror the Shiny module's StudyDate-only bypass in curate_headless.R. Check `has_study = length(names(tag_map)[tag_map == "StudyDate"]) > 0` and if `!has_numeric && has_study`, build identity parse/harmonize tibbles (as in mod_harmonize.R lines 399-418) then skip to Stage 3c.

**Gap 2 (Minor): 40-03-SUMMARY.md absent**

The standard workflow creates a SUMMARY.md for each plan after execution. Plans 01 and 02 have their SUMMARYs (committed as 6dbec3c and a follow-on commit). Plan 03 does not. A SUMMARY was created (commit 6850d0f message: "docs(40-03): complete plan 03 summary — pipeline wiring"), but the file is not on the filesystem. It was likely lost in the worktree merge (commit b40608d: "fix(40-03): restore date parsing pipeline changes lost during worktree merge"). The code changes from Plan 03 are present; only the documentation artifact is missing.

These two gaps are related — Gap 1 is the substantive code issue; Gap 2 is the documentation artifact.

---

_Verified: 2026-04-27T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
