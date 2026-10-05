# Run Curation Module - Server

Run Curation Module - Server

## Usage

``` r
mod_run_curation_server(id, data_store, on_curation_complete = NULL)
```

## Arguments

- id:

  Module namespace ID

- data_store:

  Reactive values store from main app

- on_curation_complete:

  Callback function to execute after curation completes (for navigation)

## Value

Reactive list with curation_completed indicator
