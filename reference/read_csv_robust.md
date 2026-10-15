# Robust delimited-text reading

Decides encoding and delimiter up front rather than on read errors,
because readr warns instead of failing on wrong encodings and
delimiters:

- binary content (NUL bytes) is rejected

- invalid UTF-8 is read as Windows-1252 (a superset of Latin-1)

- the delimiter (`,`, `;`, tab, `|`) is the one giving the most fields
  on the typical line; `;` files use decimal commas

- if readr returns fewer columns or rows than the file has (a short
  title line above the header, a truncated last row), the file is
  re-read with base R padded to the widest line

## Usage

``` r
read_csv_robust(filepath)
```
