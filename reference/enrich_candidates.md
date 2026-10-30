# Fetch CompTox chemical details for DTXSIDs and return structured cache

Calls CompTox chemical detail search to retrieve CASRN, molecular
formula, and molecular weight for each unique DTXSID. Supports
incremental caching: pass existing_cache to skip already-fetched
DTXSIDs. Uses the `chemicaldetailstandard` server-side projection by
default to avoid the 73-column `chemicaldetailall` response while
retaining `isMarkush` for review metadata.

## Usage

``` r
enrich_candidates(dtxsids, existing_cache = NULL, projection = "chemicaldetailstandard")
```

## Arguments

- dtxsids:

  Character vector of DTXSIDs to enrich

- existing_cache:

  Optional tibble from a previous enrich_candidates() call. DTXSIDs
  already present in the cache will not be re-fetched.

- projection:

  CompTox server-side projection to request. Defaults to
  `chemicaldetailstandard`, the narrowest tested projection that
  includes identifiers, preferred name, formula, mass, and `isMarkush`.

## Value

Named list with:

- cache: normalized chemical details including `isMarkush`

- failed_dtxsids: character vector of DTXSIDs that could not be fetched
