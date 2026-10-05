# Fetch and cache CompTox synonym data for a set of DTXSIDs

Extends the enrichment cache with a `synonyms` column containing
pipe-joined synonym strings from all CompTox synonym tiers. Follows the
same incremental caching pattern as
[`enrich_candidates()`](https://seanthimons.github.io/concert/reference/enrich_candidates.md):
only fetches DTXSIDs not already present in the cache with a `synonyms`
column.

## Usage

``` r
enrich_synonyms(dtxsids, existing_cache = NULL)
```

## Arguments

- dtxsids:

  Character vector of DTXSIDs to enrich with synonyms

- existing_cache:

  Optional tibble from a previous enrichment call. If it already has a
  `synonyms` column, DTXSIDs already cached will not be re-fetched. If
  the `synonyms` column is absent, all DTXSIDs are treated as needing
  fetch.

## Value

Named list with:

- cache: tibble with all original columns plus a `synonyms` column
  (pipe-joined string per DTXSID; NA_character\_ if API returned no
  synonyms)

- failed_dtxsids: character vector of DTXSIDs that could not be fetched
