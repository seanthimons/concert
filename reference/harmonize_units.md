# Harmonize unit values using a conversion table

Takes numeric values and their unit strings, performs lookup against a
unit conversion table, and returns harmonized values with audit trail.

## Usage

``` r
harmonize_units(
  values,
  units,
  unit_map,
  media = NULL,
  dtxsid = NULL,
  molecular_weight = NULL,
  use_dedup = TRUE,
  category = NULL
)
```

## Arguments

- values:

  Numeric vector of parsed numeric values.

- units:

  Character vector of unit strings. Must have exactly the same length as
  `values`.

- unit_map:

  Tibble from load_unit_map() with columns: from_unit, to_unit,
  multiplier

- media:

  Optional character vector - media context for ppb/ppm routing. Must be
  `NULL`, scalar, or the same length as `values`. Values are "aqueous",
  "air", "solid", or `NULL`. Unknown media falls back to the unit map
  instead of assuming aqueous. Air `ppb`/`ppm` is not converted.

- dtxsid:

  Optional character vector of DTXSIDs for MW lookup when molarity is
  detected. Must be `NULL`, scalar, or the same length as `values`.

- molecular_weight:

  Optional numeric MW override, which skips API lookup. Must be `NULL`,
  scalar, or the same length as `values`.

- use_dedup:

  Logical. When TRUE (default), applies unit-key dedup optimization
  (Phase 37 D-07). Set to FALSE for benchmark baseline.

- category:

  Character or NULL. When non-NULL, filters unit_map to rows matching
  this category before conversion. Use "duration" for duration
  harmonization. Default NULL uses all rows (backward compatible).

## Value

A tibble with columns:

- orig_row_id: Integer linking back to input position

- orig_unit: Original unit string before normalization

- harmonized_value: Value after conversion (value \* multiplier +
  offset)

- harmonized_unit: Target unit from table, original unit for unsafe or
  unresolved pass-through, or `NA` for absent units

- conversion_factor: Multiplier applied (1 for pass-through)

- unit_flag: Status. `""` indicates an exact success; `case_fallback`
  indicates an unambiguous case-insensitive success; `unmatched`,
  `ambiguous_unit`, `absent`, `needs_context`, `needs_mw`, and
  `mw_lookup_failed` identify pass-through states requiring no
  conversion or further review. A successful MW lookup that returns a
  missing MW uses `needs_mw`; package, API, response-schema, and
  requested-row failures use `mw_lookup_failed`.

## Details

Lookup strategy:

1.  Validate vector lengths before normalization or external lookup.

2.  Preserve missing-like units (`NA`, empty, or whitespace-only) as
    `absent`.

3.  Load synonyms internally and normalize whitespace and micro symbols.

4.  Recognize molarity only with exact scientific casing: `M`, `mM`,
    `uM`, `nM`, `pM`, and the corresponding correctly cased `mol/L`
    forms.

5.  Route aqueous and solid `ppb`/`ppm` by media. Air values pass
    through with `needs_context` because gas conversion also needs MW,
    temperature, and pressure.

6.  Prefer case-sensitive exact matches against `unit_map$from_unit`.

7.  Use case-insensitive fallback only when every complete-map match has
    the same target, multiplier, and offset. Ambiguous fallback passes
    through.

8.  Pass unmatched units through unchanged.

Performance: Vectorized implementation (Plan 34-04) - O(n) hash lookups
instead of O(n\*m) per-row match() calls. Benchmarks: \<1 sec for 128k
rows vs 8+ sec prior.

## Examples

``` r
unit_map <- tibble::tibble(
  from_unit = c("mg/L", "ug/L"),
  to_unit = c("mg/L", "mg/L"),
  multiplier = c(1, 0.001)
)
# Basic usage (backward compatible)
harmonize_units(c(5, 10), c("ug/L", "mg/L"), unit_map)
#> # A tibble: 2 × 6
#>   orig_row_id orig_unit harmonized_value harmonized_unit conversion_factor
#>         <int> <chr>                <dbl> <chr>                       <dbl>
#> 1           1 ug/L                 0.005 mg/L                        0.001
#> 2           2 mg/L                10     mg/L                        1    
#> # ℹ 1 more variable: unit_flag <chr>

# With molarity conversion
harmonize_units(c(1), c("mM"), unit_map, molecular_weight = c(100))
#> # A tibble: 1 × 6
#>   orig_row_id orig_unit harmonized_value harmonized_unit conversion_factor
#>         <int> <chr>                <dbl> <chr>                       <dbl>
#> 1           1 mM                     100 mg/L                          100
#> # ℹ 1 more variable: unit_flag <chr>

# With media context for ppb/ppm
harmonize_units(c(10), c("ppb"), unit_map, media = c("aqueous"))
#> # A tibble: 1 × 6
#>   orig_row_id orig_unit harmonized_value harmonized_unit conversion_factor
#>         <int> <chr>                <dbl> <chr>                       <dbl>
#> 1           1 ppb                   0.01 mg/L                        0.001
#> # ℹ 1 more variable: unit_flag <chr>
```
