# Save user reference list overrides

Persists only rows whose source is not `app_default`, leaving packaged
defaults untouched. Rows are saved to `user_reference_lists.rds`.

## Usage

``` r
save_user_reference_lists(reference_lists, cache_dir = NULL)
```

## Arguments

- reference_lists:

  List containing stop_words, block_patterns, and/or strip_terms
  tibbles.

- cache_dir:

  Directory for reference cache files. Defaults to the bundled
  package/source reference cache.

## Value

Invisibly returns the saved sidecar list.
