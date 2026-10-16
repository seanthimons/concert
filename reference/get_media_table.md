# Load the CONCERT media vocabulary

Builds the runtime map from the pinned envharmonizer tables, downloading
them on first use. The result is memoised for the session. If the tables
are unavailable it warns once and returns NULL so callers can degrade
gracefully.

## Usage

``` r
get_media_table()
```

## Value

Tibble with columns term, canonical_term, envo_id, parent,
media_category, source, fetch_timestamp, assertion_mode, confidence,
active; or NULL.
