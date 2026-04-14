---
phase: 29-static-data-foundations
plan: 01
subsystem: database
tags: [unit-conversion, rds, tibble, reference-data, ecotox, sswqs]

requires:
  - phase: 28-test-migration
    provides: tests/testthat structure with 953 passing tests and load_or_fetch_reference() base pattern

provides:
  - inst/extdata/unit_conversion.rds — 151-row unit conversion lookup table with ECOTOX + SSWQS sources
  - R/cleaning_reference.R load_unit_map() — exported loader function following established cache-or-fetch pattern
  - Unit conversion table covers concentration, mass, dose, mass_fraction, percent, time, dimensionless, turbidity, microbial, radioactivity, pH, conductivity, dissolved_oxygen, temperature, hardness categories

affects:
  - 29-02 (ToxVal schema manifest — same phase, may reference unit categories)
  - 31-unit-harmonization-engine (primary consumer of load_unit_map())
  - load_all_reference_lists() callers (now returns 6-key list instead of 5)

tech-stack:
  added: []
  patterns:
    - load_unit_map(cache_dir) follows load_or_fetch_reference() cache-or-fetch pattern established in Phase 10
    - Unit conversion table uses 6-column schema (from_unit, to_unit, multiplier, category, confidence, source)
    - inst/extdata/ as location for static data RDS files (not cached, not regenerated, ships with package)
    - Probe-both-paths pattern for tests finding inst/extdata from both devtools::test() and test_file() contexts

key-files:
  created:
    - inst/extdata/unit_conversion.rds
  modified:
    - R/cleaning_reference.R
    - tests/testthat/test-cleaning-reference.R

key-decisions:
  - "6-column unit table schema: from_unit, to_unit, multiplier, category, confidence, source — matches D-01/D-02/D-03"
  - "151 rows covering 15 unit categories across ECOTOX and SSWQS sources"
  - "Molar concentration units (mol/L, M, mM, etc.) kept with multiplier=1 and confidence=LOW — MW-dependent conversions deferred to Phase 31 harmonizer"
  - "Temperature and non-linear units (F, K) kept with multiplier=NA_real_ and confidence=LOW — offset conversions not representable as simple multipliers"
  - "inst/extdata/ for static RDS (not reference_cache/) — unit table ships with package, not regenerated on first use"
  - "Probe-both-paths test pattern for inst/extdata resolution: works from both devtools::test() (project root wd) and test_file() (tests/testthat/ wd)"

patterns-established:
  - "Static data pattern: build-time script writes RDS to inst/extdata/, loader reads it via load_or_fetch_reference()"
  - "Non-linear unit handling: store with multiplier=NA_real_ and confidence=LOW to flag for special processing downstream"

requirements-completed: [DATA-01, DATA-03]

duration: 22min
completed: 2026-04-14
---

# Phase 29 Plan 01: Unit Conversion Table and Loader Summary

**151-row unit conversion RDS (15 categories, ECOTOX+SSWQS sources) with load_unit_map() loader following established cache-or-fetch pattern, exported and integrated into load_all_reference_lists()**

## Performance

- **Duration:** 22 min
- **Started:** 2026-04-14T19:53:12Z
- **Completed:** 2026-04-14T20:15:00Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Built `inst/extdata/unit_conversion.rds` with 151 unit conversion rows across 15 categories (concentration, mass, dose, mass_fraction, percent, time, dimensionless, turbidity, microbial, radioactivity, pH, conductivity, dissolved_oxygen, temperature, hardness)
- Implemented `load_unit_map(cache_dir)` in `R/cleaning_reference.R` with roxygen docs, @export, and graceful 4-row fallback if RDS is missing
- Added `unit_map` key to `load_all_reference_lists()` return value (now 6 keys)
- Added 3 new test_that blocks (structure, conversions, integration) plus updated existing 5-key test to expect 6 keys — all 46 tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Create unit conversion RDS file** - `b6ce1f9` (feat)
2. **Task 2: Implement load_unit_map() function** - `915a96e` (feat)
3. **Task 3: Add unit tests for load_unit_map()** - `3cb916d` (test)

**Plan metadata:** (docs commit — see final commit hash after state update)

## Files Created/Modified

- `inst/extdata/unit_conversion.rds` — 151-row unit conversion tibble, 12KB, compress=FALSE
- `R/cleaning_reference.R` — Added load_unit_map() function (40 lines) and updated load_all_reference_lists() with 6th key
- `tests/testthat/test-cleaning-reference.R` — 3 new test_that blocks for load_unit_map, updated structure test for 6 keys

## Decisions Made

- Molar concentration units (mol/L, M, mM, etc.) stored with `multiplier=1` and `confidence="LOW"` — MW-dependent, Phase 31 harmonizer must handle separately
- Temperature and offset-based units (°F, K) stored with `multiplier=NA_real_` and `confidence="LOW"` — cannot be represented as simple scale factors
- Located in `inst/extdata/` (not `inst/extdata/reference_cache/`) because unit table is static package data, not a user-regenerated cache
- Test path resolution: probe two candidate directories (`getwd()/inst/extdata` and `getwd()/../../inst/extdata`) to handle both `devtools::test()` and standalone `test_file()` invocations

## Deviations from Plan

None — plan executed exactly as written. The test path resolution fix (probing both candidate directories) was a minor implementation detail to handle testthat's working directory behavior, not a deviation from plan intent.

## Issues Encountered

- `testthat::test_file()` changes working directory to `tests/testthat/` before running tests, so `inst/extdata` relative path doesn't resolve. Fixed by probing two candidate paths. `devtools::test()` keeps project root as wd, so that path works directly.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `load_unit_map("inst/extdata")` is ready for Phase 31 unit harmonization engine
- `load_all_reference_lists()` callers will now receive `unit_map` key — no breaking change (new key added)
- Phase 29-02 (ToxVal schema manifest) is unblocked — no dependency on 29-01

---
*Phase: 29-static-data-foundations*
*Completed: 2026-04-14*
