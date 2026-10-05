# Run one iteration of the agent curation loop

Sources `decisions.R`, runs the staged headless pipeline with a curation
cache, and writes `status.md`, `pending.csv`, and `replay.R` next to it.
When no rows are pending it also writes the curated workbook (and ToxVal
files when `harmonize` is set). Re-run after editing `decisions.R` until
`status.md` reports `done: TRUE`.

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

Invisibly, a list with `done`, `pending`, and `state`.
