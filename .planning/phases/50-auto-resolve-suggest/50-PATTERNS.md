# Phase 50: Auto-Resolve & Suggest - Pattern Map

**Mapped:** 2026-05-10
**Files analyzed:** 3 (R/consensus.R, R/mod_review_results.R, R/export_helpers.R)
**Analogs found:** 3 / 3

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `R/consensus.R` | service | CRUD / transform | `R/consensus.R` (self — extending existing functions) | exact |
| `R/mod_review_results.R` | component (Shiny module) | event-driven / request-response | `R/mod_review_results.R` (self — extending existing module) | exact |
| `R/export_helpers.R` | utility | transform / batch | `R/export_helpers.R` (self — extending existing helper) | exact |

---

## Pattern Assignments

### `R/consensus.R` — auto-resolve/suggest classification, init_resolution_state extensions, resolve_row extensions, accept-all-suggestions

**Analog:** `R/consensus.R` (self-extension)

#### `init_resolution_state()` extension pattern (lines 165–173)

The existing function guards with `if (!".pinned" %in% names(df))` before adding each column. Add `.resolution_method` and `.resolution_reason` with the same guard pattern:

```r
init_resolution_state <- function(df) {
  if (!".pinned" %in% names(df)) {
    df$.pinned <- FALSE
  }
  if (!".manual_entry" %in% names(df)) {
    df$.manual_entry <- FALSE
  }
  # NEW for Phase 50:
  if (!".resolution_method" %in% names(df)) {
    df$.resolution_method <- NA_character_
  }
  if (!".resolution_reason" %in% names(df)) {
    df$.resolution_reason <- NA_character_
  }
  df
}
```

#### `compute_similarity_scores()` — classification step pattern (lines 313–381)

The scoring loop iterates `disagree_idx`, builds `candidate_scores` per row, and writes `scores[i]`. The new `classify_auto_resolve()` function should run immediately after `compute_similarity_scores()` and follow the same index-vector pattern:

```r
# Pattern: vectorized index loop writing back to df columns
for (i in disagree_idx) {
  # ... compute per-row result ...
  scores[i] <- max(candidate_scores)
}
resolution_state$similarity_score <- scores
resolution_state
```

The new classification function needs per-candidate scores (best and second-best), not just the row's best score. It must re-loop over `dtxsid_cols` to collect all candidate scores before applying thresholds D-01/D-02/D-03.

#### `resolve_row()` — single-row resolution pattern to model auto-resolve (lines 395–421)

```r
resolve_row <- function(df, row_idx, chosen_column, dtxsid_cols) {
  # Validate row is disagree
  if (df$consensus_status[row_idx] != "disagree") {
    stop("Row ", row_idx, " is not a disagree row (status: ", df$consensus_status[row_idx], ")")
  }
  # Validate chosen_column exists and has data
  if (!chosen_column %in% dtxsid_cols) {
    stop("Column '", chosen_column, "' is not in dtxsid_cols")
  }
  val <- df[[chosen_column]][row_idx]
  if (is.na(val)) {
    stop("Column '", chosen_column, "' has NA value for row ", row_idx)
  }
  # Initialize resolution state
  df <- init_resolution_state(df)
  # Set consensus
  df$consensus_dtxsid[row_idx] <- val
  df$consensus_source[row_idx] <- sub("^dtxsid_", "", chosen_column)
  df$.pinned[row_idx] <- TRUE
  df
}
```

**For auto-resolve**, extend `resolve_row()` or write a wrapper that additionally sets:
- `df$.resolution_method[row_idx] <- "auto"` (or `"suggested-accept"` / `"bulk-accept"`)
- `df$.resolution_reason[row_idx] <- sprintf("score=%.2f, gap=%.2f, threshold=0.95", best_score, gap)`

Note that `resolve_row()` validates `consensus_status == "disagree"`. Auto-resolved rows should be processed before `consensus_status` changes, OR the wrapper must allow `"suggested"` and `"auto_resolved"` statuses.

#### `apply_priority_chain()` — bulk resolution pattern for "Accept All Suggestions" (lines 434–458)

```r
apply_priority_chain <- function(df, priority_order, dtxsid_cols) {
  df <- init_resolution_state(df)

  for (i in seq_len(nrow(df))) {
    # Only process disagree rows that are not pinned
    if (df$consensus_status[i] != "disagree") {
      next
    }
    if (isTRUE(df$.pinned[i])) {
      next
    }
    # Walk priority order, pick first with non-NA value
    for (col in priority_order) {
      val <- df[[col]][i]
      if (!is.na(val)) {
        df$consensus_dtxsid[i] <- val
        df$consensus_source[i] <- sub("^dtxsid_", "", col)
        break
      }
    }
  }
  df
}
```

**`accept_all_suggestions()` must follow this exact pattern:**
- `if (df$consensus_status[i] != "suggested") next`
- `if (isTRUE(df$.pinned[i])) next`
- Resolve using the best-scoring candidate column (stored at classification time — see D-11)
- Set `.resolution_method[i] <- "bulk-accept"` and `.resolution_reason[i]`
- Set `.pinned[i] <- TRUE` and `consensus_status[i] <- "agree"` (or keep `"suggested"` then change)

#### `classify_consensus()` — status values to extend (lines 58–152)

The function uses a pre-allocated character vector `consensus_status <- character(nrow(df))` and fills it with `"agree"`, `"disagree"`, `"error"`, etc. The new `classify_auto_resolve()` post-processor (runs after `compute_similarity_scores()`) must update `consensus_status` from `"disagree"` to `"auto_resolved"` or `"suggested"` using vectorized index assignments, not inside `classify_consensus()` itself:

```r
# Pattern: vectorized status update
auto_idx <- which(...)  # rows meeting auto-resolve threshold
suggested_idx <- which(...)  # rows meeting suggest threshold
df$consensus_status[auto_idx] <- "auto_resolved"
df$consensus_status[suggested_idx] <- "suggested"
df$.pinned[auto_idx] <- TRUE
```

---

### `R/mod_review_results.R` — status chips, modal suggestion highlight, accept button, bulk accept button

**Analog:** `R/mod_review_results.R` (self-extension)

#### Status chip color pattern (lines 867–903)

The `consensus_status` colDef uses a named color vector and `status_levels` intersection to build filterable dropdown chips:

```r
status_levels <- intersect(
  c("agree", "agree_caveat", "single", "wqx", "disagree", "error", "manual", "unresolvable"),
  unique(as.character(df_display$consensus_status))
)
status_colors <- c(
  "agree"        = "#28a745",
  "agree_caveat" = "#17a2b8",
  "single"       = "#6c757d",
  "wqx"          = "#20c997",
  "disagree"     = "#fd7e14",
  "error"        = "#343a40",
  "manual"       = "#6f42c1",
  "unresolvable" = "#721c24"
)

col_defs[["consensus_status"]] <- reactable::colDef(
  cell = function(value, index) {
    val <- as.character(value)
    bg <- status_colors[val] %||% "#6c757d"
    htmltools::span(
      style = sprintf(
        "background:%s;color:#fff;padding:2px 8px;border-radius:4px;font-weight:600;font-size:0.85em;display:inline-block;",
        bg
      ),
      val
    )
  },
  filterMethod = htmlwidgets::JS(
    "function(rows, columnId, filterValue) {
      return rows.filter(function(row) {
        return row.values[columnId] === filterValue;
      });
    }"
  ),
  filterInput = make_select_filter(status_levels, "consensus_status")
)
```

**Add to `status_levels` vector:** `"auto_resolved"` and `"suggested"` (already done by the `intersect()` pattern — just extend `status_levels` and `status_colors`).

Proposed colors (Claude's discretion per D-05):
- `"auto_resolved"` = `"#0dcaf0"` (Bootstrap info-blue, distinct from manual purple)
- `"suggested"` = `"#fd7e14"` ← conflicts with `"disagree"`; use `"#e67e22"` (darker orange) or `"#ffc107"` (amber) instead

#### Row background color pattern (lines 964–986)

```r
row_bg_colors <- c(
  "agree"        = "rgba(40, 167, 69, 0.08)",
  "disagree"     = "rgba(220, 53, 69, 0.08)",
  "manual"       = "rgba(111, 66, 193, 0.08)",
  ...
)
row_style_fn <- function(index) {
  status <- as.character(df_display$consensus_status[index])
  bg <- row_bg_colors[status]
  if (!is.null(bg) && !is.na(bg)) list(backgroundColor = bg) else NULL
}
```

Add `"auto_resolved"` and `"suggested"` entries following the same `rgba(r,g,b,0.08)` pattern.

#### `derive_resolution_html()` — HTML column builder pattern (lines 49–170)

This function uses vectorized masks (`status == "manual" & !is.na(dtxsid)`) to build the Resolution column HTML. The pattern for adding auto-resolved/suggested rendering:

```r
# Pattern: per-status mask + paste0 HTML assembly
manual_mask <- status == "manual" & !is.na(dtxsid)
manual_badge <- '<span class="badge bg-info ms-1" style="font-size:0.7em;">manual</span>'
result[has_mp] <- paste0(
  "\u2705 ",
  htmltools::htmlEscape(dtxsid[has_mp]),
  " \u2014 ",
  htmltools::htmlEscape(mpref[has_mp]),
  " ",
  manual_badge
)
```

For auto_resolved rows, render a Compare button (same as the existing disagree+pinned change link pattern) with an "auto" badge. For suggested rows, render the Compare button (same as disagree+not-pinned) since the modal is where the Accept button lives (D-07).

#### Compare button / modal pattern (lines 1184–1343)

`observeEvent(input$compare_row_click)` builds candidate cards using `get_resolution_options()`, then `showModal()`. The suggested candidate highlight and "Accept Suggestion" button must be injected into this same modal flow:

```r
# Existing card structure
div(
  class = "candidate-card card mb-2",
  style = "border: 2px solid #dee2e6; ...",
  div(
    class = "card-body",
    div(
      class = "d-flex justify-content-between align-items-start",
      ...
      tags$button(
        class = "modal-select-btn btn btn-sm btn-outline-success",
        `data-column` = col,
        "Select"
      )
    ),
    ...
  )
)
```

For the suggested candidate card: change `style` to `"border: 2px solid #0dcaf0; background-color: #f0fbff;"` and change the button to `class = "modal-select-btn btn btn-sm btn-success"` with label `"Accept Suggestion"`. The `modal_candidate_select` JS input already handles the column name — no new JS needed.

#### `observeEvent(input$modal_confirm)` — modal resolution pattern (lines 1350–1387)

```r
observeEvent(input$modal_confirm, {
  row_idx <- data_store$modal_row_idx
  chosen_column <- data_store$modal_selected_column

  if (is.null(chosen_column)) {
    showNotification("Please select a candidate first", type = "warning")
    return()
  }
  ...
  group_rows <- get_group_rows(row_idx, isolate(data_store$dedup_group_map))
  updated_df <- data_store$resolution_state
  for (r in group_rows) {
    updated_df <- resolve_row(updated_df, r, chosen_column, data_store$dtxsid_cols)
  }
  data_store$resolution_state <- updated_df
  data_store$consensus_summary <- recalc_consensus_summary(updated_df)
  removeModal()
  showNotification(notification_msg, type = "message")
})
```

The accept-suggestion flow follows this exact pattern — `resolve_row()` call + `recalc_consensus_summary()` + `removeModal()` + `showNotification()`. The only difference is setting `.resolution_method = "suggested-accept"` and `.resolution_reason`.

#### `observeEvent(input$apply_priority)` — bulk action pattern (lines 1528–1575)

```r
observeEvent(input$apply_priority, {
  req(data_store$resolution_state, data_store$priority_order, data_store$dtxsid_cols)

  tryCatch({
    before_count <- sum(
      data_store$resolution_state$consensus_status == "disagree" &
        !isTRUE(data_store$resolution_state$.pinned),
      na.rm = TRUE
    )

    updated_df <- apply_priority_chain(
      data_store$resolution_state,
      data_store$priority_order,
      data_store$dtxsid_cols
    )

    data_store$resolution_state <- updated_df

    after_count <- sum(
      updated_df$consensus_status == "disagree" &
        !isTRUE(updated_df$.pinned),
      na.rm = TRUE
    )
    resolved_count <- before_count - after_count

    data_store$consensus_summary <- recalc_consensus_summary(updated_df)

    showNotification(
      paste0("Applied priority chain: ", resolved_count, " rows resolved"),
      type = "message"
    )
  },
  error = function(e) {
    showNotification(paste0("Error applying priority: ", e$message), type = "error")
  })
})
```

**"Accept All Suggestions" button handler** copies this pattern exactly, replacing `apply_priority_chain()` with `accept_all_suggestions()`, and counting/displaying the number of SUGGESTED rows resolved.

#### `shinyjs::hidden()` button pattern (lines 396–411)

Bulk action buttons that appear conditionally use `shinyjs::hidden()` in UI + `shinyjs::show()` / `shinyjs::hide()` in `observe()`:

```r
# In UI:
shinyjs::hidden(
  actionButton(
    ns("accept_all_suggestions"),
    "Accept All Suggestions",
    icon = icon("check-double"),
    class = "btn-sm btn-info"
  )
)

# In server observe():
observe({
  has_suggested <- any(data_store$resolution_state$consensus_status == "suggested", na.rm = TRUE)
  if (has_suggested) {
    shinyjs::show("accept_all_suggestions")
  } else {
    shinyjs::hide("accept_all_suggestions")
  }
})
```

#### `recalc_consensus_summary()` — must be extended (lines 5–16)

```r
recalc_consensus_summary <- function(df) {
  list(
    n_agree = sum(df$consensus_status == "agree", na.rm = TRUE),
    n_disagree = sum(df$consensus_status == "disagree" & !isTRUE(df$.pinned), na.rm = TRUE),
    n_agree_caveat = sum(df$consensus_status == "agree_caveat", na.rm = TRUE),
    n_single = sum(df$consensus_status == "single", na.rm = TRUE),
    n_error = sum(df$consensus_status == "error", na.rm = TRUE),
    n_manual = sum(df$consensus_status == "manual", na.rm = TRUE),
    n_unresolvable = sum(df$consensus_status == "unresolvable", na.rm = TRUE),
    n_wqx = sum(df$consensus_status == "wqx", na.rm = TRUE)
  )
}
```

Add `n_auto_resolved` and `n_suggested` entries. The summary value boxes in `output$curation_stats` (lines 492–536) will need corresponding UI elements or the existing "Disagree" box updated to reflect unresolved disagree count (excluding auto_resolved/suggested).

---

### `R/export_helpers.R` — include .resolution_method and .resolution_reason in export

**Analog:** `R/export_helpers.R` (self-extension)

#### Curated Data sheet column exclusion pattern (lines 41–47)

```r
curated_data_sheet <- resolution_state %>%
  dplyr::mutate(
    needs_review = (consensus_status %in% c("error", "unresolvable"))
  ) %>%
  # Note: similarity_score (from Phase 49) flows through automatically -- not excluded
  dplyr::select(-tidyselect::any_of(c(".pinned", ".manual_entry")))
```

`.resolution_method` and `.resolution_reason` should **not** be added to the `any_of()` exclusion list — they flow through automatically exactly like `similarity_score`. The comment already documents this pattern. No code change is needed to export_helpers.R unless column ordering is desired, in which case use `dplyr::relocate()`:

```r
# Optional: position .resolution_method/.resolution_reason after consensus_source
curated_data_sheet <- curated_data_sheet %>%
  dplyr::relocate(
    tidyselect::any_of(c(".resolution_method", ".resolution_reason")),
    .after = consensus_source
  )
```

#### Summary sheet pattern (lines 64–88)

If a summary count for auto-resolved/suggested rows is desired, extend the `Metric`/`Value` tibble following the existing pattern:

```r
summary_sheet <- tibble::tibble(
  Metric = c(
    "Total Rows",
    "Consensus - Agree",
    ...
    "Consensus - Auto-Resolved",   # NEW
    "Consensus - Suggested"        # NEW
  ),
  Value = c(
    nrow(resolution_state),
    ...
    sum(resolution_state$consensus_status == "auto_resolved", na.rm = TRUE),  # NEW
    sum(resolution_state$consensus_status == "suggested", na.rm = TRUE)       # NEW
  )
)
```

---

## Shared Patterns

### State mutation pattern
**Source:** `R/consensus.R` lines 395–421 (`resolve_row()`), lines 434–458 (`apply_priority_chain()`)
**Apply to:** All new resolution functions in `consensus.R`

Every function that mutates resolution state must:
1. Call `df <- init_resolution_state(df)` at the top (idempotent guard)
2. Return the full modified data frame (not just the changed rows)
3. Set `.pinned <- TRUE` on resolved rows to prevent re-processing

### Error handling pattern
**Source:** `R/mod_review_results.R` lines 1147–1181 (`observeEvent(input$resolve_row_choice)`)
**Apply to:** All new `observeEvent` handlers in `mod_review_results.R`

```r
tryCatch(
  {
    # ... mutation logic ...
    data_store$resolution_state <- updated_df
    data_store$consensus_summary <- recalc_consensus_summary(updated_df)
    showNotification("...", type = "message")
  },
  error = function(e) {
    showNotification(paste0("Error: ", e$message), type = "error")
  }
)
```

### Consensus summary recalculation
**Source:** `R/mod_review_results.R` line 1176, 1373, 1491, 1561
**Apply to:** Every handler that modifies `data_store$resolution_state`

Always call `data_store$consensus_summary <- recalc_consensus_summary(data_store$resolution_state)` immediately after any write to `data_store$resolution_state`.

### Dedup group propagation
**Source:** `R/mod_review_results.R` lines 1145, 1367, 1396
**Apply to:** All row-resolution handlers (including accept-suggestion, bulk-accept)

```r
group_rows <- get_group_rows(row_idx, isolate(data_store$dedup_group_map))
for (r in group_rows) {
  updated_df <- resolve_row(updated_df, r, chosen_column, data_store$dtxsid_cols)
}
```

Every single-row action must propagate to all rows in the dedup group. The bulk "Accept All Suggestions" loop (`for (i in seq_len(nrow(df)))`) already operates on all rows so dedup-group expansion is not needed there.

### JS `Shiny.setInputValue` with priority:event pattern
**Source:** `R/mod_review_results.R` lines 261–307 (compare_js script block)
**Apply to:** Any new button added to the comparison modal

```r
# Existing pattern for modal buttons
tags$button(
  class = "btn btn-primary",
  onclick = sprintf(
    "Shiny.setInputValue('%s', {t: Math.random()}, {priority: 'event'});",
    session$ns("accept_suggestion")
  ),
  "Accept Suggestion"
)
```

The `{priority: 'event'}` flag ensures the handler fires even when the value doesn't change (e.g., clicking Accept on the same suggestion twice). The `t: Math.random()` forces Shiny to treat each click as a new event.

---

## No Analog Found

None — all three files are self-extensions with excellent existing analogs.

---

## Metadata

**Analog search scope:** `R/consensus.R`, `R/mod_review_results.R`, `R/export_helpers.R` (all read in full)
**Files scanned:** 3
**Pattern extraction date:** 2026-05-10
