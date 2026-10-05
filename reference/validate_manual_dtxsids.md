# Validate manually-entered DTXSIDs via CompTox bulk API

Validate manually-entered DTXSIDs via CompTox bulk API

## Usage

``` r
validate_manual_dtxsids(dtxsids, batch_size = 20, delay_sec = 1)
```

## Arguments

- dtxsids:

  Character vector of DTXSID strings (e.g., "DTXSID7020182")

- batch_size:

  Integer batch size for API calls (default 20)

- delay_sec:

  Numeric delay in seconds between batches (default 1)

## Value

Tibble with columns: searchValue, dtxsid, preferredName, rank, is_valid
