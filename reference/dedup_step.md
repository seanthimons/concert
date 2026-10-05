# Deduplication wrapper for cleaning step functions

Runs a cleaning step function on only the distinct values of the target
columns, then remaps the results back to the full parent dataframe. This
provides a significant speedup when the dataset has many repeated values
(e.g., the same chemical name appearing in thousands of rows).

## Usage

``` r
dedup_step(step_fn, df, ..., dedup_cols, uniqueness_threshold = 0.5)
```

## Arguments

- step_fn:

  Step function to call. Must return `list(cleaned_data, audit_trail)`.

- df:

  Full parent dataframe to process.

- ...:

  Additional arguments passed to `step_fn` (e.g., `tag_map`).

- dedup_cols:

  Character vector of column names to dedup on. The composite key is
  constructed by pasting these column values together.

- uniqueness_threshold:

  Numeric in `[0, 1]`. If n_distinct/n_total exceeds this value, skip
  dedup and call the step directly. Default: 0.5.

## Value

List with `cleaned_data` (same row count as `df`) and `audit_trail` (row
IDs valid for `df`). Identical shape to calling `step_fn(df, ...)`
directly.

## Details

If the uniqueness ratio (n_distinct / n_total) exceeds
`uniqueness_threshold`, deduplication is bypassed and the step function
is called directly on the full dataframe (D-03). This avoids overhead in
datasets that are already highly unique. Audit row IDs retain
`original_row_id` when present, including gaps left by removed rows and
repeated IDs from synonym expansion.
