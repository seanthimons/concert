# Generate a CONCERT replay script

Generate a CONCERT replay script

## Usage

``` r
generate_concert_script(
  input_path,
  output_path,
  tag_map,
  header_row,
  review_overrides = NULL,
  wqx_threshold = 0.85,
  starts_with = FALSE,
  harmonize = FALSE,
  media = NULL,
  unit_map = NULL,
  corrections = NULL,
  media_map = NULL,
  format = "parquet",
  source_name = NULL,
  reference_lists = NULL,
  activate_all_references = FALSE,
  site_manifest = NULL,
  site_alias_map = NULL,
  value_corrections = NULL,
  cleaning_steps = NULL,
  multi_analyte_resolutions = NULL,
  accept_suggestions = FALSE,
  review_picks = NULL,
  row_flags = NULL,
  pubchem = FALSE,
  desalt = FALSE,
  desalt_workflows = c("qsar-ready", "ms-ready")
)
```

## Arguments

- input_path:

  Character input file path shown at the top of the script.

- output_path:

  Character output XLSX path shown at the top of the script.

- tag_map:

  Named list of chemical, numeric, metadata, and study tags.

- header_row:

  Detected header row to pin for replay.

- review_overrides:

  Optional content-match override spec from
  [`build_review_overrides()`](https://seanthimons.github.io/concert/reference/build_review_overrides.md)
  to embed as generated per-column
  [`dplyr::rows_update()`](https://dplyr.tidyverse.org/reference/rows.html)
  override tables.

- wqx_threshold:

  WQX fuzzy match threshold.

- starts_with:

  Logical. Enables CompTox starts-with fallback search.

- harmonize:

  Logical. Re-run harmonization during replay.

- media:

  Optional dataset-wide media fallback.

- unit_map:

  Optional effective unit harmonization map. When `harmonize = TRUE` it
  is snapshotted against package defaults so only user deltas (plus a
  baseline hash) are embedded.

- corrections:

  Optional effective numeric corrections table to embed when
  `harmonize = TRUE`.

- media_map:

  Optional effective media harmonization map. When `harmonize = TRUE` it
  is snapshotted against package defaults so only user deltas (plus a
  baseline hash) are embedded.

- format:

  ToxVal output format for harmonized headless runs.

- source_name:

  Optional source name for ToxVal mapping.

- reference_lists:

  Optional current cleaning reference lists to snapshot for portable
  replay.

- activate_all_references:

  Logical. Replays the preflight setting that activates all cleaning
  reference-list rows for the run.

- site_manifest:

  Optional curated Dataset Context site manifest to embed in the replay
  script.

- site_alias_map:

  Optional Dataset Context raw-label alias map to embed in the replay
  script.

- value_corrections:

  Optional pre-cleaning value correction table to embed. See
  [`apply_value_corrections()`](https://seanthimons.github.io/concert/reference/apply_value_corrections.md).

- cleaning_steps:

  Optional named list of cleaning step switches to embed.

- multi_analyte_resolutions:

  Optional multi-analyte resolution table to embed.

- accept_suggestions:

  Logical. Embed the bulk-accept switch.

- review_picks:

  Optional content-keyed DTXSID picks table to embed.

- row_flags:

  Optional content-keyed row flag table to embed.

- pubchem:

  Logical. Enables PubChem candidate lookup for unresolved names.

- desalt:

  Logical. Enables salt parent suggestions independently of PubChem.

- desalt_workflows:

  Standardizer workflows used when `desalt = TRUE`: "qsar-ready",
  "ms-ready", or both (default).

## Value

Complete R script as a character scalar.
