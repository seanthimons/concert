# Classify harmonized tagged measurements

Bridges `harmonize_tagged_numeric_measurements()` to
[`classify_detection_events()`](https://seanthimons.github.io/concert/reference/classify_detection_events.md)
using only explicit semantic tags: `Result`, optional `ReportingLimit`,
optional `Uncertainty`, optional `UncertaintyCoverage`, and optional
`Qualifier`.

## Usage

``` r
classify_harmonized_detection(
  input_df,
  tag_values,
  measurement_result,
  detect_operator = c(">", ">=")
)
```

## Arguments

- input_df:

  Data frame used for harmonization.

- tag_values:

  Named tag map.

- measurement_result:

  Output from `harmonize_tagged_numeric_measurements()`.

- detect_operator:

  Reporting-limit comparison for `result_flag`.

## Value

List with `expanded_detection` aligned to primary result rows and
`row_detection` collapsed to one row per source row.
