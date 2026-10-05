# Set row flags in bulk

Set row flags in bulk

## Usage

``` r
set_row_flags(df, row_indices, flag, reason = NULL)
```

## Arguments

- df:

  Resolution state data frame.

- row_indices:

  Integer row indices to update.

- flag:

  Flag value, or NULL/NA/""/"CLEAR" to unset.

- reason:

  Optional reviewer reason to apply to all updated rows.

## Value

Updated resolution state.
