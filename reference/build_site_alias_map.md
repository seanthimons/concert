# Build A Deterministic Site Alias Map

Filters blank aliases and blank canonical destinations, then keeps one
row for each distinct raw dataset site label in first-seen order.

## Usage

``` r
build_site_alias_map(site_manifest)
```

## Arguments

- site_manifest:

  Site manifest candidate or user-edited site context.

## Value

A deterministic, distinct site alias map.
