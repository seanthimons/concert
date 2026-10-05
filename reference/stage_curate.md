# Stage 3: run the CompTox curation search and optional candidate postprocessing

Stage 3: run the CompTox curation search and optional candidate
postprocessing

## Usage

``` r
stage_curate(
  state,
  wqx_threshold = 0.85,
  starts_with = FALSE,
  postprocess_candidates = FALSE,
  cache_dir = NULL,
  pubchem = FALSE,
  desalt = FALSE,
  desalt_workflows = c("qsar-ready", "ms-ready")
)
```

## Arguments

- state:

  State list from
  [`stage_clean()`](https://seanthimons.github.io/concert/reference/stage_clean.md).

- wqx_threshold:

  Numeric WQX fuzzy matching threshold.

- starts_with:

  Logical. If TRUE, enables CompTox starts-with fallback search for
  names unresolved by exact, CAS, and WQX matching.

- postprocess_candidates:

  Logical. If TRUE, runs the same enrichment, similarity scoring, and
  auto-resolve pass used by the Shiny app after curation. Default FALSE
  for backward compatibility.

- cache_dir:

  Optional directory. When set, the CompTox search result is cached by a
  hash of the cleaned chemical columns and search settings, and the
  candidate enrichment cache persists across runs. Used by
  [`curate_iterate()`](https://seanthimons.github.io/concert/reference/curate_iterate.md)
  so re-runs after review edits skip the API.

- pubchem:

  Logical. If TRUE, searches unresolved names in PubChem and exports
  candidates without assigning DTXSIDs.

- desalt:

  Logical. If TRUE, suggests salt parent candidates without assigning
  parent DTXSIDs, and adds structure-based `parent_dtxsid_`,
  `parent_name_`, `parent_casrn_`, and `parent_status_<workflow>`
  columns for resolved rows via the chemi standardizer. Independent of
  `pubchem`.

- desalt_workflows:

  Standardizer workflows used when `desalt = TRUE`: "qsar-ready",
  "ms-ready", or both (default).

## Value

The state with `resolution_state`, `consensus_summary`,
`enrichment_cache`, `enrichment_failed`, and `script_baseline_state`
added.
