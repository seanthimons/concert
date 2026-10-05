# Classify consensus across tagged columns for each row

NOTE: This function returns status values "agree", "agree_caveat",
"single", "wqx", "disagree", and "error". Downstream code (manual
validation flow, retry merge) may add additional status values: "manual"
(manually-entered DTXSID) and "unresolvable" (error persisting after
retry).

## Usage

``` r
classify_consensus(df, dtxsid_cols)
```

## Arguments

- df:

  Data frame with DTXSID columns from map_results_to_rows()

- dtxsid_cols:

  Character vector of DTXSID column names to compare

## Value

Original df with added columns: consensus_status, consensus_dtxsid,
consensus_source, qc_tier
