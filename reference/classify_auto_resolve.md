# Classify disagree rows as auto-resolved, suggested, or leave as disagree

Runs after compute_similarity_scores(). For each disagree row, collects
per-candidate scores and applies threshold logic (D-01/D-02/D-03):

- Auto-resolve: best score \>= 0.95 AND gap \>= 0.15

- Suggest: best score \>= 0.70 (but not auto-resolve eligible)

- Leave as disagree: best score \< 0.70

## Usage

``` r
classify_auto_resolve(
  resolution_state,
  enrichment_cache,
  dtxsid_cols,
  column_tags,
  auto_threshold = 0.95,
  gap_threshold = 0.15,
  suggest_threshold = 0.7
)
```

## Arguments

- resolution_state:

  Data frame with consensus_status, similarity_score, dtxsid\_*,
  preferredName\_*, rank\_\* columns

- enrichment_cache:

  Tibble with dtxsid and (optionally) synonyms columns

- dtxsid_cols:

  Character vector of dtxsid column names

- column_tags:

  Named list (col_name -\> "Name"\|"CASRN"\|"Other")

- auto_threshold:

  Numeric, minimum score for auto-resolve (default 0.95, per D-01)

- gap_threshold:

  Numeric, minimum gap between best and second-best (default 0.15, per
  D-03)

- suggest_threshold:

  Numeric, minimum score for suggestion (default 0.70, per D-02)

## Value

resolution_state with updated consensus_status, .pinned,
.resolution_method, .resolution_reason, and .suggested_column columns
