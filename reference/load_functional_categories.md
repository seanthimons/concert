# Load functional use categories

Returns a tibble of functional use categories from ComptoxR with
provenance tracking. Falls back gracefully if ComptoxR is unavailable or
API fails.

## Usage

``` r
load_functional_categories(cache_dir)
```

## Arguments

- cache_dir:

  Directory for cache files (e.g., "data/reference_cache")

## Value

Tibble with columns: term, source, active

## Details

NOTE: Cache format changed in Phase 13 - delete existing cache files if
needed.
