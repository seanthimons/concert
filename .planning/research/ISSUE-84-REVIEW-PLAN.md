# Issue #84 review and fix plan

Reviewed 2026-10-07. Issue: [Expose obsolete FOLLOW-UP decisions when reruns now select a DTXSID](https://github.com/seanthimons/concert/issues/84).

## Scope and baseline

This is a workflow visibility and decision-maintenance gap, not authority to assign chemical identities or clear flags. The intended result is a durable evidence-change report and accurate completion diagnostics while preserving reviewer dispositions and provenance.

Checkout inspected: `41ae70a0cb1131af95ccbb56e401fb5c9ca77e95` (`v0.5.3-1-g41ae70a`), package version 0.5.3. Its additional commit is documentation about #82. `git diff v0.5.3 -- R/consensus.R R/curate_iterate.R R/curate_stages.R R/export_helpers.R` is empty. No applicable `AGENTS.md` was found in this repository or its filesystem ancestors. `CONTEXT.md` supplies terminology: durable applied input is a “portable replay section,” and draft/stale configuration is excluded from “applied state.” Existing unrelated untracked files were left untouched. No other issue plans were read.

## Evidence and independent checks

Read issue #84 and its pinned [audit](https://github.com/seanthimons/tyson_treatment_pilot/blob/42af363/outputs/concert-curation/needs_review_followup.md) and [CSV inventory](https://github.com/seanthimons/tyson_treatment_pilot/blob/42af363/outputs/concert-curation/needs_review_followup.csv) through `gh`. The issue has no comments.

**Saved-output checks independently repeated:** the inventory contains 169 rows; `review_group == "old_no_record_flag_with_selected_identity"` contains exactly 28; all 28 have nonmissing `consensus_dtxsid` and FOLLOW-UP. Example records retain the September 22 no-record reason:

| Original row | Raw name | Selected DTXSID | Saved status |
| --- | --- | --- | --- |
| 1809 | 1-Hexadecanoyl-2-(9Z-octadecenoyl)-sn-glycero-3-phospho-(1'-myo-inositol) | DTXSID701370845 | single |
| 5536 | Diminazene | DTXSID4022945 | single |
| 10432 | Butaphosphan | DTXSID5048681 | single |
| 10774 | Pyrantel embonate | DTXSID40897057 | single |
| 10871 | Tylosin phosphate | DTXSID801339503 | single |

Row 1809 also has saved `source_dtxsid = DTXSID701370845`. CAS values in the other four rows are respectively 908-54-3, 17316-67-5, 22204-24-6, and 1405-53-4. Preferred-name/scope interpretations in the issue and audit are **reported saved-output evidence**, not independently revalidated registry assignments. This review did not inspect the original workbook or replay the full pilot. Inventory count checks corroborate the reported grouping, not the truth of its historical “no record” premise. Group counts overlap other findings and must not be added together.

**Source mechanism independently confirmed:**

- `R/consensus.R::set_row_flags()` writes only flag/reason after initialization. It neither checks current matching evidence nor records evidence at decision time.
- `R/curate_stages.R::stage_review()` reapplies flags using current cleaned name and optional CAS. It does not compare previous evidence. `content_row_mask()` can match every same-name row when CAS is omitted, and ignores a supplied CAS when no CAS-tagged column exists. Decision scope therefore needs explicit safeguards before adding row-specific snapshots or acknowledgments.
- `R/curate_iterate.R::pending_rows()` excludes flagged rows from its disagree/suggested/error/unresolvable branches. Multi-analyte review is a separate exception. A successful `single` match would not enter this queue even without a flag.
- `R/curate_iterate.R::low_similarity_rows()` also excludes flagged/pinned rows. It cannot serve as the missing reconciliation report.
- `curate_iterate()` sets `done` solely from `nrow(pending) == 0`; `write_status_md()` then reports “All rows resolved or flagged” and export runs. That is queue disposition, not chemical review completion.
- `R/export_helpers.R::build_export_sheets()` continues to set `needs_review = TRUE` for FOLLOW-UP regardless of a selected DTXSID. This protects consumers honoring that field; a nonblank DTXSID alone is not approval.
- `stage_curate()` sets `script_baseline_state` to the current automated result. The export baseline-cell mechanism supports replay edits within that run, not durable evidence from the earlier human decision. Reusing it as a historical decision snapshot would compare the wrong moments.

**Isolated execution independently repeated:** with `Rscript --vanilla`, source the actual consensus and iteration definitions, extract the pure `is_multi_analyte_review_row` definition from the parsed cleaning source, and construct three synthetic FOLLOW-UP rows: gained selected identity (`single`), unchanged no-hit (`unresolvable`), and selected identity with an unresolved source-scope concern (`single`). The real `pending_rows()` returns zero rows and the actual `needs_review` expression extracted from `build_export_sheets()` evaluates `TRUE,TRUE,TRUE`. All flags and original reasons remain identical. The empty-return constructor was replaced with a base data frame because tibble is unavailable; the eligibility calculations were unchanged. Separately, the actual `content_row_mask()` matched two same-name rows with different CAS values when the decision CAS was absent.

These are constructed code-path checks, not a two-run pipeline replay or live chemical validation. Sourcing all of `cleaning_pipeline.R` initially failed on an unrelated top-level stringr dependency; extracting its pure predicate avoided that dependency. Installed-package probes under `--vanilla` found `fs`, `tibble`, `dplyr`, `readr`, and `testthat` unavailable. No dependency installation or renv bootstrap was attempted.

## Proposed implementation boundaries

1. **Define a versioned decision-evidence contract before changing queues.** Add a focused reconciliation helper module, for example `R/review_reconciliation.R`. A decision record needs a stable decision ID/revision, explicit target scope, flag, human reason, decision basis (e.g. `no_identity_found`, `scope_conflict`, `other`, `unknown_legacy`), recorded time, schema version, and immutable decision-time evidence. Capture the selected identity/status/source and normalized source-tagged candidate sets with match tier, tied IDs, lookup/validation states, source identifiers where available, and relevant scope/cleaning context. Store raw structured values as well as a deterministic fingerprint so the report can explain the changes. Candidate order and empty representation must normalize; new validation failures must not masquerade as new usable matches. Keep free-text reasons for people; never infer basis from their wording.

2. **Persist the original snapshot independently of rerun outputs.** Extend `R/curate_iterate.R` decision objects/template with a portable structured `review_decision_evidence` object and an explicit acknowledgment object. Initialize missing evidence into a suggested snapshot artifact for review/adoption; do not silently overwrite `decisions.R`. Once adopted, reruns compare against that immutable snapshot rather than rebasing it at each run. If a managed evidence sidecar is chosen instead, make its durable path/content explicit in replay and prevent accidental replacement by cache refresh. Document ownership and precedence between embedded and sidecar evidence; prefer one authoritative representation. New decisions should capture the evidence the reviewer actually saw, before their flag is applied, and record deliberate manual selections separately from automated evidence.

3. **Handle legacy decisions honestly.** Existing flags have no structured historical snapshot. Emit `baseline_missing` for legacy FOLLOW-UP records; a current selected identity can produce `legacy_flag_with_selected_identity`, which requests review without claiming a proven no-hit-to-hit transition. Never reconstruct past evidence from the September 22 reason or adopt the current result as evidence of what was previously reviewed. A reviewer can import a trusted prior structured export or explicitly establish a present-time baseline and update the decision. If older history is unavailable, retain that limitation in the report. This path is essential for the 28 pilot rows; future-only snapshot capture would leave the actual issue unaddressed.

4. **Compare before review overrides hide changes.** In `R/curate_stages.R::stage_review()`, capture current automated evidence before `review_overrides`, `accept_suggestions`, and `review_picks`, then attach final selected/manual evidence after review. Preserve distinctions between automatic selection, validated explicit pick, and merely available candidates. Expose an unchanged-schema empty reconciliation table on state. Compare all adopted flagged decision records; classify no-hit-to-selected, changed selected ID, candidate/validation changes, unavailable baseline, and missing/ambiguous target. Do not let an old pinned/manual ID hide newly conflicting automated evidence. An intentional FOLLOW-UP that already had the same selected salt/combination and conflict at decision time is unchanged; preserve its flag and count it as outstanding FOLLOW-UP, rather than repeatedly labeling it stale.

5. **Expose an additional report and separate diagnostics.** `curate_iterate()` should always write `review_reconciliation.csv`, including an empty table after resolution to remove stale report contents, and return it with state. Include decision ID/revision, data-row IDs, explicit target key, old/current evidence, change category, basis, preserved flag/reason, acknowledgment state, and recommended review action. Keep the ordinary `pending.csv` contract stable. Add `queue_complete`, reconciliation counts/completion, FOLLOW-UP counts, and a clear overall completion field. Preserve legacy `done` as queue completion initially, label its meaning in status, docs, return value, and CLI messages, and make overall review completion require no unresolved identity queue, reconciliation, or outstanding FOLLOW-UP work. Workbook generation can remain based on queue disposition so reviewers can inspect it; diagnostics must never advertise full review completion merely because it was exported. Review the CLI exit-code contract explicitly before changing it.

6. **Acknowledge evidence deliberately.** A reviewer may replace FOLLOW-UP with VERIFIED after identity/source validation, retain FOLLOW-UP with a specific scope reason and record that the current evidence was reviewed, or retain the unresolved state. Bind acknowledgment to the exact decision revision, target scope, and current evidence fingerprint; rerunning identical evidence should not requeue it, while later changed evidence should. Acknowledgment resolves that reconciliation event only and does not clear FOLLOW-UP or `needs_review`. Preserve prior decisions as history when establishing a new revision. Flag clearing remains an explicit reviewer action.

7. **Carry provenance through existing entry points.** Extend `R/code_generation.R` generation/signature exclusions and `R/curate_headless.R` / `stage_review()` arguments for the adopted evidence and acknowledgments. Ensure generated replay contains the durable inputs, not only a current result hash. Extend `R/export_helpers.R` Session State and `R/config_import.R` hydration if workbook resume is supported in this change. Imported historical evidence must retain its time/revision and must not be replaced by the current same-run script baseline. Add an optional Reconciliation sheet for reviewable workbook output. Defer a full Shiny report UI if necessary, but make `R/mod_review_results.R` flag changes capture compatible evidence before claiming the feature covers GUI decisions. Update `vignettes/headless-curation.Rmd`, roxygen/man documentation, `inst/scripts/curate_loop.R`, and NEWS for the delivered scope.

## Review and identity safeguards

- Match decision evidence by validated content/source scope, not transient row position alone. Include input provenance and original row IDs for traceability; handle reordered rows without silent reassignment. Splits/renames or changed cleaning keys must produce a target-change/migration diagnostic instead of silently inheriting an unrelated decision.
- Existing name/CAS decisions are compound scoped. Expand a report to all affected source rows but do not collapse different source chemical scope just because names match. A missing CAS-tagged column or multiple competing scope keys must be explicit diagnostics. An acknowledgment must not apply to all same-name rows by accident.
- Registry membership validation is necessary for an explicit pick but does not establish chemical scope equivalence. For Diminazene versus diaceturate and Tylosin phosphate versus a bentonite combination, require the reviewer to assess source scope. A saved preferred name or agreeing source ID is evidence to review, never automatic authorization.
- Preserve `row_flag`, `row_flag_reason`, incoming review requirements, selected identities, and provenance during report generation. Keep `needs_review` conservative. Do not automatically clear FOLLOW-UP, mark VERIFIED, accept candidates, or demote a selected ID merely because evidence changed.
- Keep failed lookup, verified absence, unavailable lookup, and missing baseline distinct. Report additions/removals in structured evidence, not changes to run timestamp or candidate ordering.

## Meaningful regression cases

Use deterministic pipeline/API mocks and adopted structured snapshots; no tests should depend on current registry responses.

1. Decision-time no-hit FOLLOW-UP gains an exact name/CAS selected identity: reconciliation appears, ordinary pending stays empty, flag/reason remain, exported `needs_review` stays TRUE, queue completion and review completion differ.
2. Unchanged no-hit FOLLOW-UP: no evidence-change event; outstanding FOLLOW-UP remains visible and review completion is false.
3. Intentional salt/combination/source-scope FOLLOW-UP with the same selected identity and structured conflict: no stale event and no automatic clearance. Newly changed candidate or source evidence creates an event without claiming the conflict is resolved.
4. Legacy no-record wording with selected identity: report missing historical baseline, without asserting transition or parsing prose. Arbitrary wording/language should behave identically. Legacy unchanged no-hit remains visibly missing a baseline until explicitly adopted.
5. Candidate-only addition without selected identity and validation unknown/failed: report evidence change but never promote it; include a candidate removed or selected ID changed case.
6. Repeated reruns preserve the original snapshot. Acknowledgment of the current fingerprint suppresses only that event; another evidence change reopens it. Reason-only edits do not acknowledge a change.
7. Same cleaned name across different CAS/source scopes, omitted CAS, missing CAS tag, reordered rows, split/renamed rows, duplicate keys, and missing targets: no cross-scope acknowledgment or positional reassignment; ambiguity is visible.
8. Candidate reorder, NA versus blank normalization, and lookup timestamps alone do not create false changes. A lookup failure cannot silently erase prior evidence and declare reconciliation complete.
9. Review pick/pin replay does not conceal changed automated evidence. Evidence and acknowledgment round-trip through generated replay and supported workbook import/export without rebasing history.
10. Empty report rewrites stale previous output; errored runs cannot present previous reconciliation as current. CLI/status/return fields and export behavior agree with the documented completion contract.

Extend `tests/testthat/test-curate-iterate.R`, add focused reconciliation tests, and cover export/replay/import in their existing suites. Existing tests intentionally assert `done = TRUE` after FOLLOW-UP removes pending rows; retain that compatibility assertion while adding explicit review-completion assertions. Run these targeted tests and package checks once dependencies are available.

## Dependencies, limitations, and next steps

The snapshot/acknowledgment schema and scope-key contract are prerequisites for reliable comparison. A prior-run output alone is not sufficient if it lacks decision-time meaning. Agree on whether this first increment supports headless decisions only or includes GUI capture/workbook resume; document any omitted path. Do not introduce additional package dependencies solely to hash evidence (`digest` is already imported).

`stage_curate()` caches automated searches by cleaned chemical input/settings; a routine rerun may reuse old API evidence. The reconciliation feature reports evidence actually supplied to it and cannot claim fresh registry checks. Tests must force a changed mocked result or explicit cache invalidation. A cache-refresh policy is an adjacent follow-up, not a reason to silently refresh or delete users' caches here.

The audit's VERIFIED-plus-unresolved and newly available candidate concerns can share diagnostics/snapshot machinery, but #84 should be independently deliverable and must not depend on auto-clearing any flag. Source-ID matching and candidate collection are separate work. Counts and example chemical assignments from the pilot remain saved evidence until a reviewer independently validates them.

Recommended sequence: define schema/scope and legacy behavior; implement pure comparison with focused tests; persist immutable evidence and explicit acknowledgments; integrate iteration diagnostics/report and replay; complete the selected export/import/UI scope; run deterministic tests and document completion semantics. No implementation, commit, branch switch, comment, or PR was performed in this review.
