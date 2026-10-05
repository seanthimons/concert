# Build CHORUS Site Manifest Payload

Produces the ordered, distinct site manifest CONCERT sends downstream.
CHORUS should still validate and deduplicate on ingest.

## Usage

``` r
build_chorus_site_manifest(site_manifest)
```

## Arguments

- site_manifest:

  Site manifest candidate or user-edited site context.

## Value

A deterministic site manifest tibble.
