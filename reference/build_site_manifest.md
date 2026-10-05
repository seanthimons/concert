# Build A Deterministic Site Manifest

Sorts by user-curated order/suborder, filters blank rows, and enforces
one row per site identifier.

## Usage

``` r
build_site_manifest(site_manifest)
```

## Arguments

- site_manifest:

  Site manifest candidate or user-edited site context.

## Value

A deterministic, ordered, distinct site manifest.
