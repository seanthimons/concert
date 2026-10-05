# Refresh WQX dictionary cache

Re-downloads Characteristic.csv and Characteristic Alias.csv from EPA,
rebuilds the combined lookup tibble, and saves to cache. Overwrites any
existing cached RDS silently.

## Usage

``` r
refresh_wqx_cache(cache_dir = NULL)
```

## Arguments

- cache_dir:

  Directory for reference cache. Defaults to installed package path.

## Value

Invisibly returns the rebuilt tibble
