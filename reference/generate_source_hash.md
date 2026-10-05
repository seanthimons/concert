# Generate source hash for each row

Computes SHA256 digest of all row values (excluding source_hash itself)
concatenated with "\|" separator.

## Usage

``` r
generate_source_hash(result_tibble)
```

## Arguments

- result_tibble:

  Tibble to hash (source_hash column will be NA)

## Value

Character vector of SHA256 hashes
