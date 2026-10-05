# Pre-check predicate for flag_multi_analyte step

Checks for multi-analyte patterns: strings containing common separator
tokens (`and`, `+`, `&`, `/`) flanked by whitespace.

## Usage

``` r
precheck_multi_analyte(df, name_cols)
```

## Arguments

- df:

  Dataframe to check.

- name_cols:

  Character vector of name column names.

## Value

list(should_run = logical, est_changes = integer).
