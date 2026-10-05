# Main ensemble detection function combining all methods

Main ensemble detection function combining all methods

## Usage

``` r
detect_data_start(df, mode = "auto", manual_row = NULL)
```

## Arguments

- df:

  Data frame to analyze

- mode:

  Detection mode: "auto" or "manual"

- manual_row:

  Manual header row number (used if mode = "manual")

## Value

List with detection results including all_results for debugging
