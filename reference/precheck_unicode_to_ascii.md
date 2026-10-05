# Pre-check predicate for unicode_to_ascii step

Performs a cheap vectorized scan of all character columns using
[`stringi::stri_enc_isascii()`](https://rdrr.io/pkg/stringi/man/stri_enc_isascii.html)
to determine if any non-ASCII values exist that
[`clean_unicode()`](https://seanthimons.github.io/concert/reference/clean_unicode.md)
would transform.

## Usage

``` r
precheck_unicode_to_ascii(df)
```

## Arguments

- df:

  Dataframe to check.

## Value

list(should_run = logical, est_changes = integer).
