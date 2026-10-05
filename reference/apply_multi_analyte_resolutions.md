# Apply multiple multi-analyte resolutions

Apply multiple multi-analyte resolutions

## Usage

``` r
apply_multi_analyte_resolutions(df, name_cols, resolutions = NULL)
```

## Arguments

- df:

  Cleaned data frame.

- name_cols:

  Character vector of Name-tagged column names.

- resolutions:

  Data frame/list with `row` or `row_index`, `action`, and optional
  `value` or `values`. When `df` has an `original_row_id` column the row
  key is matched against it (as written by `pending.csv`); otherwise it
  is a 1-based row position.

## Value

List with `cleaned_data` and `audit_trail`.
