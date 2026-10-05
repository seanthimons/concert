# Hydrate Session State

Converts a parsed CONCERT export into values ready to assign into the
Shiny data_store. This function is pure and does not depend on Shiny.

## Usage

``` r
hydrate_session_state(parsed, existing_reference_lists = NULL)
```

## Arguments

- parsed:

  Parsed export returned by parse_concert_export()

- existing_reference_lists:

  Current application reference lists, merged with imported
  reference-list rows.

## Value

List with state and warnings
