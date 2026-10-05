# Extract unit conversions from ECOTOX database

Queries the ECOTOX unit_conversion table and transforms entries into a
standardized format with UCUM conventions and proper category inference.

## Usage

``` r
extract_ecotox_units(db_path)
```

## Arguments

- db_path:

  Path to ecotox.duckdb file

## Value

A tibble with columns: from_unit, to_unit, multiplier, category,
confidence, source

## Details

ECOTOX stores conversions to SI base units (g/l, mol/l). This function
transforms targets to UCUM conventions (mg/L capital L) by adjusting
multipliers accordingly.

Category inference is based on unit_domain and cur_unit_result:

- concentration: aqueous mass/volume, target = mg/L

- air_concentration: gaseous mass/volume, target = mg/m3

- mass_fraction: solid matrix, target = mg/kg

- dose: body weight adjusted rates, target = mg/kg/d

- molarity: molar concentrations, confidence = NEEDS_MW, multiplier = NA
