# Load the generated CONCERT media vocabulary cache

Reads amos_media.rds from the package reference cache. If the cache is
absent in a source checkout, falls back to building it from reviewable
media source tables so callers can degrade gracefully.

## Usage

``` r
find_local_media_table()
```

## Value

Tibble with columns term, canonical_term, envo_id, parent,
media_category, source, fetch_timestamp, assertion_mode, confidence,
active; or NULL.
