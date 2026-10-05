# Load block patterns list

Returns a tibble of regex patterns for substances that should be blocked
from curation with provenance tracking. These match
empty/redacted/proprietary entries.

## Usage

``` r
load_block_patterns(cache_dir)
```

## Arguments

- cache_dir:

  Directory for cache files (e.g., "data/reference_cache")

## Value

Tibble with columns: term, source, active

## Details

Patterns:

- Empty strings, dashes, dots

- Proprietary/confidential/trade secret indicators

- "Not disclosed" phrases

NOTE: Cache format changed in Phase 13 - delete existing cache files if
needed.
