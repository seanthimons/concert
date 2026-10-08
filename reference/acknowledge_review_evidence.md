# Acknowledge current evidence for an existing decision revision

This resolves only the matching reconciliation event. It does not modify
historical evidence, reviewer flags, or accepted identity.

## Usage

``` r
acknowledge_review_evidence(
  evidence,
  decision_id,
  revision,
  scope,
  current,
  recorded_at = format(Sys.time(), tz = "UTC", usetz = TRUE)
)
```

## Arguments

- evidence:

  Existing contract object, or NULL.

- decision_id:

  Stable nonempty identifier for the decision.

- revision:

  Optional next revision; defaults to the next integer.

- scope:

  Explicit source/content scope from review_evidence_scope().

- current:

  Snapshot from review_evidence_snapshot().

- recorded_at:

  Explicit audit time; does not participate in comparison.

## Value

Updated portable contract with a versioned acknowledgment.
