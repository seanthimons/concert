# Build audit trail by comparing two dataframes

Compares df_original to df_cleaned column-by-column, row-by-row. Only
records rows where original_value != new_value.

## Usage

``` r
build_audit_trail(df_original, df_cleaned, step_name, reason_fn)
```

## Arguments

- df_original:

  Original dataframe before cleaning step

- df_cleaned:

  Cleaned dataframe after cleaning step

- step_name:

  Name of the cleaning step (e.g., "unicode_to_ascii")

- reason_fn:

  Function that takes (field_name) and returns reason string

## Value

Tibble with columns: row_id, field, step, original_value, new_value,
reason
