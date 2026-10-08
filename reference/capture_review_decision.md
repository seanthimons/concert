# Capture evidence from an explicit review decision

Append an immutable versioned decision to the portable
`review_decision_evidence` object. Call only when the reviewer
explicitly supplies the evidence they reviewed; replaying a flag does
not capture it.

## Usage

``` r
capture_review_decision(
  evidence = NULL,
  decision_id,
  scope,
  current,
  disposition,
  flag = NA_character_,
  reason = NA_character_,
  revision = NULL,
  recorded_at = format(Sys.time(), tz = "UTC", usetz = TRUE)
)
```

## Arguments

- evidence:

  Existing contract object, or NULL.

- decision_id:

  Stable nonempty identifier for the decision.

- scope:

  Explicit source/content scope from review_evidence_scope().

- current:

  Snapshot from review_evidence_snapshot().

- disposition:

  Structured basis: no_hit, rejected, deferred, scope_conflict,
  accepted, or other. Accepted records do not grant acceptance.

- flag:

  Reviewer flag, retained verbatim.

- reason:

  Reviewer reason, retained verbatim and never parsed.

- revision:

  Optional next revision; defaults to the next integer.

- recorded_at:

  Explicit audit time; does not participate in comparison.

## Value

Updated portable contract object; prior records are preserved.
