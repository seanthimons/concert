# Write Curation Output in a Requested Format

Single dispatch point for writing CONCERT export output. Keeps the
"format -\> writer + what content" decision in one place so the Shiny
app and the headless pipeline cannot drift.

## Usage

``` r
write_curation_output(
  path,
  format = c("xlsx", "csv", "parquet"),
  sheets = NULL,
  toxval_tibble = NULL
)
```

## Arguments

- path:

  Destination file path.

- format:

  One of "xlsx", "csv", or "parquet". "xlsx" writes the full multi-sheet
  workbook and requires `sheets`. "csv"/"parquet" write the flat ToxVal
  table and require `toxval_tibble`.

- sheets:

  Named list of data frames from
  [`build_export_sheets()`](https://seanthimons.github.io/concert/reference/build_export_sheets.md).
  Used only when `format = "xlsx"`.

- toxval_tibble:

  Flat 56-column ToxVal tibble from
  [`map_to_toxval_schema()`](https://seanthimons.github.io/concert/reference/map_to_toxval_schema.md).
  Used only when `format` is "csv" or "parquet".

## Value

The `path`, invisibly.
