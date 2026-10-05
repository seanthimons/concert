# Clean Data Module - Server

Clean Data Module - Server

## Usage

``` r
mod_clean_data_server(id, data_store, on_cleaning_complete = NULL)
```

## Arguments

- id:

  Module namespace ID

- data_store:

  Reactive values store from main app

- on_cleaning_complete:

  Callback function to execute after cleaning completes (for navigation)

## Value

Reactive list with cleaning indicators
