# Strip salt references from name fields

Removes "and its `adjective` salts" patterns from Name-tagged columns.

## Usage

``` r
strip_salt_references(df, name_cols)
```

## Arguments

- df:

  Dataframe with name columns

- name_cols:

  Character vector of Name-tagged column names

## Value

List with cleaned_data and audit_trail

## Examples

``` r
df <- tibble::tibble(chemical_name = c("lead and its salts", "mercury and its inorganic salts"))
strip_salt_references(df, "chemical_name")
#> $cleaned_data
#> # A tibble: 2 × 1
#>   chemical_name
#>   <chr>        
#> 1 lead         
#> 2 mercury      
#> 
#> $audit_trail
#> # A tibble: 2 × 6
#>   row_id field         step                  original_value     new_value reason
#>    <int> <chr>         <chr>                 <chr>              <chr>     <chr> 
#> 1      1 chemical_name strip_salt_references lead and its salts lead      Remov…
#> 2      2 chemical_name strip_salt_references mercury and its i… mercury   Remov…
#> 
```
