# Resolve one flagged multi-analyte row

Thin wrapper over
[`resolve_review_row()`](https://seanthimons.github.io/concert/reference/resolve_review_row.md)
for name-only resolution. Retained for the headless path and existing
callers.

## Usage

``` r
resolve_multi_analyte_row(
  df,
  name_cols,
  row_index,
  action,
  values = NULL,
  cas_cols = character(0)
)
```

## Arguments

- df:

  Cleaned data frame.

- name_cols:

  Character vector of Name-tagged column names.

- row_index:

  One-based row position in `df`.

- action:

  One of `"split"`, `"keep"`, or `"rename"`.

- values:

  Split parts or rename value. For split, NULL uses
  [`suggest_multi_analyte_parts()`](https://seanthimons.github.io/concert/reference/suggest_multi_analyte_parts.md)
  on the selected Name value.

- cas_cols:

  CASRN-tagged column names. CAS values are left unchanged, but a
  repeated source CAS is recorded and requires component review.

## Value

List with `cleaned_data` and `audit_trail`.
