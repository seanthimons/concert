# Pre-check predicate for harmonize_dates step

Counts non-NA, non-empty values across StudyDate-tagged columns. Returns
should_run = TRUE when any parseable date value exists.

## Usage

``` r
precheck_harmonize_dates(df, date_cols)
```

## Arguments

- df:

  Dataframe to check.

- date_cols:

  Character vector of StudyDate-tagged column names.

## Value

list(should_run = logical, est_changes = integer).
