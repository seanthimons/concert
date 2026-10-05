# Validate CAS numbers and lookup DTXSID for valid ones

Validate CAS numbers and lookup DTXSID for valid ones

## Usage

``` r
validate_and_lookup_cas(unique_cas)
```

## Arguments

- unique_cas:

  Character vector of CAS-like strings

## Value

Tibble with original_cas, validated_cas, is_valid, dtxsid, preferredName
