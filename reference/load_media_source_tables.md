# Load reviewable media vocabulary source tables

Load reviewable media vocabulary source tables

## Usage

``` r
load_media_source_tables(source_dir = NULL)
```

## Arguments

- source_dir:

  Optional reference source directory. Published v0.1.1 tables are the
  default; explicit legacy source directories remain readable.

## Value

List with published compatibility map, matrix terms and matrix edges.
Explicit legacy directories return canonical, aliases and ontology
nodes.
