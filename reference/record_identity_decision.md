# Record identity decisions in the ledger

Appends one line per decision to the JSON Lines ledger that
`decisions.R` names
(`identity_decisions <- "identity_decisions.jsonl"`). Each decision is
fingerprinted against the last
[`curate_iterate()`](https://seanthimons.github.io/concert/reference/curate_iterate.md)
run, checked with
[`apply_identity_decisions()`](https://seanthimons.github.io/concert/reference/apply_identity_decisions.md),
and written with a snapshot of the evidence it was made on. Nothing is
written unless every decision passes. Run
[`curate_iterate()`](https://seanthimons.github.io/concert/reference/curate_iterate.md)
again to apply them.

## Usage

``` r
record_identity_decision(
  decisions_path,
  decisions,
  recorded_by,
  out_dir = dirname(decisions_path)
)
```

## Arguments

- decisions_path:

  Path to `decisions.R`.

- decisions:

  Data frame, one decision per row. `row_index` is the row as shown in
  `pending.csv`; add `name` to pick one part of a split row. `action` is
  `accept`, `retain_unresolved` or `withdraw`. `scope`, `conflict`,
  `reason` and `evidence_reference` are as in
  [`apply_identity_decisions()`](https://seanthimons.github.io/concert/reference/apply_identity_decisions.md);
  `accept` also needs `selected_dtxsid` and `correspondence = TRUE`.
  `withdraw` needs only `row_index` and `reason`. A batch of only
  withdrawals needs no completed run, so it can remove a decision that
  stops
  [`curate_iterate()`](https://seanthimons.github.io/concert/reference/curate_iterate.md).

- recorded_by:

  Who made the decision, for example `"owner"`.

- out_dir:

  Output directory of the run. Defaults to the decisions file directory.

## Value

Invisibly, the ledger path.

## Details

The ledger is append-only. The latest line for a source row wins, so
record a row again to change its decision, or with `action = "withdraw"`
to remove it.
