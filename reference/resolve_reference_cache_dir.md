# Resolve the default bundled reference cache directory

Prefer installed package data. When running the Shiny app from a source
checkout, system.file() may be empty, so fall back to
inst/extdata/reference_cache before allowing data/reference_cache to be
created with minimal fallback data.

## Usage

``` r
resolve_reference_cache_dir(cache_dir = NULL)
```

## Arguments

- cache_dir:

  Optional explicit cache directory

## Value

Character path to a reference cache directory
