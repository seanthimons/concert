# Validate Tag Pairing Requirements

Checks that required tag pairings are satisfied. Currently validates
that Result and Unit tags appear together (per D-12/D-13).

## Usage

``` r
validate_tag_pairing(tags)
```

## Arguments

- tags:

  Named list where names are column names and values are tag types

## Value

Character warning message if pairing violated, NULL otherwise. Note:
This is a warning, not a blocker (per D-14/D-15).

## Details

Per D-12 and D-13, Result and Unit should be paired for meaningful
harmonization. This function returns a warning message if:

- Result is tagged without Unit

- Unit is tagged without Result, Numeric, ReportingLimit, or Uncertainty

The warning is informational and does not block tag application.

## Examples

``` r
# Unpaired Result - returns warning
validate_tag_pairing(list(col1 = "Result"))
#> [1] "Result tagged without Unit - harmonization may be incomplete"

# Paired Result/Unit - returns NULL
validate_tag_pairing(list(col1 = "Result", col2 = "Unit"))
#> NULL

# Non-numeric tags - returns NULL
validate_tag_pairing(list(col1 = "Name"))
#> NULL
```
