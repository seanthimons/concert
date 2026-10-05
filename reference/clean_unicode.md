# Clean Unicode symbols in character strings

A function to replace Unicode symbols (Greek letters, math symbols,
etc.) with their ASCII equivalents or pseudo-delimited names.

## Usage

``` r
clean_unicode(x, ...)

# S3 method for class 'character'
clean_unicode(x, ...)

# Default S3 method
clean_unicode(x, ...)

# S3 method for class 'data.frame'
clean_unicode(x, ...)
```

## Arguments

- x:

  A character vector or a data frame to be processed.

- ...:

  Additional arguments passed to methods.

## Value

The modified character vector or data frame.

## Details

Greek letters are replaced with lowercase labels (e.g., 'alpha').
Mathematical comparison symbols like '\>=' are normalized, and
plus/minus symbols are replaced with '+/-'. If a data frame is provided,
all character columns are processed.

Unhandled Unicode characters will be flagged for the user.

## Examples

``` r
if (FALSE) { # \dontrun{
clean_unicode("17\u03b2-Estradiol")
# Returns: "17beta-Estradiol"

clean_unicode("Concentration \u2265 10 \u00b5g/L")
# Returns: "Concentration >= 10 ug/L"
} # }
```
