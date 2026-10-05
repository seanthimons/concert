# Load WQX dictionary lookup table

Returns a combined tibble of canonical WQX Characteristic Names and
alias mappings (synonym, standardize, retired). Uses the generic
cache-or-fetch infrastructure - builds the dictionary from EPA data on
first call if no cached RDS exists.

## Usage

``` r
load_wqx_dictionary(cache_dir)
```

## Arguments

- cache_dir:

  Directory containing reference cache RDS files

## Value

Tibble with columns: name, canonical_name, type, cas_number, group_name,
description
