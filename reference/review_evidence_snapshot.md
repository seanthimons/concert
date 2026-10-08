# Construct evidence for an explicit review

Construct evidence for an explicit review

## Usage

``` r
review_evidence_snapshot(
  automated,
  final = automated,
  row_indices = seq_len(nrow(automated)),
  validation = NULL,
  source_id_cols = "source_dtxsid",
  scope_cols = character()
)
```

## Arguments

- automated:

  Pre-review lookup state.

- final:

  Final reviewed state, separately retained from automated evidence.

- row_indices:

  Explicit reviewed rows.

- validation:

  Structured validation data with dtxsid/outcome and optional
  authority/version/reason.

- source_id_cols:

  Source DTXSID metadata column names, never promoted to consensus.

- scope_cols:

  Source/content columns binding evidence to each source row.

## Value

Versioned snapshot for capture_review_decision().
