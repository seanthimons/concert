# Strip quality adjectives from name fields

Removes quality words like "pure", "purified", "technical", "grade",
"chemical" from Name-tagged columns. Uses word boundaries for clean
removal.

## Usage

``` r
strip_quality_adjectives(df, name_cols)
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
df <- tibble::tibble(chemical_name = c("technical grade ethanol", "purified water"))
strip_quality_adjectives(df, "chemical_name")
#> $cleaned_data
#> # A tibble: 2 × 1
#>   chemical_name
#>   <chr>        
#> 1 ethanol      
#> 2 water        
#> 
#> $audit_trail
#> # A tibble: 2 × 6
#>   row_id field         step                     original_value  new_value reason
#>    <int> <chr>         <chr>                    <chr>           <chr>     <chr> 
#> 1      1 chemical_name strip_quality_adjectives technical grad… ethanol   Remov…
#> 2      2 chemical_name strip_quality_adjectives purified water  water     Remov…
#> 
```
