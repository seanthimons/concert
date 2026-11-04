# List bulk-accepted pins that current identity holds would refuse

The holds in
[`classify_auto_resolve()`](https://seanthimons.github.io/concert/reference/classify_auto_resolve.md)
and the bulk-accept blockers apply only to new classification; rows
pinned by
[`accept_all_suggestions()`](https://seanthimons.github.io/concert/reference/accept_all_suggestions.md)
replay from saved sessions unchanged. This re-runs those holds over the
existing `"bulk-accept"` rows and lists the ones that would now be held,
so they can be re-reviewed (#128). It does not modify `df`.

## Usage

``` r
audit_bulk_accepted(df, dtxsid_cols, column_tags)
```

## Arguments

- df:

  Resolution state with `.resolution_method`, `consensus_dtxsid`,
  `.suggested_column`, and `dtxsid_*`/`preferredName_*` columns.

- dtxsid_cols:

  Character vector of DTXSID column names.

- column_tags:

  Named list (col_name -\> "Name"\|"CASRN"\|"Other"); the first
  Name-tagged column supplies the input name.

## Value

Tibble of rows that would now be held, with `row_id`, `input_name`,
`consensus_dtxsid`, `accepted_name`, `token_similarity`, and `reason`.
Zero rows when nothing needs re-review. `row_id` is the position in
`df`.

## Details

A row is listed when any of these holds:

- WQX name evidence conflicts with the DTXSID candidates;

- the accepted candidate's preferred name has token Jaccard similarity
  below 0.5 with the input name, or either name is missing (see
  [`name_token_similarity()`](https://seanthimons.github.io/concert/reference/name_token_similarity.md));

- a current bulk blocker applies (identity scope, identity conflict,
  stale scope review, or a BAD/FOLLOW-UP row flag).
