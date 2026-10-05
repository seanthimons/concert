# Refresh isotope lookup cache

Rebuilds `isotope_lookup.rds` from the active
[`ComptoxR::pt`](https://seanthimons.github.io/ComptoxR/reference/pt.html)
isotope table, augments missing radiochemical isotope shortcodes from
WQX canonical rows, and resolves WQX CASRNs through the existing CAS/CCD
resolver when requested.

## Usage

``` r
refresh_isotope_cache(
  cache_dir = NULL,
  wqx_dictionary = NULL,
  resolve_wqx_cas = TRUE
)
```

## Arguments

- cache_dir:

  Directory for reference cache. Defaults to installed package path.

- wqx_dictionary:

  Optional WQX dictionary tibble. When `NULL`, the cached WQX dictionary
  is loaded or refreshed through
  [`load_wqx_dictionary()`](https://seanthimons.github.io/concert/reference/load_wqx_dictionary.md).

- resolve_wqx_cas:

  Logical. If `TRUE`, WQX CASRNs are resolved to DTXSIDs during the
  explicit refresh.

## Value

Invisibly returns the rebuilt isotope lookup list
