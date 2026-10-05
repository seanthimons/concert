# Rescue CAS-RNs from non-CASRN text columns

Uses extract_cas() to find CAS-RNs embedded in Name/Other columns.
Extracted CAS values are placed in new `cas_extract_{source}` columns.
Source text is stripped of the CAS pattern.

## Usage

``` r
rescue_cas_from_text(df, tag_map)
```

## Arguments

- df:

  Dataframe with tagged columns

- tag_map:

  Named list mapping column names to types ("CASRN", "Name", "Other")

## Value

List with cleaned_data, audit_trail, and new_tags (mapping cas_extract
columns to "CASRN")

## Examples

``` r
df <- tibble::tibble(name = c("acetone (67-64-1)", "water"))
tag_map <- list(name = "Name")
rescue_cas_from_text(df, tag_map)
#> $cleaned_data
#> # A tibble: 2 × 2
#>   name    cas_extract_name
#>   <chr>   <chr>           
#> 1 acetone 67-64-1         
#> 2 water   NA              
#> 
#> $audit_trail
#> # A tibble: 1 × 6
#>   row_id field step       original_value    new_value                     reason
#>    <int> <chr> <chr>      <chr>             <chr>                         <chr> 
#> 1      1 name  rescue_cas acetone (67-64-1) Extracted 67-64-1 to cas_ext… Extra…
#> 
#> $new_tags
#> $new_tags$cas_extract_name
#> [1] "CASRN"
#> 
#> 
```
