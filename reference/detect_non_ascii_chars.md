# Detect non-ASCII characters in a character vector

Helper function that scans a character vector for non-ASCII characters.
Returns a list of unique non-ASCII characters with their Unicode
codepoints and occurrence counts.

## Usage

``` r
detect_non_ascii_chars(x)
```

## Arguments

- x:

  Character vector to scan

## Value

Named list keyed by "U+XXXX" with elements: char, codepoint, count
