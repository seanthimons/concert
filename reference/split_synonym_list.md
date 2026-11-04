# Split synonym-list cells into their parts

Splits on `;` outside parentheses and brackets, trims, and drops empty
and repeated parts. Unlike
[`split_synonyms()`](https://seanthimons.github.io/concert/reference/split_synonyms.md),
there is no plausibility gate (short synonyms such as "EDB" are valid)
and a CASRN on the row does not matter: every synonym names the row's
own chemical.

## Usage

``` r
split_synonym_list(x)
```

## Arguments

- x:

  Character vector of synonym cells.

## Value

List the length of `x`; each element is a character vector of parts
(`character(0)` for NA or empty cells).
