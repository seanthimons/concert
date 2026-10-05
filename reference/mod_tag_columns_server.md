# Tag Columns Module - Server

Tag Columns Module - Server

## Usage

``` r
mod_tag_columns_server(
  id,
  data_store,
  on_tags_applied = NULL,
  on_tags_cleared = NULL
)
```

## Arguments

- id:

  Module namespace ID

- data_store:

  Reactive values store from main app

- on_tags_applied:

  Callback function to execute after tags applied (for navigation)

- on_tags_cleared:

  Callback function to execute after tags cleared

## Value

Reactive list with tags_applied indicator
