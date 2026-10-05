# Update a user reference list override

Adds, removes, or toggles one user-editable reference term in the
sidecar and returns the merged list for that type.

## Usage

``` r
update_user_reference_list(
  type,
  term,
  active = TRUE,
  match_mode = NULL,
  pattern = NULL,
  notes = NA_character_,
  action = c("add", "remove", "toggle"),
  cache_dir = NULL
)
```

## Arguments

- type:

  One of stop_words/stop_word, block_patterns/block_pattern, or
  strip_terms/strip_term.

- term:

  Term or pattern to update.

- active:

  Active value to use when adding or replacing a term.

- match_mode:

  Optional matching mode. One of `literal_word`, `literal_exact`, or
  `regex`.

- pattern:

  Optional pattern to store separately from `term`. Defaults to `term`.

- notes:

  Optional notes for the reference-list row.

- action:

  One of add, remove, or toggle.

- cache_dir:

  Directory for reference cache files. Defaults to the bundled
  package/source reference cache.

## Value

Tibble containing packaged defaults merged with user overrides.
