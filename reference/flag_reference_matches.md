# Flag rows matching reference list entries

Two-pass matching: exact match first (tolower comparison), then
substring match. Only active=TRUE reference entries are matched against.
Match type and source are recorded in audit trail.

## Usage

``` r
flag_reference_matches(df, name_cols, reference_list, flag_type, flag_label)
```

## Arguments

- df:

  Dataframe with name columns

- name_cols:

  Character vector of Name-tagged column names

- reference_list:

  Tibble with columns: term, source, active

- flag_type:

  Either "warning" or "blocking"

- flag_label:

  Human-readable label for the flag (e.g., "functional category")

## Value

List with cleaned_data and audit_trail

## Examples

``` r
df <- tibble::tibble(chemical_name = c("plasticizer", "dibutyl phthalate plasticizer"))
ref <- tibble::tibble(term = "plasticizer", source = "app_default", active = TRUE)
flag_reference_matches(df, c("chemical_name"), ref, "warning", "functional category")
#> $cleaned_data
#> # A tibble: 2 × 2
#>   chemical_name                 cleaning_flag                        
#>   <chr>                         <chr>                                
#> 1 plasticizer                   WARN: functional category [exact]    
#> 2 dibutyl phthalate plasticizer WARN: functional category [substring]
#> 
#> $audit_trail
#> # A tibble: 2 × 6
#>   row_id field         step         original_value              new_value reason
#>    <int> <chr>         <chr>        <chr>                       <chr>     <chr> 
#> 1      1 chemical_name flag_warning plasticizer                 WARN: fu… Match…
#> 2      2 chemical_name flag_warning dibutyl phthalate plastici… WARN: fu… Match…
#> 
```
