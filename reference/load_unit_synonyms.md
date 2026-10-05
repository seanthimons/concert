# Load unit synonym normalization table

Returns a tibble for normalizing variant unit spellings to canonical
forms before lookup in the main unit conversion table.

## Usage

``` r
load_unit_synonyms(cache_dir)
```

## Arguments

- cache_dir:

  Directory for cache files (e.g., "inst/extdata")

## Value

Tibble with columns: input_pattern, normalized_unit, is_regex, notes

## Details

Note: harmonize_units() loads this table internally via system.file().
This exported function is for inspection and debugging purposes.

Structure:

- input_pattern: String or regex pattern to match

- normalized_unit: Canonical form to use for lookup

- is_regex: TRUE if pattern is regex, FALSE if exact match

- notes: Documentation for the mapping
