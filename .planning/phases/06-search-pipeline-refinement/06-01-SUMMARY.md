---
phase: 06-search-pipeline-refinement
plan: 01
subsystem: api
tags: [comptox, cas-validation, tiered-search, curation-pipeline]

# Dependency graph
requires:
  - phase: 05-shiny-integration
    provides: "run_curation_pipeline() as Shiny-integrated module"
provides:
  - "Reordered tier chain: exact → CAS → starts-with (3-char min)"
  - "Other tag support for arbitrary identifier columns"
  - "CAS validation before starts-with fallback increases precision"
affects: [07-ui-refinement, 08-retry-workflow]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CAS validation as tier 2 (after exact, before starts-with) for precision"
    - "3-character minimum filter on starts-with to reduce API noise"
    - "Other tag inclusion in unique_names for arbitrary identifier curation"

key-files:
  created: []
  modified:
    - R/curation.R
    - tests/test_prototype_pipeline.R

key-decisions:
  - "CAS validation tier moved to position 2 (after exact, before starts-with) based on research findings"
  - "Starts-with tier now filters values shorter than 3 characters before API call"
  - "Other tagged columns participate in full tier chain alongside Name columns"
  - "CAS-from-names and CAS-from-columns tracked separately in search_summary"

patterns-established:
  - "Other tag extraction pattern: searchable_cols = c(name_cols, other_cols)"
  - "Tier chain pattern: exact → CAS fallback → starts-with (3-char min) → CASRN column validation"
  - "Separate tracking for CAS matches from name fallback vs CASRN column validation"

requirements-completed: [SRCH-01, SRCH-02, SRCH-03]

# Metrics
duration: 3min
completed: 2026-03-01
---

# Phase 06 Plan 01: Search Pipeline Refinement Summary

**Reordered search tiers to exact → CAS → starts-with with 3-char minimum, and expanded Other tag support for arbitrary identifier columns**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-01T19:57:58Z
- **Completed:** 2026-03-01T19:60:39Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Reordered tier chain to exact → CAS → starts-with in both run_tiered_search() and run_curation_pipeline()
- Added 3-character minimum filter to starts-with tier to reduce API noise
- Other tagged columns now flow through full tier chain alongside Name columns
- map_results_to_rows() automatically creates dtxsid_Other columns via existing join logic
- find_dtxsid_cols() in consensus.R auto-detects dtxsid_Other with no code changes needed

## Task Commits

Each task was committed atomically:

1. **Task 1: Reorder search tiers and expand Other tag extraction** - `a0e71bd` (feat)
2. **Task 2: Add tests for tier reorder and Other tag participation** - `b162928` (test)

**Plan metadata:** (to be committed separately)

## Files Created/Modified
- `R/curation.R` - Reordered tier chain, added Other tag extraction in deduplicate_tagged_columns(), updated search orchestration in run_curation_pipeline() and run_tiered_search()
- `tests/test_prototype_pipeline.R` - Added 4 new tests for Other tag inclusion, multiple Other columns, CAS-only tags, and 3-char minimum filter

## Decisions Made
- CAS validation positioned as Tier 2 (after exact, before starts-with) based on research indicating higher precision for CAS-identifiable chemicals
- 3-character minimum filter on starts-with tier to reduce API noise from short abbreviations
- Other column values included in unique_names extraction to support arbitrary identifier columns (synonyms, supplier codes)
- CAS-from-names and CAS-from-columns tracked separately in search_summary for visibility into dual CAS paths

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - implementation proceeded as planned. All tests pass (49 passed, 4 skipped for missing API key, 0 failures).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Search pipeline tier order validated via tests
- Other tag support enables arbitrary identifier columns to participate in consensus
- Ready for Phase 07 UI refinement (Review Results table improvements, resolution dropdown context)
- Consensus.R already auto-detects dtxsid_Other columns - SRCH-03 satisfied with no consensus code changes

## Self-Check

Verifying implementation claims:

- R/curation.R: deduplicate_tagged_columns() extracts other_cols and includes in searchable_cols ✓
- R/curation.R: run_curation_pipeline() tier order is exact → CAS fallback → starts-with (3-char min) → CASRN columns ✓
- R/curation.R: run_tiered_search() follows same reordered tier chain ✓
- tests/test_prototype_pipeline.R: Tests for Other tag inclusion, multiple Other columns, CAS-only tags, 3-char filter ✓
- All tests pass: 49 passed, 4 skipped, 0 failures ✓

**Self-Check: PASSED**

---
*Phase: 06-search-pipeline-refinement*
*Completed: 2026-03-01*
