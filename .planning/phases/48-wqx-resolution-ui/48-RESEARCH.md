# Phase 48: WQX Resolution UI - Research

**Researched:** 2026-05-07
**Domain:** Shiny module extension — WQX review modal, selectizeInput server-side search, resolution_state mutation
**Confidence:** HIGH (all findings from direct codebase reads)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Add dedicated `wqx_confidence` numeric column to Review Results reactable. Jaro-Winkler similarity (0.00–1.00) for fuzzy rows only; blank (NA) for exact and alias. Visible by default, hideable via colvis.
- **D-02:** `match_distance` from `match_wqx()` is currently discarded in `curation.R:754-761`. Must carry through to resolution_state.
- **D-03:** Teal "Review" button on ALL WQX-resolved rows (exact, alias, fuzzy). Opens a modal.
- **D-04:** Review button uses same JS `Shiny.setInputValue` pattern as `.compare-btn`.
- **D-05:** WQX Review modal has three actions in one view: Accept current, Pick different (type-ahead), Reject.
- **D-06:** Type-ahead is `selectizeInput` with server-side rendering, searching WQX dictionary (~124K rows). Results annotated with type (canonical vs alias).
- **D-07:** Modal context: original input name, current WQX match name, match score (if fuzzy), match type.
- **D-08:** WQX overrides reuse existing consensus_status values. Override → `consensus_status` stays "wqx", `preferredName` updated. Rejection → `consensus_status` = "unresolvable", `needs_review = TRUE`.
- **D-09:** `export_helpers.R` and value box summary logic require no changes.

### Claude's Discretion
- Internal wiring of how `match_distance` propagates through `run_curation_pipeline()` to `resolution_state`
- Whether selectizeInput uses `choices` or `options` with `server = TRUE` for the 124K-row dictionary
- Modal layout details (card styling, spacing, button placement)
- How the type-ahead result replaces the existing WQX match in `resolution_state` (direct column assignment vs helper function)
- Dedup group propagation for WQX overrides (should follow existing `get_group_rows()` pattern)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

## Summary

Phase 48 extends `mod_review_results.R` in three areas: (1) carrying `match_distance` from `wqx_matching.R` through `curation.R` into `resolution_state` as a `wqx_confidence` column, (2) adding a "Review" button to WQX rows in `derive_resolution_html()` that opens a new modal, and (3) implementing the modal's three-action flow (accept / type-ahead override / reject) backed by `resolution_state` mutation. The Compare modal pattern (`mod_review_results.R:1126-1288`) is the definitive template for the WQX Review modal — the structure, JS wiring, and `data_store` state tracking are all reusable.

The only pipeline change is adding `wqx_confidence` to `wqx_rows` tibble at `curation.R:754-761`. Everything else is confined to `mod_review_results.R`. The WQX dictionary already has the columns needed (`name`, `canonical_name`, `type`) for type-ahead search. Server-side selectizeInput (`updateSelectizeInput(..., server = TRUE)`) with `choices` as a named vector is the correct pattern for 124K rows.

**Primary recommendation:** Implement in three sequential tasks — (1) pipeline plumbing for `wqx_confidence`, (2) Review button in `derive_resolution_html()` + JS wiring, (3) modal observers + `resolution_state` mutation.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| wqx_confidence plumbing | curation.R | resolution_state | Pipeline builds the tibble; state carries it |
| Review button rendering | derive_resolution_html() | reactable colDef | HTML built in helper; rendered via `html = TRUE` colDef |
| JS event dispatch | Browser (inline script) | Shiny server | Same pattern as compare-btn |
| Modal display + context | Shiny server (mod_review_results_server) | — | observeEvent reads resolution_state, calls showModal |
| Type-ahead search | Shiny server (updateSelectizeInput) | WQX dictionary (cleaning_reference.R) | Server-side filtering; dictionary already loaded in curation pipeline |
| resolution_state mutation | Shiny server | get_group_rows() | All state changes go through resolution_state reactiveVal |
| Export persistence | export_helpers.R | — | No changes needed — reads resolution_state as-is |

---

## Standard Stack

### Core (all already in project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shiny | existing | `observeEvent`, `selectizeInput`, `updateSelectizeInput`, `showModal` | Project foundation |
| bslib | existing | Modal layout, card styling (Bootstrap 5) | Project theme |
| reactable | existing | Table with `html = TRUE` colDef for Resolution column | Already used for curation_table |
| htmltools | existing | `htmlEscape()`, `tags$*` in modal body | Already used in derive_resolution_html |

No new package dependencies. All capabilities are available in the current stack.

---

## Architecture Patterns

### System Architecture Diagram

```
Pipeline (curation.R)
  match_wqx() returns match_distance
       |
  wqx_rows tibble [ADD wqx_confidence column here at line 754-761]
       |
  all_results list -> bind_rows -> classified_df
       |
  init_resolution_state() -> resolution_state (now carries wqx_confidence)
       |
mod_review_results_server()
  |
  renderReactable()
    |-- derive_resolution_html()  [ADD Review button for wqx_mask rows]
    |-- colDef for wqx_confidence [new: numeric, show=TRUE, minWidth=80]
    |
  JS script block (in mod_review_results_ui)
    [ADD .wqx-review-btn click handler -> Shiny.setInputValue(ns("wqx_review_click"))]
    |
  observeEvent(input$wqx_review_click)
    |-- reads resolution_state[row_idx, ]
    |-- loads WQX dictionary (load_wqx_dictionary)
    |-- calls updateSelectizeInput(server = TRUE, choices = wqx_choices)
    |-- showModal(wqx_review_modal_ui)
    |
  observeEvent(input$wqx_typeahead)  [type-ahead selection]
    |-- show confirmation card (renderUI or shinyjs::show)
    |-- show "Use Selected Name" button
    |
  observeEvent(input$wqx_modal_confirm)  [override]
    |-- get_group_rows() -> update resolution_state preferredName
    |-- consensus_status stays "wqx"
    |-- removeModal(), notification
    |
  observeEvent(input$wqx_reject_click)  [reject]
    |-- get_group_rows() -> set consensus_status = "unresolvable"
    |-- needs_review = TRUE
    |-- removeModal(), notification
```

### Recommended Change Points

```
R/curation.R
  line 754-761: wqx_rows tibble — ADD wqx_confidence column

R/mod_review_results.R
  line 260-287: compare_js block — ADD .wqx-review-btn click handler
  line 143-153: derive_resolution_html() wqx_mask branch — ADD Review button
  line 630-945: renderReactable — ADD wqx_confidence colDef
  line 700-727: always_hidden logic — ensure wqx_confidence NOT in always_hidden
  after line 1313: ADD new observeEvent handlers (wqx_review_click, wqx_modal_confirm, wqx_reject_click, wqx_typeahead)
```

---

## Key Code Facts (Verified from Source)

### 1. match_distance discard point — `curation.R:754-761` [VERIFIED]

```r
# CURRENT (discards match_distance):
wqx_rows <- tibble::tibble(
  searchValue = wqx_resolved$input_name,
  dtxsid = NA_character_,
  preferredName = wqx_resolved$wqx_name,
  searchName = NA_character_,
  rank = NA_integer_,
  source_tier = paste0("wqx_", wqx_resolved$match_tier)
)

# AFTER CHANGE (carry match_distance as wqx_confidence):
wqx_rows <- tibble::tibble(
  searchValue = wqx_resolved$input_name,
  dtxsid = NA_character_,
  preferredName = wqx_resolved$wqx_name,
  searchName = NA_character_,
  rank = NA_integer_,
  source_tier = paste0("wqx_", wqx_resolved$match_tier),
  wqx_confidence = ifelse(
    wqx_resolved$match_tier == "fuzzy",
    1 - wqx_resolved$match_distance,   # JW distance to similarity: 1 - distance
    NA_real_
  )
)
```

**CRITICAL NOTE:** `match_wqx()` returns JW **distance** (0=identical, 1=maximally different). D-01 specifies showing JW **similarity** (0.00–1.00 where 1.00 = perfect match). The conversion is `similarity = 1 - match_distance`. Apply this at the assignment point in `curation.R`.

For exact and alias rows, `match_distance` is already `NA_real_` (see `wqx_matching.R:83`, `wqx_matching.R:97`). The `ifelse` guard is a belt-and-suspenders check.

### 2. WQX dictionary columns — `cleaning_reference.R:598` [VERIFIED]

`load_wqx_dictionary()` returns tibble with columns: `name`, `canonical_name`, `type`, `cas_number`, `group_name`, `description`.

`type` values: `"canonical"`, `"synonym"`, `"standardize"`, `"retired"`.

For type-ahead display, collapse synonym/standardize/retired into "alias":

```r
wqx_dict <- load_wqx_dictionary(cache_dir)
# Build choices for selectizeInput: label = "Name (type)", value = canonical_name
display_type <- ifelse(wqx_dict$type == "canonical", "canonical", "alias")
wqx_labels <- paste0(wqx_dict$name, " (", display_type, ")")
wqx_choices <- stats::setNames(wqx_dict$canonical_name, wqx_labels)
# updateSelectizeInput(..., choices = wqx_choices, server = TRUE)
```

**IMPORTANT:** `wqx_choices` values are `canonical_name` — so the selected value is already the canonical name to store in `preferredName`. No further lookup needed.

### 3. derive_resolution_html() WQX section — `mod_review_results.R:143-155` [VERIFIED]

```r
# CURRENT:
wqx_mask <- status == "wqx"
wqx_has_pref <- wqx_mask & !is.na(pref_name)
wqx_badge <- '<span class="badge bg-success ms-1" style="font-size:0.7em;">wqx</span>'
result[wqx_has_pref] <- paste0(
  "\u2705 ",
  htmltools::htmlEscape(pref_name[wqx_has_pref]),
  " ",
  wqx_badge
)
result[wqx_mask & !wqx_has_pref] <- paste0("\u2705 WQX matched ", wqx_badge)

# AFTER CHANGE — add Review button:
review_btn <- function(idx) {
  paste0(
    ' <button class="wqx-review-btn btn btn-sm btn-outline-success" data-row="',
    idx, '">Review</button>'
  )
}
result[wqx_has_pref] <- paste0(
  "\u2705 ",
  htmltools::htmlEscape(pref_name[wqx_has_pref]),
  " ",
  wqx_badge,
  review_btn(row_indices[wqx_has_pref])
)
result[wqx_mask & !wqx_has_pref] <- paste0(
  "\u2705 WQX matched ",
  wqx_badge,
  review_btn(row_indices[wqx_mask & !wqx_has_pref])
)
```

### 4. Compare modal JS pattern — `mod_review_results.R:260-287` [VERIFIED]

```js
$(document).on('click', '.compare-btn', function() {
  var row = $(this).data('row');
  Shiny.setInputValue('{ns("compare_row_click")}', {row: row, t: Math.random()}, {priority: 'event'});
});
```

WQX review button follows this exactly, using `wqx_review_click` as the input name.

### 5. resolution_state mutation pattern — `mod_review_results.R:1268-1288` [VERIFIED]

The Compare modal confirm uses this exact pattern for group-propagated mutation:

```r
group_rows <- get_group_rows(row_idx, isolate(data_store$dedup_group_map))
updated_df <- data_store$resolution_state
for (r in group_rows) {
  updated_df <- resolve_row(updated_df, r, chosen_column, data_store$dtxsid_cols)
}
data_store$resolution_state <- updated_df
data_store$consensus_summary <- recalc_consensus_summary(updated_df)
removeModal()
```

For WQX override, `resolve_row()` does not apply (it picks from existing DTXSID columns). The pattern instead is direct column assignment:

```r
group_rows <- get_group_rows(row_idx, isolate(data_store$dedup_group_map))
updated_df <- data_store$resolution_state
new_name <- input$wqx_typeahead   # the canonical name from type-ahead
for (r in group_rows) {
  # Find the preferredName column for this row's source column
  # Simplest approach: update all preferredName_* columns that currently match
  # OR: update consensus_preferredName directly if it exists
  # Check what column holds the displayed preferred name for WQX rows
}
```

**DISCOVERY NEEDED:** `derive_resolution_html()` reads `pref_name` by scanning `preferredName_*` columns. For WQX rows, this is the `preferredName` set in `wqx_rows` tibble. Need to verify the exact column name that holds `pref_name` for WQX rows after classification. The `pref_cols` loop at line 61 reads the first non-NA `preferredName_*` column. For WQX rows, this is `preferredName_{source_column_name}` set during `bind_rows` in `curation.R`. To override, update that column directly.

**Simpler approach (discretionary):** Add a dedicated `wqx_override_name` column to resolution_state, modify `derive_resolution_html()` to prefer it when set. This avoids ambiguity about which `preferredName_*` column to update.

### 6. selectizeInput server-side pattern [VERIFIED — standard Shiny]

For 124K-row datasets, the correct pattern:

```r
# UI: declare with NULL choices — server will populate
selectizeInput(ns("wqx_typeahead"), label = NULL, choices = NULL,
  options = list(placeholder = "Type to search WQX names...", maxOptions = 20))

# Server: load dictionary once on modal open, pass with server=TRUE
wqx_dict <- load_wqx_dictionary(cache_dir)
display_type <- ifelse(wqx_dict$type == "canonical", "canonical", "alias")
wqx_labels <- paste0(wqx_dict$name, " (", display_type, ")")
wqx_choices <- stats::setNames(wqx_dict$canonical_name, wqx_labels)
updateSelectizeInput(session, "wqx_typeahead", choices = wqx_choices, server = TRUE)
```

`server = TRUE` sends choices lazily to the browser — only matched options are transferred, not all 124K rows at once. This is the correct approach for large choice sets.

**PITFALL:** `updateSelectizeInput` must be called after `showModal()` to ensure the input exists in the DOM. Call it inside the same `observeEvent(input$wqx_review_click)` block, after `showModal()`.

### 7. WQX dictionary load location [VERIFIED]

In `curation.R:746-747`, the dictionary is loaded as:
```r
cache_dir <- system.file("extdata", "reference_cache", package = "chemreg")
wqx_dict <- load_wqx_dictionary(cache_dir)
```

The same pattern applies in `mod_review_results_server()` for modal type-ahead. The dictionary is cached as RDS so repeated loads are fast.

### 8. Modal state management [VERIFIED]

The Compare modal uses `data_store$modal_row_idx` and `data_store$modal_selected_column`. The WQX Review modal should use parallel fields: `data_store$wqx_modal_row_idx`. Since both modals can't be open simultaneously, reusing `data_store$modal_row_idx` is also acceptable (discretionary).

### 9. colvis mechanism for new column [VERIFIED]

The colvis toggle at `mod_review_results.R:700-727` uses two categories:
- `always_hidden` — internal columns never shown
- `untagged_cols` — visible only when checked

`wqx_confidence` should be in **neither** — it should be visible by default. The colvis toggle is implemented as checkboxes for `untagged_cols`. To make `wqx_confidence` hideable, it needs to be added to the `untagged_cols` pool. The simplest approach: add it to `untagged_cols` explicitly after the column exists in `df_display`, or treat it as a named visible column that the toggle manages. Review the toggle mechanism at lines 714-719 for the exact pattern.

### 10. Test file coverage [VERIFIED]

Existing test file: `tests/testthat/test-mod-review-helpers.R` covers `derive_resolution_html()` for WQX rows. New tests for Review button HTML and `wqx_confidence` column should go in this file. New modal observer tests (if any unit tests are written) would also go here.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Large-set type-ahead | Custom AJAX search | `updateSelectizeInput(..., server = TRUE)` | Built into Shiny; handles lazy transfer |
| Dedup group propagation | Custom loop | `get_group_rows()` at line 173 | Already exists, handles NULL map case |
| Group-aware state update | Custom `lapply` | Loop over `get_group_rows()` result, direct df mutation | Established pattern in compare modal confirm |
| HTML escaping in button | Manual replace | `htmltools::htmlEscape()` | Already used throughout derive_resolution_html |

---

## Common Pitfalls

### Pitfall 1: JW Distance vs Similarity Inversion
**What goes wrong:** Storing `match_distance` directly as `wqx_confidence` — gives scores where lower = better match (0.13 for a good match), but D-01 specifies "similarity score (0.00–1.00)" where higher = better.
**Why it happens:** `match_wqx()` returns JW *distance* (`match_distance`), not similarity.
**How to avoid:** Apply `wqx_confidence = 1 - match_distance` at `curation.R:754-761`.
**Warning signs:** Fuzzy match rows showing confidence near 0 for clearly-good matches.

### Pitfall 2: updateSelectizeInput Before DOM Exists
**What goes wrong:** Calling `updateSelectizeInput` before `showModal()` — the input element doesn't exist yet, choices are silently dropped.
**Why it happens:** `showModal()` is async; the selectizeInput inside it hasn't rendered when `updateSelectizeInput` fires.
**How to avoid:** Call `updateSelectizeInput` immediately after `showModal()` in the same `observeEvent` block. Shiny's rendering pipeline ensures the modal is queued first.

### Pitfall 3: preferredName Column Ambiguity for WQX Rows
**What goes wrong:** WQX rows have `preferredName_{source_col}` set during pipeline. Updating the wrong column (or a column that doesn't exist) leaves `derive_resolution_html()` showing the old name.
**Why it happens:** The `pref_cols` loop in `derive_resolution_html()` reads first non-NA `preferredName_*` column. If the override goes to a different column than what was set during curation, the old value may still take precedence.
**How to avoid:** Either (a) add a `wqx_override_name` column and check it first in `derive_resolution_html()`, or (b) identify the exact `preferredName_*` column used for the row and update it directly. Option (a) is safer.

### Pitfall 4: wqx_confidence Column Not Propagating Through bind_rows
**What goes wrong:** Adding `wqx_confidence` to `wqx_rows` but not accounting for other tibbles in `all_results` that don't have this column — `bind_rows` fills them with NA which is correct behavior.
**Why it happens:** Non-WQX result tibbles lack `wqx_confidence`.
**How to avoid:** This is expected and correct — `bind_rows` fills missing columns with NA. No special handling needed.

### Pitfall 5: Colvis Not Including wqx_confidence
**What goes wrong:** `wqx_confidence` is always hidden or never toggleable because it falls into `always_hidden` or is not in the toggle mechanism.
**Why it happens:** The colvis toggle at lines 714-719 only handles `untagged_cols` (columns from the original upload that weren't tagged). `wqx_confidence` is a pipeline-added column, not an original column.
**How to avoid:** Add explicit `colDef` for `wqx_confidence` that doesn't set `show = FALSE`. The colvis toggle may need a special case for pipeline-added columns, or simply leave `wqx_confidence` out of the `always_hidden` and `untagged_cols` sets so it renders with default visibility (visible).

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat (existing) |
| Config file | `tests/testthat.R` |
| Quick run command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-mod-review-helpers.R')"` |
| Full suite command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "devtools::load_all(); testthat::test_dir('tests/testthat')"` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| CONF-03 | wqx_confidence column shows similarity score for fuzzy rows | unit | `test_file('tests/testthat/test-mod-review-helpers.R')` | Extend existing |
| CONF-03 | wqx_confidence is NA for exact/alias rows | unit | same | Extend existing |
| RES-01 | type-ahead selectize receives WQX dictionary choices | unit/smoke | Shiny smoke test | New test needed |
| RES-02 | reject sets consensus_status = "unresolvable" + needs_review | unit | `test_file('tests/testthat/test-mod-review-helpers.R')` | New test in existing file |
| RES-02 | type-ahead override updates preferredName, keeps consensus_status "wqx" | unit | same | New test in existing file |
| RES-03 | export includes wqx_confidence column | unit | `test_file('tests/testthat/test-export-import.R')` | May need extension |

### Wave 0 Gaps
- [ ] Add `wqx_confidence` column tests to `tests/testthat/test-mod-review-helpers.R` (helper tests for derive_resolution_html with Review button, wqx_confidence value assertions)
- [ ] Shiny smoke test after any UI change (CLAUDE.md requirement)

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `preferredName_*` columns for WQX rows are named after the source column (e.g., `preferredName_Chemical`) — adding `wqx_override_name` approach avoids ambiguity | Pitfall 3 | If existing column structure differs, override wiring may need adjustment |
| A2 | WQX dictionary size is ~124K rows (from CONTEXT.md D-06) | Type-ahead | If significantly larger, `updateSelectizeInput server=TRUE` still handles it but performance testing needed |

---

## Sources

### Primary (HIGH confidence — direct codebase reads)
- `R/curation.R:754-761` — wqx_rows tibble construction (discard point for match_distance)
- `R/wqx_matching.R:19-205` — match_wqx() return signature, JW distance semantics
- `R/mod_review_results.R:48-156` — derive_resolution_html() full implementation
- `R/mod_review_results.R:260-287` — compare_js JS event pattern
- `R/mod_review_results.R:1126-1313` — Compare modal full flow
- `R/mod_review_results.R:629-946` — renderReactable, colDef structure, colvis mechanism
- `R/cleaning_reference.R:519-603` — WQX dictionary columns and load function
- `R/consensus.R:89-108` — WQX guard in classify_consensus
- `R/export_helpers.R:40-86` — needs_review flag logic, no wqx-specific changes needed
- `.planning/phases/48-wqx-resolution-ui/48-UI-SPEC.md` — approved UI design contract

## Metadata

**Confidence breakdown:**
- Pipeline plumbing (match_distance carry): HIGH — discard point read directly, conversion math confirmed
- Review button pattern: HIGH — derive_resolution_html and compare-btn both read directly
- Modal pattern: HIGH — Compare modal read in full, structure reusable
- selectizeInput server-side: HIGH — standard Shiny pattern, no external lookup needed
- resolution_state mutation: HIGH — both compare modal and direct mutation patterns read
- preferredName override column: MEDIUM — exact column name for WQX rows requires runtime verification (see A1)

**Research date:** 2026-05-07
**Valid until:** 2026-06-07 (stable codebase, no external dependencies)
