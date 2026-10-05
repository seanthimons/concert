# Detect and split range values

Determines whether a normalized remainder string represents a numeric
range (e.g., "5-10", "-10–5", "-10-5") rather than a negative number or
scientific notation. Returns split low/mid/high values for ranges.

## Usage

``` r
split_ranges(remainder, qualifier)
```

## Arguments

- remainder:

  Character vector (post-qualifier-extraction, post-normalization)

- qualifier:

  Character vector (matching length, from extract_qualifier)

## Value

A list with logical `is_range`, numeric `low`, `mid`, `high` (NA for
non-ranges)

## Details

Pre-guard order (per D-04): (a) If qualifier is non-empty, it is NOT a
range (qualified values are single rows) (b) Apply range regex that
captures optional leading negative, full decimal/exponent numbers, then
a hyphen separator, then a second full number (c) Negative sign
immediately after 'e'/'E' is part of exponent, not a range separator
