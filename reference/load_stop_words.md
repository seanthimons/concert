# Load stop words list

Returns a tibble of chemistry-specific stop words with provenance
tracking. These are domain knowledge defaults, not ComptoxR-seeded.

## Usage

``` r
load_stop_words(cache_dir)
```

## Arguments

- cache_dir:

  Directory for cache files (e.g., "data/reference_cache")

## Value

Tibble with columns: term, source, active

## Details

Stop words are terms that indicate placeholder/test entries:

- test, sample, unknown, blank, standard, control, reference

- placeholder, tbd, tba

- na, n/a, none, not available, not applicable

NOTE: Cache format changed in Phase 13 - delete existing cache files if
needed.
