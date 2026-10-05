# Run tiered search: exact -\> CAS -\> starts-with (3-char min)

Run tiered search: exact -\> CAS -\> starts-with (3-char min)

## Usage

``` r
run_tiered_search(dedup_result)
```

## Arguments

- dedup_result:

  Output of deduplicate_tagged_columns

## Value

Tibble of all lookup results with source_tier column
