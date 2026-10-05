# Extract distinct units from ToxVal database

Queries the ToxVal toxval table for distinct unit strings. Returns raw
inventory for gap analysis, NOT conversion mappings.

## Usage

``` r
extract_toxval_units(db_path)
```

## Arguments

- db_path:

  Path to toxval.duckdb file

## Value

A tibble with column: unit (distinct unit strings)
