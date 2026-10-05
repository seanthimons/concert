# Extracts all valid CASRNs from a character vector

This function searches for and extracts all valid Chemical Abstracts
Service Registry Numbers (CASRNs) from a character vector. It uses a
flexible pattern to find candidate strings (including those without
hyphens) and then validates each one using the
[`as_cas()`](https://seanthimons.github.io/concert/reference/as_cas.md)
coercion and validation function.

## Usage

``` r
extract_cas(x)
```

## Arguments

- x:

  A character vector of text to be searched.

## Value

A list of character vectors. Each element of the list corresponds to an
element of the input `x` and contains all valid CASRNs found. An empty
`character(0)` vector indicates no valid CASRNs were found for that
input string.

## See also

[`as_cas()`](https://seanthimons.github.io/concert/reference/as_cas.md)
and
[`is_cas()`](https://seanthimons.github.io/concert/reference/is_cas.md)
for the underlying coercion and validation logic.

## Examples

``` r
text <- c(
  "The CAS for formaldehyde is 50-00-0, and water is 7732-18-5.",
  "An invalid number is 50-00-1, but a padded one is 007732-18-5.",
  "No hyphens: 50000.",
  "No valid CASRNs in this string.",
  NA
)
extract_cas(text)
#> [[1]]
#> [1] "50-00-0"   "7732-18-5"
#> 
#> [[2]]
#> [1] "7732-18-5"
#> 
#> [[3]]
#> [1] "50-00-0"
#> 
#> [[4]]
#> character(0)
#> 
#> [[5]]
#> character(0)
#> 
# [[1]]
# [1] "50-00-0"   "7732-18-5"
#
# [[2]]
# [1] "7732-18-5"
#
# [[3]]
# [1] "50-00-0"
#
# [[4]]
# character(0)
#
# [[5]]
# character(0)
```
