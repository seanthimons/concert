# Strip terminal enclosures (parentheticals and brackets) from name fields

Removes terminal `(...)` and `[...]` from Name-tagged columns, with
protection for chemical names containing "yl" (except exception words),
percentages, Roman oxidation states, recognized identity tokens, and
enclosures attached directly to the name with no preceding whitespace
(e.g. `Cyclo(L-Phe-L-Pro)`). Preserves stripped content in
`formula_extract_{source}` columns.

## Usage

``` r
strip_terminal_enclosures(df, name_cols)
```

## Arguments

- df:

  Dataframe with name columns

- name_cols:

  Character vector of Name-tagged column names

## Value

List with cleaned_data, audit_trail, and new_tags (empty list)

## Details

Recognized identity tokens protect the entire enclosure, including mixed
annotation text. Supported forms include 13C/14C, 15N, 17O/18O, 2H/3H,
34S and 37Cl with optional one- or two-digit counts, and D/d with a
count. Isotope symbols are case-sensitive; ring-/U- prefixes are
case-insensitive, with optional spaces between isotope components.
Congener codes include Parlar/P, TMX, Hp-Sed/Hx-Sed, Andrews-Vetter B
codes, T/Tox, and PCB/BZ/CB/PBDE/BDE/PBB/IUPAC numbers, matched
case-insensitively. Congener tokens cannot immediately follow a hyphen
in a longer name; name-attached isotope tokens remain supported.
Unsupported synonym enclosures such as Tryptophan-P-1 follow ordinary
annotation stripping. Single-digit charges with a preceding or following
sign are also protected. Numeric comma lists ending in a hyphen (e.g.
1,3- or 2,4,6-) are protected as positional locants, not charges. Comma
spacing affects recognition only; single locants, primed locants, and
general structural-name parsing are not included in this extension.
Reporting-basis phrases such as "as PCB6" are preserved separately from
individual-congener evidence, including mixed annotations. The observed
PCBtotal qualifier has no established composition in the source
workbook; preserving it does not certify congener identity or aggregate
composition. Recognition does not rewrite the original enclosure text.

## Examples

``` r
df <- tibble::tibble(chemical_name = c("Acetone (ACS reagent)", "ethanol (ethyl alcohol)"))
strip_terminal_enclosures(df, "chemical_name")
#> $cleaned_data
#> # A tibble: 2 × 2
#>   chemical_name           formula_extract_chemical_name
#>   <chr>                   <chr>                        
#> 1 Acetone                 ACS reagent                  
#> 2 ethanol (ethyl alcohol) NA                           
#> 
#> $audit_trail
#> # A tibble: 1 × 6
#>   row_id field         step                      original_value new_value reason
#>    <int> <chr>         <chr>                     <chr>          <chr>     <chr> 
#> 1      1 chemical_name strip_terminal_enclosures Acetone (ACS … Acetone   Strip…
#> 
#> $new_tags
#> list()
#> 
```
