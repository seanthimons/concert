# Apply staged review decisions in one batch

Applies a set of
[`resolve_review_row()`](https://seanthimons.github.io/concert/reference/resolve_review_row.md)
specs keyed by row index. Decisions are applied in descending row-index
order so each positional split leaves the earlier rows' positions
intact.

## Usage

``` r
apply_review_resolutions(df, name_cols, decisions, cas_cols = character(0))
```

## Arguments

- df:

  Cleaned data frame.

- name_cols:

  Character vector of Name-tagged column names.

- decisions:

  Named list keyed by row index; each element is a `spec` list accepted
  by
  [`resolve_review_row()`](https://seanthimons.github.io/concert/reference/resolve_review_row.md).

- cas_cols:

  Character vector of CASRN-tagged column names.

## Value

List with `cleaned_data` and `audit_trail`.
