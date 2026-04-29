---
phase: 37-performance-architecture
plan: "03"
subsystem: cleaning-pipeline
tags: [dedup, precheck, performance, cleaning-pipeline, name-chain, audit-trail]

requires:
  - phase: 37-01
    provides: dedup_step(), remap_audit_to_parent(), build_skip_result()
  - phase: 37-02
    provides: precheck_unicode_to_ascii, precheck_trim_whitespace, precheck_normalize_cas, precheck_name_cleaning, precheck_isotope_shortcodes, precheck_multi_analyte, precheck_chiral_restore
provides:
  - "run_cleaning_pipeline() fully migrated to dedup_step + precheck wiring (all dedup-eligible steps)"
  - "Two-pass dedup architecture: Pass 1 covers name chain steps 6-pre through 6d3, Pass 2 covers steps 7-9"
  - "Integration test validating PERF-02 audit trail row_id integrity with 100-row duplicate dataset"
affects: [37-performance-architecture, curate_headless, mod_clean_data, test-cleaning-pipeline-validation]

tech-stack:
  added: []
  patterns:
    - "Inline-transform-as-closure: Steps 1-2 (unicode, whitespace) are inline dplyr::mutate chains; wrapped in local step_fn closures to satisfy dedup_step() step-function contract"
    - "Composite step function: multiple sequential steps grouped into one closure for a single dedup pass (name_chain_pass1, name_chain_pass2)"
    - "NULL-fallback guard for precheck: when reference data is NULL but step has a runtime fallback (ComptoxR), treat as should_run=TRUE rather than skip"
    - "Two-pass dedup boundary: synonym split (row-count-changing) is the hard structural break; Pass 1 on pre-synonym row set, Pass 2 on post-synonym row set"

key-files:
  created: []
  modified:
    - "R/cleaning_pipeline.R - run_cleaning_pipeline() migrated to dedup_step + precheck for all dedup-eligible steps"
    - "tests/testthat/test-cleaning-pipeline.R - integration test for dedup pipeline audit integrity"

key-decisions:
  - "NULL isotope_lookup treated as should_run=TRUE for pass2 precheck: expand_isotope_shortcodes falls back to ComptoxR when lookup is NULL; precheck cannot scan absent data so we default to running the pass"
  - "Pass 1 composite function propagates new_tags from first enclosure strip (enclosure_result$new_tags) to orchestrator for tag_map_updated and new_tags accumulation"
  - "Pass 2 runs only when any of three prechecks are TRUE; if all FALSE, three build_skip_result() calls are added to audit_combined for log completeness"

patterns-established:
  - "Inline-transform closure pattern: wrap dplyr::mutate(across(...)) chains in a local function(df_in, ...) returning list(cleaned_data, audit_trail) to satisfy dedup_step contract"
  - "NULL-guard before precheck: if (is.null(lookup_val)) list(should_run=TRUE, est_changes=NA_integer_) else precheck_fn(df, cols, lookup_val)"

requirements-completed:
  - PERF-04

duration: 8min
completed: "2026-04-24"
---

# Phase 37 Plan 03: Orchestrator Dedup+Precheck Migration Summary

**run_cleaning_pipeline() fully migrated to dedup_step + precheck gates for all 15 cleaning steps, with two-pass name-chain dedup boundary split at synonym split**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-24T19:29:16Z
- **Completed:** 2026-04-24T19:37:30Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Steps 1 (unicode), 2 (whitespace), and 3 (CAS normalization) each gated by their precheck predicate and wrapped in `dedup_step()` — inline transforms converted to local closures to satisfy the step-function contract
- Name chain split into two dedup passes: `name_chain_pass1` (steps 6-pre through 6d3) runs as one composite dedup group; `name_chain_pass2` (steps 7-9) runs as a second composite dedup group on the post-synonym row set
- Synonym split (Step 6e) intentionally runs outside any dedup per D-01 (changes row count)
- Integration test added: 100-row dataset with 5 distinct base names (20x repeat each) validates dedup fires and audit row_ids stay within bounds (PERF-02)
- Full test suite: FAIL 3 / PASS 1634 — same 3 pre-existing failures in test-cleaning-reference.R / test-reference-provenance.R (unrelated to dedup migration), 3 net new tests pass

## Task Commits

1. **Task 1: Wire dedup and pre-checks into Steps 1-3** — `8db7378` (feat)
2. **Task 2: Wire dedup Pass 1 and Pass 2, add integration test** — `168c0ce` (feat)

**Plan metadata:** (committed with SUMMARY below)

## Files Created/Modified

- `R/cleaning_pipeline.R` — `run_cleaning_pipeline()` migrated; inline-transform closures for Steps 1-2; `name_chain_pass1` and `name_chain_pass2` composite functions; NULL isotope_lookup guard
- `tests/testthat/test-cleaning-pipeline.R` — integration test: "run_cleaning_pipeline with dedup produces identical results to pre-dedup baseline"

## Decisions Made

- **NULL isotope_lookup → always run pass2:** `precheck_isotope_shortcodes` returns FALSE when lookup is NULL, but `expand_isotope_shortcodes` has a ComptoxR fallback. Added `is.null(isotope_lookup_val)` guard at orchestrator level to emit `should_run=TRUE` rather than silently skipping isotope expansion. Without this, all existing isotope and multi-analyte tests failed.
- **Pass 1 new_tags propagation:** The composite `name_chain_pass1` returns `new_tags = enclosure_result$new_tags` (from first `strip_terminal_enclosures` call, Step 6a). These are then merged back into the orchestrator's `new_tags` and `tag_map_updated` after `pass1_result` completes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] NULL isotope_lookup precheck returns FALSE, blocking ComptoxR fallback path**
- **Found during:** Task 2 (Pass 2 wiring) — validation tests for isotope expansion and multi-analyte all failed
- **Issue:** `precheck_isotope_shortcodes(df, name_cols, NULL)` returns `should_run=FALSE` because it can't scan an absent lookup table. But `expand_isotope_shortcodes` with `isotope_lookup=NULL` falls back to `ComptoxR::pt$isotope` and successfully expands shortcodes. The combined pass2 precheck (`isotope || multi || chiral`) evaluated to FALSE, so pass2 was entirely skipped.
- **Fix:** Added orchestrator-level guard before calling precheck: `if (is.null(isotope_lookup_val)) list(should_run=TRUE, est_changes=NA_integer_) else precheck_isotope_shortcodes(df_final, name_cols, isotope_lookup_val)`. This preserves the original always-run behavior when no cached lookup is provided.
- **Files modified:** `R/cleaning_pipeline.R` (orchestrator only, not precheck function)
- **Verification:** All 61 validation tests pass after fix
- **Committed in:** `168c0ce` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug in precheck-to-step contract)
**Impact on plan:** Essential fix for correctness — without it, isotope expansion and multi-analyte flagging were silently skipped for all calls where reference_lists=NULL (the common case in tests and headless usage without a pre-built reference cache).

## Issues Encountered

The precheck predicate functions (Plan 02) were designed with the assumption that NULL reference data means no work is possible. This is valid for steps that absolutely require reference data (e.g., CAS normalization, strip_reference_terms). For `expand_isotope_shortcodes`, the step has an internal ComptoxR fallback that the precheck cannot anticipate. The fix is a one-line NULL guard at the call site, not a change to the precheck function itself, which keeps Plan 02's precheck design intact.

## Known Stubs

None — all steps wire real data through the dedup path.

## Threat Flags

None — no new network endpoints, auth paths, or schema changes introduced.

## Next Phase Readiness

- All dedup-eligible cleaning pipeline steps are now wrapped with dedup_step + precheck
- Performance gains available immediately: any run_cleaning_pipeline() call with repeated chemical names will deduplicate before processing
- Unit harmonization dedup (Plan 04) is independent and can proceed in parallel
- The two-pass name-chain dedup pattern is established for reuse if new post-synonym steps are added

---

*Phase: 37-performance-architecture*
*Completed: 2026-04-24*

## Self-Check: PASSED

- FOUND: R/cleaning_pipeline.R
- FOUND: tests/testthat/test-cleaning-pipeline.R
- FOUND: .planning/phases/37-performance-architecture/37-03-SUMMARY.md
- Commit 8db7378: feat(37-03): wire dedup+precheck into run_cleaning_pipeline Steps 1-3 — FOUND
- Commit 168c0ce: feat(37-03): wire two-pass dedup into name chain and add integration test — FOUND
