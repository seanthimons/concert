# Apply synonym normalization to unit strings

Performance: Split exact-match rules (hash lookup O(1)) from regex
rules. Only regex rules require per-rule gsub passes. (Codex
optimization)

## Usage

``` r
apply_synonyms(unit_strings, synonyms)
```

## Arguments

- unit_strings:

  Character vector of normalized unit strings

- synonyms:

  Tibble from get_unit_synonyms() or NULL

## Value

Character vector with synonyms applied
