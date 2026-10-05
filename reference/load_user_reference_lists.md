# Load user reference list overrides

Loads the sidecar RDS containing user-editable reference list rows.
Missing or malformed sidecars return an empty typed list so packaged
defaults still load.

## Usage

``` r
load_user_reference_lists(cache_dir = NULL)
```

## Arguments

- cache_dir:

  Directory for reference cache files. Defaults to the bundled
  package/source reference cache.

## Value

List with stop_words, block_patterns, and strip_terms tibbles.
