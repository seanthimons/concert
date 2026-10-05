# Extract molecular formulas from text

Finds and returns chemically valid molecular formulas from a character
vector, restricted to content inside parentheses or square brackets.

## Usage

``` r
extract_formulas(text_vector)
```

## Arguments

- text_vector:

  A character vector of text to search.

## Value

A list of character vectors. Each element corresponds to one input
string and contains all formulas found inside its bracketed content.

## Details

Behavior:

- Correctly handles parentheses, square brackets, stoichiometric
  numbers, and grouped substructures (e.g., "(NH3)2").

- Recognizes complexes and hydrates inside brackets when they include
  spaces, middle dot (U+00B7), plus/minus, or periods (these are
  normalized before validation).

- Ignores oxidation state Roman numerals in brackets, e.g., "(III)" or
  "( ii )".

- Excludes carbon backbone ranges like "C9-12".

## Examples

``` r
texts <- c(
  "Water (H2O) and ethanol (C2H5OH).",
  "Complex: [Pt(NH3)2Cl2] catalyst.",
  "Hydrate: (CuSO4 . 5H2O)",
  "Oxidation state: iron (III) chloride",  # "(III)" is ignored
  "Backbone range: C9-12 alcohols"         # "C9-12" is ignored
)
extract_formulas(texts)
#> [[1]]
#> [1] "H2O"    "C2H5OH"
#> 
#> [[2]]
#> [1] "Pt(NH3)2Cl2"
#> 
#> [[3]]
#> [1] "CuSO4 . 5H2O"
#> 
#> [[4]]
#> character(0)
#> 
#> [[5]]
#> character(0)
#> 
```
