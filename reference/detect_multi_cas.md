# Detect rows with multiple CAS-RNs

Flags rows containing more than one non-NA CAS value across all
CASRN-tagged columns. Adds multi_cas (logical) and multi_cas_count
(integer) columns.

## Usage

``` r
detect_multi_cas(df, tag_map)
```

## Arguments

- df:

  Dataframe with CASRN columns

- tag_map:

  Named list mapping column names to types ("CASRN", "Name", "Other")

## Value

Dataframe with multi_cas and multi_cas_count columns added

## Examples

``` r
df <- tibble::tibble(cas1 = c("67-64-1", NA), cas2 = c("108-88-3", NA))
tag_map <- list(cas1 = "CASRN", cas2 = "CASRN")
detect_multi_cas(df, tag_map)
#> # A tibble: 2 × 4
#>   cas1    cas2     multi_cas multi_cas_count
#>   <chr>   <chr>    <lgl>               <int>
#> 1 67-64-1 108-88-3 TRUE                    2
#> 2 NA      NA       FALSE                   0
```
