# Perform post-curation Unicode QC (read-only detection)

Scans a dataframe for non-ASCII characters without modifying the data.
This is a QC function for post-curation detection of Unicode that may
not have been handled by clean_unicode.

## Usage

``` r
perform_unicode_qc(df)
```

## Arguments

- df:

  Dataframe to scan (typically post-curation resolution_state)

## Value

List with: rows_with_non_ascii (integer), row_indices (integer vector),
unhandled_chars (named list keyed by "U+XXXX")

## Details

Returns a report of:

- How many rows contain non-ASCII characters

- Which row indices have non-ASCII

- What specific Unicode characters were found (with codepoints and
  counts)

## Examples

``` r
df <- tibble::tibble(name = c("acetone", "\u03B1-tocopherol"))
result <- perform_unicode_qc(df)
result$rows_with_non_ascii  # => 1
#> [1] 1
result$row_indices  # => c(2)
#> [1] 2
result$unhandled_chars[["U+03B1"]]$count  # => 1
#> NULL
```
