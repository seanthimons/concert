# Validate manually-entered DTXSIDs via CompTox bulk API

Validate manually-entered DTXSIDs via CompTox bulk API

## Usage

``` r
validate_manual_dtxsids(
  dtxsids,
  batch_size = 20,
  delay_sec = 1,
  lookup_fn = ComptoxR::ct_chemical_search_equal_bulk
)
```

## Arguments

- dtxsids:

  Character vector of DTXSID strings (e.g., "DTXSID7020182")

- batch_size:

  Integer batch size for API calls (default 20)

- delay_sec:

  Numeric delay in seconds between batches (default 1)

- lookup_fn:

  Injectable authoritative equality lookup.

## Value

Tibble with searchValue, dtxsid, preferredName, rank, is_valid and
validation_status. Unavailable, not_found, ambiguous and
returned_id_mismatch remain distinct; only an exact unique
requested/returned ID is valid.
