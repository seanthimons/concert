# Stage 6: write outputs and build the result list

Stage 6: write outputs and build the result list

## Usage

``` r
stage_export(state, output_path = NULL, format = "parquet", write_files = TRUE)
```

## Arguments

- state:

  State list from
  [`stage_harmonize()`](https://seanthimons.github.io/concert/reference/stage_harmonize.md).

- output_path:

  Character. Path for the output XLSX file. Parent directories are
  created automatically if they do not exist. Required when
  `write_files = TRUE`; ignored when `write_files = FALSE`.

- format:

  Character. Output format for ToxVal data when harmonize=TRUE. One of
  "parquet", "csv", or "both". Default "parquet". Ignored when
  harmonize=FALSE.

- write_files:

  Logical. If TRUE (default), writes XLSX and optional parquet/CSV
  outputs. If FALSE, runs fully in memory and returns the same list
  without requiring or creating output files.

## Value

The list documented under the
[`curate_headless()`](https://seanthimons.github.io/concert/reference/curate_headless.md)
return value.
