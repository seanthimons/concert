# Compute similarity scores for all disagree rows in resolution_state

For each disagree row, scores each candidate DTXSID by comparing the
user's original Name-tagged column value against the candidate's
preferredName and all cached synonyms. Returns the best (max) candidate
score per row. Non-disagree rows get NA_real\_.

## Usage

``` r
compute_similarity_scores(
  resolution_state,
  enrichment_cache,
  dtxsid_cols,
  column_tags
)
```

## Arguments

- resolution_state:

  Data frame with consensus_status, dtxsid\_*, preferredName\_*,
  rank\_\* columns

- enrichment_cache:

  Tibble with dtxsid and (optionally) synonyms columns

- dtxsid_cols:

  Character vector of dtxsid column names (e.g., c("dtxsid_Chemical",
  "dtxsid_CAS"))

- column_tags:

  Named list (col_name -\> "Name"\|"CASRN"\|"Other") – used to find
  input name column

## Value

resolution_state with similarity_score column added
