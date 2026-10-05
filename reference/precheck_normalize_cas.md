# Pre-check predicate for normalize_cas step

Checks whether any CASRN-tagged column contains values that
[`as_cas()`](https://seanthimons.github.io/concert/reference/as_cas.md)
would transform (unformatted pure-digit strings, or common placeholder
text).

## Usage

``` r
precheck_normalize_cas(df, tag_map)
```

## Arguments

- df:

  Dataframe to check.

- tag_map:

  Named character vector or list mapping column names to types.

## Value

list(should_run = logical, est_changes = integer).
