# Classify row-level detection events

Appends CONCERT-owned detection fields. `result_flag` is driven only by
numeric result, positivity, and the optional reporting limit comparison.
Lab qualifiers, parser qualifiers such as `"<"`, and narrative raw
result text never change `result_flag` or `detection_event_class`; any
non-empty qualifier value only raises follow-up/review context.

## Usage

``` r
classify_detection_events(
  df,
  result_col = "result_value",
  reporting_limit_col = "reporting_limit_value",
  uncertainty_col = "uncertainty_value",
  qualifier_col = "qualifier",
  parser_qualifier_col = "result_qualifier",
  raw_result_col = "raw_result_text",
  measurement_type_col = "measurement_type",
  coverage_col = "uncertainty_coverage",
  result_unit_col = "result_unit",
  detect_operator = c(">", ">=")
)
```

## Arguments

- df:

  Data frame of parsed/harmonized observations.

- result_col:

  Column containing numeric result values.

- reporting_limit_col:

  Optional column containing numeric reporting limits.

- uncertainty_col:

  Optional column containing numeric uncertainty values.

- qualifier_col:

  Optional source qualifier column or columns.

- parser_qualifier_col:

  Optional parser qualifier column, e.g. from
  [`parse_numeric_results()`](https://seanthimons.github.io/concert/reference/parse_numeric_results.md).

- raw_result_col:

  Optional raw result text column, preserved for context.

- measurement_type_col:

  Optional measurement type column.

- coverage_col:

  Optional uncertainty coverage column.

- result_unit_col:

  Optional harmonized/original result unit column used to conservatively
  infer radiological rows from units such as pCi or pCi/L.

- detect_operator:

  Reporting-limit comparison for `result_flag`. Default `">"` means
  `result == reporting_limit` is non-detect.

## Value

`df` with generated detection fields appended.
