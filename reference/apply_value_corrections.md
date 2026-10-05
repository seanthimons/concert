# Apply dataset-specific value corrections before cleaning

Rewrites cell values in named columns using a small pattern/replacement
table. This is the escape hatch for dataset quirks the reference lists
cannot express: a "Total " prefix on every analyte, a known-bad CAS, a
unit typo. Runs before the cleaning pipeline so every downstream step
sees the corrected value.

## Usage

``` r
apply_value_corrections(df, value_corrections = NULL)
```

## Arguments

- df:

  Data frame after frontmatter extraction and
  [`janitor::clean_names()`](https://sfirke.github.io/janitor/reference/clean_names.html).

- value_corrections:

  Data frame with columns `column`, `pattern`, `replacement`, and
  optional `match_mode` (one of `"regex"` (default), `"literal_exact"`,
  or `"literal_word"`). Rows are applied in order.

## Value

List with `cleaned_data` and `audit_trail` (step `value_correction`).
