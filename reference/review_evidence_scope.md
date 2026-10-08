# Construct explicit source/content review scope

Construct explicit source/content review scope

## Usage

``` r
review_evidence_scope(df, row_indices, columns)
```

## Arguments

- df:

  Source data frame.

- row_indices:

  Explicit selected row indices.

- columns:

  Source/content and lineage columns; exclude transient positions.

## Value

Canonical scope object for capture_review_decision().
