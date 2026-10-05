# Validate Excel Size Limits

Checks if a data frame exceeds Excel's row or column limits. Throws an
informative error if limits are exceeded.

## Usage

``` r
validate_excel_size(df, sheet_name)
```

## Arguments

- df:

  Data frame to validate

- sheet_name:

  Name of the sheet (for error messages)

## Value

invisible(TRUE) on success
