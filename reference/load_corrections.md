# Load one-off corrections table

Returns a tibble of (pattern, replacement) pairs for correcting
source-specific malformed Result values before numeric parsing. Applied
as vectorized gsub() before parse_numeric_results(). Patterns are
treated as regex.

## Usage

``` r
load_corrections(cache_dir)
```

## Arguments

- cache_dir:

  Directory for cache files (e.g., "inst/extdata/reference_cache")

## Value

Tibble with columns: pattern (character), replacement (character)
