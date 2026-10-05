# Register chemistry and environmental domain units

Called automatically on package load. Registers units not in udunits2:

- Molarity: M, mM, uM, nM, pM (based on mol/L)

- Turbidity: NTU, FTU, JTU (dimensionless, not interconvertible)

- Microbial: CFU, MPN (dimensionless counts)

## Usage

``` r
register_concert_units()
```

## Value

NULL (called for side effects)
