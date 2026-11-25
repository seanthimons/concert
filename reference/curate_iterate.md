# Run one iteration of the agent curation loop

Sources `decisions.R`, runs the staged headless pipeline with a curation
cache, and writes `status.md`, `pending.csv`, and `replay.R` next to it.
`replay.R` is one self-contained file: its decision tables are CSV text
blocks, one decision per line, with multi-analyte resolutions recorded
by name and CASRN. When no rows are pending it also writes the curated
workbook (and ToxVal files when `harmonize` is set). Re-run after
editing `decisions.R` until `status.md` reports `done: TRUE`.

## Usage

``` r
curate_iterate(
  decisions_path,
  out_dir = dirname(decisions_path),
  verbose = TRUE
)
```

## Arguments

- decisions_path:

  Path to a decisions file. Create one with
  [`curate_decisions_template()`](https://seanthimons.github.io/concert/reference/curate_decisions_template.md).

- out_dir:

  Output directory. Defaults to the decisions file directory.

- verbose:

  Logical. Print pipeline messages.

## Value

Invisibly, a list with `done`, `pending`, `identity_drift` and `state`.
`identity_drift` lists identity decisions that were skipped because
their recorded evidence fingerprint no longer matches the row; each is
also an `identity_drift` row in `pending.csv`. It is `NULL` when there
are no identity decisions.
