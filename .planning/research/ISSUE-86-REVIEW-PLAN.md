# Issue #86 review and fix plan

Reviewed 2026-10-07. Issue: [Support explicit source DTXSID evidence and warn when identifier columns are unused](https://github.com/seanthimons/concert/issues/86).

## Scope and conclusion

This is a missing explicit source-identifier workflow plus a configuration diagnostic, not a demonstrated failure to honor an identifier tag. The pilot omitted `source_dtxsid` from its tags. The current taxonomy has no dedicated DTXSID role; `Other` sends values through generic name searching without the source-validation/provenance contract requested here. Add an opt-in DTXSID evidence role, distinct validation outcomes, identity review gates, and unused-column diagnostics. Do not assign the 31 saved source IDs wholesale or infer validity from source/resolver agreement.

Inspected checkout HEAD `41ae70a0cb1131af95ccbb56e401fb5c9ca77e95`, DESCRIPTION version 0.5.3. The issue's observed export used v0.5.3 tag commit `33c775e843c7dbe85b2201ebe07ccd840487f8af`; these commit identities differ, so current-source findings are identified separately from the saved run. Read repository `CLAUDE.md`; no AGENTS.md was found in the checked ancestor paths or relevant source/test directories. The review-only task overrides its branch/commit instructions. Its mandatory fresh-session Shiny cold boot applies to later UI implementation. No fixes, commits, branch changes, package installations, or external comments were performed.

## Evidence and confidence

### Independently confirmed current behavior

- `R/curation.R:21`, `deduplicate_tagged_columns()`: only columns in `tag_map` enter the dedup key map; Name and Other provide `unique_names`, CASRN provides `unique_cas`. Omitted `source_dtxsid` produces neither queries nor warnings in this function.
- `R/tag_helpers.R:37`, `classify_tags()`: chemical roles are Name, CASRN, Other. A proposed `DTXSID` role is currently dropped from chemical dispatch. `R/mod_tag_columns.R` presents those same roles. `R/auto_tag_columns.R` suggests Other for a DTXSID-looking header.
- `R/consensus.R:15`, `find_dtxsid_cols()`: recognizes only `dtxsid` and `dtxsid_*`, not `source_dtxsid`. Sourcing unchanged consensus functions into an isolated R environment confirmed that retained `source_dtxsid` does not resolve a row whose name result is missing.
- The same isolated run confirmed a significant safeguard requirement: adding raw metadata as `dtxsid_source` immediately makes generic consensus select it with status `single`, without registry validation. Never solve this by renaming an input column or broadening the regex to include `source_dtxsid`.
- `map_results_to_rows()` preserves original input metadata but builds evidence columns from configured dedup columns. Its generated columns can collide with input names; explicit generated-evidence ownership is needed when introducing source evidence.
- `validate_manual_dtxsids()` in `R/curation.R:1641` is an existing membership-check starting point, not a sufficient source validator. It collapses API exceptions and no hits into `is_valid = FALSE`, accepts any non-NA returned DTXSID, and chooses a lowest-ranked response without enforcing returned-ID equality or rejecting ambiguous responses. It does not return CAS/scope checks.
- `stage_review()` uses name and optional CAS selectors for `review_picks`. Equal name/CAS rows can have differing source IDs; source evidence must not be accepted across all such rows accidentally. `curate_iterate()` pending extraction excludes flagged rows, so merely displaying candidates in the ordinary pending queue would miss row 2415 (BAD) and row 541 (FOLLOW-UP).

### Independently recounted saved-output evidence

Read the issue and its linked audit and CSV at pinned pilot commit `42af363` (resolved through GitHub API). The raw.githubusercontent.com URLs returned HTTP 404 in this environment; authenticated `gh api repos/seanthimons/tyson_treatment_pilot/contents/...?...ref=42af363` retrieved the pinned files. The audit expressly reports no live identity validation and identifies the source-column omission in the workbook's saved Column Tags. I did not independently extract the workbook's XML here.

CSV assertions independently confirm:

- 169 inventory rows; 31 contain `source_dtxsid_not_used_in_consensus`, all have source DTXSIDs and blank consensus DTXSIDs.
- 17 have resolver/PubChem identifier candidates containing the same source ID; 14 have neither candidate field populated with an identifier.
- Original row 541: `8-iso Prostaglandin F2alpha Ethanolamide`, source and resolver `DTXSID101538364`, resolver status `unverified`, FOLLOW-UP, consensus error.
- Original row 2415: `NoName_3444`, source `DTXSID20902870`, BAD, no resolver/PubChem DTXSID candidate, consensus error.
- The audit reports Prochloraz-d4 source/resolver agreement with failed Dashboard validation. This is reported saved evidence, not an independently repeated live validation.

These counts overlap other findings and must not be added to the total. None establishes valid chemical assignments or that all 31 rows are recoverable.

### Isolated verification and limitations

Ran `Rscript --vanilla` with R 4.6.1. `tibble`, `dplyr`, `testthat`, `ComptoxR`, and `fs` are unavailable; `jsonlite` is available. No renv bootstrap was invoked. Executed unchanged base-R `classify_tags()`, `find_dtxsid_cols()`, and `classify_consensus()` with synthetic rows and assertions. For `deduplicate_tagged_columns()`, copied the function in memory and replaced only its `tibble::tibble` constructor with `data.frame` so its query/dedup logic could execute. That adapter makes this an isolated logic check, not a test of tibble behavior or the complete pipeline. It asserted omitted IDs absent from the query/key map, zero warnings, and Other-tagged IDs entering the name pool. No files were changed by the reproduction. Full pipeline, Shiny, and live registry identity validation remain unrun.

## Proposed implementation contract

1. Add explicit `DTXSID` chemical evidence role, labeled “Source DTXSID” in the UI. Configuration example: `tag_map <- list(raw_name = "Name", raw_casrn = "CASRN", source_dtxsid = "DTXSID", source = "Other")`. The role opts into direct identifier validation and review evidence, not implicit trust. Keep Other behavior compatible; document that it is generic lookup and not the new source validation path. Do not silently retag existing workbooks or suggestions.
2. Add `ignored_identifier_cols = character()` for intentional retained metadata. Persist it in headless decisions, replay, and session settings. Explicit ignore disables source lookup and acknowledges the diagnostic; it never creates consensus evidence. Validate named columns and reject a column configured both DTXSID and ignored. The UI should provide an explicit “Keep as metadata” acknowledgment.
3. Retain original raw ID, normalized candidate ID, source column and row identity. Trim and uppercase for lookup only; format validation must reject blank/malformed identifiers before API calls. Define the supported DTXSID grammar from the upstream documented contract rather than inventing a fixed digit count. Deduplicate valid normalized IDs for lookup, then map results back to every original row without changing order/count.
4. Return structured statuses: `invalid_format`, `validated`, `not_found`, `unavailable`, `ambiguous`, `returned_id_mismatch`, plus row-level `identity_conflict`/`scope_review`/`identity_unconfirmed` as needed. Transport/auth/rate failures are unavailable, not proof an ID is invalid. Require exact normalized requested/returned DTXSID equality and unique authoritative identity response. Record endpoint/authority, timestamp, preferred name, returned CAS, any available scope/qualifier evidence, and diagnostic reason. Missing detail remains unknown rather than passed.
5. Existence alone is insufficient for assignment. Check original and cleaned name, valid CAS, isotope labels, stereochemistry, charge/acid versus anion, parent versus salt, mixture/class/aggregate scope, and existing WQX evidence. Use existing qualifier/reference helpers where appropriate; similarity alone cannot waive these distinctions. Identical IDs from source/resolver/PubChem must not count as independent validated authorities. Contradicting direct name/CAS evidence blocks promotion even if the source ID exists.
6. Default source evidence to reviewable. Only promote to generated consensus evidence after compatible identity checks or a deliberate, documented row-specific review acceptance. A placeholder/absent name can be recovered after authoritative membership validation and explicit source-scope review; populate the selected preferred name without rewriting the raw placeholder. If the remaining context cannot establish identity, leave it unassigned and reviewable. No unconditional placeholder auto acceptance.
7. Preserve BAD/FOLLOW-UP/VERIFIED flags and prior reasons until an explicit reviewer decision changes them. Source recovery must not auto clear exclusion flags. Show newly validated source evidence and validation failures in a separate diagnostic/evidence view that includes flagged rows, or a bounded additional pending type. Coordinate ordinary queue changes with the separate review-completion issue; broad flag maintenance is outside #86.
8. Detect retained unused DTXSID-looking columns using bounded header recognition plus sampled valid-looking values, with empty/unrelated-header safeguards. Show column name, count/sample diagnostics, and remediation (“Source DTXSID” or explicitly keep metadata). Inspect retained input, not just selected tagged columns. Warn once per configuration state in Shiny and emit structured headless diagnostics; do not auto tag, look up, or promote unconfigured data. Diagnostic detection must also cover bare `dtxsid` and `dtxsid_*` input metadata without admitting it to consensus.

## Code boundaries and order

| Boundary | Planned change |
| --- | --- |
| `R/tag_helpers.R`, `R/mod_tag_columns.R`, `R/auto_tag_columns.R` | Extend role/UI, explicit metadata acknowledgment, unused-ID diagnostic helper. Suggestions remain proposals requiring apply. |
| New focused `R/source_identifier_evidence.R` | Pure normalization/diagnostic functions, injectable batched lookup adapter, structured validation schema, row-level identity checks and evidence eligibility. Inspect ComptoxR v1.7.1 authoritative details API before selecting an endpoint. |
| `R/curate_stages.R`, `R/cleaning_pipeline.R` | Keep source IDs out of name-specific cleanup, CAS extraction, multi-analyte splitting and name fallback while preserving full tag/provenance maps. Explicitly split Name/CASRN/Other lookup roles from DTXSID role rather than passing it through all existing chemical cleaners. |
| `R/curation.R` | Orchestrate source validation separately from name/CAS search; avoid ID/name query-key collisions. Do not inject source evidence through isotope `pre_resolved`, which currently overwrites all tagged lookup columns. Produce an explicit generated-evidence column registry after row mapping. |
| `R/consensus.R` and candidate postprocessing callers | Consume only generated and eligible evidence; exclude raw input columns with reserved prefixes. Preserve source name/CAS/qualifier disagreement and existing ties/WQX guard. Rejected/unavailable IDs live in candidate diagnostics outside selectable `dtxsid_*` fields. |
| `R/mod_review_results.R`, `R/curate_stages.R` review helpers | Show raw/normalized ID, membership and identity status, authority and reason; require validation-aware acceptance. Use existing signature/replay identity helpers with source column/value in the selector, not name/CAS matching alone. Never silently fan out an acceptance to conflicting source rows. |
| `R/curate_headless.R`, `R/curate_iterate.R`, `R/code_generation.R` | Wire role/ignore configuration and source diagnostics through decisions, pending/status outputs and generated replay; add DTXSID to workflow taxonomy. Persist selectors and acceptance provenance. |
| `R/export_helpers.R`, corresponding import/session handling | Export/reimport source validation state and configured role/ignore acknowledgment; unresolved source validation keeps `needs_review` visible where applicable. Preserve input ID and flags. |
| `R/curate_stages.R` cache key | Include tags, source ID values, ignored columns, identity policy/schema version and authority/cache freshness. Current key hashes values/settings but not role assignments. Source changes or Name/Other-to-DTXSID changes must invalidate eligible evidence; transient unavailable results must be retryable. |
| `README.md`, headless roxygen/manuals, curation workflow documentation | Explain configuration omission versus lookup failure, Other compatibility, review-first defaults, unavailable versus rejected, placeholder recovery, metadata ignore and provenance examples. Update generated documentation with implementation. |

Implement in order: pure evidence/diagnostic contract and tests; upstream validation adapter; pipeline eligibility/identity and cache ownership; UI/headless/replay/export wiring; documentation and integration verification. Avoid simultaneous broad consensus refactoring unless required to enforce generated-evidence ownership.

## Meaningful regression cases

- Untagged `source_dtxsid`: retained unchanged, unused-column warning, zero source lookups, no source-derived consensus; explicitly ignored metadata suppresses the warning and remains unused through replay/export/import.
- Valid source ID with name no hit: returns preferred name/CAS as evidence; compatible corroboration or explicit scope acceptance permits assignment and records provenance. Placeholder `NoName_3444` recovery must preserve raw name and BAD flag until separately reviewed.
- Source/name disagree; source/CAS disagree; source disagrees with WQX evidence-only canonical name: no clean single/agree assignment through source promotion. Distinguish genuine synonyms from qualifiers and acid/anion, salt/parent, stereochemistry or mixture scope.
- Rejected format, unknown authoritative ID, returned-ID mismatch, duplicate/ambiguous API results, unavailable endpoint, missing metadata: correct distinct statuses, raw values retained, no selectable/accepted source evidence. An unavailable response can recover on retry.
- Prochloraz-d4-style source/resolver agreement with failed authoritative validation: never accepted merely due to matching candidates. Mock statuses; saved IDs are evidence fixtures, not claims of present registry validity.
- Repeated IDs batched once but row-level incompatible context checked separately; two otherwise equal name/CAS rows with different source IDs cannot both receive one source acceptance. Reordering/export/reimport retains correct review target; stale changed ID rejects replay acceptance.
- Input named `dtxsid` or `dtxsid_source` cannot bypass validation or collide with generated evidence. Single-column mapper naming and multiple-column naming both remain correct.
- Name/CAS exact ties retain their normal conflict behavior; eligible source evidence may discriminate a tie only after identity checks. Existing isotope pre-resolution and BLOCK exclusion must not copy the source ID into all independent evidence columns.
- Cache role/value/ignore-policy changes invalidate results, unavailable lookups are retryable, and prior manual pins/flags survive candidate refresh. Persisted evidence carries its validation date/status without becoming fresh automatically.
- Warning detection: empty columns, malformed ID-looking values, non-ID generic metadata, absent retained columns, explicit acknowledgment, repeated Apply Tags, and large inventories. Warnings must be useful without silent mutation or repeated flooding.
- End-to-end headless mock: configure DTXSID and ignored columns, export review evidence, accept one validated source row, replay/reimport with identical identities and diagnostics. Shiny mock covers apply/acknowledgment/acceptance and flagged-row evidence visibility.

Extend relevant existing suites (`test-tag-dispatch.R`, `test-auto-tag-columns.R`, `test-consensus.R`, `test-prototype-pipeline.R`, `test-curate-iterate.R`, `test-code-generation.R`, `test-export-import.R`, `test-export-review.R`) and add focused source-evidence tests. Mock all external API outcomes in deterministic CI. Run targeted suites and package checks once dependencies exist; fresh-session `concert::run_app()` is mandatory after UI/reactive implementation per CLAUDE.md. Do optional live registry validation separately and record authority/date; do not make CI depend on current public availability.

## Dependencies, decisions and limits

- Requires package/test dependencies and ComptoxR details/response-contract inspection; no installation or live registry request was made during this review.
- Needs explicit supported membership authority and scope-review policy. The plan recommends review-first source evidence, avoiding a promise that public ID existence alone proves the source record's meaning.
- Uses current replay signatures, review queues, reserved generated-column conventions and cache invalidation. Preserve compatibility for existing Other tags and existing decisions files. Dedicated source acceptance may require extending row-target selectors rather than stretching legacy name-only `review_picks`.
- Issue #82's WQX-only rows are excluded from the 31 saved count, but WQX conflict safeguards still apply to implementation. Follow-up flag/queue maintenance is a coordination dependency, not authorization to rewrite those flags here.
- The 31-row inventory is a pinned saved-output validation fixture, not an acceptance oracle. The expected number of recoverable rows remains unknown until authoritative identity and source-scope review.
