# Identify isotope rows that are already pre-resolved to DTXSID

Isotope normalization can canonicalize WQX radiochemical names without a
CompTox DTXSID. Only rows that actually have an isotope DTXSID should
skip the normal curation search pool; unresolved isotope matches must
continue to WQX matching.

## Usage

``` r
get_pre_resolved_isotope_rows(clean_data)
```

## Arguments

- clean_data:

  Cleaned data frame containing cleaning_flag and isotope_dtxsid

## Value

Integer row indices for pre-resolved isotope rows
