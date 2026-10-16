# Harmonize analytical-method strings

Exact lookup of normalized labels against the pinned envharmonizer
v0.1.1 analytical tables. One input can yield several ordered components
(overall method, separation, detection), so the result is long: one or
more rows per input row, never zero. Unmatched values get one row with
`confidence_tier = "unresolved"` and `status = "queued"`.

## Usage

``` r
harmonize_methodology(raw_method, orig_row_id = seq_along(raw_method))
```

## Arguments

- raw_method:

  Character vector of method strings.

- orig_row_id:

  Row ids aligned with `raw_method`.

## Value

Tibble with orig_row_id, raw_method, component_order, term_id,
preferred_label, analytical_role, match_type, assertion_mode,
confidence_tier, status and artifact_version.
