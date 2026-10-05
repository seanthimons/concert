# Transform ECOTOX SI targets to UCUM conventions

Internal helper to convert ECOTOX's SI base unit targets to
UCUM-compliant canonical forms with adjusted multipliers.

## Usage

``` r
transform_ecotox_to_ucum(cur_target, ecotox_mult, domain, orig)
```

## Arguments

- cur_target:

  ECOTOX cur_unit_result (e.g., "g/l", "mol/l")

- ecotox_mult:

  Original ECOTOX conversion factor

- domain:

  ECOTOX unit_domain category

- orig:

  Original unit string for molarity detection

## Value

List with to_unit, multiplier, category, confidence
