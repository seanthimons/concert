# Validate CAS numbers and lookup DTXSID for valid ones

Validate CAS numbers and lookup DTXSID for valid ones

## Usage

``` r
validate_and_lookup_cas(unique_cas, preserve_candidates = FALSE)
```

## Arguments

- unique_cas:

  Character vector of CAS-like strings

- preserve_candidates:

  Keep all lookup hits and explicit lookup outcomes for provisional
  review evidence instead of choosing the best-ranked hit.

## Value

Tibble with original_cas, validated_cas, is_valid, dtxsid, preferredName
