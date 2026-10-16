# Download the pinned envharmonizer tables if missing or modified

The tables are not committed. The cache directory is versioned, so
bumping the pin makes the next start fetch the new release.

## Usage

``` r
ensure_envharmonizer_tables(root = envharmonizer_cache_root())
```

## Arguments

- root:

  Cache root; the release lands in `envharmonizer-0.1.1/` below it.

## Value

The cache root, invisibly.
