# Map lookup results back to all original rows

Map lookup results back to all original rows

## Usage

``` r
map_results_to_rows(df, dedup_key_map, lookup_results, pre_resolved = NULL)
```

## Arguments

- df:

  Original data frame

- dedup_key_map:

  Dedup key map from deduplicate_tagged_columns

- lookup_results:

  Lookup results from run_tiered_search

- pre_resolved:

  Optional tibble with columns (row_idx, dtxsid, preferredName,
  source_tier) for rows that were resolved without API search (e.g.
  isotope_match). These are injected directly into the result vectors,
  overriding any API results for those row indices.

## Value

Original df with lookup columns joined back
