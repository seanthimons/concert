# Normalize a unit string for lookup

Applies normalization chain to prepare unit strings for lookup: (a) Trim
leading/trailing whitespace (b) Replace micro symbols: U+00B5 (micro
sign) and U+03BC (Greek mu) -\> "u" (c) Collapse spaces around "/": "mg
/ L" -\> "mg/L"

## Usage

``` r
normalize_unit_string(x)
```

## Arguments

- x:

  Character vector of unit strings

## Value

Character vector of normalized unit strings
