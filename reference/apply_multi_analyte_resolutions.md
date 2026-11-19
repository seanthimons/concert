# Apply multiple multi-analyte resolutions

Apply multiple multi-analyte resolutions

## Usage

``` r
apply_multi_analyte_resolutions(
  df,
  name_cols,
  resolutions = NULL,
  cas_cols = character(0)
)
```

## Arguments

- df:

  Cleaned data frame.

- name_cols:

  Character vector of Name-tagged column names.

- resolutions:

  Data frame/list with `action`, optional `value` or `values`, optional
  `note`, and one of two row keys:

  - `name` and optional `casrn`: every row whose first Name column
    equals `name` and whose first CASRN column equals `casrn`. A blank
    `casrn` matches rows with a blank CAS only. This key survives rows
    moving in the input.

  - `row_index` (or `row`): when `df` has an `original_row_id` column
    the key is matched against it (as written by `pending.csv`);
    otherwise it is a 1-based row position. It takes precedence, with a
    warning, when `name` is also present.

  `value` holds the rename value, or split parts separated by `;`. A
  `note` is appended to the audit trail reason. An optional `cas_value`
  holds CAS numbers separated by `;` to assign to the resulting rows by
  position (one per part, or one for all parts); without it CAS values
  are left unchanged.

- cas_cols:

  CASRN-tagged column names. CAS values are left unchanged, but a
  repeated source CAS is recorded and requires component review.

## Value

List with `cleaned_data` and `audit_trail`.
