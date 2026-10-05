# Clean text field by stripping whitespace and punctuation artifacts

Chain: trim -\> squish -\> strip leading/trailing underscores and
asterisks. DOES NOT strip internal punctuation (preserves CAS numbers
like "67-64-1" and IUPAC names like "2,4-dichlorophenol").

## Usage

``` r
clean_text_field(x)
```

## Arguments

- x:

  Character vector

## Value

Character vector with whitespace and artifacts removed

## Examples

``` r
clean_text_field("  hello  ")  # => "hello"
#> [1] "hello"
clean_text_field("__name__")  # => "name"
#> [1] "name"
clean_text_field("*starred*")  # => "starred"
#> [1] "starred"
clean_text_field("67-64-1")  # => "67-64-1" (preserved)
#> [1] "67-64-1"
clean_text_field("2,4-dichlorophenol")  # => "2,4-dichlorophenol" (preserved)
#> [1] "2,4-dichlorophenol"
```
