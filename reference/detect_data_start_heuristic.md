# Detect data start using heuristic fill ratio method

Detect data start using heuristic fill ratio method

## Usage

``` r
detect_data_start_heuristic(df, min_filled_ratio = 0.7, min_cols = 3)
```

## Arguments

- df:

  Data frame to analyze

- min_filled_ratio:

  Minimum proportion of filled cells (default: 0.7)

- min_cols:

  Minimum number of filled cells required (default: 3)

## Value

List with header_row, data_start_row, metadata_rows, method, confidence
