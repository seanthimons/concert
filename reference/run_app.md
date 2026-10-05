# Launch the CONCERT Shiny Application

Launches the CONCERT Shiny app for chemical inventory upload, cleaning,
and curation. The app provides a full workflow from file upload through
CompTox API curation with audit trail export.

## Usage

``` r
run_app(...)
```

## Arguments

- ...:

  Additional arguments passed to
  [`runApp`](https://rdrr.io/pkg/shiny/man/runApp.html), such as `port`,
  `host`, or `launch.browser`.

## Value

Invisible `NULL`. The function is called for its side effect of
launching the Shiny application.

## Examples

``` r
if (FALSE) { # \dontrun{
# Launch with default settings
run_app()

# Launch on specific port without browser
run_app(port = 3838, launch.browser = FALSE)
} # }
```
