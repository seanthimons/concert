---
phase: 40-date-parser
plan: "01"
subsystem: date-parser
tags: [date-parsing, lubridate, harmonization, tdd]
dependency_graph:
  requires: []
  provides:
    - parse_dates() function with 5-column tibble output contract
    - lubridate declared in Imports
  affects:
    - R/mod_harmonize.R (Plans 02/03 will wire parse_dates() into Stage 4.6)
    - R/curate_headless.R (Plans 02/03 will wire parse_dates() into Stage 3c)
    - R/tag_helpers.R (Plans 02/03 will add study_types group)
tech_stack:
  added:
    - lubridate 1.9.4 (promoted to Imports from absent)
  patterns:
    - TDD RED/GREEN with per-phase commits
    - Vectorized parse via lubridate::parse_date_time(train=FALSE)
    - dplyr::case_when() for strict flag priority enforcement
    - Empty-input guard matching unit_harmonizer.R analog pattern
key_files:
  created:
    - R/date_parser.R
    - tests/testthat/test-date-parser.R
  modified:
    - DESCRIPTION
decisions:
  - "train=FALSE is required for heterogeneous date columns (PITFALL-01 confirmed)"
  - "Orders vector: ymd, Ymd, bY, BY, dBY, BdY, mdy, dmy, Y, Ym (bY before mdy prevents Jan 2015 misparse)"
  - "2-digit year cutoff: lubridate default (year<69 -> 2000+y, >=69 -> 1900+y) — acceptable for regulatory data 1950-2030"
  - "Partial check precedes ambiguity check to prevent year-only false-positive (PITFALL-04)"
metrics:
  duration_minutes: 3
  completed_date: "2026-04-27"
  tasks_completed: 2
  files_created: 2
  files_modified: 1
---

# Phase 40 Plan 01: Date Parser Core Function Summary

**One-liner:** `parse_dates()` with lubridate train=FALSE, 10-order heterogeneous format detection, and 5-level flag priority (unparseable > partial > inferred_format > ambiguous > "").

## Tasks Completed

| # | Name | Type | Commit | Files |
|---|------|------|--------|-------|
| 1a | RED: Failing tests for parse_dates() | test | 67f4ec4 | tests/testthat/test-date-parser.R |
| 1b | GREEN: Implement parse_dates() | feat | f5e05e4 | R/date_parser.R |
| 2 | Add lubridate to DESCRIPTION Imports | chore | 44f8e8c | DESCRIPTION |

## What Was Built

`R/date_parser.R` exports `parse_dates(raw_dates, orig_row_id)` — the core date parsing engine for Phase 40. It handles 8 format families in a single vectorized call via `lubridate::parse_date_time(orders=ORDERS, train=FALSE, quiet=TRUE)`:

- ISO `ymd` (2015-03-15)
- YYYYMMDD compact `Ymd` (20150315)
- Named month-year `bY`/`BY` (Mar 2015, MARCH 2015)
- SAS `dBY`/`BdY` (15MAR2015)
- MDY US `mdy` (03/15/2015)
- DMY European `dmy` (15/03/2015)
- Year-only `Y` (2015) → partial flag
- Numeric month-year `Ym` (2015-03) → partial flag

Output is a 5-column tibble matching the DATE-02 contract: `orig_row_id`, `raw_date`, `parsed_date`, `date_year`, `date_flag`.

## Test Coverage

32 `test_that` blocks across 7 sections, 80 assertions total:

| Section | Coverage |
|---------|----------|
| 1 - Output schema (DATE-02) | Column names, types, orig_row_id, raw_date preservation |
| 2 - Format families (DATE-01) | One block per format family (7 families) |
| 3 - Ambiguity flagging (DATE-03) | Ambiguous (01/02/2015), not ambiguous (13/02/2015, 03/15/2015) |
| 4 - Partial dates (D-03/D-04) | Year-only, named month-year, numeric month-year, date_year always populated |
| 5 - 2-digit year (D-08/D-09) | inferred_format flag, valid parsed_date, valid date_year |
| 6 - Unparseable (D-10) | N/A, ongoing, not reported, TBD, empty string, NA_character_ |
| 7 - Empty input guard | character(0) returns 0-row typed tibble |

## Key Implementation Decisions

**train=FALSE is mandatory** (PITFALL-01): With the default `train=TRUE`, lubridate trains on the dominant format across the entire input vector. Mixed-format columns produce wrong parses (e.g., "Jan 2015" parsed as 2015-01-20 when MDY is dominant). `train=FALSE` tries each order independently per element.

**Orders vector ordering matters** (PITFALL-02): `bY`/`BY` must precede `mdy` in the orders vector. Even with `train=FALSE`, "Jan 2015" can match `mdy` (month=Jan, day=20, year=15) if `mdy` appears first.

**Partial check precedes ambiguity** (PITFALL-04): Year-only "2015" parses to 2015-01-01 (day=1, month=1, both <= 12). Without the `!is_partial` guard in the ambiguity check, these would receive `"ambiguous"` instead of `"partial"`.

**2-digit year**: No `cutoff_2000` parameter exists in `parse_date_time()` (PITFALL-03). Detection via regex pre-scan `[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}$`; library default cutoff (68) applied at parse time; all 2-digit-year inputs flagged `"inferred_format"` regardless of result (D-09).

## Deviations from Plan

None — plan executed exactly as written. The RESEARCH.md note that lubridate was in `Suggests` was incorrect (it was completely absent), but PATTERNS.md had already corrected this and the plan explicitly said "unconditional add".

## TDD Gate Compliance

| Gate | Status | Commit |
|------|--------|--------|
| RED (test commit) | PASS — 32 tests, all failed with "could not find function parse_dates" | 67f4ec4 |
| GREEN (feat commit) | PASS — 80 assertions, 0 failures | f5e05e4 |
| REFACTOR | Skipped — no cleanup needed after GREEN |

## Known Stubs

None. `parse_dates()` is fully implemented. No placeholder data or hardcoded empty values flow to downstream consumers.

## Threat Flags

No new network endpoints, auth paths, file access patterns, or schema changes introduced. T-40-03 (DoS via large input) mitigation present: empty-input guard prevents zero-length edge case; vectorized C-level parse via lubridate handles large inputs efficiently.

## Self-Check: PASSED

| Item | Status |
|------|--------|
| R/date_parser.R | FOUND |
| tests/testthat/test-date-parser.R | FOUND |
| DESCRIPTION | FOUND (lubridate present) |
| 40-01-SUMMARY.md | FOUND |
| Commit 67f4ec4 (RED) | FOUND |
| Commit f5e05e4 (GREEN) | FOUND |
| Commit 44f8e8c (DESCRIPTION) | FOUND |
