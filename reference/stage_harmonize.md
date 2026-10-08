# Stage 5: run numeric, unit, media, and ToxVal harmonization

Stage 5: run numeric, unit, media, and ToxVal harmonization

## Usage

``` r
stage_harmonize(
  state,
  harmonize = FALSE,
  unit_map = NULL,
  unit_map_snapshot = NULL,
  corrections = NULL,
  media_map = NULL,
  media_map_snapshot = NULL,
  media = NULL,
  source_name = NULL,
  toxval_identity_mode = c("lookup", "accepted")
)
```

## Arguments

- state:

  State list from
  [`stage_review()`](https://seanthimons.github.io/concert/reference/stage_review.md).

- harmonize:

  Logical. If TRUE, runs numeric parsing, unit harmonization, and ToxVal
  schema mapping after curation. Default FALSE for backward compat.

- unit_map:

  Tibble with unit conversion mappings, or NULL (default) to load from
  package cache via load_unit_map().

- unit_map_snapshot:

  Optional compact replay snapshot from
  [`generate_concert_script()`](https://seanthimons.github.io/concert/reference/generate_concert_script.md);
  reconstructs the effective unit map from package defaults plus
  embedded deltas. Mutually exclusive with `unit_map`.

- corrections:

  Tibble with pattern/replacement columns for one-off corrections, or
  NULL (default) to load from package cache.

- media_map:

  Optional media harmonization map passed to
  [`harmonize_media()`](https://seanthimons.github.io/concert/reference/harmonize_media.md).

- media_map_snapshot:

  Optional compact replay snapshot from
  [`generate_concert_script()`](https://seanthimons.github.io/concert/reference/generate_concert_script.md);
  reconstructs the effective media map from package defaults plus
  embedded deltas. Mutually exclusive with `media_map`.

- media:

  Character. Media context for ppb/ppm routing: "aqueous", "air", or
  "solid". NULL (default) uses aqueous assumption.

- source_name:

  Optional dataset identifier for ToxVal `source`. Defaults to the input
  filename stem.

- toxval_identity_mode:

  ToxVal identifier policy: "lookup" preserves the existing audit export
  default; "accepted" gates IDs and preserves every measurement row with
  NA IDs when blocked.

## Value

The state with `harmonize`, `harmonization_refs`,
`harmonization_runtime_result`, `toxval_output`, `harmonize_audit`, and
`detection_results` added. When `harmonize = FALSE`, the harmonization
flag and identity policy are retained.
