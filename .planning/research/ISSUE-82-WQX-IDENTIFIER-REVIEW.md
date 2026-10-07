# Issue #82: WQX identifier continuation and pending review

Initial investigation: 2026-10-07. Branch: `fix/82-wqx-identifier-review`.
Baseline: `origin/main`, v0.5.3, commit `33c775e843c7dbe85b2201ebe07ccd840487f8af`.

## Finding

The current code confirms the reported gap. WQX vocabulary evidence ends the
name search without identifying the substance. Both subsequent candidate lookup
eligibility and headless pending selection exclude `wqx`, so an unreviewed,
identifier-free row can coexist with `done = TRUE`. Export already flags these
rows as needing review. This is a continuation/accounting defect, not evidence
that a dictionary CAS identifies the input substance.

Sources:

- [Issue #82](https://github.com/seanthimons/concert/issues/82)
- [Pilot investigation](https://github.com/seanthimons/tyson_treatment_pilot/blob/f5bf5ce/outputs/concert-curation/wqx_resolution_followup.md)
- [Nine affected pilot rows](https://github.com/seanthimons/tyson_treatment_pilot/blob/f5bf5ce/outputs/concert-curation/wqx_resolution_followup.csv)

The pilot artifacts report four exact and five fuzzy rows; six have canonical
CAS values in the bundled dictionary. Those workbook observations were read
from the published investigation and CSV, not independently reproduced here.

## Code boundaries

| Location | Current behavior | Required change |
| --- | --- | --- |
| `R/wqx_matching.R::match_wqx()` | Returns name, tier, distance and alias type; drops CAS. | Add canonical-entry CAS evidence, including for aliases, with stable empty/no-match output. |
| `R/curation.R::run_curation_pipeline()` | Appends WQX results with missing DTXSID; removes matched inputs from `final_missed`. | Continue identifier lookup using available CAS and useful canonical-name queries while retaining WQX evidence. |
| `R/curation.R::map_results_to_rows()` | Keeps one result per search value; explicitly maps only known fields. | Carry new provenance/candidate fields through mapping. Avoid losing the WQX tier/name when another lookup returns a candidate. |
| `R/consensus.R::classify_consensus()` | Name-only WQX becomes `wqx`; DTXSID remains missing. | Preserve this distinction between vocabulary evidence and an accepted identifier. |
| `R/pubchem_fallback.R::unresolved_name_queries()` | Only `error`/`unresolvable` with missing/blank consensus DTXSID qualify. | Include identifier-free WQX rows and retain original versus canonical query provenance. |
| `R/curate_iterate.R::pending_rows()` | Selects multi-analyte, disagree/suggested, and error/unresolvable rows. | Include unreviewed WQX rows with actionable evidence and candidate/status fields. |
| `R/curate_iterate.R::curate_iterate()` | Completion is `nrow(pending) == 0`. | Pending selection must account for WQX identity review. |
| `R/export_helpers.R::export_curated_workbook()` | Marks WQX as needing review unless VERIFIED or `manual_wqx`. | Reuse the existing review semantics when defining the pending predicate. |

`unresolved_name_queries()` serves PubChem, chemi resolver, and salt-parent
suggestions, so changing it affects all three. It currently searches the first
Name-tagged column and may restore the original input name using
`original_row_id`; a canonical-name continuation must preserve those behaviors
and multi-analyte part handling.

The resolver always runs in the main pipeline. PubChem and salt-parent lookup
are optional. CAS continuation should therefore not depend on PubChem being on.
`run_tiered_search()` is a separate helper without WQX integration; implementing
the change there alone would miss the active `run_curation_pipeline()` path.

## Identity and review constraints

Recommended initial approach: store dictionary-derived CAS lookup results as
review candidates, separately from the per-input accepted `dtxsid` fields.
Neither exact vocabulary membership nor successful dictionary-CAS lookup alone
should assign or verify the input's DTXSID. A later automatic acceptance path
would need independent identity evidence and explicit acceptance rules.

The bundled dictionary was read locally with base R. Canonical `Cyhalothrin`
has CAS `68085-85-8`, `Tetracycline` has `60-54-8`, and
`Sulfachloropyridazine` has `80-32-0`; canonical `Methadone-d9` has no CAS.
Cyhalothrin also has a retired entry pointing to `.lambda.-Cyhalothrin`, while
the canonical and higher-priority aliases point to `Cyhalothrin`. CAS must come
from the selected canonical entry, not an arbitrary same-name dictionary row.

The pilot's `DTXSID6023997` / alpha-Cyhalothrin association is existing pilot
evidence only. No live validation was performed here. Unqualified Cyhalothrin,
its stereoisomers, isotope-labelled compounds, salts and class-level analytes
must retain their identity distinctions.

`fuzzy_identity_ok()` checks identity qualifier tokens and restricts labelled
fuzzy names to punctuation/case equivalence. It does not establish that plural
`TETRACYCLINES` represents singular `Tetracycline`. That fuzzy match and any
CAS-derived single-compound candidate must remain subject to review.

Adding CAS hits to the existing accepted lookup columns could bypass review:
mapping collapses results to one result per input, and consensus could classify
a lone identifier as `single`. Changing the status to `disagree` also exposes
the row to automatic scoring. Keep candidate evidence separate until reviewed.

Existing `get_resolution_options()` permits only disagree/auto_resolved/suggested
statuses. Merely adding WQX to pending selection will not populate its generic
`candidates` field. Expose WQX CAS candidates explicitly or extend the review
option model deliberately. Extend both `pending_rows()` and `empty_pending()`
schemas together; ensure evidence also survives exports and replay baselines.

Review accounting should recognize VERIFIED and `manual_wqx` as reviewed
name-only evidence. FOLLOW-UP/BAD already remove work from the pending queue
under the explicit disposition contract; FOLLOW-UP can still mean exported
`needs_review = TRUE`. Completion means no undecided queue items, not that every
row has a DTXSID. Preserve this documented distinction in status output.

## Verification performed

- Read current source, relevant existing tests, issue body, and pilot artifacts.
- Read the bundled RDS dictionary using `Rscript --vanilla`.
- Executed the actual `unresolved_name_queries()` on synthetic Cyhalothrin,
  Methadone-d9 and TETRACYCLINES WQX-only rows: zero of three eligible.
- Executed the actual `pending_rows()` function body through its `idx` assignment
  on the same fixture: zero of three pending. Stopped before tibble construction;
  this was a selector-level reproduction, not a pipeline or export run.
- Confirmed the completion expression reports true for an empty pending queue.

The available R 4.6.1 environment lacks `fs`, `testthat`, `tibble`, `dplyr`,
`stringdist`, `devtools`, and `ComptoxR`. No package tests, full pipeline rerun,
or live identifier lookups were performed. The project startup attempted renv
bootstrap; it was stopped, and dependency restoration is left for implementation.
Function-only parsing bypassed package-dependent top-level setup for the
selector reproduction; no application functions were stubbed.

## Implementation sequence and regression coverage

1. Extend matcher evidence and its mapping; handle aliases, missing CAS,
   normalized canonical keys, duplicates, and empty input. Update the exported
   `match_wqx()` documentation when its return schema changes.
2. Add injectable, deduplicated CAS candidate continuation with provenance and
   lookup status. Preserve original input name, canonical name, tier and distance
   even when lookup fails or returns a different preferred name.
3. Extend candidate eligibility and query attribution for WQX-only rows. Consider
   both original and canonical names when different; do not silently replace the
   original query. Keep resolved rows excluded and external failures reviewable.
4. Extend pending output and completion accounting using the established review
   dispositions. Validate candidate selection through reproducible `review_picks`.
5. Run the focused suites below after restoring the R environment, then relevant
   headless/export checks. A Shiny cold boot is required if implementation changes
   app/server/reactive code.

| Suite | Regression cases |
| --- | --- |
| `test-wqx-matching.R` | Exact canonical CAS; alias inherits canonical CAS; no CAS; empty/no-match schema; duplicate alias priority. |
| `test-wqx-pipeline-integration.R` | CAS lookup attempted for WQX evidence; original name/tier retained; different preferred identity remains candidate; no-CAS row continues; PubChem disabled; lookup failure; fuzzy class does not acquire accepted DTXSID. |
| `test-pubchem-fallback.R` | WQX eligibility for PubChem and resolver; original/canonical query provenance; duplicate queries; NA/blank DTXSID; resolved-row exclusion; accepted consensus unchanged. |
| `test-curate-iterate.R` | Unreviewed exact/fuzzy WQX appears in pending and prevents done; missing-CAS/no-hit WQX remains pending; validated pick or explicit disposition clears work; reviewed name-only evidence remains reviewed. |
| `test-export-review.R` | Pending/export review semantics agree; candidates and provenance survive output; FOLLOW-UP remains flagged for review. |

The existing integration test titled “WQX matching narrows final_missed to only
truly unresolved names” encodes the old distinction: vocabulary matching alone
removes identifier-free names from continuation. Revise that expectation or
separate vocabulary misses from identifier-pending work rather than retaining
it as an assertion of successful identity resolution.

This branch currently contains research only. No resolution behavior or pilot
curation decisions have been changed.
