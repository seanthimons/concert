# Report candidate validation work without changing identity or flags

Missing historical evidence is informational. Only changed evidence from
a captured no-hit, rejected, or deferred decision opens candidate
validation. Unchanged dispositions and repeated unavailable checks do
not reopen work.

## Usage

``` r
build_candidate_review(
  automated,
  final = automated,
  row_flags = NULL,
  evidence = NULL,
  name_col,
  cas_col = NA_character_,
  scope_data = automated,
  scope_cols = c(name_col, cas_col),
  validation = NULL,
  source_id_cols = "source_dtxsid"
)
```

## Arguments

- automated:

  Pre-review lookup data.

- final:

  Final reviewed data with preserved flags and identities.

- row_flags:

  Optional content-keyed reviewer decisions.

- evidence:

  Portable review_decision_evidence object.

- name_col, cas_col:

  Source name and optional CAS column names.

- scope_data:

  Immutable source/content data, aligned with automated rows.

- scope_cols:

  Source/content and lineage columns defining review scope.

- validation:

  Optional structured candidate validation outcomes.

- source_id_cols:

  Source ID metadata columns, never consensus votes.

## Value

Stable data frame; actionable rows require candidate validation, never
acceptance.
