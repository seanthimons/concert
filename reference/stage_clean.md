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

  Optional data frame/list with `row_index` (or `row`), `action`, and
  optional `value`/`values` columns. `row_index` is the
  `original_row_id` as written to `pending.csv`, so it stays valid after
  synonym or multi-analyte splits. Applied after cleaning and before
  curation.

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
