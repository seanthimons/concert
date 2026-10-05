# Safely extract character column from data frame

Returns the column if it exists, otherwise returns NA_character\_
vector.

## Usage

``` r
safe_extract_char(df, col, n)
```

## Arguments

- df:

  Data frame to extract from

- col:

  Column name

- n:

  Number of rows expected

## Value

Character vector of length n
