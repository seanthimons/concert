# Resolve an unambiguous phrase fallback for a normalized media string

Given a normalized (trimws + tolower) input string that did not produce
a resolved exact match, checks whether a table term appears as a full
token/phrase in the input. Embedded substrings such as `"water"` in
`"wastewater"` are intentionally ignored. Longer matching phrases
subsume their own tokens. Conflicting identities or routes remain
unresolved. Published graph edges are not walked.

## Usage

``` r
walk_parent(norm_term, media_tbl)
```

## Arguments

- norm_term:

  Single normalized character string.

- media_tbl:

  Tibble returned by `get_media_table()`.

## Value

Integer row index or NA_integer\_.

## Details

Returns the integer row index of the resolved entry, or `NA_integer_`.
