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
  verbose = TRUE,
  output_path = NULL,
  check_lock = FALSE
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

- output_path:

  Workbook path for this run. Overrides `output_path` in `decisions.R`,
  so a trial run in another `out_dir` needs no edited copy of the
  decisions file.

- check_lock:

  Logical. When `TRUE`, run nothing: compare the files and versions the
  last run in `out_dir` recorded in `run_lock.json` with the current
  ones and return what changed.

## Value

Invisibly, a list with `done`, `pending`, `identity_drift` and `state`.
`identity_drift` lists identity decisions that were skipped because
their recorded evidence fingerprint no longer matches the row; each is
also an `identity_drift` row in `pending.csv`. It is `NULL` when there
are no identity decisions. With `check_lock = TRUE`, a list with
`current` (nothing changed since the lock), `done` (that run was done)
and `changed` (what differs).

## Run lock

A run that finishes writes `run_lock.json` in `out_dir`: the concert,
ComptoxR and local DSSTox versions, and a SHA-256 of `decisions.R`, the
input file, the identity ledger and every existing file `decisions.R`
names as a string. A failed run leaves no lock. The lock does not cover
files whose paths `decisions.R` builds at run time, files read by a file
it sources, or web lookups cached in `out_dir/cache`.

## Mapping

When the run is done it writes `mapping.csv`: one line per curated row
with the source columns, then `dtxsid`, `wqx_name`, `preferred_name`,
`identity_status`, `decided_by` (`automatic`, `pick`,
`accepted_suggestion`, `identity_decision` or `flag`), `row_flag` and
`identity_blockers`.
