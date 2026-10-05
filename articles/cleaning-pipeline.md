# Cleaning pipeline

``` r

library(concert)
```

This vignette covers the offline half of the pipeline: reading a messy
file, finding the header row, tagging columns, and cleaning names and
CAS numbers. Nothing here touches the network.

## Read a file with frontmatter

Lab exports usually start with report metadata. Here is a small CSV with
four lines of frontmatter before the real header, padded with commas the
way Excel writes them.

``` r

csv_path <- tempfile(fileext = ".csv")
writeLines(c(
  "Chemical Inventory Report,,,,",
  "Generated: 2024-01-15,,,,",
  "Laboratory: Organic Chemistry Lab,,,,",
  ",,,,",
  "Chemical Name,CAS Number,Result,Unit,Location",
  "Acetone,67641,2.5,mg/L,Building A",
  "  Ethanol  ,64-17-5,< 0.5,ug/L,Building A",
  "Toluene,108-88-3,12,mg/L,Building B",
  "Lead + Zinc,,0.3,ppb,Building B"
), csv_path)

raw <- safely_read_file(csv_path, "csv")
raw
#> # A tibble: 9 × 5
#>   V1                                V2         V3     V4    V5        
#>   <chr>                             <chr>      <chr>  <chr> <chr>     
#> 1 Chemical Inventory Report         NA         NA     NA    NA        
#> 2 Generated: 2024-01-15             NA         NA     NA    NA        
#> 3 Laboratory: Organic Chemistry Lab NA         NA     NA    NA        
#> 4 NA                                NA         NA     NA    NA        
#> 5 Chemical Name                     CAS Number Result Unit  Location  
#> 6 Acetone                           67641      2.5    mg/L  Building A
#> 7 Ethanol                           64-17-5    < 0.5  ug/L  Building A
#> 8 Toluene                           108-88-3   12     mg/L  Building B
#> 9 Lead + Zinc                       NA         0.3    ppb   Building B
```

[`detect_data_start()`](https://seanthimons.github.io/concert/reference/detect_data_start.md)
runs three detectors (fill-ratio heuristic, chemistry keyword matching,
type consistency) and keeps the most confident answer.

``` r

detection <- detect_data_start(raw)
detection[c("header_row", "data_start_row", "method", "confidence")]
#> $header_row
#> [1] 5
#> 
#> $data_start_row
#> [1] 6
#> 
#> $method
#> [1] "heuristic"
#> 
#> $confidence
#> [1] 0.874135
```

If detection is wrong, pass the row yourself:

``` r

detection <- detect_data_start(raw, mode = "manual", manual_row = 5)
```

[`extract_clean_data()`](https://seanthimons.github.io/concert/reference/extract_clean_data.md)
promotes the header row and drops everything above it. The app then runs
[`handle_merged_cells()`](https://seanthimons.github.io/concert/reference/handle_merged_cells.md)
and
[`janitor::clean_names()`](https://sfirke.github.io/janitor/reference/clean_names.html),
so do the same here.

``` r

clean <- extract_clean_data(raw, detection)
clean <- janitor::clean_names(handle_merged_cells(clean))
clean
#> # A tibble: 4 × 5
#>   chemical_name cas_number result unit  location  
#>   <chr>         <chr>      <chr>  <chr> <chr>     
#> 1 Acetone       67641      2.5    mg/L  Building A
#> 2 Ethanol       64-17-5    < 0.5  ug/L  Building A
#> 3 Toluene       108-88-3   12     mg/L  Building B
#> 4 Lead + Zinc   NA         0.3    ppb   Building B
```

## Tag columns

Tags tell the pipeline what each column means.
[`suggest_column_tags()`](https://seanthimons.github.io/concert/reference/suggest_column_tags.md)
guesses from header names only, and stays quiet when unsure.

``` r

suggest_column_tags(names(clean))
#> $chemical_name
#> [1] "Name"
#> 
#> $cas_number
#> [1] "CASRN"
#> 
#> $result
#> [1] "Result"
#> 
#> $unit
#> [1] "Unit"
#> 
#> $location
#> [1] ""
```

Suggestions are a starting point. Build the final `tag_map` yourself;
every `Result` column needs a `Unit` partner.

``` r

tag_map <- list(
  chemical_name = "Name",
  cas_number = "CASRN",
  result = "Result",
  unit = "Unit"
)
is.null(validate_tag_pairing(tag_map))  # NULL means no pairing problem
#> [1] TRUE
```

## Run the cleaning pipeline

[`run_cleaning_pipeline()`](https://seanthimons.github.io/concert/reference/run_cleaning_pipeline.md)
chains the cleaning steps and records every change.

``` r

result <- run_cleaning_pipeline(clean, tag_map)
result$cleaned_data
#> # A tibble: 4 × 12
#>   original_row_id chemical_name cas_number result unit  location   multi_cas
#>             <int> <chr>         <chr>      <chr>  <chr> <chr>      <lgl>    
#> 1               1 Acetone       67-64-1    2.5    mg/L  Building A FALSE    
#> 2               2 Ethanol       64-17-5    < 0.5  ug/L  Building A FALSE    
#> 3               3 Toluene       108-88-3   12     mg/L  Building B FALSE    
#> 4               4 Lead + Zinc   NA         0.3    ppb   Building B FALSE    
#> # ℹ 5 more variables: multi_cas_count <int>, cleaning_flag <chr>,
#> #   formula_extract_chemical_name <chr>, synonym_count <int>,
#> #   synonym_index <int>
```

The audit trail has one row per changed cell: which step touched it and
the before and after values. Here the CAS for acetone was normalized to
the hyphenated form, and the multi-analyte cell was flagged.

``` r

result$audit_trail[, c("row_id", "field", "step", "original_value", "new_value")]
#> # A tibble: 2 × 5
#>   row_id field         step               original_value new_value  
#>    <int> <chr>         <chr>              <chr>          <chr>      
#> 1      1 cas_number    normalize_cas      67641          67-64-1    
#> 2      4 chemical_name flag_multi_analyte Lead + Zinc    Lead + Zinc
```

The `Lead + Zinc` row was flagged, not split. Multi-analyte cells are
left for review because the right action (split, keep, rename) depends
on the dataset. See
[`resolve_multi_analyte_row()`](https://seanthimons.github.io/concert/reference/resolve_multi_analyte_row.md)
and the headless vignette for how to resolve them in bulk.

### Switch steps off

Some datasets are mangled by a step that helps elsewhere. `mask` turns
individual steps off. Names are `unicode`, `whitespace`, `cas`, `names`,
`isotopes`, `multi`, `chiral`, `truncated`, `bare_formula`, and
`reference_flags`.

``` r

no_multi <- run_cleaning_pipeline(clean, tag_map, mask = list(multi = FALSE))
unique(no_multi$audit_trail$step)
#> [1] "normalize_cas"
```

### Fix values before cleaning

[`apply_value_corrections()`](https://seanthimons.github.io/concert/reference/apply_value_corrections.md)
runs column-scoped pattern replacements before the pipeline. Use it for
known prefixes, suffixes, and typos.

``` r

corrections <- data.frame(
  column = "chemical_name",
  pattern = "^Total ",
  replacement = ""
)
fixed <- apply_value_corrections(
  data.frame(chemical_name = c("Total Lead", "Zinc")),
  corrections
)
fixed$cleaned_data
#>   chemical_name
#> 1          Lead
#> 2          Zinc
```

## CAS helpers

The CAS utilities are exported for use outside the pipeline.

``` r

is_cas(c("67-64-1", "67-64-2", "not a cas"))
#> [1]  TRUE FALSE FALSE
as_cas(c("67641", "64-17-5"))
#> [1] "67-64-1" "64-17-5"
extract_cas("ethanol (64-17-5) in water")
#> [[1]]
#> [1] "64-17-5"
```

## Reference lists

The name-cleaning steps read bundled reference lists: stop words, strip
terms, block patterns, functional categories, and an isotope lookup.
Load them to inspect or extend.

``` r

refs <- load_all_reference_lists()
names(refs)
#>  [1] "stop_words"            "block_patterns"        "functional_categories"
#>  [4] "strip_terms"           "corrections"           "isotope_lookup"       
#>  [7] "unit_map"              "unit_synonyms"         "toxval_schema"        
#> [10] "media_map"
head(refs$strip_terms, 3)
#> # A tibble: 3 × 6
#>   term          pattern       match_mode   source        active notes
#>   <chr>         <chr>         <chr>        <chr>         <lgl>  <chr>
#> 1 "modified"    "modified"    literal_word legacy_review FALSE  NA   
#> 2 "\\d+%$"      "\\d+%$"      regex        legacy_review FALSE  NA   
#> 3 "part [a-z]:" "part [a-z]:" regex        legacy_review FALSE  NA
```

User edits persist through
[`save_user_reference_lists()`](https://seanthimons.github.io/concert/reference/save_user_reference_lists.md)
and are merged over the package defaults on the next load.
