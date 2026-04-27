---
phase: 41-media-harmonizer-amos-pipeline
plan: "01"
subsystem: media-harmonization
tags:
  - tdd
  - envo
  - media-classification
  - ppb-routing
dependency_graph:
  requires:
    - inst/extdata/reference_cache/ (RDS cache convention from Phase 26)
    - R/unit_harmonizer.R (get_media_target consumer of media_category)
  provides:
    - harmonize_media() function with ENVO-based media classification
    - inst/extdata/reference_cache/amos_media.rds (curated ENVO vocabulary, 26 entries)
  affects:
    - ppb/ppm routing in harmonize_units() (media_category feeds get_media_target())
    - Phase 41 Plans 02-03 (AMOS enrichment, pipeline wiring)
tech_stack:
  added: []
  patterns:
    - TDD RED/GREEN cycle (same as date_parser.R pattern)
    - system.file() cache loading (same as unit_harmonizer.R)
    - O(1) hash map exact lookup + vectorized grepl parent-walk
    - Pre-allocated output vectors (no growing-list pattern)
    - vapply for multi-pattern grepl to avoid length>1 warning
key_files:
  created:
    - R/media_harmonizer.R
    - tests/testthat/test-media-harmonizer.R
    - inst/extdata/reference_cache/amos_media.rds
  modified: []
decisions:
  - "Curated 26 ENVO entries (not just 20-30 minimum): includes aqueous biological (blood/plasma/serum) and covers all test cases"
  - "walk_parent uses vapply(tbl_terms, grepl, ..., x=norm_term) to fix length>1 pattern warning from grepl(vector, scalar)"
  - "freshwater sediment is a first-class table entry (parent=sediment), not a derived compound -- satisfies MEDIA-03"
  - "blood/plasma/serum classified as aqueous biological (media_category=aqueous) enabling ppb routing for toxicological matrices"
metrics:
  duration: "7 minutes"
  completed: "2026-04-27"
  tasks_completed: 2
  files_created: 3
  lines_written: 461
  tests_added: 62
---

# Phase 41 Plan 01: Media Harmonizer Core Engine Summary

**One-liner:** ENVO-based media harmonization engine with exact + parent-walk resolution, 26-entry curated vocabulary, and media_category output feeding ppb/ppm unit routing.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | RED -- Write failing tests for harmonize_media() | c208d5a | tests/testthat/test-media-harmonizer.R |
| 2 | GREEN -- Implement harmonize_media() and curated ENVO subset | 246e0c4 | R/media_harmonizer.R, inst/extdata/reference_cache/amos_media.rds |

## What Was Built

### R/media_harmonizer.R (199 lines)

Exported function `harmonize_media(raw_media, orig_row_id)` that:
1. Guards against empty input, returning a typed 0-row tibble (T-41-02 DoS mitigation)
2. Loads the curated ENVO vocabulary via `get_media_table()` (system.file cache pattern)
3. Normalizes input with `trimws(tolower())` for case/whitespace invariance
4. Performs O(1) hash-map exact lookup via `stats::setNames()`
5. Runs `walk_parent()` for unmatched rows — substring bidirectional matching, walks up parent column to find nearest ancestor with media_category
6. Assigns flags: `""` (exact), `"parent_walk"`, `"media_unmatched"`
7. Returns 6-column tibble: orig_row_id, raw_media, canonical_media, envo_id, media_category, media_flag

### inst/extdata/reference_cache/amos_media.rds (26 entries)

Curated ENVO vocabulary covering:
- **Aqueous (10):** water, freshwater, saltwater, seawater, marine water, groundwater, surface water, drinking water, wastewater, effluent
- **Aqueous biological (3):** blood, plasma, serum
- **Solid (10):** soil, sediment, freshwater sediment (first-class D-11), marine sediment, sludge, dust, tissue, biota, food, diet
- **Air (3):** air, ambient air, indoor air

### tests/testthat/test-media-harmonizer.R (262 lines, 24 test_that blocks)

Nine test sections: output schema, exact match, case/whitespace, compound media MEDIA-03, parent-walk D-08, unmatched flagging D-10, empty input guard, mixed vector, media_category domain.

## Test Results

- New tests: 62 passing, 0 failing, 0 warnings
- Full suite: 1817 passing, 3 failing (pre-existing, unchanged), 2 skipped

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed grepl length>1 pattern warning in walk_parent()**
- **Found during:** GREEN phase test run (devtools::load_all + test_file)
- **Issue:** `grepl(tbl_terms, norm_term, fixed=TRUE)` passed a length-26 vector as the `pattern` argument -- R only uses the first element and emits a warning. This caused 4 warnings in the test output and silently wrong candidate detection.
- **Fix:** Replaced with `vapply(tbl_terms, grepl, logical(1L), x = norm_term, fixed = TRUE)` which correctly applies each table term as a separate pattern against `norm_term`.
- **Files modified:** R/media_harmonizer.R
- **Commit:** 246e0c4 (included in GREEN commit)

## Known Stubs

None -- all test inputs resolve correctly against the curated vocabulary. The `amos_media.rds` file contains real ENVO IDs and is a complete initial vocabulary (Plan 02 will enrich it with AMOS-derived terms, but the current 26 entries are not stubs).

## Threat Surface Scan

No new network endpoints, auth paths, or trust boundary changes introduced. `get_media_table()` reads a package-internal RDS at `inst/extdata/reference_cache/amos_media.rds` — read-only at runtime, committed to git (T-41-01 accepted). Empty-input guard addresses T-41-02 (DoS). Flag values expose only resolution path metadata (T-41-03 accepted).

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| R/media_harmonizer.R exists | FOUND |
| tests/testthat/test-media-harmonizer.R exists | FOUND |
| inst/extdata/reference_cache/amos_media.rds exists | FOUND |
| Commit c208d5a (RED) exists | FOUND |
| Commit 246e0c4 (GREEN) exists | FOUND |
| All 62 new tests pass | PASS |
| Pre-existing 3 failures unchanged | PASS |
