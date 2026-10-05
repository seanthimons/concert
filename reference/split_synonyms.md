# Split semicolon-separated synonyms in name fields

Splits semicolon-separated synonyms into separate rows. Semicolons
inside balanced parentheses or brackets stay within the name; unmatched
or mismatched enclosures leave the entire cell unsplit. Commas never
split: inverted IUPAC and CAS-registry names ("butane, 2,2-dimethyl",
"Fatty acids, C16-22, lithium salts") carry commas inside one name. Rows
that carry a CASRN are never split (one CAS is one chemical). CAS-less
rows are left intact when any fragment cannot stand alone as a name
(trailing hyphen, leading locant, bare descriptor such as "branched").
Primary name keeps original row; synonyms get new rows with CAS columns
set to NA. Switch off in the pipeline with
`mask = list(synonyms = FALSE)`.

## Usage

``` r
split_synonyms(df, name_cols, tag_map)
```

## Arguments

- df:

  Dataframe with name columns

- name_cols:

  Character vector of Name-tagged column names

- tag_map:

  Named list mapping column names to types

## Value

List with cleaned_data and audit_trail

## Examples

``` r
df <- tibble::tibble(
  original_row_id = 1L,
  cas_number = "67-64-1",
  chemical_name = "xylene; dimethylbenzene; xylol"
)
tag_map <- list(cas_number = "CASRN", chemical_name = "Name")
split_synonyms(df, "chemical_name", tag_map)
#> $cleaned_data
#> # A tibble: 1 × 5
#>   original_row_id cas_number chemical_name           synonym_count synonym_index
#>             <int> <chr>      <chr>                           <int>         <int>
#> 1               1 67-64-1    xylene; dimethylbenzen…             1             1
#> 
#> $audit_trail
#> # A tibble: 0 × 6
#> # ℹ 6 variables: row_id <int>, field <chr>, step <chr>, original_value <chr>,
#> #   new_value <chr>, reason <chr>
#> 
```
