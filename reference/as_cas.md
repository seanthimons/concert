# Coerces and validates a string to a standard CASRN format

This function attempts to convert a string into a valid Chemical
Abstracts Service Registry Number (CASRN). It handles common data
quality issues such as extra non-digit characters, missing hyphens, and
leading zeros. The function extracts all digits, trims any leading
zeros, formats the result into the standard "xx-yy-z" structure, and
then validates it using the
[`is_cas()`](https://seanthimons.github.io/concert/reference/is_cas.md)
check-digit algorithm.

## Usage

``` r
as_cas(x)
```

## Arguments

- x:

  A character vector of potential CASRN strings.

## Value

A character vector of the same length as `x`. Returns the correctly
formatted, canonical CASRN string if valid, otherwise returns
`NA_character_`.

## See also

[`is_cas()`](https://seanthimons.github.io/concert/reference/is_cas.md)
for the underlying validation logic.

## Examples

``` r
# Handles standard and padded formats
as_cas("50-00-0")
#> [1] "50-00-0"
as_cas("0050-00-0") # Padded with leading zeros
#> [1] "50-00-0"
as_cas("000575-38-2") # Another padded example
#> [1] "575-38-2"

# Handles extra characters and missing hyphens
as_cas("CAS: 7732-18-5")
#> [1] "7732-18-5"
as_cas("50000")
#> [1] "50-00-0"

# Returns NA for invalid CASRNs
as_cas("50-00-1") # Invalid check digit
#> [1] NA
as_cas("not-a-casrn")
#> [1] NA
```
