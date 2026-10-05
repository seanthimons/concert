# Strip user-defined reference terms from name fields

Removes terms from the strip_terms reference list from Name-tagged
columns. Matching behavior is controlled by each row's `match_mode`:
`literal_word`, `literal_exact`, or `regex`.

## Usage

``` r
strip_reference_terms(df, name_cols, strip_terms_tbl)
```

## Arguments

- df:

  Dataframe with name columns

- name_cols:

  Character vector of Name-tagged column names

- strip_terms_tbl:

  Tibble with columns: term, source, active

## Value

List with cleaned_data and audit_trail

## Examples

``` r
df <- tibble::tibble(chemical_name = c("pure acetone", "technical ethanol"))
terms <- tibble::tibble(term = c("pure", "technical"), source = "user", active = TRUE)
strip_reference_terms(df, "chemical_name", terms)
#> $cleaned_data
#> # A tibble: 2 × 1
#>   chemical_name
#>   <chr>        
#> 1 acetone      
#> 2 ethanol      
#> 
#> $audit_trail
#> # A tibble: 2 × 6
#>   row_id field         step                  original_value    new_value reason 
#>    <int> <chr>         <chr>                 <chr>             <chr>     <chr>  
#> 1      1 chemical_name strip_reference_terms pure acetone      acetone   Remove…
#> 2      2 chemical_name strip_reference_terms technical ethanol ethanol   Remove…
#> 
```
