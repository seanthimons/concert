---
phase: 29-static-data-foundations
plan: 02
subsystem: database
tags: [toxval, schema, rds, tibble, parquet, typed-na, reference-loader]

# Dependency graph
requires:
  - phase: 29-01-static-data-foundations
    provides: load_unit_map() pattern and inst/extdata/ directory established

provides:
  - inst/extdata/toxval_schema.rds — zero-row 56-column typed tibble for ToxVal output templating
  - load_toxval_schema(cache_dir) — loader function following established cache-or-fetch pattern
  - load_all_reference_lists() updated to include toxval_schema (7 keys total)

affects:
  - phase-32 (ToxVal mapper — consumes toxval_schema as output template)
  - phase-31 (unit harmonization — uses same inst/extdata loader pattern)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Zero-row typed tibble via tibble()[0,] for schema templating
    - typed NA values (NA_character_, NA_real_, NA_integer_) for parquet compatibility

key-files:
  created:
    - inst/extdata/toxval_schema.rds
  modified:
    - R/cleaning_reference.R
    - tests/testthat/test-cleaning-reference.R

key-decisions:
  - "Use tibble()[0,] slice to produce zero-row typed tibble — tibble() with scalar NAs creates 1-row tibble, must slice to 0"
  - "load_toxval_schema() fallback returns minimal 7-column schema with warning — consistent with load_unit_map() pattern"
  - "Test probing pattern (candidates with getwd() and ../..) carried over from load_unit_map tests for devtools/test_file wd compatibility"

patterns-established:
  - "Schema manifest pattern: zero-row tibble with typed NAs stored as RDS in inst/extdata/, loaded via load_or_fetch_reference()"

requirements-completed:
  - DATA-02

# Metrics
duration: 12min
completed: 2026-04-14
---

# Phase 29 Plan 02: ToxVal Schema Manifest Summary

**56-column zero-row typed tibble saved as inst/extdata/toxval_schema.rds with load_toxval_schema() loader following established cache-or-fetch pattern**

## Performance

- **Duration:** 12 min
- **Started:** 2026-04-14T16:01:19Z
- **Completed:** 2026-04-14T16:13:00Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Created ToxVal schema manifest RDS with all 56 typed columns (identifiers, toxicity values, study design, species, exposure, source/provenance, quality, and 12 audit columns)
- Implemented load_toxval_schema() in R/cleaning_reference.R with full roxygen documentation and @export
- Added 5 test_that blocks covering zero-row validation, required columns, typed NA verification, and integration with load_all_reference_lists()

## Task Commits

Each task was committed atomically:

1. **Task 1: Create ToxVal schema manifest RDS file** - `35efdf9` (feat)
2. **Task 2: Implement load_toxval_schema() function** - `811d501` (feat)
3. **Task 3: Add unit tests for load_toxval_schema()** - `2480560` (test)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified
- `inst/extdata/toxval_schema.rds` — Zero-row 56-column typed tibble schema template
- `R/cleaning_reference.R` — Added load_toxval_schema() function; updated load_all_reference_lists() to include toxval_schema key
- `tests/testthat/test-cleaning-reference.R` — Added 5 test blocks; updated 6-key expectation to 7-key

## Decisions Made
- Used `tibble()[0, ]` slice pattern to produce zero-row tibble — scalar NA values in tibble() constructor yield a 1-row tibble, must slice to get zero rows
- load_toxval_schema() fallback path returns minimal 7-column schema with warning when RDS file is missing — consistent with load_unit_map() approach
- Test directory probing pattern (checking both `getwd()/inst/extdata` and `getwd()/../../inst/extdata`) carried forward from load_unit_map tests to handle devtools::test() vs test_file() working directory difference

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed zero-row tibble construction**
- **Found during:** Task 1 (Create ToxVal schema manifest RDS file)
- **Issue:** Plan's R snippet built tibble with scalar NA values — this creates a 1-row tibble, not zero-row. The plan's `stopifnot(nrow(toxval_schema) == 0)` verification caught the issue on first execution attempt.
- **Fix:** Appended `[0, ]` slice to the tibble() constructor call to produce a zero-row result while preserving all typed columns
- **Files modified:** inst/extdata/toxval_schema.rds (recreated correctly)
- **Verification:** `nrow(readRDS(...)) == 0` and `ncol() == 56` confirmed
- **Committed in:** 35efdf9 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug in plan's R snippet)
**Impact on plan:** Fix was a one-line correction to the tibble construction idiom. No scope change.

## Issues Encountered
- Initial tibble() with scalar NAs creates 1-row tibble, not 0-row — resolved by slicing with `[0, ]`

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- inst/extdata/toxval_schema.rds ready for Phase 32 (ToxVal mapper) to use as output column template
- load_toxval_schema() exported and available via library(chemreg)
- load_all_reference_lists() now returns 7 keys; tests updated accordingly
- No blockers

## Self-Check: PASSED

- FOUND: inst/extdata/toxval_schema.rds
- FOUND: R/cleaning_reference.R
- FOUND: tests/testthat/test-cleaning-reference.R
- FOUND: .planning/phases/29-static-data-foundations/29-02-SUMMARY.md
- FOUND commit: 35efdf9
- FOUND commit: 811d501
- FOUND commit: 2480560

---
*Phase: 29-static-data-foundations*
*Completed: 2026-04-14*
