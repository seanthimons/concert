# Load isotope lookup table

Builds a pre-processed lookup table from the active
[`ComptoxR::pt`](https://seanthimons.github.io/ComptoxR/reference/pt.html)
isotope data for use by
[`expand_isotope_shortcodes()`](https://seanthimons.github.io/concert/reference/expand_isotope_shortcodes.md).
Cached to RDS to avoid rebuilding on every run. If a WQX dictionary
cache is already present, missing radiochemical isotope shortcodes are
added without live CAS lookups.

## Usage

``` r
load_isotope_lookup(cache_dir)
```

## Arguments

- cache_dir:

  Directory for cache files (e.g., "data/reference_cache")

## Value

List with components: lookup (tibble), elem_alt_names (named character
vector)

## Details

The lookup contains shortcode-\>canonical mappings (e.g. "u234" -\>
"Uranium-234"), element name-\>canonical mappings for spelled-out
normalization, and alternate element name spellings (American vs IUPAC).
