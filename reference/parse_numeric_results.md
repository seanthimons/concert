# Parse messy numeric result strings into a structured tibble

Handles whitespace, commas, scientific notation (x10 with or without
caret and spaces, spaced E, Fortran exponents, standard e), word
multipliers ("7 million"), footnote asterisks and doubled-decimal typos,
qualifier extraction (\<, \>, \<=, \>=, ~, =), unicode qualifiers (\>=,
\<=), narrative detection (BDL, ND, trace, etc.), range splitting (5-10
-\> 3 rows), and unparseable values.

## Usage

``` r
parse_numeric_results(values)
```

## Arguments

- values:

  Character vector of raw result strings

## Value

A tibble with columns: orig_row_id, orig_result, numeric_value,
qualifier, range_bin, parse_flag. Range values produce 3 rows sharing
the same orig_row_id.

## Details

Unparseable strings containing no digits (e.g. "See note") are
reclassified as narrative: numeric_value = NA, parse_flag = "narrative",
excluded from the unparseable warning and the correction workflow.

Range splitting (PARS-03): "5-10" becomes 3 rows per D-02 and D-03:

- low row: qualifier="\>=", range_bin="low"

- mid row: qualifier="~", range_bin="mid"

- high row: qualifier="\<=", range_bin="high" Negative numbers (-5) and
  scientific notation (1e-3) are NOT split (numeric pre-guard).

Implementation note: range detection runs on a pre-Fortran-normalized
form. This is critical because the Fortran exponent normalizer converts
"5-10" to "5e-10" (matches digit-minus-digits pattern). Ranges are
detected first, then Fortran normalization applies only to non-range
values.

## Examples

``` r
parse_numeric_results(c("< 5.0", "2.5x10^3", "BDL", "4.56+02", "\u2265100"))
#> # A tibble: 5 × 6
#>   orig_row_id orig_result numeric_value qualifier range_bin parse_flag 
#>         <int> <chr>               <dbl> <chr>     <chr>     <chr>      
#> 1           1 < 5.0                   5 "<"       as_is     ""         
#> 2           2 2.5x10^3             2500 ""        as_is     ""         
#> 3           3 BDL                    NA ""        as_is     "narrative"
#> 4           4 4.56+02               456 ""        as_is     ""         
#> 5           5 ≥100                  100 ">="      as_is     ""         
parse_numeric_results(c("5-10", "-5", "1e-3"))
#> # A tibble: 5 × 6
#>   orig_row_id orig_result numeric_value qualifier range_bin parse_flag
#>         <int> <chr>               <dbl> <chr>     <chr>     <chr>     
#> 1           1 5-10                5     ">="      low       ""        
#> 2           1 5-10                7.5   "~"       mid       ""        
#> 3           1 5-10               10     "<="      high      ""        
#> 4           2 -5                 -5     ""        as_is     ""        
#> 5           3 1e-3                0.001 ""        as_is     ""        
```
