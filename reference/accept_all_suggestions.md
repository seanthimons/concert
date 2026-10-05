# Accept all suggested resolutions in bulk

For each row with consensus_status == "suggested" that is not pinned,
resolves to the best-scoring candidate (stored in .suggested_column).
Sets .resolution_method to "bulk-accept" and .pinned to TRUE.

## Usage

``` r
accept_all_suggestions(df, dtxsid_cols)
```

## Arguments

- df:

  Data frame with consensus_status, .suggested_column, dtxsid\_\*
  columns

- dtxsid_cols:

  Character vector of DTXSID column names

## Value

Modified df with suggested rows resolved
