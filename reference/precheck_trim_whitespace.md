# Pre-check predicate for trim_whitespace_punctuation step

Checks whether any character column contains values that
[`clean_text_field()`](https://seanthimons.github.io/concert/reference/clean_text_field.md)
would change (leading/trailing whitespace, excess internal whitespace,
leading/trailing underscores or asterisks).

## Usage

``` r
precheck_trim_whitespace(df)
```

## Arguments

- df:

  Dataframe to check.

## Value

list(should_run = logical, est_changes = integer).
