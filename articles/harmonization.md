# Measurement harmonization

``` r

library(concert)
```

Harmonization turns free-text results, unit strings, and media labels
into numeric values in ToxVal target units. In
[`curate_headless()`](https://seanthimons.github.io/concert/reference/curate_headless.md)
it runs when `harmonize = TRUE`; in the app it is the Harmonize tab. The
building blocks are exported and work on plain vectors.

## Parse numeric results

Result columns mix numbers with qualifiers, detection limits, and
scientific notation in several spellings.

``` r

parsed <- parse_numeric_results(c("< 5.0", "2.5x10^3", "BDL", "4.56+02", "≥100", "5-10", "1e-3"))
parsed
#> # A tibble: 9 × 6
#>   orig_row_id orig_result numeric_value qualifier range_bin parse_flag 
#>         <int> <chr>               <dbl> <chr>     <chr>     <chr>      
#> 1           1 < 5.0               5     "<"       as_is     ""         
#> 2           2 2.5x10^3         2500     ""        as_is     ""         
#> 3           3 BDL                NA     ""        as_is     "narrative"
#> 4           4 4.56+02           456     ""        as_is     ""         
#> 5           5 ≥100              100     ">="      as_is     ""         
#> 6           6 5-10                5     ">="      low       ""         
#> 7           6 5-10                7.5   "~"       mid       ""         
#> 8           6 5-10               10     "<="      high      ""         
#> 9           7 1e-3                0.001 ""        as_is     ""
```

Each row keeps the original string, the parsed value, and a qualifier or
flag explaining anything that was not a plain number.

## Harmonize units

[`harmonize_units()`](https://seanthimons.github.io/concert/reference/harmonize_units.md)
converts values into the target unit for each unit family using the
bundled conversion table.

``` r

unit_map <- load_unit_map()
head(unit_map[, c("from_unit", "to_unit", "multiplier")])
#> # A tibble: 6 × 3
#>   from_unit to_unit multiplier
#>   <chr>     <chr>        <dbl>
#> 1 %         %                1
#> 2 % vol     % v/v            1
#> 3 % WSF     % WSF            1
#> 4 % sat     % sat            1
#> 5 pH        pH               1
#> 6 v/v       v/v              1
```

``` r

harmonize_units(
  values = c(2.5, 500, 12, 0.3),
  units = c("mg/L", "ug/L", "µg/l", "ppb"),
  unit_map = unit_map
)
#> # A tibble: 4 × 6
#>   orig_row_id orig_unit harmonized_value harmonized_unit conversion_factor
#>         <int> <chr>                <dbl> <chr>                       <dbl>
#> 1           1 mg/L                 2.5   mg/L                        1    
#> 2           2 ug/L                 0.5   mg/L                        0.001
#> 3           3 µg/l                 0.012 mg/L                        0.001
#> 4           4 ppb                  0.3   ppb                         1    
#> # ℹ 1 more variable: unit_flag <chr>
```

Notes on the lookup:

- Micro symbols and whitespace are normalized before lookup.
- Exact, case-sensitive matches win. Case-insensitive fallback only
  applies when every candidate row agrees on the target and multiplier.
- Unknown units pass through unchanged with `unit_flag = "unmatched"`.

### ppb and ppm need a media context

`ppb` in water means micrograms per litre. In soil it means micrograms
per kilogram. In air it is a volume ratio that cannot be converted
without molecular weight, temperature, and pressure. Pass `media` to
route these.

``` r

harmonize_units(
  values = c(1, 1, 1),
  units = c("ppb", "ppb", "ppb"),
  unit_map = unit_map,
  media = c("aqueous", "solid", "air")
)[, c("orig_unit", "harmonized_value", "harmonized_unit", "unit_flag")]
#> # A tibble: 3 × 4
#>   orig_unit harmonized_value harmonized_unit unit_flag      
#>   <chr>                <dbl> <chr>           <chr>          
#> 1 ppb                  0.001 mg/L            ""             
#> 2 ppb                  0.001 mg/kg           ""             
#> 3 ppb                  1     ppb             "needs_context"
```

### Molarity needs a molecular weight

Units like `mM` or `mol/L` convert to mass concentration only with a
molecular weight. Supply it directly, or pass `dtxsid` and let the
function look it up from CompTox (network required).

``` r

harmonize_units(
  values = 1,
  units = "mM",
  unit_map = unit_map,
  molecular_weight = 58.08
)[, c("orig_unit", "harmonized_value", "harmonized_unit", "unit_flag")]
#> # A tibble: 1 × 4
#>   orig_unit harmonized_value harmonized_unit unit_flag
#>   <chr>                <dbl> <chr>           <chr>    
#> 1 mM                    58.1 mg/L            ""
```

## Harmonize media

Media labels are mapped to canonical terms with ENVO identifiers and a
routing category (`aqueous`, `air`, `solid`). That category is what
feeds the ppb/ppm routing above.

``` r

harmonize_media(c("surface water", "Soil", "ambient air", "mystery matrix"))[
  , c("raw_media", "canonical_media", "envo_id", "media_category", "media_flag")
]
#> # A tibble: 4 × 5
#>   raw_media      canonical_media envo_id       media_category media_flag       
#>   <chr>          <chr>           <chr>         <chr>          <chr>            
#> 1 surface water  surface water   ENVO:00002042 aqueous        ""               
#> 2 Soil           soil            ENVO:00001998 solid          ""               
#> 3 ambient air    ambient air     ENVO:00002005 air            ""               
#> 4 mystery matrix NA              NA            NA             "media_unmatched"
```

Unmatched labels get `media_flag = "media_unmatched"` and no route. Add
them to the media map in the app’s Harmonize tab, or pass a custom
`media_map`.

## Dates and uncertainty

``` r

parse_dates(c("2024-01-15", "01/15/2024", "15 Jan 2024", "not a date"))
#> # A tibble: 4 × 5
#>   orig_row_id raw_date    parsed_date date_year date_flag    
#>         <int> <chr>       <chr>           <int> <chr>        
#> 1           1 2024-01-15  2024-01-15       2024 ""           
#> 2           2 01/15/2024  2024-01-15       2024 ""           
#> 3           3 15 Jan 2024 2024-01-15       2024 ""           
#> 4           4 not a date  NA                 NA "unparseable"
```

Uncertainty columns are normalized to two-sigma with
[`normalize_uncertainty_to_two_sigma()`](https://seanthimons.github.io/concert/reference/normalize_uncertainty_to_two_sigma.md),
using the tagged `UncertaintyCoverage` column when present.

## Putting it together

`curate_headless(harmonize = TRUE)` runs these steps on the tagged
columns, then
[`map_to_toxval_schema()`](https://seanthimons.github.io/concert/reference/map_to_toxval_schema.md)
assembles the 56-column ToxVal table. The returned list carries the
harmonization audit alongside the data:

``` r

out <- curate_headless(
  input_path = "input.xlsx",
  output_path = "output.xlsx",
  tag_map = list(chemical_name = "Name", casrn = "CASRN", result = "Result", unit = "Unit", matrix = "Media"),
  harmonize = TRUE,
  format = "both"
)
out$data              # ToxVal rows
out$harmonize_audit   # one row per converted or flagged value
```
