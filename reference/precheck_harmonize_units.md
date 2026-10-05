# Pre-check predicate for harmonize_units step

Counts unit values present in Unit-tagged columns. Returns should_run =
TRUE when any Unit-tagged column has non-NA, non-empty values (all will
be processed by harmonize_units). est_changes reports the total number
of values that will pass through the harmonization step.

## Usage

``` r
precheck_harmonize_units(df, unit_cols, unit_map)
```

## Arguments

- df:

  Dataframe to check.

- unit_cols:

  Character vector of Unit-tagged column names.

- unit_map:

  Tibble with column from_unit (the working copy).

## Value

list(should_run = logical, est_changes = integer).
