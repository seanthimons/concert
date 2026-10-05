# Pre-check predicate for the name cleaning chain (Steps 6-pre through 6d3)

Intentionally broad: returns TRUE whenever any name column has non-empty
values, because the individual name steps have complex interdependencies
that make cell-level prediction impractical.

## Usage

``` r
precheck_name_cleaning(df, name_cols)
```

## Arguments

- df:

  Dataframe to check.

- name_cols:

  Character vector of name column names.

## Value

list(should_run = logical, est_changes = integer).
