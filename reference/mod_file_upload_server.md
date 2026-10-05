# File Upload Module - Server

File Upload Module - Server

## Usage

``` r
mod_file_upload_server(
  id,
  data_store,
  reset_all_downstream = NULL,
  on_session_restored = NULL
)
```

## Arguments

- id:

  Module namespace ID

- data_store:

  Reactive values store from main app

- reset_all_downstream:

  Optional callback function to reset downstream state (app navigation)

- on_session_restored:

  Optional callback after a CONCERT export session is hydrated

## Value

Reactive list with file processing outputs
