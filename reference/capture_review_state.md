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
  decision_id = review_decision_key(name, casrn),
  evidence = state$review_decision_evidence
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

## Value

Updated portable review_decision_evidence object.
