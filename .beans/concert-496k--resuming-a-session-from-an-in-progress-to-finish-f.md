---
# concert-496k
title: Resuming a session from an in-progress to-finish file should still output all corrections that were outputted against the RAW file.
status: in-progress
type: bug
priority: normal
created_at: 2026-07-14T16:01:34Z
updated_at: 2026-07-14T20:32:12Z
---

Feedback from user: they started a curation but then had to stop. The presumption was that by uploading a concert output Excel workbook back into a fresh session would restore all changes that were recorded against the raw data. Code replay only seems to output incremental changes from workbook to workbook not against raw. 

Could be related but flagged columns (eg bad or verified or follow-up) do not seem to be outputted either when resuming from a finished workbook and changes occur. 

Desired end state should be full replay against RAW data, even if resuming from a `finished` session. 


---

## Root-cause analysis (2026-07-14)

Replay overrides = `diff(script_baseline_state, resolution_state)` (`build_review_overrides`). On resume, `script_baseline_state` is meant to be reconstructed as the automated-from-raw baseline by replaying stored `baseline_cell` records from the workbook's Session State sheet (`restore_script_baseline`, `config_import.R:358`).

Reproduced end-to-end: when `baseline_cells` ARE present, replay correctly emits every correction against raw (both sessions' consensus_dtxsid, `.pinned`, `row_flag = BAD`). The mechanism itself is sound.

It breaks two ways, both producing the reported symptoms:

1. **Resumed workbook carries no `baseline_cells`** (likely the user's case). `restore_script_baseline` then falls back to `baseline = final` (`config_import.R:364-373`). Then `diff(final, new_edits)` = only post-resume edits ("workbook to workbook, not against raw"), and flags already in `final` diff to nothing → not emitted. `baseline_cells` go missing when `script_baseline_state` was NULL or **row-count-mismatched** vs final at the original export (`build_baseline_diff_rows` returns NULL on mismatch, e.g. dedup changed row counts), or the workbook predates the feature.

2. **Re-running curation after resume** wipes imported corrections: `mod_run_curation.R:172` overwrites `resolution_state` with a fresh automated run; `:265` resets `script_baseline_state`. Secondary path.

## Fix (approved: A + B)

- **A (robust):** When `baseline_cells` are absent on resume, stop falling back to `baseline = final`. Record every non-default review-column value in the imported workbook as an override against an empty/automated baseline so replay re-runs automated curation from raw then stamps the workbook's exact values on top (output == workbook, full fidelity against raw).
- **B (harden):** Make baseline persistence tolerant of row-count changes / never silently drop to `baseline = final`; guard the `mod_run_curation` clobber so resumed corrections aren't lost without warning.

Not caused by the reference/map-snapshot replay work on branch dev-replay-analysis-v2; adjacent subsystem (session-state persistence).


## Implemented (awaiting UAT) — commit 99577c8

A + B done on branch dev-replay-analysis-v2:
- `restore_script_baseline()` falls back to a review-emptied baseline (new `empty_review_baseline()`) instead of the curated state, so a baseline-less workbook replays every review correction (dtxsid, flags, pins, manual entries) against a fresh raw curation.
- `mod_run_curation` captures existing review corrections before a re-run and re-applies them to the fresh automated results; pure automated stays as the replay baseline.

Tests: rewrote "imports without baseline records" to assert full replay reconstruction; export/import + cleaning-reference + code-generation suites pass (0 failures); Shiny cold-boot clean.

Known limitation (ponytail-noted in code): prior edits to *tagged input columns* on a baseline-less resume are not recovered (their raw-derived origin isn't known at import). Review-column corrections — the reported case — are.

Needs user acceptance against the actual workbook that triggered the report before closing.


## Follow-up filed
ID-keyed baseline diff deferred to concert-brxw (positional alignment currently holds; not an active bug).


## Item 1 (ToxVal after resume) — VERIFIED, no reconstruction bug
Reproduced: export a non-harmonized workbook -> parse -> hydrate_session_state -> run_harmonization_runtime on the restored state produces ToxVal (3 rows). On resume, reference_lists still carries unit_map + media_map (preserved via merge_reference_lists from the app's startup load) and numeric/study tags restore correctly. So resume -> Run Harmonization -> ToxVal works.

The empty ToxVal in the reported workbook is because it was exported with "harmonization not run" (placeholder sheet); toxval_output is NULL on resume and the ToxVal export control is gated on !is.null(toxval_output) (mod_review_results.R:3822). Resolution for the user: Run Harmonization on the resumed session, then re-export. No code fix required.

Optional UX nudge (not yet done): on resume from a non-harmonized workbook, surface that ToxVal is empty until harmonization is run, instead of a silently hidden/placeholder export.

## Item 2 (export-time transparency) — DONE (commit e42d582)
build_baseline_diff_rows() now logs a console [replay] message with the reason (null baseline vs row-count mismatch) when a workbook is exported without baseline_cells. Warning-only, no user-facing nudge to re-run curation (re-running curation is a full recompute and can change automated results, so it is not advised as a casual fix). Healthy exports stay silent.

## Follow-up
concert-brxw: id-keyed baseline diff (deferred; positional alignment currently holds).
