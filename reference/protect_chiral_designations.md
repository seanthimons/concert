# Protect chiral designations from downstream stripping

Replaces chiral markers - (+), (-), (R), (S), (R,S), (dl), etc. - with
numbered placeholders (###CHIRAL_n###) and sets a WARNING flag. Must run
BEFORE strip_terminal_enclosures() (Step 6a).

## Usage

``` r
protect_chiral_designations(df, name_cols)
```

## Arguments

- df:

  Dataframe with name columns

- name_cols:

  Character vector of Name-tagged column names

## Value

List with cleaned_data (tibble) and audit_trail (tibble)

## Examples

``` r
df <- tibble::tibble(chemical_name = c("(+)-catechin", "acetone"))
protect_chiral_designations(df, c("chemical_name"))
#> $cleaned_data
#> # A tibble: 2 × 2
#>   chemical_name              cleaning_flag              
#>   <chr>                      <chr>                      
#> 1 ###CHIRAL_PLUS###-catechin WARNING: chiral designation
#> 2 acetone                    NA                         
#> 
#> $audit_trail
#> # A tibble: 1 × 6
#>   row_id field         step                      original_value new_value reason
#>    <int> <chr>         <chr>                     <chr>          <chr>     <chr> 
#> 1      1 chemical_name protect_chiral_designati… (+)-catechin   ###CHIRA… Chira…
#> 
```
