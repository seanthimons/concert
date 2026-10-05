# Initialize resolution state on a classified data frame

Adds .pinned column (FALSE), .manual_entry column (FALSE), public
row_flag column (NA_character\_), and row_flag_reason column
(NA_character\_) if not already present. Also adds .resolution_method
and .resolution_reason columns (NA_character\_) for tracking how each
row was resolved (per D-11).

## Usage

``` r
init_resolution_state(df)
```

## Arguments

- df:

  Data frame (typically output of classify_consensus)

## Value

df with .pinned, .manual_entry, row_flag, row_flag_reason,
.resolution_method, and .resolution_reason columns

## Details

Valid .resolution_method values: "auto", "suggested-accept",
"bulk-accept", "manual", NA.
