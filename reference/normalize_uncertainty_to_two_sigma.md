# Convert reported uncertainty to a two-sigma half-width

Negative uncertainty values are invalid and return `NA_real_`; callers
should surface them as review context rather than allowing inverted
intervals. Explicit one-sigma coverage is doubled. Missing or unknown
coverage is treated as already two-sigma so classification remains
deterministic.

## Usage

``` r
normalize_uncertainty_to_two_sigma(
  uncertainty_value,
  uncertainty_coverage = NULL
)
```

## Arguments

- uncertainty_value:

  Numeric vector of reported uncertainty.

- uncertainty_coverage:

  Character vector, e.g. "two_sigma", "one_sigma".

## Value

Numeric vector of non-negative two-sigma half-widths.
