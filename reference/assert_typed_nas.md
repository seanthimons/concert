# Assert no bare NA values in tibble

Verifies all columns have typed NA values (NA_character\_, NA_real\_,
etc.) and no columns are logical type (which would indicate bare NA).

## Usage

``` r
assert_typed_nas(tbl)
```

## Arguments

- tbl:

  Tibble to verify

## Value

Invisible NULL (stops with error if assertion fails)
