# Strip terminal "unspecified" suffixes from name fields

Removes terminal `[,;-]? unspecified` patterns from Name-tagged columns.

## Usage

``` r
strip_terminal_unspecified(df, name_cols)
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
df <- tibble::tibble(chemical_name = c("compound, unspecified", "chemical - unspecified"))
strip_terminal_unspecified(df, "chemical_name")
#> $cleaned_data
#> # A tibble: 2 × 1
#>   chemical_name
#>   <chr>        
#> 1 compound     
#> 2 chemical     
#> 
#> $audit_trail
#> # A tibble: 2 × 6
#>   row_id field         step                      original_value new_value reason
#>    <int> <chr>         <chr>                     <chr>          <chr>     <chr> 
#> 1      1 chemical_name strip_terminal_unspecifi… compound, uns… compound  Remov…
#> 2      2 chemical_name strip_terminal_unspecifi… chemical - un… chemical  Remov…
#> 
```
