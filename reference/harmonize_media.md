# Harmonize environmental media strings to canonical CONCERT media terms

Maps a character vector of raw environmental media strings against the
generated CONCERT media vocabulary cache (`amos_media.rds`). Resolution
order: (1) user assertions; (2) active bundled auto assertions; (3)
unambiguous phrase fallback for partial matches; (4) `media_unmatched`
flag for everything else. Pending source-table aliases are not
auto-resolved.

## Usage

``` r
harmonize_media(
  raw_media,
  orig_row_id = seq_along(raw_media),
  media_map = NULL
)
```

## Arguments

- raw_media:

  Character vector of media strings to harmonize.

- orig_row_id:

  Integer vector of row IDs corresponding to each element of
  `raw_media`. Defaults to `seq_along(raw_media)` for direct column
  processing.

- media_map:

  Optional tibble with columns term, canonical_term, envo_id,
  media_category, source, active, and assertion_mode. When NULL
  (default), falls back to the bundled generated media cache via
  get_media_table(). Pass a merged map from load_media_map() to enable
  user-defined mappings (MEDIT-03, D-14). If the tibble uses `canonical`
  instead of `canonical_term` (display schema), the column is translated
  internally before lookup.

## Value

A row-preserving tibble retaining these original columns:

- orig_row_id:

  Integer row position for join-by-position merge.

- raw_media:

  Original input string, preserved for audit.

- canonical_media:

  Canonical CONCERT media term, or `NA_character_` if unmatched.

- envo_id:

  ENVO identifier for the matched term, or `NA_character_`.

- media_category:

  Top-level routing value: `"aqueous"`, `"air"`, `"solid"`, or
  `NA_character_`.

- media_flag:

  One of: `""` (exact match), `"parent_walk"`, `"media_unmatched"`.

Additional fields retain published `term_id`, `parent_id`,
`preferred_label`, `rank`, `definition`, `physical_phase`,
`physical_state`, `is_water_based`, `concert_unit_route`,
`ontology_node_id`, `ontology_path`, `source`, `assertion_mode`,
`confidence`, `confidence_tier`, and `artifact_version`. CURIE
capitalization is preserved. `routing_status` is `available`,
`unavailable` for a known identity without a route, or `unmatched`. A
successful identity match does not require a route.
