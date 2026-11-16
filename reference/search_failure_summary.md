# Count degraded lookups in a curation pipeline result

Combines the failures
[`run_curation_pipeline()`](https://seanthimons.github.io/concert/reference/run_curation_pipeline.md)
swallowed (counted in queries) with the per-row failure statuses of the
WQX CAS, PubChem, desalt, resolver and source-identifier lookups
(counted in rows).

## Usage

``` r
search_failure_summary(pipeline_result)
```

## Arguments

- pipeline_result:

  A list returned by
  [`run_curation_pipeline()`](https://seanthimons.github.io/concert/reference/run_curation_pipeline.md).

## Value

A tibble with columns lookup, n and unit; zero rows when nothing failed.
