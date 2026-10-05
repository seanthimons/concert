# Pre-check predicate for harmonize_media step

Counts non-NA, non-empty values across Media-tagged columns. Returns
should_run = TRUE when any media value is present. est_changes reports
total values that will be processed by harmonize_media.

## Usage

``` r
precheck_harmonize_media(df, media_cols, media_map = NULL)
```

## Arguments

- df:

  Dataframe to check.

- media_cols:

  Character vector of Media-tagged column names.

- media_map:

  Optional tibble with column term. When provided and non-empty, used as
  supplementary info only (est_changes always reflects total values).

## Value

list(should_run = logical, est_changes = integer).
