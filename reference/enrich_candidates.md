# Fetch CompTox chemical details for DTXSIDs and return structured cache

Calls CompTox chemical detail search to retrieve CASRN, molecular
formula, and molecular weight for each unique DTXSID. Supports
incremental caching: pass existing_cache to skip already-fetched
DTXSIDs.

## Usage

``` r
enrich_candidates(dtxsids, existing_cache = NULL)
```

## Arguments

- dtxsids:

  Character vector of DTXSIDs to enrich

- existing_cache:

  Optional tibble from a previous enrich_candidates() call. DTXSIDs
  already present in the cache will not be re-fetched.

## Value

Named list with:

- cache: tibble(dtxsid, casrn, molecular_formula, molecular_weight)

- failed_dtxsids: character vector of DTXSIDs that could not be fetched
