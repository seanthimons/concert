# Expand isotope shortcodes to canonical Name-Mass format (vectorized)

Two-pass approach applied column-at-a-time:

1.  Naked shortcode expansion: u234 -\> Uranium-234 (using cached
    isotope lookup)

2.  Spelled-out normalization: radium 226 -\> Radium-226 Plus special
    case: unat -\> WARNING flag (unresolvable natural uranium mixture)

## Usage

``` r
expand_isotope_shortcodes(df, name_cols, isotope_lookup = NULL)
```

## Arguments

- df:

  Dataframe with name columns

- name_cols:

  Character vector of Name-tagged column names

- isotope_lookup:

  Optional pre-built lookup from load_isotope_lookup(). If NULL, falls
  back to building from ComptoxR::pt\$isotope directly.

## Value

List with cleaned_data (tibble) and audit_trail (tibble)

## Details

Exclusions per ISOT-03:

- Carbon backbone patterns (C12H22O11) - NOT expanded

- Deuterium d-prefix patterns (d-glucose) - NOT expanded

- Isotope prefixes in compound names (14C-glucose) - NOT expanded

## Examples

``` r
df <- tibble::tibble(chemical_name = c("u234", "radium 226", "C12H22O11"))
expand_isotope_shortcodes(df, c("chemical_name"))
#> $cleaned_data
#> # A tibble: 3 × 3
#>   chemical_name cleaning_flag isotope_dtxsid
#>   <chr>         <chr>         <chr>         
#> 1 Uranium-234   isotope_match DTXSID40891752
#> 2 Radium-226    isotope_match DTXSID3051202 
#> 3 C12H22O11     NA            NA            
#> 
#> $audit_trail
#> # A tibble: 2 × 6
#>   row_id field         step                      original_value new_value reason
#>    <int> <chr>         <chr>                     <chr>          <chr>     <chr> 
#> 1      1 chemical_name expand_isotope_shortcodes u234           Uranium-… Isoto…
#> 2      2 chemical_name expand_isotope_shortcodes radium 226     Radium-2… Isoto…
#> 
```
