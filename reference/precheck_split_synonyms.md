# Pre-check predicate for split_synonyms step

Counts CAS-less name values containing a comma or semicolon. Rows with a
CASRN are never split, so they are excluded from the estimate.

## Usage

``` r
precheck_split_synonyms(df, name_cols, tag_map)
```

## Arguments

- df:

  Dataframe to check.

- name_cols:

  Character vector of name column names.

- tag_map:

  Named list mapping column names to types.

## Value

List with should_run (logical) and est_changes (integer).
