# Normalize A Site Manifest

Coerces a site manifest to the canonical CONCERT schema while preserving
user-facing site identifiers and source audit columns.

## Usage

``` r
normalize_site_manifest(site_manifest)
```

## Arguments

- site_manifest:

  Data frame-like site manifest.

## Value

A tibble with canonical site manifest columns.
