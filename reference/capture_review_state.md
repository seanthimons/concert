# Capture evidence currently inspected in a staged review

Call explicitly when making or revising a disposition. Merely replaying
flags never captures a baseline. Source/content scope is retained
separately from the automated evidence and final manual selection.
Multiple source rows may share a flag decision; this does not grant
scope-sensitive ID acceptance.

## Usage

``` r
capture_review_state(
  state,
  name,
  casrn = NA_character_,
  disposition,
  flag = NA_character_,
  reason = NA_character_,
  decision_id = review_decision_key(name, casrn, scope),
  evidence = state$review_decision_evidence,
  scope = NULL
)
```

## Arguments

- state:

  Staged curation state after review.

- name, casrn:

  Content selector matching the reviewed flag decision.

- disposition, flag, reason:

  Structured disposition and human decision.

- decision_id:

  Optional stable ID; defaults to
  [`review_decision_key()`](https://seanthimons.github.io/concert/reference/review_decision_key.md).

- evidence:

  Existing immutable records; defaults to the state's records.

- scope:

  Named list of input-column values when the flag was narrowed to them
  (for example `list(source_label = "Ammonia, total")`).

## Value

Updated portable review_decision_evidence object.
