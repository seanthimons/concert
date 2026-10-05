# Extract distinct units from SSWQS parquet file

Reads the SSWQS benchmark parquet file and extracts distinct unit
values. Returns raw inventory for gap analysis, NOT conversion mappings.

## Usage

``` r
extract_sswqs_units(parquet_path)
```

## Arguments

- parquet_path:

  Path to sswqs.parquet file

## Value

A tibble with column: unit (distinct unit strings)
