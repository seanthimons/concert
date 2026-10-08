# Diagnose retained identifier columns without a source evidence role

Diagnose retained identifier columns without a source evidence role

## Usage

``` r
unused_source_identifier_diagnostics(
  df,
  tags = list(),
  ignored_identifier_cols = character()
)
```

## Arguments

- df:

  Retained input rows.

- tags:

  Named column role list.

- ignored_identifier_cols:

  Columns deliberately retained as metadata.

## Value

Structured column diagnostics. No values or roles are changed.
