# Add deterministic radiological activity-concentration conversions

Environmental radioisotope results are commonly reported as activity per
volume, but live datasets also use bare activity units such as `pCi` as
shorthand. Keep those dimensions separate: concentration units harmonize
to `pCi/L`; bare activity units harmonize to `pCi` without assuming a
volume basis.

## Usage

``` r
augment_radiological_unit_map(unit_map)
```

## Arguments

- unit_map:

  Tibble with unit conversion columns

## Value

Tibble with radiological rows overriding conflicting source rows

## Details

Existing ECOTOX-derived cache rows mix canonical targets (`Bq/l` vs
`pCi/L`) and omit several common curie-scale variants. This helper
installs stable targets for environmental radiological detections.
