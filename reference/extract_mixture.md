# Detects chemical mixtures by name based on ratio patterns

This function searches a vector of chemical names for patterns
indicating a ratio, such as "(1:1)" or "(2:1)". It is useful for
identifying potential mixtures that might not be flagged by other means.
The search is robust to extra whitespace. It complements
[`flag_multi_analyte()`](https://seanthimons.github.io/concert/reference/flag_multi_analyte.md),
which detects `+`/`and` separators rather than numeric ratios.

## Usage

``` r
extract_mixture(name_vector)
```

## Arguments

- name_vector:

  A character vector of chemical names to search.

## Value

A logical vector of the same length as `name_vector`. Returns `TRUE` if
a ratio pattern is found, `FALSE` if not, and `NA` for `NA` inputs.

## Examples

``` r
 if (FALSE) { # \dontrun{
test_names <- c(
  "Ethanol, water (1:1)",
  "Sodium chloride",
  "Styrene-butadiene copolymer (3:1)",
  "A name with extra spaces ( 2 : 1 )",
  "A name with decimals (1.5:1)",
  "1,2-Dichlorobenzene", # Should be FALSE
 "Mixture (3:1 w/w)",
  NA
)
extract_mixture(test_names)
test_names %>% enframe(., name = 'idx', value = 'name') %>% mutate(bool_mix = extract_mixture(name))
# Expected output: TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NA
} # }
```
