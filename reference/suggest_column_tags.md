# Suggest Column Tags From Header Names

Heuristically guesses a tag type for each column from its (already
[`janitor::clean_names()`](https://sfirke.github.io/janitor/reference/clean_names.html)-normalized)
header name. This powers the "suggest, don't auto-apply" pre-fill in the
Tag Columns step: the returned suggestions seed the dropdowns, but the
user always reviews and applies.

## Usage

``` r
suggest_column_tags(col_names)
```

## Arguments

- col_names:

  Character vector of column names (post-`clean_names()`).

## Value

A named list, one element per input column (1:1, order preserved), whose
value is a tag type (e.g. `"CASRN"`, `"Name"`, `"Result"`) or `""` when
no confident match is found. Returns an empty named list for zero-length
input. Returned as a list (not an atomic vector) so callers can safely
use `suggestions[[col]] %||% ""` without a subscript-out-of-bounds error
on missing keys.

## Details

The matcher is **name-only** (no cell-value sampling) and
**precision-first**: it matches on whole tokens, prefers the most
specific (longest) keyword phrase, drops dangerous generic tokens (bare
`name`, `date`, `value`, `id`, `exposure`), and emits at most one
suggestion for the singular chemical tags (`Name`, `CASRN`).

Every emitted value is a member of the
[`classify_tags()`](https://seanthimons.github.io/concert/reference/classify_tags.md)
taxonomy (`R/tag_helpers.R`); unmatched columns return `""`.

## Examples

``` r
suggest_column_tags(c("cas_number", "chemical_name", "supplier_name"))
#> $cas_number
#> [1] "CASRN"
#> 
#> $chemical_name
#> [1] "Name"
#> 
#> $supplier_name
#> [1] ""
#> 
# $cas_number    -> "CASRN"
# $chemical_name -> "Name"
# $supplier_name -> ""   (generic 'name' without a chemical qualifier)
```
