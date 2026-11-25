# Re-confirm identity decisions whose evidence changed

For the decisions the last
[`curate_iterate()`](https://seanthimons.github.io/concert/reference/curate_iterate.md)
run reported as `identity_drift`, appends a ledger line that keeps the
decision and takes the current evidence fingerprint and snapshot. Use it
only after reviewing each row against its current evidence. Stops,
writing nothing, when the number of drifted decisions is not `expected`
or a named row has not drifted.

## Usage

``` r
reconfirm_identity_decisions(
  decisions_path,
  note,
  expected,
  recorded_by,
  rows = NULL,
  out_dir = dirname(decisions_path)
)
```

## Arguments

- decisions_path:

  Path to `decisions.R`.

- note:

  Why the decisions still hold on the changed evidence.

- expected:

  Number of decisions the caller means to re-confirm.

- recorded_by:

  Who made the decision, for example `"owner"`.

- rows:

  Optional `row_index` values to restrict to. Default: every drifted
  decision.

- out_dir:

  Output directory of the run. Defaults to the decisions file directory.

## Value

Invisibly, the ledger path.
