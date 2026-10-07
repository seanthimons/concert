# Issue #88 review and fix plan

Reviewed 2026-10-07: [PubChem fallback emits colon-only DTXSID candidate when no synonym matches](https://github.com/seanthimons/concert/issues/88).

## Baseline and scope

Baseline v0.5.3 is `33c775e843c7dbe85b2201ebe07ccd840487f8af`. The current checkout is `41ae70a0cb1131af95ccbb56e401fb5c9ca77e95` (`v0.5.3-1-g41ae70a`); `R/pubchem_fallback.R` and `tests/testthat/test-pubchem-fallback.R` have no diff against that tag. No applicable `AGENTS.md` was found in ancestor directories or the repository. `CLAUDE.md` supplies R formatting/testing guidance; the explicit review-only task overrides its implementation branch/commit advice. No Shiny code change is proposed.

This review changed only this plan. No dependency installation, service request, fix, branch change, commit, or issue comment was made.

## Independently confirmed behavior

Using R 4.6.1 with `Rscript --vanilla`, sourced the actual `R/pubchem_fallback.R` into an isolated environment and called `add_pubchem_candidates()` with base-R data frames and injected search/synonym functions. This executes the function rather than only recreating its expression; it does not require the installed concert package or ComptoxR.

| Stubbed synonym response for CID 1 | Current candidate | Lookup status |
| --- | --- | --- |
| `Other synonym` | `:` | `hit` |
| Zero rows, typed `cid` and `synonym` columns | `:` | `hit` |
| Missing/NA synonym | `:` | `hit` |
| `DTXSID123`, CID 1 | `1:DTXSID123` | `hit` |
| Two distinct IDs plus a duplicate pair | `1:DTXSID123; 1:DTXSID456` | `hit` |
| Valid DTXSID, NA CID | `NA:DTXSID123` | `hit` |
| Valid DTXSID, CID `junk` | `junk:DTXSID123` | `hit` |
| Valid DTXSID, absent CID column | `:DTXSID123` | `hit` |

Assertions also confirmed duplicate unresolved names cause one search and receive the same bad value, resolved rows are skipped, and consensus IDs remain unchanged. Search exceptions, zero CID hits, and synonym exceptions retain their existing `error`, `no_hit`, and `synonyms_error` statuses with NA DTXSID candidates.

Cause: `R/pubchem_fallback.R:62–65` formats matching vectors before checking whether matches exist. Base R evaluates `paste0(integer(0), ":", character(0))` to the one-element string `":"`; consequently `length(candidates)` passes. Filtering only synonyms also permits missing or malformed CID components.

Minimal repeatable reproduction from the repository root:

```r
# Run with Rscript --vanilla; injected functions avoid external services.
e <- new.env(parent = baseenv())
sys.source("R/pubchem_fallback.R", envir = e)
df <- data.frame(raw_name = "Example", consensus_status = "error",
                 consensus_dtxsid = NA_character_)
out <- e$add_pubchem_candidates(
  df, "raw_name",
  search_fn = function(...) data.frame(cid = 1L),
  synonyms_fn = function(...) data.frame(cid = 1L, synonym = "Other synonym")
)
stopifnot(identical(out$pubchem_dtxsid_candidates, ":"),
          out$pubchem_lookup_status == "hit",
          out$pubchem_cid_candidates == "1")
```

## Reported evidence and limits

Issue #88 reports colon-only saved fields on original rows 7938, 7952, 8159, and 10378 of an October 6, 2026 v0.5.3 export containing 11,221 rows. Its [audit](https://github.com/seanthimons/tyson_treatment_pilot/blob/42af363/outputs/concert-curation/needs_review_followup.md) and [inventory](https://github.com/seanthimons/tyson_treatment_pilot/blob/42af363/outputs/concert-curation/needs_review_followup.csv) are reported saved-output evidence, not independently inspected or revalidated in this review. The isolated results establish the defect independently; they do not establish those rows' current chemical identities or live PubChem responses. Overlapping audit row counts must not be added.

`fs`, `testthat`, `tibble`, and `ComptoxR` are unavailable in this environment. No installed-package tests, full pipeline replay, or live API validation ran. `--vanilla` avoided renv bootstrap.

## Concrete implementation plan

1. Confine production edits to candidate assembly in `add_pubchem_candidates()` (`R/pubchem_fallback.R:62–65`), and regression tests to `tests/testthat/test-pubchem-fallback.R`. Preserve function signature and output schema.
2. Before formatting, require both named synonym-table columns and aligned values. Convert components to character explicitly. Select rows with a nonmissing exact `^DTXSID[0-9]+$` synonym and a nonmissing positive integer CID representation (`^[1-9][0-9]*$`). Missing columns or zero eligible rows yield no candidate strings; leave the initialized `NA_character_` untouched. Avoid recycling components or manufacturing a fallback pair.
3. Call `paste0()` only when eligible rows exist. Continue deduplicating complete CID/DTXSID pairs in encounter order and joining with `"; "`. Do not deduplicate solely on DTXSID: separate CIDs remain useful evidence.
4. Preserve `pubchem_cid_candidates`, `pubchem_query`, and `hit` after a successful CID lookup and successful synonym call even when no eligible candidate exists. Retain existing exception/no-hit statuses, query deduplication, original-name selection, and unresolved-row filtering. Never assign a fallback ID to consensus.
5. Do not broaden this fix into search-CID coercion, service schema redesign, chemistry validation, or a new status vocabulary. The existing `as.integer(cids)` lookup behavior is outside this candidate-formatting change. Strict formatting validates syntax, not whether a CID/DTXSID association is scientifically correct.

Downstream inspection: `R/curation.R:1042` invokes the fallback; `R/curate_iterate.R:277–283` passes candidate fields through to pending rows; `R/mod_review_results.R:2261` includes them in deduplication. Fixing construction prevents the malformed value from propagating without changes to those consumers. Existing saved exports require regeneration or separately authorized cleanup; the code fix does not rewrite them.

## Meaningful regression cases and acceptance

Add stubbed cases asserting the complete relevant output, not just absence of a colon:

- Non-DTXSID-only synonyms and typed empty synonyms: candidate is exactly NA, CID `1` and status `hit` remain.
- One valid pair and multiple pairs across CIDs, with duplicates/interspersed irrelevant synonyms: stable expected strings and pair deduplication.
- Missing/NA/blank/malformed CID, zero/negative/fractional CID, and missing/NA/malformed synonym; mixed valid and invalid rows: emit only complete valid pairs, otherwise NA. Missing required columns must never produce recycled strings.
- Duplicate unresolved queries plus a resolved control row: one lookup, matching outputs on unresolved rows, resolved output remains NA, and consensus IDs/statuses remain identical.
- Existing no-hit/search-error/synonym-error behavior retains statuses and NA candidates; synonym errors retain saved CID hits.

In a provisioned environment, run the focused PubChem test file under the package test harness, then `test-curate-iterate.R` to verify pending candidate passthrough. Use `Rscript --vanilla` and a loaded package/development namespace; raw `test_file()` alone does not supply internal functions. Do not substitute live API calls for deterministic regression tests. The existing happy-path test already covers original-name lookup and consensus separation and should continue passing.

Acceptance: no emitted candidate contains a missing or invalid component; no matching synonym means NA, with successful CID hits still visible for review. Complete the focused tests before considering #88 fixed; dependency absence currently prevents that package-level acceptance check.
