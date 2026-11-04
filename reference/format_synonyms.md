# Format synonyms for a Synonym-tagged column

Joins synonyms into the `"a; b; c"` form that a `"Synonym"` column
expects. Commas never separate synonyms (they occur inside names such as
"Benzene, 1,2-dichloro-"), so build the cell with this helper rather
than pasting by hand.

## Usage

``` r
format_synonyms(x)
```

## Arguments

- x:

  A list (for example a list column) with one character vector of
  synonyms per row, giving one string per element; or an atomic
  character vector, which is a single row's synonyms and gives one
  string.

## Value

Character vector. Empty or all-NA elements give `NA_character_`. A
synonym containing `;` outside brackets cannot be represented, so its
semicolons become commas, with a warning. A synonym with an unbalanced
parenthesis or bracket also warns, because it makes its whole cell
unsplittable.

## Examples

``` r
format_synonyms(c("EDB", "Ethylene dibromide"))
#> [1] "EDB; Ethylene dibromide"
format_synonyms(list(c("o-DCB", "ortho-Dichlorobenzene"), NA))
#> [1] "o-DCB; ortho-Dichlorobenzene" NA                            
```
