# Load merged media harmonization map (user edits + bundled defaults)

User rows (user_media_map.rds) take precedence for the same term. Falls
back to the generated media cache via get_media_table() for all other
terms. Returns a display-schema tibble with columns for the media editor
DT plus the additional columns harmonize_media() needs internally
(canonical_term, envo_id, media_category, assertion_mode, confidence)
when passed as media_map parameter.

## Usage

``` r
load_media_map(cache_dir)
```

## Arguments

- cache_dir:

  Directory for cache files (e.g., "inst/extdata/reference_cache")

## Value

Tibble with columns: term, canonical, canonical_term, envo_id, parent,
media_category, source, fetch_timestamp, assertion_mode, confidence,
active

## Details

On first run, if user_media_map.rds does not exist, the function returns
the generated media table normalised to the merged schema. If
get_media_table() also returns NULL (e.g., amos_media.rds not yet
built), the function returns an empty tibble with the correct column
types.
