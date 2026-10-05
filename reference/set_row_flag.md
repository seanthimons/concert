# Set one row flag

Set one row flag

## Usage

``` r
set_row_flag(df, row_idx, flag, reason = NULL)
```

## Arguments

- df:

  Resolution state data frame.

- row_idx:

  Integer row index to update.

- flag:

  Flag value, or NULL/NA/""/"CLEAR" to unset.

- reason:

  Optional reviewer reason for BAD/FOLLOW-UP/follow-up flags.

## Value

Updated resolution state.
