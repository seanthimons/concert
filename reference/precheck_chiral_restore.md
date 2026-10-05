# Pre-check predicate for restore_chiral_designations step

Checks whether any name column contains the chiral placeholder token
(`###CHIRAL_`), which is only present when
[`protect_chiral_designations()`](https://seanthimons.github.io/concert/reference/protect_chiral_designations.md)
was previously applied.

## Usage

``` r
precheck_chiral_restore(df, name_cols)
```

## Arguments

- df:

  Dataframe to check.

- name_cols:

  Character vector of name column names.

## Value

list(should_run = logical, est_changes = integer).
