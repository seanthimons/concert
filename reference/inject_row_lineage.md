# Inject row lineage tracking

Adds original_row_id column as first column to track row identity
through transformations.

## Usage

``` r
inject_row_lineage(df)
```

## Arguments

- df:

  Dataframe to add lineage to

## Value

Dataframe with original_row_id as first column

## Examples

``` r
df <- tibble::tibble(a = 1:3, b = c("x", "y", "z"))
inject_row_lineage(df)  # => tibble with original_row_id = 1:3 as first column
#> # A tibble: 3 × 3
#>   original_row_id     a b    
#>             <int> <int> <chr>
#> 1               1     1 x    
#> 2               2     2 y    
#> 3               3     3 z    
```
