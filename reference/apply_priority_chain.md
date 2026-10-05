# Apply en masse column priority to resolve all non-pinned disagree rows

Apply en masse column priority to resolve all non-pinned disagree rows

## Usage

``` r
apply_priority_chain(df, priority_order, dtxsid_cols)
```

## Arguments

- df:

  Classified data frame

- priority_order:

  Character vector of dtxsid column names ranked by preference

- dtxsid_cols:

  Character vector of all DTXSID column names

## Value

Modified df with consensus filled for resolved rows
