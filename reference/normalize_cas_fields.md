# Normalize CAS fields using ComptoxR

Applies as_cas() to all CASRN-tagged columns:

- Converts unformatted CAS (e.g., "67641") to standard format
  ("67-64-1")

- Converts placeholder text ("no cas", "n/a", "proprietary", "-") to NA

- Validates checksums and sets invalid CAS to NA

## Usage

``` r
normalize_cas_fields(df, tag_map)
```

## Arguments

- df:

  Dataframe with CAS columns

- tag_map:

  Named list mapping column names to types ("CASRN", "Name", "Other")

## Value

List with cleaned_data (tibble), audit_trail (tibble), and new_tags
(generated CASRN columns)

## Examples

``` r
df <- tibble::tibble(cas = c("67641", "no cas", "67-64-2"))
tag_map <- list(cas = "CASRN")
normalize_cas_fields(df, tag_map)
#> $cleaned_data
#> # A tibble: 3 × 1
#>   cas    
#>   <chr>  
#> 1 67-64-1
#> 2 NA     
#> 3 NA     
#> 
#> $audit_trail
#> # A tibble: 3 × 6
#>   row_id field step          original_value new_value reason                    
#>    <int> <chr> <chr>         <chr>          <chr>     <chr>                     
#> 1      1 cas   normalize_cas 67641          67-64-1   Normalize CAS-RN in cas u…
#> 2      2 cas   normalize_cas no cas         [NA]      Normalize CAS-RN in cas u…
#> 3      3 cas   normalize_cas 67-64-2        [NA]      Normalize CAS-RN in cas u…
#> 
#> $new_tags
#> list()
#> 
```
