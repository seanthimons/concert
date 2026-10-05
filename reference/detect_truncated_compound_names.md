# Detect likely truncated compound names

Flags Name-tagged fields with unbalanced parentheses/brackets or
ellipsis markers that indicate a likely truncated compound name. This is
a flag-only detector: original Name values are preserved.

## Usage

``` r
detect_truncated_compound_names(df, name_cols)
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
df <- tibble::tibble(chemical_name = c("Bisphenol A (BPA", "acetone"))
detect_truncated_compound_names(df, c("chemical_name"))
#> $cleaned_data
#> # A tibble: 2 × 2
#>   chemical_name    cleaning_flag                                   
#>   <chr>            <chr>                                           
#> 1 Bisphenol A (BPA BLOCK: truncated compound [unbalanced delimiter]
#> 2 acetone          NA                                              
#> 
#> $audit_trail
#> # A tibble: 1 × 6
#>   row_id field         step                      original_value new_value reason
#>    <int> <chr>         <chr>                     <chr>          <chr>     <chr> 
#> 1      1 chemical_name detect_truncated_compound Bisphenol A (… Bispheno… Unbal…
#> 
```
