# Phase 48: WQX Resolution UI - Pattern Map

**Mapped:** 2026-05-07
**Files analyzed:** 2 (modified)
**Analogs found:** 2 / 2

---

## File Classification

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------|------|-----------|----------------|---------------|
| `R/curation.R` | service (pipeline) | transform | `R/curation.R:754-761` itself — targeted column addition | exact (self-patch) |
| `R/mod_review_results.R` | Shiny module (UI + server) | request-response + event-driven | `R/mod_review_results.R:1126-1288` (Compare modal pattern) | exact |

No new files are created in Phase 48. All work is additive modifications to two existing files.

---

## Pattern Assignments

### `R/curation.R` — wqx_confidence plumbing (lines 754-761)

**Change:** Extend the `wqx_rows` tibble to carry `wqx_confidence` instead of discarding `match_distance`.

**Existing code to patch** (`R/curation.R:754-761`):
```r
wqx_rows <- tibble::tibble(
  searchValue = wqx_resolved$input_name,
  dtxsid = NA_character_,
  preferredName = wqx_resolved$wqx_name,
  searchName = NA_character_,
  rank = NA_integer_,
  source_tier = paste0("wqx_", wqx_resolved$match_tier)
)
```

**After patch — copy this pattern:**
```r
wqx_rows <- tibble::tibble(
  searchValue = wqx_resolved$input_name,
  dtxsid = NA_character_,
  preferredName = wqx_resolved$wqx_name,
  searchName = NA_character_,
  rank = NA_integer_,
  source_tier = paste0("wqx_", wqx_resolved$match_tier),
  wqx_confidence = ifelse(
    wqx_resolved$match_tier == "fuzzy",
    1 - wqx_resolved$match_distance,  # JW distance -> similarity (0=bad, 1=perfect)
    NA_real_
  )
)
```

**Critical:** `match_wqx()` returns JW *distance* (0 = identical). D-01 specifies *similarity* (1 = perfect match). The conversion `1 - match_distance` is mandatory. For non-fuzzy rows, `match_distance` is already `NA_real_` — the `ifelse` guard is belt-and-suspenders.

**bind_rows behavior:** Non-WQX result tibbles in `all_results` lack `wqx_confidence`. `dplyr::bind_rows` fills missing columns with `NA_real_` — this is correct and expected, no special handling needed.

---

### `R/mod_review_results.R` — Four change points

#### Change Point 1: `derive_resolution_html()` — Add Review button (lines 143-155)

**Analog:** `compare-btn` pattern at lines 130-138 — inline button with `data-row` attribute.

**Existing wqx block** (`mod_review_results.R:143-155`):
```r
# wqx
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
```

**Pattern to copy — compare-btn HTML** (lines 130-138):
```r
result[compare_mask] <- paste0(
  '<button class="compare-btn btn btn-sm btn-outline-primary" data-row="',
  row_indices[compare_mask],
  '">',
  search_icon,
  ' Compare</button>'
)
```

**After patch — wqx block with Review button:**
```r
wqx_mask <- status == "wqx"
wqx_has_pref <- wqx_mask & !is.na(pref_name)
wqx_badge <- '<span class="badge bg-success ms-1" style="font-size:0.7em;">wqx</span>'
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

---

#### Change Point 2: `compare_js` block — Add `.wqx-review-btn` click handler (lines 260-287)

**Analog:** Existing `.compare-btn` handler at lines 263-266.

**Existing JS to copy** (`mod_review_results.R:263-266`):
```js
$(document).on('click', '.compare-btn', function() {
  var row = $(this).data('row');
  Shiny.setInputValue('{ns("compare_row_click")}', {row: row, t: Math.random()}, {priority: 'event'});
});
```

**New handler to add inside the same `sprintf(...)` block:**
```js
$(document).on('click', '.wqx-review-btn', function() {
  var row = $(this).data('row');
  Shiny.setInputValue('{ns("wqx_review_click")}', {row: row, t: Math.random()}, {priority: 'event'});
});
```

**Implementation note:** The `compare_js` block uses `sprintf()` with positional `%s` arguments — add `ns("wqx_review_click")` as a new argument at the matching position. Verify the `sprintf` argument count matches the `%s` count after edit.

---

#### Change Point 3: `renderReactable()` — Add `wqx_confidence` colDef (lines 630-945)

**Analog:** `n_rows` colDef (lines 730-744) for a simple non-badge numeric colDef. The `Resolution` colDef (line 880) for `html = TRUE` baseline.

**Pattern to copy — simple numeric colDef:**
```r
col_defs[["n_rows"]] <- reactable::colDef(
  name = "Rows",
  minWidth = 60,
  cell = function(value, index) { ... }
)
```

**New colDef for wqx_confidence:**
```r
if ("wqx_confidence" %in% names(df_display)) {
  col_defs[["wqx_confidence"]] <- reactable::colDef(
    name = "WQX Conf.",
    minWidth = 80,
    cell = function(value, index) {
      if (is.na(value)) return("")
      formatC(value, digits = 2, format = "f")
    }
  )
}
```

**Colvis note:** `wqx_confidence` must NOT appear in `always_hidden` (lines 700-710) or `untagged_cols` (lines 714-716). An explicit `colDef` without `show = FALSE` makes it visible by default. The conditional `if ("wqx_confidence" %in% names(df_display))` guard handles the case where old data without this column is still in session.

---

#### Change Point 4: New `observeEvent` handlers — WQX Review modal (after line 1313)

**Analog:** Complete Compare modal flow at lines 1126-1312. Copy the following sub-patterns:

**4a. Modal open observer — copy from `observeEvent(input$compare_row_click)` (lines 1126-1244):**
```r
observeEvent(input$wqx_review_click, {
  req(data_store$resolution_state)

  row_idx <- input$wqx_review_click$row
  row <- data_store$resolution_state[row_idx, ]

  # Store modal state (reuse existing field or add wqx_modal_row_idx)
  data_store$wqx_modal_row_idx <- row_idx

  # Read display context from resolution_state row
  input_name   <- row$searchValue          # original upload name
  wqx_name     <- ...                      # from pref_name (first non-NA preferredName_*)
  match_tier   <- ...                      # from source_tier_* column
  confidence   <- row$wqx_confidence       # NA for non-fuzzy

  showModal(modalDialog(
    title = "Review WQX Match",
    ...,                                   # modal body (see UI spec)
    footer = tagList(
      actionButton(session$ns("wqx_modal_confirm"), "Use Selected Name", class = "btn-primary"),
      tags$button(
        class = "btn btn-outline-danger",
        onclick = sprintf(
          "Shiny.setInputValue('%s', {t: Math.random()}, {priority: 'event'});",
          session$ns("wqx_reject_click")
        ),
        "Reject"
      ),
      modalButton("Cancel")
    ),
    size = "m",
    easyClose = TRUE
  ))

  # MUST call updateSelectizeInput AFTER showModal
  cache_dir <- system.file("extdata", "reference_cache", package = "chemreg")
  wqx_dict <- load_wqx_dictionary(cache_dir)
  display_type <- ifelse(wqx_dict$type == "canonical", "canonical", "alias")
  wqx_labels <- paste0(wqx_dict$name, " (", display_type, ")")
  wqx_choices <- stats::setNames(wqx_dict$canonical_name, wqx_labels)
  updateSelectizeInput(session, "wqx_typeahead", choices = wqx_choices, server = TRUE)
})
```

**4b. Override confirm observer — copy from `observeEvent(input$modal_confirm)` (lines 1252-1288):**
```r
observeEvent(input$wqx_modal_confirm, {
  row_idx <- data_store$wqx_modal_row_idx
  new_name <- input$wqx_typeahead

  if (is.null(new_name) || new_name == "") {
    showNotification("Please select a WQX name first", type = "warning")
    return()
  }

  # Group-propagated mutation (copy from lines 1268-1274)
  group_rows <- get_group_rows(row_idx, isolate(data_store$dedup_group_map))
  updated_df <- data_store$resolution_state
  for (r in group_rows) {
    # Update the preferredName_* column for the WQX source column
    # Preferred approach: add wqx_override_name column to resolution_state
    updated_df$wqx_override_name[r] <- new_name
    # consensus_status stays "wqx" — no change needed
  }
  data_store$resolution_state <- updated_df
  data_store$consensus_summary <- recalc_consensus_summary(updated_df)

  removeModal()
  showNotification(
    sprintf("WQX match updated to '%s' for %d row(s)", new_name, length(group_rows)),
    type = "message"
  )
  data_store$wqx_modal_row_idx <- NULL
})
```

**4c. Reject observer — copy mutation pattern from modal_skip (lines 1291-1312):**
```r
observeEvent(input$wqx_reject_click, {
  row_idx <- data_store$wqx_modal_row_idx
  if (is.null(row_idx)) return()

  group_rows <- get_group_rows(row_idx, isolate(data_store$dedup_group_map))
  updated_df <- data_store$resolution_state
  for (r in group_rows) {
    updated_df$consensus_status[r] <- "unresolvable"
    updated_df$needs_review[r] <- TRUE
  }
  data_store$resolution_state <- updated_df
  data_store$consensus_summary <- recalc_consensus_summary(updated_df)

  removeModal()
  showNotification(
    sprintf("%d row(s) marked as unresolvable", length(group_rows)),
    type = "message"
  )
  data_store$wqx_modal_row_idx <- NULL
})
```

**selectizeInput UI declaration (in modal body):**
```r
selectizeInput(
  session$ns("wqx_typeahead"),
  label = NULL,
  choices = NULL,
  options = list(
    placeholder = "Type to search WQX names...",
    maxOptions = 20
  )
)
```

---

## Shared Patterns

### Group-Propagated State Mutation
**Source:** `R/mod_review_results.R:1268-1274`
**Apply to:** Both `wqx_modal_confirm` and `wqx_reject_click` observers
```r
group_rows <- get_group_rows(row_idx, isolate(data_store$dedup_group_map))
updated_df <- data_store$resolution_state
for (r in group_rows) {
  # ... mutate updated_df[r, columns] ...
}
data_store$resolution_state <- updated_df
data_store$consensus_summary <- recalc_consensus_summary(updated_df)
```

### Modal State Tracking
**Source:** `R/mod_review_results.R:1144-1146, 1286-1287`
**Apply to:** WQX Review modal open/close observers
```r
# On open:
data_store$wqx_modal_row_idx <- row_idx

# On close (confirm or reject):
data_store$wqx_modal_row_idx <- NULL
```

### JS Event Dispatch
**Source:** `R/mod_review_results.R:263-266`
**Apply to:** `.wqx-review-btn` click handler in `compare_js` sprintf block
```js
$(document).on('click', '.wqx-review-btn', function() {
  var row = $(this).data('row');
  Shiny.setInputValue('{ns("wqx_review_click")}', {row: row, t: Math.random()}, {priority: 'event'});
});
```

### showNotification Pattern
**Source:** `R/mod_review_results.R:1283-1284`
**Apply to:** All three WQX modal observers
```r
removeModal()
showNotification(notification_msg, type = "message")
```

---

## preferredName Override Strategy (Discretionary — Pitfall 3 Mitigation)

The RESEARCH.md identifies ambiguity in which `preferredName_*` column to update for WQX rows (Pitfall 3). The recommended discretionary approach is:

**Add a `wqx_override_name` column** to `resolution_state`. Modify `derive_resolution_html()` to prefer it over `pref_name` when set for WQX rows:

```r
# In derive_resolution_html(), in the wqx section, before existing pref_name logic:
wqx_override <- if ("wqx_override_name" %in% names(df)) df$wqx_override_name else rep(NA_character_, n)

# Use wqx_override_name when set, fall back to pref_name
effective_name <- ifelse(!is.na(wqx_override), wqx_override, pref_name)
wqx_has_pref <- wqx_mask & !is.na(effective_name)
result[wqx_has_pref] <- paste0(
  "\u2705 ",
  htmltools::htmlEscape(effective_name[wqx_has_pref]),
  " ",
  wqx_badge,
  review_btn(row_indices[wqx_has_pref])
)
```

The `wqx_override_name` column is initialized as `NA_character_` via `bind_rows` when not present in non-WQX rows — correct behavior.

---

## Testing Patterns

### Existing test file to extend
**File:** `tests/testthat/test-mod-review-helpers.R`
**Current coverage:** `recalc_consensus_summary`, `derive_match_type`, `derive_resolution_html` (WQX badge, name rendering, agree regression)

**Pattern to copy for new tests** (from lines 73-98 of test file):
```r
test_that("derive_resolution_html includes wqx-review-btn for WQX rows", {
  df <- data.frame(
    consensus_status = c("wqx"),
    consensus_dtxsid = c(NA_character_),
    preferredName_Chemical = c("Dissolved oxygen (DO)"),
    .pinned = c(FALSE),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  result <- derive_resolution_html(df, row_indices = 1L)
  expect_match(result, "wqx-review-btn")
  expect_match(result, 'data-row="1"')
})
```

**New tests needed (add to `test-mod-review-helpers.R`):**
- `wqx_confidence` is `1 - match_distance` for fuzzy rows
- `wqx_confidence` is `NA` for exact and alias rows
- `derive_resolution_html` includes `wqx-review-btn` for WQX rows
- `derive_resolution_html` includes `data-row` attribute matching `row_indices`

---

## No Analog Found

None. All patterns have direct analogs in the existing codebase.

---

## Metadata

**Analog search scope:** `R/mod_review_results.R`, `R/curation.R`, `tests/testthat/test-mod-review-helpers.R`
**Files scanned:** 3 primary + CONTEXT.md + RESEARCH.md
**Pattern extraction date:** 2026-05-07
