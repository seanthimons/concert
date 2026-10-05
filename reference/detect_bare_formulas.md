# Detect bare molecular formulas

Uses an element-token regex to identify bare molecular formulas (H2O,
NaCl, CuSO4). Bare formulas are blocked because they lack chemical
context needed for curation. Detected formulas are moved to
`formula_blocked_{col}` columns and name set to NA.

## Usage

``` r
detect_bare_formulas(df, name_cols, isotope_lookup = NULL)
```

## Arguments

- df:

  Dataframe with name columns

- name_cols:

  Character vector of Name-tagged column names

- isotope_lookup:

  Optional isotope lookup from
  [`load_isotope_lookup()`](https://seanthimons.github.io/concert/reference/load_isotope_lookup.md).
  Known isotope shortcodes are not blocked as bare formulas.

## Value

List with cleaned_data and audit_trail

## Examples

``` r
df <- tibble::tibble(chemical_name = c("H2O", "acetone", "NaCl"))
detect_bare_formulas(df, c("chemical_name"))
#> $cleaned_data
#> # A tibble: 3 × 3
#>   chemical_name cleaning_flag       formula_blocked_chemical_name
#>   <chr>         <chr>               <chr>                        
#> 1 NA            BLOCK: bare formula H2O                          
#> 2 acetone       NA                  NA                           
#> 3 NA            BLOCK: bare formula NaCl                         
#> 
#> $audit_trail
#> # A tibble: 2 × 6
#>   row_id field         step                original_value new_value reason      
#>    <int> <chr>         <chr>               <chr>          <chr>     <chr>       
#> 1      1 chemical_name detect_bare_formula H2O            [NA]      Bare molecu…
#> 2      3 chemical_name detect_bare_formula NaCl           [NA]      Bare molecu…
#> 
```
