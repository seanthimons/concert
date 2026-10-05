# Build the generated runtime media map from reviewable source tables

Build the generated runtime media map from reviewable source tables

## Usage

``` r
build_media_runtime_map(
  source_tables = load_media_source_tables(),
  fetch_timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
)
```

## Arguments

- source_tables:

  List returned by load_media_source_tables().

- fetch_timestamp:

  Timestamp for legacy sources; ignored for pinned artifacts.

## Value

Tibble compatible with legacy amos_media.rds consumers.
