# Construct a pre-check skip result for a cleaning pipeline step

Construct a pre-check skip result for a cleaning pipeline step

## Usage

``` r
build_skip_result(df, step_name)
```

## Arguments

- df:

  Dataframe to pass through unchanged.

- step_name:

  Character. The step being skipped (for message).

## Value

list with cleaned_data passthrough and empty typed audit trail.
