# Extract qualifier prefix from normalized string

Parses a leading qualifier from a normalized numeric string. Supported
qualifiers (in order of priority): \<=, \>=, \<, \>, ~, = Per D-07: no
qualifier found -\> qualifier = ""

## Usage

``` r
extract_qualifier(x)
```

## Arguments

- x:

  Character vector (already normalized)

## Value

Named list with two character vectors: `qualifier` and `remainder`
