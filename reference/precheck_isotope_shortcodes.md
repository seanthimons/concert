# Pre-check predicate for expand_isotope_shortcodes step

Uses a compiled word-boundary regex from the isotope lookup shortcodes
to count values that contain a recognizable isotope abbreviation.

## Usage

``` r
precheck_isotope_shortcodes(df, name_cols, isotope_lookup)
```

## Arguments

- df:

  Dataframe to check.

- name_cols:

  Character vector of name column names.

- isotope_lookup:

  Dataframe with a `shortcode` column, or NULL.

## Value

list(should_run = logical, est_changes = integer).
