# Append row-level detection fields by source row id

Append row-level detection fields by source row id

## Usage

``` r
append_detection_fields(df, row_detection, allow_existing_generated = FALSE)
```

## Arguments

- df:

  Data frame receiving generated detection fields.

- row_detection:

  Row-level detection output from
  [`classify_harmonized_detection()`](https://seanthimons.github.io/concert/reference/classify_harmonized_detection.md).

- allow_existing_generated:

  Logical. When TRUE, existing CONCERT-generated detection columns are
  replaced. Keep FALSE for source data.

## Value

`df` with generated detection columns appended.
