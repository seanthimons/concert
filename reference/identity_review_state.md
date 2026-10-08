# Derive accepted identity eligibility from current evidence

Lookup consensus remains provisional when review, scope or source
conflicts are unresolved. Derived fields are recomputed and must not be
used as replay authority. Registry existence and source correspondence
are separate checks.

## Usage

``` r
identity_review_state(df)
```

## Arguments

- df:

  Curated row data with consensus and optional review fields.

## Value

A tibble with identity_status, identity_blockers, identity_eligible, and
accepted_dtxsid, aligned to the input rows.
