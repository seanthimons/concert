# Add structure-based parent DTXSIDs for resolved rows

Standardizes each `consensus_dtxsid` structure with the chemi
standardizer and writes `parent_dtxsid_<workflow>`,
`parent_name_<workflow>`, `parent_casrn_<workflow>`, and
`parent_status_<workflow>` columns per workflow. `consensus_dtxsid` is
never changed. Results are cached per DTXSID and workflow; errors are
retried on the next call.

## Usage

``` r
add_structure_parents(
  df,
  cache = NULL,
  workflows = DESALT_WORKFLOWS,
  lookup_fn = desalt_lookup_structures,
  stdize_fn = desalt_standardize
)
```

## Arguments

- df:

  Resolution state with `consensus_dtxsid`.

- cache:

  Parent cache from a previous call, or NULL.

- workflows:

  One or both of "qsar-ready" and "ms-ready".

- lookup_fn, stdize_fn:

  Injectable DTXSID structure lookup and standardizer calls.

## Value

List with `data` and `cache`.
