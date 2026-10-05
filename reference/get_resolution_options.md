# Get available resolution options for a disagree row

Returns rich metadata for each option including DTXSID, preferredName,
and rank. Options are sorted by rank (best match first, lowest rank
number).

## Usage

``` r
get_resolution_options(df, row_idx, dtxsid_cols, enrichment_cache = NULL)
```

## Arguments

- df:

  Classified data frame

- row_idx:

  Integer row index

- dtxsid_cols:

  Character vector of DTXSID column names

- enrichment_cache:

  Optional enrichment cache with CASRN, molecular formula, and molecular
  weight columns for DTXSID options.

## Value

Named list of column_name = list(dtxsid, preferredName, rank) for
columns with data. Sorted by rank (best first). Empty list if row is not
"disagree".
