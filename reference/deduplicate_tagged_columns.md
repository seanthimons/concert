# Deduplicate tagged column values before API calls

Deduplicate tagged column values before API calls

## Usage

``` r
deduplicate_tagged_columns(df, tag_map, skip_flags = NULL, skip_rows = NULL)
```

## Arguments

- df:

  Data frame with chemical data

- tag_map:

  Named list mapping column names to tag types ("Name", "CASRN", or
  "Other")

- skip_flags:

  Optional character vector of cleaning_flag values. Rows whose
  cleaning_flag contains any of these values are excluded from the
  search pool (their dedup_key_map entries are kept but marked as
  skipped).

- skip_rows:

  Optional integer vector of explicit row indices to exclude from the
  search pool. When supplied, this takes precedence over skip_flags.

## Value

List with unique_names, unique_cas, dedup_key_map, and skipped_rows
(integer vector)
