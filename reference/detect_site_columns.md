# Detect Site/Location Columns In A Dataset

Uses cleaned header names and conservative value checks to identify
likely source site labels, site identifiers, site names, coordinates,
and optional grouping metadata.

## Usage

``` r
detect_site_columns(df)
```

## Arguments

- df:

  Data frame after file detection/extraction.

## Value

A list with detected column names and `has_site_context`.
