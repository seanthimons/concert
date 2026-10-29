# Token Jaccard similarity between two names

Lowercase alphanumeric word overlap. Shared prefixes such as "Total" or
"Phosphorus" do not rescue names whose distinguishing token differs.

## Usage

``` r
name_token_similarity(a, b)
```

## Arguments

- a, b:

  Character vectors of names (recycled).

## Value

Numeric vector in `[0, 1]`; NA where either name is missing.
