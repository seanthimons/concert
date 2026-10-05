# Normalize WQX lookup keys

WQX includes PAH locant variants that differ only by whitespace or
bracket style, e.g. `benzo (a) anthracene`, `benzo(a) anthracene`, and
`Benzo[a]anthracene`. Normalize those variants before exact/alias lookup
so they do not fall through to isotope-adjacent fuzzy matches.

## Usage

``` r
normalize_wqx_key(x)
```

## Arguments

- x:

  Character vector of raw WQX/name values.

## Value

Character vector normalized for WQX dictionary key lookup.
