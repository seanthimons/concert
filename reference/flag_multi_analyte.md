# Flag rows containing naked multi-analyte expressions

Flags rows where name columns contain naked " + ", " and ", " & ", or "
/ " between tokens as "WARNING: potential multi-analyte". Does NOT
modify cell values (flag only per D-11). See
[`multi_analyte_separator_pattern()`](https://seanthimons.github.io/concert/reference/multi_analyte_separator_pattern.md).

## Usage

``` r
flag_multi_analyte(df, name_cols)
```

## Arguments

- df:

  Dataframe with name columns

- name_cols:

  Character vector of Name-tagged column names

## Value

List with cleaned_data (tibble) and audit_trail (tibble)

## Details

A naked " + " means a plus sign surrounded by whitespace and NOT inside
parentheses. "(+)-catechin" is NOT flagged - the + is inside
parentheses. " & " and " / " are likewise skipped inside a parenthetical
group, e.g. "endosulfan (alpha & beta)".

## Examples

``` r
df <- tibble::tibble(chemical_name = c("nitrate + nitrite", "(+)-catechin", "acetone"))
flag_multi_analyte(df, c("chemical_name"))
#> $cleaned_data
#> # A tibble: 3 × 2
#>   chemical_name     cleaning_flag                   
#>   <chr>             <chr>                           
#> 1 nitrate + nitrite WARNING: potential multi-analyte
#> 2 (+)-catechin      NA                              
#> 3 acetone           NA                              
#> 
#> $audit_trail
#> # A tibble: 1 × 6
#>   row_id field         step               original_value    new_value     reason
#>    <int> <chr>         <chr>              <chr>             <chr>         <chr> 
#> 1      1 chemical_name flag_multi_analyte nitrate + nitrite nitrate + ni… Poten…
#> 
```
