# Safely read a file with multiple fallback strategies

Safely read a file with multiple fallback strategies

## Usage

``` r
safely_read_file(filepath, file_ext)
```

## Arguments

- filepath:

  Character. Path to the file to read

- file_ext:

  Character. File extension (csv, xlsx, xls)

## Value

A tibble with the raw file contents (no header parsing)
