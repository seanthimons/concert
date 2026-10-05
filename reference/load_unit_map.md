# Load unit conversion map

Returns a tibble of unit conversion factors for harmonizing measurement
units. Contains conversions from various units to canonical forms (e.g.,
ug/L -\> mg/L).

## Usage

``` r
load_unit_map(cache_dir = NULL)
```

## Arguments

- cache_dir:

  Directory for cache files (e.g., "inst/extdata")

## Value

Tibble with columns: from_unit, to_unit, multiplier, category,
confidence, source, offset, conversion_type

## Details

Structure:

- from_unit: Source unit string (case-sensitive)

- to_unit: Target canonical unit

- multiplier: Conversion factor (from_unit \* multiplier = to_unit)

- category: Unit category (concentration, mass, dose, etc.)

- confidence: Match quality ("HIGH" for exact case, "LOW" for
  case-insensitive or approximate)

- source: Provenance (ECOTOX, SSWQS, user_added)
