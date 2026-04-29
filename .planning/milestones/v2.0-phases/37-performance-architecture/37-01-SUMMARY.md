---
phase: 37-performance-architecture
plan: "01"
subsystem: pipeline
tags: [dedup, performance, audit-trail, cleaning-pipeline]

# Dependency graph
requires:
  - phase: 36-toxval-shiny-integration
    provides: cleaning_pipeline.R with build_audit_trail() and step function contract

provides:
  - dedup_step() orchestrator wrapper in R/cleaning_pipeline.R
  - remap_audit_to_parent() utility in R/cleaning_pipeline.R
  - tests/testthat/test-dedup-infrastructure.R with 39 assertions

affects:
  - 37-02 (pre-check predicates will sit alongside these functions)
  - 37-03 (cleaning pipeline migration uses dedup_step at each step call site)
  - 37-04 (harmonization dedup follows same dedup_step contract)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "dedup_step() wrapper pattern: deduplicate target columns, run step on unique slice, remap cleaned_data and audit trail to parent"
    - "remap_audit_to_parent() uses split()+match() for O(n) parent_map construction, avoiding O(n*m) which() per key"
    - "NA sentinel '__NA__' in dedup key construction groups NAs as one unique value (T-37-02)"
    - "Uniqueness bypass at 0.5 threshold: n_distinct/n_total > threshold -> call step directly (D-03)"
    - "PERF-02 assertion: stopifnot(max(remapped_audit$row_id) <= nrow(df)) enforced inside dedup_step"

key-files:
  created:
    - tests/testthat/test-dedup-infrastructure.R
  modified:
    - R/cleaning_pipeline.R

key-decisions:
  - "parent_map built via split()+match() in O(n) rather than which() per unique key in O(n*m) — avoids hotspot at 100K rows with many unique keys"
  - "dedup_step preserves new_tags from step result so CAS-augmenting steps work through the wrapper unchanged"
  - "remap_audit_to_parent returns audit_slice unchanged (not a fresh empty tibble) on nrow==0 fast path — preserves exact column types"

patterns-established:
  - "dedup_step(step_fn, df, ..., dedup_cols, uniqueness_threshold=0.5): canonical wrapper signature for all cleaning pipeline step migrations"
  - "remap_audit_to_parent(audit_slice, parent_map): canonical audit ID expander; parent_map keys are character positions in unique slice"

requirements-completed:
  - PERF-01
  - PERF-02

# Metrics
duration: 10min
completed: "2026-04-24"
---

# Phase 37 Plan 01: Dedup Infrastructure Summary

**`dedup_step()` orchestrator wrapper and `remap_audit_to_parent()` utility implementing O(n) dedup with PERF-02 row-ID integrity assertion, tested with 39 assertions across 8 test_that blocks**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-04-24T19:00:00Z
- **Completed:** 2026-04-24T19:10:41Z
- **Tasks:** 2
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments

- `remap_audit_to_parent()`: expands audit row IDs from deduplicated-slice positions back to all matching parent rows using pre-allocated vectors and O(n) `split()+match()` construction
- `dedup_step()`: wraps any step function, processes only distinct string values, remaps both `cleaned_data` and audit trail to the parent dataset; enforces PERF-02 max-row-ID assertion and includes D-03 uniqueness bypass
- 39-assertion test suite covering empty audit fast path, row-ID expansion fidelity, D-03 bypass at uniqueness ratio 1.0, 100-row duplicate dataset, NA grouping, `new_tags` passthrough, step contract shape, `normalize_cas_fields` integration, and PERF-02 sentinel error

## Task Commits

1. **Task 1: Implement dedup_step() and remap_audit_to_parent()** - `a21117e` (feat)
2. **Task 2: Test dedup_step() and remap_audit_to_parent()** - `62fd1fa` (test)

## Files Created/Modified

- `R/cleaning_pipeline.R` — added `remap_audit_to_parent()` (after line 98) and `dedup_step()` (after remap); both exported with `@export` roxygen tags
- `tests/testthat/test-dedup-infrastructure.R` — 8 `test_that()` blocks, 39 assertions; includes `uppercase_step` helper, remap expansion tests, bypass threshold test, duplicate-data correctness, NA handling, `normalize_cas_fields` integration, and PERF-02 error sentinel

## Decisions Made

- **O(n) parent_map via split()**: The initial `lapply(seq_along(unique_keys), function(i) which(key_vec == unique_keys[i]))` was O(n*m). Replaced with `key_to_unique_pos <- match(key_vec, unique_keys)` then `split(seq_along(key_vec), key_to_unique_pos)` which builds the full inverse map in one O(n) pass.
- **`new_tags` passthrough**: `dedup_step` checks `!is.null(result$new_tags)` and copies it to the return list, keeping CAS-augmenting steps (which return a third list element) compatible with the wrapper.
- **remap fast path returns `audit_slice` unchanged**: when `nrow(audit_slice) == 0`, returning the input directly preserves the exact tibble column types without reconstructing them, while still satisfying the empty-typed-tibble invariant.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug / Performance] Replaced O(n*m) parent_map construction with O(n) split()+match()**

- **Found during:** Task 1 (implementation review after post-edit advisory)
- **Issue:** `lapply(seq_along(unique_keys), function(i) which(key_vec == unique_keys[i]))` scans the full `key_vec` once per unique key — O(n*m) where n=rows and m=unique keys. At 100K rows with 50K unique keys, this is 5 billion operations.
- **Fix:** Precomputed `key_to_unique_pos <- match(key_vec, unique_keys)` (O(n)), then `split(seq_along(key_vec), key_to_unique_pos)` (O(n)) to build the full inverse map. Per-key lookups into the resulting `groups` list are O(1) hash access.
- **Files modified:** `R/cleaning_pipeline.R`
- **Committed in:** `a21117e` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — performance bug)
**Impact on plan:** Essential for correctness at 100K+ rows. No scope creep — same algorithm, different construction order.

## Issues Encountered

- Pre-existing test failures in `test-cleaning-reference.R` and `test-reference-provenance.R` (3 failures, confirmed by baseline check against commit `917d7ed` — present before any changes in this plan). Not introduced by this work.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `dedup_step()` and `remap_audit_to_parent()` are ready for Plan 03 (cleaning pipeline step migration)
- Both functions are exported and loadable via `devtools::load_all()`
- Full test suite at 1538 passing tests (3 pre-existing failures, 2 skips — no regressions from this plan)
- Plan 02 (pre-check predicates) can proceed in parallel since it uses the same `R/cleaning_pipeline.R` file but adds new predicate functions, not call-site changes

## Self-Check: PASSED

- FOUND: `R/cleaning_pipeline.R`
- FOUND: `tests/testthat/test-dedup-infrastructure.R`
- FOUND: `.planning/phases/37-performance-architecture/37-01-SUMMARY.md`
- FOUND: commit `a21117e` (Task 1 — feat)
- FOUND: commit `62fd1fa` (Task 2 — test)
- `@export` tags confirmed at lines 114 and 183 of `R/cleaning_pipeline.R`
- `stopifnot(max(remapped_audit$row_id) <= nrow(df))` confirmed at line 233

---
*Phase: 37-performance-architecture*
*Completed: 2026-04-24*
