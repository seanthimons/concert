# Stage 2: run the cleaning pipeline

Stage 2: run the cleaning pipeline

## Usage

``` r
stage_clean(
  state,
  multi_analyte_resolutions = NULL,
  value_corrections = NULL,
  cleaning_steps = NULL
)
```

## Arguments

- state:

  State list from
  [`stage_ingest()`](https://seanthimons.github.io/concert/reference/stage_ingest.md).

- multi_analyte_resolutions:

  Optional data frame/list with `name`, optional `casrn`, `action`, and
  optional `value` and `note` columns. Every row whose cleaned Name and
  CAS match is resolved; a blank `casrn` matches rows with a blank CAS
  only. `row_index` (the `original_row_id` written to `pending.csv`) is
  still accepted in place of `name`, but depends on input row order.
  Applied after cleaning and before curation. See
  [`apply_multi_analyte_resolutions()`](https://seanthimons.github.io/concert/reference/apply_multi_analyte_resolutions.md).

- value_corrections:

  Optional data frame with `column`, `pattern`, `replacement`, and
  optional `match_mode` columns. Applied to the detected data before
  cleaning, so before Unicode folding: match Unicode hyphens with
  `\\p{Pd}`, not `-`. See
  [`apply_value_corrections()`](https://seanthimons.github.io/concert/reference/apply_value_corrections.md).

- cleaning_steps:

  Optional named list of logicals switching cleaning steps on or off:
  `unicode`, `whitespace`, `cas`, `names`, `synonyms`, `isotopes`,
  `multi`, `chiral`, `truncated`, `bare_formula`, `reference_flags`.
  Omitted names keep their defaults.

## Value

The state with `cleaning_result`, `merged_tags`, and
`merged_chemical_tags` added.
