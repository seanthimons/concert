# Refresh ToxVal identifiers from the current resolution state

The app harmonizes before curation, and review edits change DTXSIDs
after harmonization, so a stored ToxVal tibble can carry stale
identifiers. Re-derives `dtxsid` and `name` from `resolution_state` via
map_to_toxval_schema() and rehashes the rows.

## Usage

``` r
refresh_toxval_identity(toxval_output, resolution_state, harmonized_data)
```

## Arguments

- toxval_output:

  Stored ToxVal tibble from the harmonization run.

- resolution_state:

  Current curated data (same rows as harmonization input).

- harmonized_data:

  Harmonized tibble the ToxVal rows were built from.

## Value

`toxval_output` with refreshed identifiers, or unchanged when the inputs
do not line up.
