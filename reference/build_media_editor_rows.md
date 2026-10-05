# Build rows for the Media Classification editor

Combines published defaults, user mappings, unresolved AMOS aliases, and
unique raw unmatched uploaded terms produced by harmonize_media().

## Usage

``` r
build_media_editor_rows(media_map, media_results)
```

## Arguments

- media_map:

  Media map tibble from load_media_map().

- media_results:

  harmonize_media() output, or NULL before pipeline run.

## Value

Tibble for DT rendering and tests.
