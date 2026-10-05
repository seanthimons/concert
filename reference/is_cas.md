# Checks if a string is a syntactically and algorithmically valid CASRN

A valid CAS Registry Number (CASRN) is a string in the format
"dd...d-dd-d", containing 5 to 10 digits in total. The final digit is a
check-digit calculated using a specific algorithm. This function
validates both the format and the check-digit calculation.

## Usage

``` r
is_cas(x)
```

## Arguments

- x:

  A character vector of potential CASRN strings.

## Value

A logical vector of the same length as `x`. Returns `TRUE` for each
valid CASRN, `FALSE` for invalid ones, and `NA` for `NA` inputs.

## Examples

``` r
is_cas("50-00-0")  # Valid
#> [1] TRUE
is_cas("50-00-1")  # Invalid check digit
#> [1] FALSE
is_cas("7732-18-5") # Valid
#> [1] TRUE
is_cas("100-42-5")  # Valid
#> [1] TRUE
is_cas("not-a-casrn")
#> [1] FALSE
is_cas(c("50-00-0", "50-00-1", NA, "7732-18-5"))
#> [1]  TRUE FALSE    NA  TRUE
```
