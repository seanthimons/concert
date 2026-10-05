# Resolve one flagged review row (multi-analyte and/or multi-CAS)

Single coordinated engine behind
[`resolve_multi_analyte_row()`](https://seanthimons.github.io/concert/reference/resolve_multi_analyte_row.md).
Splits the selected Name value and, when `pairing = "position"`, assigns
CAS values from `spec$cas_parts` across the resulting rows so a row
flagged for both reasons cannot be split twice into garbage.

## Usage

``` r
resolve_review_row(df, name_cols, row_index, spec, cas_cols = character(0))
```

## Arguments

- df:

  Cleaned data frame.

- name_cols:

  Character vector of Name-tagged column names.

- row_index:

  One-based row position in `df`.

- spec:

  List describing the disposition:

  - `name_action`: `"split"`, `"keep"`, or `"rename"`.

  - `name_parts`: split parts or rename value (character or newline/`;`
    text). For split, `NULL`/empty falls back to
    [`suggest_multi_analyte_parts()`](https://seanthimons.github.io/concert/reference/suggest_multi_analyte_parts.md).

  - `cas_parts`: CAS values to assign (character or newline/`;` text).
    Ignored unless `pairing = "position"`.

  - `pairing`: `"position"` pairs name/CAS parts one-to-one (counts must
    match, or one side has length 1); `"broadcast"` (default) leaves CAS
    columns intact.

- cas_cols:

  Character vector of CASRN-tagged column names.

## Value

List with `cleaned_data` and `audit_trail`.
