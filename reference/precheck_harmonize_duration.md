# Pre-check predicate for harmonize_duration step

Counts non-NA, non-empty values across Duration and DurationUnit tagged
columns. Returns should_run = TRUE when any such value exists.

## Usage

``` r
precheck_harmonize_duration(df, dur_cols, dur_unit_cols, unit_map)
```

## Arguments

- df:

  Dataframe to check.

- dur_cols:

  Character vector of Duration-tagged column names.

- dur_unit_cols:

  Character vector of DurationUnit-tagged column names.

- unit_map:

  Tibble with column from_unit (the working copy, reserved for future
  use).

## Value

list(should_run = logical, est_changes = integer).
