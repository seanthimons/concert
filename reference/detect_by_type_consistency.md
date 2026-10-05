# Detect data start by checking column type consistency

Detect data start by checking column type consistency

## Usage

``` r
detect_by_type_consistency(df, scan_rows = 50)
```

## Arguments

- df:

  Data frame to analyze

- scan_rows:

  Number of rows to scan after each candidate (default: 50)

## Value

List with header_row, data_start_row, method, confidence
