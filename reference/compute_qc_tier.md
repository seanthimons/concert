# Compute numeric QC tier for a consensus classification

Compute numeric QC tier for a consensus classification

## Usage

``` r
compute_qc_tier(status, n_matched, n_total)
```

## Arguments

- status:

  Character: "agree", "agree_caveat", "disagree", "single", "error"

- n_matched:

  Integer: number of columns that matched (had same DTXSID)

- n_total:

  Integer: total number of tagged columns (K)

## Value

Integer QC tier (1 = best, K+1 = worst)
