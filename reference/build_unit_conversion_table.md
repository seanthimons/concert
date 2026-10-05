# Build comprehensive unit conversion table

Extracts units from ECOTOX (primary source), performs coverage analysis
against ToxVal and SSWQS, transforms to UCUM conventions, and saves the
result as an RDS file.

## Usage

``` r
build_unit_conversion_table(
  ecotox_path,
  toxval_path = NULL,
  sswqs_path = NULL,
  output_path
)
```

## Arguments

- ecotox_path:

  Path to ecotox.duckdb file (required)

- toxval_path:

  Path to toxval.duckdb file (optional, for coverage analysis)

- sswqs_path:

  Path to sswqs.parquet file (optional, for coverage analysis)

- output_path:

  Path to write output RDS file

## Value

The unit conversion tibble (invisibly)

## Details

The output table has 6 columns:

- from_unit: source unit string

- to_unit: target canonical unit (UCUM)

- multiplier: conversion factor (NA for molarity units)

- category: unit category (concentration, air_concentration,
  mass_fraction, dose, molarity, etc.)

- confidence: HIGH, LOW, or NEEDS_MW

- source: provenance (ECOTOX, manual)
