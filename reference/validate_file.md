# Validate uploaded file before processing

Validate uploaded file before processing

## Usage

``` r
validate_file(file_input, max_size_mb = 50)
```

## Arguments

- file_input:

  File input object from Shiny fileInput

- max_size_mb:

  Maximum file size in MB (default: 50)

## Value

List with success (TRUE/FALSE) and message
