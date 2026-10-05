# Extract Site Candidates

Builds a first-seen, distinct raw-label list from detected site/location
columns. User order fields are left blank by default; source row order
remains available as the deterministic fallback order.

## Usage

``` r
extract_site_candidates(df, detection = NULL)
```

## Arguments

- df:

  Data frame after file detection/extraction.

- detection:

  Optional result from
  [`detect_site_columns()`](https://seanthimons.github.io/concert/reference/detect_site_columns.md).

## Value

A site manifest candidate tibble.
