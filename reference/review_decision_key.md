# Construct a stable content-selector decision ID

Construct a stable content-selector decision ID

## Usage

``` r
review_decision_key(name, casrn = NA_character_, scope = NULL)
```

## Arguments

- name:

  Reviewed source name.

- casrn:

  Optional reviewed CAS selector.

- scope:

  Optional named list of input-column values the decision is narrowed
  to; `NULL` keeps the unscoped key.

## Value

Stable decision identifier for capture_review_decision().
