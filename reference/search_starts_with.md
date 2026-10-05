# Starts-with fallback search for names that failed exact match

Uses a session-level cache to avoid redundant API calls for repeated
terms. Cache keys are lowercased search terms; cache persists within R
session.

## Usage

``` r
search_starts_with(missed_names)
```

## Arguments

- missed_names:

  Character vector of names that failed exact match

## Value

Tibble with same columns as search_exact, may have multiple rows per
input
