---
# concert-ezlh
title: Auto-tag suggestion prefers analyte_id over analyte
status: todo
type: bug
priority: normal
created_at: 2026-06-19T17:36:20Z
updated_at: 2026-06-19T17:36:20Z
parent: concert-sr8r
---

The Tag Columns auto-suggestion logic can suggest `analyte_id` as Chemical Name while leaving `analyte` blank when both columns are present and `analyte_id` appears first in the uploaded data.

## Observed Behavior

`suggest_column_tags()` is name-only and token-based. `analyte_id` is normalized to tokens `c("analyte", "id")`, so it matches the `Name` keyword `analyte`. The second pass enforces at most one `Name` suggestion. When `analyte_id` and `analyte` tie on specificity, the current `which.max()` tie-break keeps the first column in input order and blanks the other.

Verified locally:

```r
suggest_column_tags(c("analyte_id", "analyte"))
# analyte_id -> "Name"
# analyte    -> ""

suggest_column_tags(c("analyte", "analyte_id"))
# analyte    -> "Name"
# analyte_id -> ""
```

Relevant code:

- `R/auto_tag_columns.R`: `.auto_tag_tokens()` splits `analyte_id` into whole-word tokens.
- `R/auto_tag_columns.R`: `.auto_tag_phrase_table()` includes bare `analyte` as a `Name` keyword.
- `R/auto_tag_columns.R`: `suggest_column_tags()` de-duplicates singular chemical tags (`Name`, `CASRN`) by keeping the highest specificity, with input order as the tie-break.
- `R/mod_file_upload.R`: suggestions are generated from `names(data_store$clean)` after `janitor::clean_names()`.
- `R/mod_tag_columns.R`: suggestions pre-fill the dropdown only when no applied tag already exists.

## Expected Behavior

When both `analyte` and `analyte_id` are present, `analyte` should receive the `Name` suggestion and `analyte_id` should remain blank unless there is a more explicit, supported identifier tag. Identifier-suffixed headers should not win a tie over the plain semantic chemical-name header.

## Proposed Fix

Adjust the auto-tag ranking so identifier-suffixed chemical-name candidates are lower confidence than bare semantic name candidates. Possible approaches:

1. Add a secondary ranking penalty when matched `Name` candidates also include generic identifier tokens such as `id`, `identifier`, or `code`.
2. Treat exact/bare keyword matches as stronger than keyword-plus-generic-suffix matches for singular tag de-duplication.
3. Add explicit blockers for ambiguous headers like `analyte_id` unless they match a known chemical identifier tag such as `cas`, `casrn`, or `dtxsid`.

Prefer a minimal ranking change in `suggest_column_tags()` over hard-coding only `analyte_id`, because the same bug can occur for `chemical_id`, `compound_id`, `substance_id`, or `reagent_id`.

## Acceptance Criteria

- `suggest_column_tags(c("analyte_id", "analyte"))` returns `analyte_id = ""` and `analyte = "Name"`.
- `suggest_column_tags(c("chemical_id", "chemical_name"))` returns `chemical_id = ""` and `chemical_name = "Name"`.
- `suggest_column_tags(c("compound_id", "compound"))` returns `compound_id = ""` and `compound = "Name"`.
- CAS and known identifier behavior is not regressed: `cas_number` still suggests `CASRN`, and `dtxsid` still suggests `Other`.
- Singular chemical tag de-duplication remains deterministic and still emits at most one `Name` and one `CASRN` suggestion.
- Focused tests are added or updated in `tests/testthat/test-auto-tag-columns.R`.

## Non-Goals

- Do not sample cell values for this fix.
- Do not auto-apply tags; suggestions must remain reviewable pre-fills.
- Do not broaden bare generic tokens such as `id`, `name`, `date`, or `value` into standalone suggestions.
