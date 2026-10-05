# Get deduplication preview counts before running full pipeline

Get deduplication preview counts before running full pipeline

## Usage

``` r
get_dedup_preview(clean_data, column_tags)
```

## Arguments

- clean_data:

  The cleaned data frame

- column_tags:

  Named list (col_name -\> "Name"\|"CASRN"\|"Other")

## Value

List with n_names and n_cas
