# Issue #83 review and fix plan

Reviewed 2026-10-07. [Issue #83](https://github.com/seanthimons/concert/issues/83): “Verified unresolved rows disappear from pending review after exact-match ties.” Review only; no implementation, decision edits, registry assignments, comments, commits, or branch changes.

## Conclusion and baseline

The package queue gap is confirmed. `pending_rows()` excludes every non-NA flag before considering `error`/`unresolvable` status. Consequently a VERIFIED row with no selected identity can produce an empty queue and `done: TRUE`, even though workbook export correctly marks the row as needing review. A narrowly scoped fix should reopen contradictory VERIFIED decisions while preserving their provenance and keeping intentional FOLLOW-UP/BAD dispositions outside ordinary pending review.

Checkout: `41ae70a0cb1131af95ccbb56e401fb5c9ca77e95`, described as `v0.5.3-1-g41ae70a`; DESCRIPTION version 0.5.3. The commit after v0.5.3 is documentation. `git diff v0.5.3 -- R/curate_iterate.R R/consensus.R R/curate_stages.R R/export_helpers.R` is empty. The inspected behavior therefore matches the issue's v0.5.3 baseline (`33c775e843c7dbe85b2201ebe07ccd840487f8af`). Existing unrelated untracked workspace files were left alone.

Read repository guidance in CLAUDE.md and CONTEXT.md; no applicable AGENTS.md was found in ancestors or the reviewed directories. The explicit review-only assignment overrides guidance to implement on a feature branch and commit iteratively. CLAUDE.md requires a fresh-session Shiny cold boot if a future implementation touches app/UI/reactive code. CONTEXT.md distinguishes applied state from stale configuration; the guard should reflect current accepted results, not infer acceptance from an old flag.

## Evidence and independently confirmed behavior

Fetched the issue with `gh issue view 83 --repo seanthimons/concert --json number,title,body,url,comments` (no comments). Read the linked [audit](https://github.com/seanthimons/tyson_treatment_pilot/blob/42af363/outputs/concert-curation/needs_review_followup.md) and [inventory](https://github.com/seanthimons/tyson_treatment_pilot/blob/42af363/outputs/concert-curation/needs_review_followup.csv) using authenticated `gh api repos/seanthimons/tyson_treatment_pilot/contents/outputs/concert-curation/<filename>?ref=42af363`, decoding the API content in memory. The public raw URL returned HTTP 404; authenticated retrieval succeeded.

Independent CSV assertions confirm the *saved inventory's contents*: 169 inventory rows; 16 in `verified_without_selected_identity`; all 16 have VERIFIED, error, blank consensus DTXSID, and `needs_review = 1`; names are PFHxDA (14), PFTrDA (1), Perfluoroalkanes (1). Original row 9406 stores PFHxDA ties `DTXSID1070800; DTXSID701026646` with acid/anion names. PFTrDA original row 9683 stores `DTXSID20892489; DTXSID90868151`. Perfluoroalkanes row 4380 stores `DTXSID30894934; DTXSID60109225`, with the first ID also in source metadata and the unverified resolver candidate. Their common old reason is “Low-similarity match confirmed: synonym, trade name, abbreviation, or CAS-registry name.” These are independently checked saved-output assertions, not fresh registry validation, a workbook replay, or proof of the correct chemical assignments. No chemical identity was selected or validated here. The audit says the exported workbook had 11,221 rows and 178 review rows; those workbook totals were not independently reconstructed in this review. Findings overlap and must not be summed.

Source boundaries:

- `R/curate_iterate.R:194`: `pending_rows()` computes `flagged <- !is.na(rs$row_flag)` and gates both ordinary pick and no-match queues with `!flagged`. Multi-analyte review has a separate inclusion path. Existing tied identifiers are carried in `pending$tied_dtxsids` even for an error row.
- `R/curate_iterate.R:516`: `done <- nrow(pending) == 0`. `write_status_md()` says all rows are resolved or flagged when done; there is no dedicated contradictory-verification diagnostic. Templates currently say every flagged row leaves pending.csv.
- `R/consensus.R:396`: `set_row_flags()` updates only flag and reason. It intentionally neither chooses an identity nor changes consensus status. Existing tests explicitly preserve that separation.
- `R/consensus.R:153`: tie-only rows with no other identifier remain error with NA consensus ID. Existing row flags/reasons survive classification. This is appropriate identity protection; fixing the queue should not change tie classification.
- `R/curate_stages.R:303`: `stage_review()` validates explicit review picks, then sets manual identity, pin, and resolution method. Flags are applied afterward. `content_row_mask()` matches cleaned name and optional CAS, potentially multiple rows. Rerunning decisions re-applies a stale flag even without restoring a prior Shiny session.
- `R/export_helpers.R:79`: export derives `needs_review` from error/unresolvable, FOLLOW-UP, incoming review state, and unreviewed WQX. VERIFIED does not suppress an error. This explains the queue/export contradiction; export should retain this protection.

Ran isolated `Rscript --vanilla` checks. `fs`, `tibble`, `testthat`, and `dplyr` are unavailable. Source-loaded `R/consensus.R`; extracted the current `is_multi_analyte_review_row`, `first_tag_col`, `pending_rows`, and `empty_pending` definitions into a private environment. Supplied the standard null-coalescing helper. For the two pending constructors only, replaced `tibble::tibble` with `data.frame` in memory so selection could execute without dependencies. No predicate or identity logic was changed; this is a source-isolated reproduction with a constructor shim, not a run of the installed package. Results/assertions:

| Synthetic state | Current pending count | Confirmed result |
| --- | ---: | --- |
| VERIFIED, error, NA identity, two PFHxDA ties | 0 | Implied completion TRUE |
| Same row, flag cleared | 1 | `no_match`; both tied IDs retained |
| FOLLOW-UP, error, NA identity | 0 | Intentional disposition excluded |
| VERIFIED, manual, selected identity | 0 | Valid reviewed identity excluded |
| Set VERIFIED on an error row | — | Status and selected identity unchanged |
| Classify one tied name source with no selected ID and old VERIFIED | — | error, NA ID, prior flag and reason preserved |

The actual installed-package reproduction and test suite remain unrun because dependencies are missing. No packages were installed and renv bootstrap was avoided.

## Proposed implementation boundaries

1. Add one vectorized, internal contradictory-verification predicate near the resolution-state helpers in `R/consensus.R`. Detect VERIFIED with current unresolved status (`error`, `unresolvable`, `disagree`, `suggested`) or a missing/empty/whitespace-only selected identity. Handle absent columns and NA status deliberately. Pinned state must not override a contradiction. Preserve a valid reviewed WQX name-only identity as an explicit exception: WQX intentionally supports a canonical name without a DTXSID, and issue #82 tracks that separate path. Confirm the exception with `consensus_status == "wqx"` and a present canonical `consensus_name`, using the existing WQX review contract; do not equate every blank DTXSID with failure.
2. In `R/curate_iterate.R`, OR the contradiction mask into pending inclusion independently of old flag and pin gates. Use a distinct `pending_type`, such as `verified_unresolved`, so a row is actionable even if its old status would otherwise appear accepted. Preserve multi-analyte precedence to avoid duplicates. Retain both tie IDs, current evidence and original row IDs. Add prior `row_flag` and `row_flag_reason` to pending output and `empty_pending()` together, so reviewers can see the stale decision without mutation. Use the existing no-match evidence path for error ties; `get_resolution_options()` currently returns no ordinary options for error status, so the dedicated tied-ID field must remain available.
3. Update `write_status_md()` and starter decision comments to explain that VERIFIED requires a current accepted identity; show contradictory-verification counts and why the run is incomplete. With contradictions represented in pending, the existing `done` calculation becomes safe without a second divergent completion predicate. FOLLOW-UP/BAD can still complete disposition review while exported `needs_review` may remain TRUE; describe completion as curation decisions dispositioned, not universal identity resolution.
4. Keep `set_row_flags()` backward compatible: preserve flag and reason even when contradictory. Do not reject legacy input before it can be surfaced, erase the old reason, rewrite VERIFIED automatically, change consensus identities, or modify tie ranking. Keep `stage_review()`'s explicit validated pick pathway. A new validated pick resolves the contradiction; an explicit FOLLOW-UP/BAD with a specific reason dispositions it. A repeated generic VERIFIED reason alone must leave it pending.
5. Add regression tests in `test-curate-iterate.R` and focused predicate/provenance cases in `test-consensus.R`; check exported review status using `test-export-review.R`. Update generated documentation only if comments/public contracts change. A changelog entry should explain reopened VERIFIED rows and unchanged intentional unresolved dispositions. No new public API, network service, or chemical lookup is needed for the guard.

## Review and identity safeguards

Never auto-select acid, anion, the first tie, a PubChem hint, or an unverified resolver/source ID. Membership validation of a DTXSID establishes registry existence, not correspondence to the dataset's acid/anion or class scope. The pilot must separately revisit the three name-level decisions against source methods/SDS and registry evidence, then record an explicit pick or specific unresolved disposition. Preserve prior decisions, reasons, current candidate evidence, and original row IDs in artifacts.

Name-keyed review picks propagate across every matching cleaned name, with CAS restricting only when supplied and available. PFHxDA spans sources/quarters; reviewers must establish shared scope before applying one name-wide pick. Where identical names require different identities across sources, the current key cannot safely express the distinction; report that limitation and use unresolved dispositions until a separately reviewed decision-key change is available. Do not broaden #83 into source-ID ingestion, stale FOLLOW-UP reopening, automatic provenance migration, or a general evidence-fingerprint framework. The guard catches a visible contradiction; it cannot detect every changed candidate set when an old selected ID remains present.

## Regression and validation plan

Meaningful acceptance cases, using offline fixtures and mocked registry validation:

- VERIFIED + error + NA, empty, or whitespace selected ID is pending and yields `done: FALSE`; current tie candidates and old reason survive, including an original row ID different from row position.
- VERIFIED + unresolvable/disagree/suggested is surfaced; unresolved status must not disappear merely because a stray selected ID or `.pinned = TRUE` remains.
- VERIFIED + valid manual/agree/single selected ID stays out of pending; all-accepted fixtures still complete.
- FOLLOW-UP and BAD unresolved rows remain intentionally excluded from ordinary review; no global “all flags invalid” behavior.
- Explicit validated pick closes a reopened tie without choosing the other candidate, retains historical flag/reason, and is emitted in replay. Invalid picks fail validation. Specific FOLLOW-UP dispositions close it without inventing an identity. Merely reapplying VERIFIED does not close it.
- Empty state/missing optional columns are safe; pending schema remains stable; multi-analyte warning is retained once and keeps its existing priority.
- A legitimate VERIFIED WQX canonical name without DTXSID is not reopened by this chemical guard; an error row with WQX metadata is still contradictory. Coordinate this boundary with #82 without folding its fix into #83.
- Mocked `curate_iterate()` rerun starts with an accepted row/old VERIFIED decision, changes pipeline evidence to an exact tie, emits pending/status/replay with `done: FALSE`, and cannot silently write final completion outputs. Repeated reruns remain deterministic.
- Export preserves `needs_review = TRUE` for unresolved VERIFIED; no change clears incoming review merely because a flag exists.

After installing/restoring the project's dependencies in an authorized implementation environment, run focused consensus, iterate, export-review, and review-resolution tests first; inspect offline replay artifacts and run package checks appropriate to the changed code. Run a fresh-session Shiny cold boot if UI modules or reactive state are touched. A dependency-complete full pipeline replay is subsequent integration validation, distinct from fresh registry validation of pilot identities. No external evidence fetch is needed in CI.

## Dependencies, limitations, and next steps

Package work has no required chemical-assignment dependency. Dependency restoration is required for real testthat/package validation. WQX exception behavior should be coordinated with #82; deliberate FOLLOW-UP exclusion is an acceptance requirement, not a bug to remove. No claim is made that all changed decisions can be detected without stored evidence history.

Recommended next action: implement the internal guard and pending/status changes with offline regressions, then separately request pilot source-scope review of PFHxDA, PFTrDA, and Perfluoroalkanes. The 16 rows should reappear as unresolved review before any new chemistry choice is made.
