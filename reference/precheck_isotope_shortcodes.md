# Pre-check predicate for expand_isotope_shortcodes step

With a symbol/mass lookup (the WQX radiochemical cache), dry-runs
[`expand_isotope_shortcodes()`](https://seanthimons.github.io/concert/reference/expand_isotope_shortcodes.md)
on the distinct names and counts the values it would change or flag (a
bare "unat"), so the gate sees exactly what the step rewrites:
spelled-out names such as "Cesium 137", but not alkyl chain lengths such
as "(C14-17)". A narrower gate made one row's cleaning depend on
unrelated rows. A legacy `shortcode` lookup still uses a word-boundary
regex.

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

  Isotope lookup (a list with `lookup`, or a data frame with
  `symbol`/`mass` or legacy `shortcode` columns), or NULL.

## Value

list(should_run = logical, est_changes = integer).
