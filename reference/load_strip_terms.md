# Load strip terms list

Returns a tibble of terms to strip from chemical names with provenance
tracking. Default terms are seeded from the hardcoded strip functions
(quality adjectives, salt references, terminal unspecified). Users can
add custom terms via the UI.

## Usage

``` r
load_strip_terms(cache_dir)
```

## Arguments

- cache_dir:

  Directory for cache files (e.g., "data/reference_cache")

## Value

Tibble with columns: term, source, active
