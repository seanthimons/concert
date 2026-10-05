# Check for Required Chemical Tags

Validates that both Name and CASRN tags are present, which are required
for the cleaning pipeline to operate.

## Usage

``` r
has_required_chemical_tags(chemical_tags)
```

## Arguments

- chemical_tags:

  Named list of chemical tags (output from classify_tags)

## Value

Logical: TRUE if both Name and CASRN are present, FALSE otherwise

## Details

The cleaning pipeline requires both a chemical name column and a CASRN
column to perform deduplication and enrichment. This function checks
that at least one column is tagged as "Name" and at least one as
"CASRN".

## Examples

``` r
# Both present - returns TRUE
has_required_chemical_tags(list(col1 = "Name", col2 = "CASRN"))
#> [1] TRUE

# Missing CASRN - returns FALSE
has_required_chemical_tags(list(col1 = "Name"))
#> [1] FALSE

# Empty - returns FALSE
has_required_chemical_tags(list())
#> [1] FALSE
```
