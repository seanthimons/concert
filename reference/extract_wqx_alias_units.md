# Extract candidate units from WQX Characteristic Alias inventory

Scans EPA's `Characteristic Alias.csv` for unit-bearing alias
conventions. This is an inventory/gap-analysis helper only; WQX aliases
are evidence for observed unit strings, not conversion authority.

## Usage

``` r
extract_wqx_alias_units(alias_path = NULL)
```

## Arguments

- alias_path:

  Path to `Characteristic Alias.csv`. Defaults to the bundled WQX
  reference-source CSV when available.

## Value

A tibble with candidate unit strings and evidence counts.
