---
status: resolved
trigger: "Thousands of jsonlite warnings on review results page: Input to asJSON(keep_vec_names=TRUE) is a named vector"
created: 2026-04-29
updated: 2026-04-29
---

## Symptoms

- **Expected**: No console warnings on the review results page
- **Actual**: Warning "Input to asJSON(keep_vec_names=TRUE) is a named vector. In a future version of jsonlite, this option will not be supported, and named vectors will be translated into arrays instead of objects. If you want JSON object output, please use a named list instead. See ?toJSON." printed thousands of times
- **Error**: jsonlite deprecation warning about named vectors vs named lists
- **Timeline**: Occurs when viewing review results page
- **Reproduction**: Navigate to review results page in the Shiny app

## Current Focus

- hypothesis: Named vector subscripting with `named_vector[key]` preserves the key as a name attribute on the result. Reactable serializes cell/rowStyle return values via jsonlite, which sees named character vectors instead of plain scalars, emitting the warning once per cell/row rendered.
- next_action: complete
- test: null
- expecting: null

## Evidence

- timestamp: 2026-04-29T00:00:00
  file: R/mod_review_results.R
  finding: |
    Five named-vector lookup sites found:
    1. Line 37 (derive_match_type): `tier_label_map[tier_val[update_mask]]` — assigns named strings into result vector, which is then used as a data column fed into reactable
    2. Line 765: `match_colors[val]` in match_type colDef cell function — named color string passed to sprintf()
    3. Line 766: `match_text_colors[val]` in same cell function
    4. Line 806: `status_colors[val]` in consensus_status colDef cell function
    5. Line 903: `row_bg_colors[status]` in row_style_fn — named color string put into list(backgroundColor = bg), serialized per row by reactable/jsonlite

## Eliminated

- Direct jsonlite::toJSON calls in R/mod_harmonize.R already use unname() correctly — not the source

## Resolution

- root_cause: Named vector subscripting with `named_vector[key]` preserves the name attribute on the returned scalar. Reactable serializes cell function return values and rowStyle lists via jsonlite, which triggers the keep_vec_names deprecation warning once per rendered cell/row. Five sites in mod_review_results.R are affected.
- fix: Wrapped each named-vector lookup in unname() at lines 37, 765, 766, 806, 903 in R/mod_review_results.R. air format and jarl check both pass.
