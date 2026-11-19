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

  Integer: number of tagged columns that apply to the row (K).
  [`classify_consensus()`](https://seanthimons.github.io/concert/reference/classify_consensus.md)
  counts only the columns listed in the row's `lookup_evidence_columns`,
  so a row without an extracted CAS does not count that column and its
  tier number is one smaller than before 0.6.14.

## Value

Integer QC tier (1 = best, K+1 = worst)
