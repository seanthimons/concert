# Resolve a single disagreement row by choosing a preferred column

Resolve a single disagreement row by choosing a preferred column

## Usage

``` r
resolve_row(df, row_idx, chosen_column, dtxsid_cols)
```

## Arguments

- df:

  Classified data frame

- row_idx:

  Integer row index

- chosen_column:

  Character: name of the dtxsid column to use

- dtxsid_cols:

  Character vector of DTXSID column names

## Value

Modified df with consensus filled and row pinned
