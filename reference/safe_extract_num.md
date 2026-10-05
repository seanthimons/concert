# Safely extract numeric column from data frame

Returns the column if it exists, otherwise returns NA_real\_ vector.

## Usage

``` r
safe_extract_num(df, col, n)
```

## Arguments

- df:

  Data frame to extract from

- col:

  Column name

- n:

  Number of rows expected

## Value

Numeric vector of length n
