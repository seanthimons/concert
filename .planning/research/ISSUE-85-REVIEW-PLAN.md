# Issue #85 review and fix plan

Reviewed 2026-10-07. Issue: https://github.com/seanthimons/concert/issues/85

## Scope and baseline

Expose candidate-validation work on unresolved flagged rows while preserving their saved dispositions and preventing automatic identity acceptance or repeated reopening of unchanged rejections. This is distinct from reconciling flags on rows that already have a selected identity.

The checkout is `41ae70a0cb1131af95ccbb56e401fb5c9ca77e95` (`v0.5.3-1-g41ae70a`). Its relevant runtime files have no differences from v0.5.3 (`33c775e843c7dbe85b2201ebe07ccd840487f8af`); the intervening commit is documentation only. No applicable AGENTS.md was found in the workspace or ancestor directories. Read CLAUDE.md: retain its performance guidance, and require a fresh Shiny cold boot if implementation later touches UI/server code. The explicit review-only instruction overrides its branch/commit guidance. No other issue plans were read.

## Independently confirmed behavior

- `R/curate_iterate.R:194`, `pending_rows()`, treats every non-NA row flag as sufficient to exclude ordinary unresolved or pick-required rows. It does not inspect candidate evidence or validation status. Multi-analyte review has a separate exception.
- An isolated execution of the current function with a FOLLOW-UP Diminazene row, blank consensus identity, resolver `DTXSID7043792`, and `unverified` status returned zero pending rows. Removing the flag returned one `no_match` row with its resolver evidence retained. Its ordinary `candidates` field was blank because `get_resolution_options()` in `R/consensus.R:442` excludes error/unresolvable statuses and considers only normal lookup columns.
- `unresolved_name_queries()` filters unresolved status and blank consensus identity, not flags. Injected resolver/PubChem lookups therefore collected candidates on the flagged row, retained FOLLOW-UP, and never assigned consensus identity. Injected public checking produced `unverified` on error, `not_public` on an empty membership result, and `public` on a returned ID. All three remained excluded from pending review.
- `R/pubchem_fallback.R:301` catches public-membership errors as `unverified`. `ensure_dsstox()` requires explicit `options(concert.dsstox_install = TRUE)` before installing/refreshing; stale local data can be used without refresh. An unverified candidate is not a rejection.
- `R/curate_stages.R:277` reapplies content-keyed row flags after curation. Current flag decisions have only name, optional CAS, flag, and reason; there is no structured evidence-at-disposition snapshot. Reapplying the same decision cannot establish when it was originally reviewed.
- `stage_curate()` caches the full pipeline result, including resolver candidates and membership statuses. Its cache key does not include registry version or local DSSTox availability. Installing a local database does not by itself refresh cached `unverified` evidence.
- `validate_manual_dtxsids()` in `R/curation.R:1641` currently collapses API failure and successful no-result into `is_valid = FALSE`. It is suitable for blocking acceptance, but its boolean alone is unsuitable for a persisted definitive rejection. Direct-ID responses also need an exact requested-ID check before candidate validation is considered successful.
- `curate_iterate()` sets `done` solely from pending row count. Its existing contract intentionally permits flagged unresolved rows to finish. Any added actionable candidate-validation queue must be included in completion accounting; an informational legacy report need not silently change that contract.

Reproduction limits: R 4.6.1 is available, but fs, tibble, dplyr, testthat, and ComptoxR are missing from the vanilla library. Used `Rscript --vanilla` and parsed selected current function definitions into an isolated environment. Replaced only `tibble::tibble` constructors with base `data.frame` in memory and injected external candidate/public-check functions; the queue predicates and discovery code were otherwise unchanged. All assertions above passed. This is an isolated code-path reproduction, not an installed-package test, live chemical validation, DSSTox download, or full pipeline replay. No source files or dependencies were modified.

## Saved evidence checked separately

Read the issue and its linked audit/inventory at pilot commit `42af363` using authenticated `gh api` contents access. Anonymous raw links returned 404; authenticated access succeeded.

- Audit: https://github.com/seanthimons/tyson_treatment_pilot/blob/42af363/outputs/concert-curation/needs_review_followup.md
- Inventory: https://github.com/seanthimons/tyson_treatment_pilot/blob/42af363/outputs/concert-curation/needs_review_followup.csv

Independently parsed the saved inventory: 169 rows total; the named group has exactly 15 rows, all FOLLOW-UP with blank consensus DTXSID; 13 resolver statuses are `unverified` and two are `no_hit` with PubChem-only IDs. The saved row 541 has source/resolver `DTXSID101538364`; Eoxin rows 553/554 have PubChem IDs matching their source metadata; Diminazene 2894 has source/resolver/PubChem `DTXSID7043792`. Phytonadione 4906 contains source/PubChem `DTXSID8023472` and resolver `DTXSID101511904`.

The inventory also preserves explicit Dashboard-rejection reasons for Prochloraz-d4 `DTXSID801539501` and Sisapronil `DTXSID101538590`; the latter has malformed PubChem evidence `":"`. Those are documented prior outcomes, not independently revalidated rejection results. The audit reports the October 6 run lacked local DSSTox. Neither present registry membership nor chemical equivalence was established by this review. Counts overlap other findings and must not be added together. The old reason's date and the later saved candidate fields support a reconciliation need, but without a historical machine-readable snapshot the exact candidate change cannot be proved per row.

## Recommended bounded implementation

Prefer a shared internal evidence comparator plus a report/queue extension; do not change consensus scoring or blanket-clear flags.

1. **Normalize candidate evidence in a small internal helper, e.g. `R/candidate_review.R`.** Read resolver semicolon-separated IDs and PubChem CID:DTXSID pairs without putting them into `find_dtxsid_cols()` or trusted consensus columns. Retain per-source attribution, CID, query and validation outcome. Accept only complete `^DTXSID[0-9]+$` tokens; ignore/report `":"`, empty/NA tokens and malformed strings. Deduplicate and sort for stable comparison. Keep source IDs as attributed metadata when available, not a new trusted identifier tag. Parent/desalted IDs remain explicitly separate suggestions; never promote a parent to the salt or isotope identity.
2. **Persist the evidence actually reviewed with a disposition.** Extend existing `row_flags` tables with optional, versioned `reviewed_candidate_evidence` and `candidate_disposition` fields; validate a small supported disposition set such as `no_hit`, `rejected`, and `deferred`. The snapshot contains normalized source/query/ID evidence and any definitive per-candidate validation results with service/build/version metadata. Preserve `flag` and `reason`. Only an explicit review decision supplies or replaces this snapshot: never stamp the freshly discovered set as reviewed simply because an old row_flag is reapplied. Existing four-column flag tables remain valid.
3. **Compute a candidate-review report after `stage_review()`.** Limit the actionable workflow to blank-consensus unresolved rows with candidate IDs; retain row flag/reason, current evidence, prior snapshot, change reason and per-candidate status. A `no_hit` snapshot gaining IDs becomes `candidate_validation`; conflicting IDs remain a conflict requiring identity review. Compare canonical evidence rather than string order or timestamps. An unchanged rejected/deferred snapshot is recorded as already dispositioned and does not reopen. A changed candidate set or meaningful validator-version/outcome change can require another review; a timeout or repeated unavailable check alone is not fresh evidence.
4. **Handle legacy decisions honestly.** Without a snapshot, emit `baseline_unknown` in the report and preserve the original reason. Do not label current IDs definitively new or erase an explicit historic rejection. This report exposes all 15 audited stale no-record cases without needing to infer a chemical decision from prose. Do not put legacy known-rejection rows into the actionable queue merely because the same candidate remains unverified. Seed a structured prior no-hit/rejected snapshot only through an explicit reviewed migration; no automatic reason-string classifier. Preserve legacy rejection reasons in the report until migrated.
5. **Wire the result into the iteration artifacts.** `R/curate_iterate.R`: add actionable candidate-validation rows to `pending_rows()` without clearing flags, include flag/reason and the current/prior evidence in its stable empty/nonempty schema, and write the full report as `candidate_review.csv` on every run (including an empty header-only report). `write_status_md()` explains validation versus identity decisions, flags baseline-unknown legacy work, and never implies that an unverified candidate is accepted. New actionable rows affect `done`; unchanged rejected/deferred rows and legacy informational rows do not. Document that legacy completion may still have unresolved flagged rows and candidate-report work.
6. **Preserve replay and validation semantics.** `R/curate_stages.R`: carry optional snapshot/disposition fields through matching and resolution state without resetting them. `R/code_generation.R` already serializes row_flags as an optional object; verify its serializer preserves added fields rather than introducing a separate decision API. Ensure exported/imported review decisions retain them where applicable (`R/export_helpers.R`, `R/config_import.R`, and review override helpers), with schema validation and defaults for old files. For direct validation, add a result-preserving internal adapter that distinguishes available-and-rejected from transport/unavailable errors; leave existing public boolean behavior compatible. Public membership and identity acceptance remain separate. Do not automatically run registry lookups merely to build a report.
7. **Refresh validation separately from name discovery.** Provide an explicit candidate validation operation that can recheck saved unverified candidates against already available local data or configured direct API access without discarding all cached name searches. Cache outcomes by candidate ID plus validator/build version, preserve definitive rejections, and do not cache outages as rejections. Version the candidate-review snapshot/cache schema. Retain the DSSTox opt-in gate; no new download or background refresh path.

For an initial small patch, steps 1–5 plus snapshot replay round-trip are the acceptance-critical change. The richer explicit validation operation can follow once unavailable/rejected semantics and version metadata are defined, but reporting must already distinguish those outcomes and avoid silently reusing a boolean rejection on service failure.

## Review and identity safeguards

- Source agreement is evidence, not public-membership confirmation or identity acceptance. Even all three Diminazene IDs agreeing does not justify selecting an ID automatically.
- Phytonadione must display both IDs and attribution. A successful public-membership check for either does not resolve the identity conflict.
- Prochloraz-d4 must retain isotope scope; do not substitute unlabelled Prochloraz or a standardized parent. Apply the same constraints to salts and stereochemical labels in the 15-row evidence group.
- `content_row_mask()` currently applies a name-only decision to every matching cleaned name when CAS is absent. Candidate snapshots must be checked against each matched row's source/context evidence, not copied indiscriminately to different provenance rows. Before accepting or migrating a decision, surface match counts and refuse ambiguous, materially different evidence sets. Row position alone is not a persistent decision key; preserve original row IDs for reporting and multi-analyte part identity where relevant.
- A manual accepted pick still needs existing direct-ID validation plus human source/identity confirmation. Candidate-validation results alone do not pin a row, assign `consensus_dtxsid`, clear FOLLOW-UP, or set VERIFIED.
- Keep historic explicit rejections visible with validator/reason/version; error, missing database, and stale database are separate limitations. Changes must be reviewable and replayable without live network access.

## Meaningful regression cases

| Case | Required observable result |
| --- | --- |
| FOLLOW-UP + explicit prior no-hit snapshot + new resolver ID, public check unavailable | One candidate-validation pending row; unavailable is explicit; flag/reason and blank consensus preserved. |
| FOLLOW-UP + PubChem-only CID:ID evidence | Candidate validation appears even with resolver no_hit; CID attribution preserved. |
| Source/PubChem A versus resolver B (4906-shaped fixture) | Both IDs and sources reported; conflict cannot be auto-selected by majority. |
| Same IDs in reordered/duplicated fields | No evidence-change reopening. |
| Explicit rejected snapshot, same Prochloraz-d4/Sisapronil IDs | No new actionable row or repeated validation attempt; rejection and isotope constraint stay visible. |
| Rejected old ID plus genuinely new ID | New evidence requires review; previous rejection remains attached to the old ID. |
| Public-membership checker/API unavailable versus successful no-result | Different outcomes; outage never persists as definitive rejection. |
| Missing/stale DSSTox without opt-in | Zero install/refresh calls; limitation reported. |
| Unverified cached candidate followed by explicit check with local data available | Revalidation works without rerunning unrelated searches; cache version and outcome change recorded. |
| PubChem CID but no valid DTXSID (`":"`, empty, NA) | No candidate-validation work based on malformed token; CID hit remains diagnostic. |
| Legacy no snapshot and legacy explicit rejected reason | baseline_unknown report, preserved reason, no fabricated historical delta and no repeated legacy rejection reopening. |
| Same cleaned name across different source IDs/CAS/split parts | Acknowledgment cannot suppress materially different rows; identifiers and part scope preserved. |
| Persisted disposition through decisions/replay/export/import | Canonical snapshot and outcome retained; old decision tables still work. |
| Iteration with actionable candidate work versus unchanged rejection | First reports done FALSE; second does not reopen merely because it remains unresolved. Empty/nonempty report schema stable. |
| Pinned/selected identity, BAD, unrelated FOLLOW-UP, unresolved multi-analyte | Existing handling retained; any diagnostics do not silently change the saved identity/flag. |

Extend `tests/testthat/test-pubchem-fallback.R`, `test-curate-iterate.R`, `test-review-resolution.R`, `test-code-generation.R`, and export/import tests as boundaries require; use injected services and small synthetic fixtures. Add focused comparator tests for stable snapshots and changed evidence. Run these with restored dependencies and then relevant package checks. If UI parity is included, reuse the shared report helper in `R/mod_review_results.R`, add targeted rendering/dedup coverage, and perform the mandatory fresh-session Shiny cold boot.

## Dependencies and limits

The malformed PubChem token needs a producer fix as well as defensive parsing here; treat that as a separate dependency rather than letting `":"` reopen review. Shared flag/evidence persistence and content-key ambiguity may overlap other issues, but this review does not resolve their scope. No full dependency restoration, package test suite, pilot replay or live chemical validation was performed. No issue comments, commits, branch switches, PRs, or runtime fixes were made. The only written artifact is this plan.
