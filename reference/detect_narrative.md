# Detect narrative (non-numeric) values

Identifies values that represent qualitative descriptions rather than
numbers. Flags: known narrative terms (BDL, ND, etc.), empty strings,
NA, whitespace-only.

## Usage

``` r
detect_narrative(x)
```

## Arguments

- x:

  Character vector (remainder after qualifier extraction)

## Value

Logical vector, TRUE = narrative
