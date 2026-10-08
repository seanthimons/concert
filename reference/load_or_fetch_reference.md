# Generic cache-or-fetch function

Checks if cache file exists. If yes, reads from disk. If no, calls
fetch_fn, creates directory structure, saves result to disk, and returns
result.

## Usage

``` r
load_or_fetch_reference(cache_path, fetch_fn, name)
```

## Arguments

- cache_path:

  Full path to cache file (e.g., "data/reference_cache/stop_words.rds")

- fetch_fn:

  Function that fetches/generates the data when cache missing

- name:

  Human-readable name for logging

## Value

Data returned by fetch_fn (or read from cache)

## Examples

``` r
cache_path <- file.path(tempdir(), "data.rds")
load_or_fetch_reference(cache_path, function() c("a", "b"), "test_data")
#> Fetching test_data (cache not found)...
#> Cached test_data to: /tmp/RtmpaSMcut/data.rds
#> [1] "a" "b"
```
