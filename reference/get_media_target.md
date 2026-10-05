# Get target unit for ppb/ppm based on media context

Get target unit for ppb/ppm based on media context

## Usage

``` r
get_media_target(unit, media)
```

## Arguments

- unit:

  Character - the unit string (should be ppb or ppm)

- media:

  Character - "aqueous", "air", "solid", or NULL

## Value

Character target, `NA_character_` when air needs gas context, or NULL
when media is unknown/not applicable.
