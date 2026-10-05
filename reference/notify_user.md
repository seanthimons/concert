# Show a Shiny notification and mirror important messages to the console

Show a Shiny notification and mirror important messages to the console

## Usage

``` r
notify_user(ui, type = "message", ..., log_context = NULL)
```

## Arguments

- ui:

  Notification content passed to
  [`shiny::showNotification()`](https://rdrr.io/pkg/shiny/man/showNotification.html).

- type:

  Notification type passed to
  [`shiny::showNotification()`](https://rdrr.io/pkg/shiny/man/showNotification.html).

- ...:

  Additional arguments passed to
  [`shiny::showNotification()`](https://rdrr.io/pkg/shiny/man/showNotification.html).

- log_context:

  Optional short context label included in console output.

## Value

The notification id returned by
[`shiny::showNotification()`](https://rdrr.io/pkg/shiny/man/showNotification.html).
