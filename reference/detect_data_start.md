# Main ensemble detection function combining all methods

Main ensemble detection function combining all methods

## Usage

``` r
detect_data_start(
  df,
  mode = "auto",
  manual_row = NULL,
  min_filled_ratio = 0.7,
  min_cols = 3,
  scan_rows = 50
)
```

## Arguments

- df:

  Data frame to analyze

- mode:

  Detection mode: "auto" or "manual"

- manual_row:

  Manual header row number (used if mode = "manual")

- min_filled_ratio, min_cols:

  Passed to
  [`detect_data_start_heuristic()`](https://seanthimons.github.io/concert/reference/detect_data_start_heuristic.md)

- scan_rows:

  Passed to
  [`detect_by_type_consistency()`](https://seanthimons.github.io/concert/reference/detect_by_type_consistency.md)

## Value

List with detection results including all_results for debugging

## Details

The method with the highest confidence wins. Ties go to the earlier
method in the order heuristic, pattern, type_consistency.
