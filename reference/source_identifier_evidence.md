# Validate source DTXSID membership without accepting source identity

Validate source DTXSID membership without accepting source identity

## Usage

``` r
source_identifier_evidence(
  df,
  tags,
  lookup_fn = source_identifier_lookup,
  checked_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
)
```

## Arguments

- df:

  Rows with source identifier columns.

- tags:

  Named roles, including explicit DTXSID roles.

- lookup_fn:

  Injectable batched authoritative details lookup.

- checked_at:

  Validation timestamp; injectable for deterministic tests.

## Value

Long evidence table, retaining original row and column values.
