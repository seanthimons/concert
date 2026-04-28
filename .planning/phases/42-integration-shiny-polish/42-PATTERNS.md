# Phase 42: Integration & Shiny Polish - Pattern Map

**Mapped:** 2026-04-28
**Files analyzed:** 6 (5 modifications, 1 new file)
**Analogs found:** 6 / 6

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `R/mod_clean_data.R` | module (UI + server) | request-response | `R/mod_harmonize.R` lines 163-173 (button enable/disable) | exact — same disabled-button pattern |
| `R/mod_harmonize.R` | module (UI + server) | event-driven + CRUD | `R/mod_harmonize.R` lines 175-200, 906-984, 1010-1367 (working copy + modals) | self-referential — new media editor copies existing unit editor sub-pattern |
| `R/cleaning_pipeline.R` | service (pipeline) | batch + transform | `R/cleaning_pipeline.R` lines 283-458 (existing `precheck_*` functions) | exact — new harmonization pre-checks follow identical signature and body structure |
| `R/media_harmonizer.R` | service (lookup) | transform | `R/media_harmonizer.R` lines 124-199 (current `harmonize_media()`) | self-referential — adding optional parameter with fallback |
| `R/cleaning_reference.R` | service (persistence) | file-I/O | `R/cleaning_reference.R` lines 204-224 (`load_corrections`) + lines 414-426 (`load_all_reference_lists`) | exact — same `load_or_fetch_reference` pattern + list extension |
| `inst/extdata/reference_cache/user_media_map.rds` | config (data) | file-I/O | `inst/extdata/reference_cache/` (existing `corrections.rds` empty-on-first-run pattern) | role-match — RDS with empty-tibble fallback on first run |

---

## Pattern Assignments

### `R/mod_clean_data.R` (module, request-response)
**Change scope:** Replace `actionButton(ns("run_cleaning"), ...)` with `actionButton(ns("run_pipeline"), ...)`. Replace `observeEvent(input$run_cleaning, {...})` with two new observers: one that runs pre-checks and opens the modal, one that executes the step-masked pipeline.

**Analog:** `R/mod_harmonize.R` (button declaration + enable/disable pattern); `R/mod_harmonize.R` lines 906-951 (modal construction pattern)

**Existing button declaration to replace** (`R/mod_clean_data.R` lines 63-68):
```r
actionButton(
  ns("run_cleaning"),
  "Run Cleaning",
  class = "btn-success btn-lg",
  icon = icon("magic")
)
```

**Replacement button pattern** — wrap in `shinyjs::disabled()` then enable via observer, copying `R/mod_harmonize.R` lines 74-81 and 163-173:
```r
shinyjs::disabled(
  actionButton(
    ns("run_pipeline"),
    "Run Pipeline",
    class = "btn-success btn-lg",
    icon = icon("play")
  )
)

# Enable/disable observer (copy from mod_harmonize.R lines 163-173)
observe({
  if (!is.null(data_store$column_tags) && has_required_chemical_tags(data_store$column_tags)) {
    shinyjs::enable("run_pipeline")
  } else {
    shinyjs::disable("run_pipeline")
  }
})
```

**Pre-flight modal construction pattern** — copy from `R/mod_harmonize.R` lines 906-951 (showModal/modalDialog/easyClose/footer structure):
```r
observeEvent(input$run_pipeline, {
  req(data_store$clean)

  # Collect all pre-checks synchronously before showing modal
  df       <- data_store$clean
  tag_map  <- data_store$column_tags
  name_cols <- names(tag_map)[tag_map == "Name"]

  checks <- list(
    unicode   = precheck_unicode_to_ascii(df),
    whitespace = precheck_trim_whitespace(df),
    cas       = precheck_normalize_cas(df, tag_map),
    names     = precheck_name_cleaning(df, name_cols),
    isotopes  = precheck_isotope_shortcodes(df, name_cols, data_store$reference_lists$isotope_lookup),
    multi     = precheck_multi_analyte(df, name_cols),
    chiral    = precheck_chiral_restore(df, name_cols),
    # Harmonization pre-checks (new in Phase 42)
    h_units   = precheck_harmonize_units(df, ...),
    h_dur     = precheck_harmonize_duration(df, ...),
    h_dates   = precheck_harmonize_dates(df, ...),
    h_media   = precheck_harmonize_media(df, ...)
  )

  total_changes <- sum(vapply(checks, function(x) x$est_changes, integer(1)))

  if (total_changes == 0L) {
    showNotification(
      tagList(
        "Pre-flight check: no steps have changes to apply.",
        actionLink(session$ns("open_preflight_anyway"), "Run anyway?", class = "alert-link ms-2")
      ),
      type = "message",
      duration = 8
    )
    return()
  }

  showModal(modalDialog(
    title = "Pre-flight Check",
    size  = "m",
    easyClose = FALSE,
    uiOutput(session$ns("preflight_checklist")),
    footer = tagList(
      modalButton("Cancel"),
      actionButton(session$ns("run_all"),     "Run All Steps",      class = "btn-outline-secondary"),
      actionButton(session$ns("run_checked"), "Run Checked Steps",  class = "btn-primary")
    )
  ))
})
```

**Pipeline execution observer pattern** — copy error handling and `withProgress` from `R/mod_clean_data.R` lines 130-341:
```r
observeEvent(input$run_checked, {
  req(data_store$clean)
  shinyjs::disable("run_pipeline")
  removeModal()

  tryCatch(
    {
      withProgress(message = "Running pipeline...", value = 0, {
        # ... existing cleaning steps with step-mask guards
        # ... followed by harmonization steps with step-mask guards
      })
    },
    error = function(e) {
      showNotification(paste("Pipeline failed:", e$message), type = "error", duration = NULL)
    },
    finally = {
      shinyjs::enable("run_pipeline")
    }
  )
})
```

---

### `R/mod_harmonize.R` (module, event-driven + CRUD)
**Change scope:** (1) Remove `actionButton(ns("run_harmonization"), ...)` from UI. (2) Add `media_map_working` one-shot initialization. (3) Add media editor accordion panel with DT table, UNMATCHED/MAPPED sections, row-click modal, save/persist logic, and re-run notification.

**Analog:** `R/mod_harmonize.R` lines 175-200 (working copy init), 906-951 (edit modal), 1010-1061 (add modal), 1319-1367 (add-from-unmatched modal), 1063-1102 (save observer), 761-764 (re-run link)

**Working copy initialization pattern** (`R/mod_harmonize.R` lines 180-189 — copy verbatim, replace names):
```r
media_map_ready <- reactiveVal(FALSE)
observe({
  if (
    is.null(data_store$media_map_working) &&
      !is.null(data_store$reference_lists$media_map)
  ) {
    data_store$media_map_working <- data_store$reference_lists$media_map
    if (!media_map_ready()) media_map_ready(TRUE)
  }
})
```

**DT table with UNMATCHED/MAPPED sections** — use `media_flag == "media_unmatched"` from `data_store$media_results` to drive row ordering; badge HTML in `source` column copies the badge-class switch pattern from `R/mod_harmonize.R` lines 853-858:
```r
output$media_table <- DT::renderDT({
  req(media_map_ready())
  tbl <- data_store$media_map_working

  # Badge HTML for source column (D-12)
  tbl$source <- dplyr::case_when(
    tbl$source == "user" ~ '<span class="badge bg-primary">user</span>',
    TRUE                 ~ '<span class="badge bg-secondary">amos</span>'
  )

  DT::datatable(
    tbl,
    escape     = FALSE,
    selection  = "single",
    rownames   = FALSE,
    options    = list(pageLength = 25, dom = "ftp"),
    callback   = DT::JS(sprintf(
      "table.on('click', 'tr', function() {
         var d = table.row(this).data();
         if (d) Shiny.setInputValue('%s', {term: d[0], ts: Date.now()}, {priority: 'event'});
       });",
      session$ns("open_media_edit_modal")
    ))
  )
}, server = FALSE)
```

**Edit modal pattern** — copy from `R/mod_harmonize.R` lines 906-951 (showModal, hidden orig key, easyClose = FALSE, Discard + Save footer):
```r
observeEvent(input$open_media_edit_modal, {
  msg <- input$open_media_edit_modal
  req(msg$term)

  tbl <- data_store$media_map_working
  row <- tbl[tbl$term == msg$term, ][1, ]

  showModal(modalDialog(
    title     = "Edit Media Mapping",
    easyClose = FALSE,
    textInput(session$ns("modal_media_term"),      "Term",      value = row$term),
    textInput(session$ns("modal_media_canonical"),  "Canonical", value = row$canonical),
    checkboxInput(session$ns("modal_media_active"), "Active",    value = isTRUE(row$active)),
    tags$input(
      type  = "hidden",
      id    = session$ns("modal_media_orig_term"),
      value = row$term
    ),
    footer = tagList(
      modalButton("Discard"),
      actionButton(session$ns("save_media_mapping"), "Save Mapping", class = "btn-primary")
    )
  ))
})
```

**Save observer with RDS persistence** — copy upsert logic from `R/mod_harmonize.R` lines 1063-1102 + `saveRDS` from `R/cleaning_reference.R` line 34:
```r
observeEvent(input$save_media_mapping, {
  req(input$modal_media_term, input$modal_media_canonical)

  new_row <- tibble::tibble(
    term      = trimws(input$modal_media_term),
    canonical = trimws(input$modal_media_canonical),
    source    = "user",
    active    = isTRUE(input$modal_media_active)
  )

  tbl <- data_store$media_map_working
  orig <- input$modal_media_orig_term
  if (!is.null(orig) && orig != "") {
    idx <- which(tbl$term == orig & tbl$source == "user")
    if (length(idx) > 0) tbl <- tbl[-idx[1], ]
  }
  data_store$media_map_working <- dplyr::bind_rows(new_row, tbl)

  # Persist user rows only
  user_rows <- data_store$media_map_working[data_store$media_map_working$source == "user", ]
  cache_path <- system.file("extdata/reference_cache", package = "chemreg")
  saveRDS(user_rows, file.path(cache_path, "user_media_map.rds"), compress = FALSE)

  removeModal()

  # Re-run notification — copy from mod_harmonize.R lines 750-764
  showNotification(
    tagList(
      "Media mappings updated. Re-run harmonization to apply changes?",
      actionLink(session$ns("media_rerun_now"), "Re-run now", class = "alert-link ms-2")
    ),
    type     = "message",
    duration = 8
  )
})

observeEvent(input$media_rerun_now, {
  shinyjs::click("run_harmonization")
})
```

**AMOS override confirmation modal** (D-13) — second nested modal, same pattern:
```r
# Before save_media_mapping upsert logic, check for AMOS conflict:
amos_conflict <- tbl$term == new_row$term & tbl$source == "amos"
if (any(amos_conflict)) {
  existing_canonical <- tbl$canonical[which(amos_conflict)[1]]
  showModal(modalDialog(
    title     = "Override AMOS Mapping?",
    easyClose = FALSE,
    p(sprintf(
      'This term already has an AMOS mapping (canonical: "%s"). Override with your mapping?',
      existing_canonical
    )),
    footer = tagList(
      modalButton("Cancel"),
      actionButton(session$ns("confirm_amos_override"), "Override", class = "btn-warning")
    )
  ))
  return()
}
```

---

### `R/cleaning_pipeline.R` (service, batch + transform)
**Change scope:** Add 4 new harmonization pre-check functions (`precheck_harmonize_units`, `precheck_harmonize_duration`, `precheck_harmonize_dates`, `precheck_harmonize_media`).

**Analog:** `R/cleaning_pipeline.R` lines 283-458 — all 7 existing `precheck_*` functions. Every new function must match this exact signature and return contract.

**Canonical signature and return pattern** (from lines 283-301 — `precheck_unicode_to_ascii`):
```r
#' Pre-check predicate for harmonize_units step
#'
#' @param df Dataframe to check.
#' @param unit_cols Character vector of Unit-tagged column names.
#' @param unit_map Tibble with column from_unit (the working copy).
#' @return list(should_run = logical, est_changes = integer).
#' @keywords internal
precheck_harmonize_units <- function(df, unit_cols, unit_map) {
  if (length(unit_cols) == 0) {
    return(list(should_run = FALSE, est_changes = 0L))
  }
  # Vectorized: count values not found in unit_map$from_unit
  all_unit_vals <- unlist(lapply(unit_cols, function(col) df[[col]]))
  all_unit_vals <- all_unit_vals[!is.na(all_unit_vals) & nzchar(all_unit_vals)]
  unmapped <- sum(!all_unit_vals %in% unit_map$from_unit)
  est_changes <- as.integer(unmapped)
  list(should_run = length(all_unit_vals) > 0L, est_changes = est_changes)
}
```

**Pattern for "no relevant columns = FALSE" guard** (from lines 340-342 — `precheck_normalize_cas`):
```r
if (length(relevant_cols) == 0) {
  return(list(should_run = FALSE, est_changes = 0L))
}
```

**Pattern for vectorized count** (from lines 295-300):
```r
est_changes <- as.integer(sum(vapply(
  relevant_cols,
  function(col) sum(condition_fn(df[[col]]), na.rm = TRUE),
  integer(1)
)))
list(should_run = est_changes > 0L, est_changes = est_changes)
```

**Orchestration call pattern** (from `R/cleaning_pipeline.R` lines 1948-2210):
```r
# Pattern: run pre-check → branch on should_run → call step or build_skip_result
units_check <- precheck_harmonize_units(df, unit_cols, data_store$unit_map_working)
if (!units_check$should_run) {
  # passthrough — no audit rows generated
} else {
  # run harmonize_units(...)
}
```

---

### `R/media_harmonizer.R` (service, transform)
**Change scope:** Extend `harmonize_media()` signature to accept optional `media_map` parameter. Fall back to `get_media_table()` when `NULL`.

**Analog:** `R/media_harmonizer.R` lines 124-199 (current `harmonize_media()` — self-referential modification)

**Current signature** (line 124):
```r
harmonize_media <- function(raw_media, orig_row_id = seq_along(raw_media)) {
```

**New signature with backward-compatible optional parameter:**
```r
harmonize_media <- function(raw_media, orig_row_id = seq_along(raw_media), media_map = NULL) {
```

**Internal fallback pattern** — replace lines 139-149 with:
```r
# Use passed-in map or fall back to bundled AMOS table (D-14 priority order)
media_tbl <- if (!is.null(media_map) && nrow(media_map) > 0) {
  media_map
} else {
  get_media_table()
}
if (is.null(media_tbl) || nrow(media_tbl) == 0L) {
  return(tibble::tibble(   # same zero-row tibble as current lines 141-149
    orig_row_id     = as.integer(orig_row_id),
    raw_media       = as.character(raw_media),
    canonical_media = NA_character_,
    envo_id         = NA_character_,
    media_category  = NA_character_,
    media_flag      = rep("media_unmatched", n)
  ))
}
```

**Column name translation note:** `amos_media.rds` uses `canonical_term`; `user_media_map.rds` uses `canonical`. The merged `media_map_working` should normalize to `canonical_term` before passing into `harmonize_media()` so the internal lookup (`media_tbl$canonical_term`) remains unchanged, OR the function translates on entry. Choose one consistently.

**Call site update** (`R/mod_harmonize.R` line 349):
```r
# Before:
harmonize_media(raw_media = ..., orig_row_id = ...)

# After:
harmonize_media(raw_media = ..., orig_row_id = ..., media_map = data_store$media_map_working)
```

---

### `R/cleaning_reference.R` (service, file-I/O)
**Change scope:** Add `load_media_map(cache_dir)` function and add `media_map` key to `load_all_reference_lists()`.

**Analog:** `R/cleaning_reference.R` lines 204-224 (`load_corrections`) — closest structural match because `user_media_map.rds` also starts as an empty tibble on first run, then accumulates user rows.

**`load_corrections` template** (lines 204-224 — copy structure, replace names and schema):
```r
load_corrections <- function(cache_dir) {
  cache_path <- file.path(cache_dir, "corrections.rds")

  fetch_fn <- function() {
    tibble::tibble(
      pattern     = character(),
      replacement = character()
    )
  }

  load_or_fetch_reference(cache_path, fetch_fn, "one-off corrections")
}
```

**New `load_media_map` function** — follows same structure; merges user RDS with AMOS table:
```r
#' Load merged media harmonization map (user edits + AMOS fallback)
#'
#' User rows (user_media_map.rds) take precedence for the same term.
#' Falls back to amos_media.rds for all other terms.
#'
#' @param cache_dir Directory for cache files (e.g., "inst/extdata/reference_cache")
#' @return Tibble with columns: term, canonical, source, active
#' @export
load_media_map <- function(cache_dir) {
  user_path <- file.path(cache_dir, "user_media_map.rds")
  user_map  <- if (file.exists(user_path)) readRDS(user_path) else NULL

  amos_raw <- get_media_table()  # from media_harmonizer.R

  amos_map <- if (!is.null(amos_raw) && nrow(amos_raw) > 0) {
    tibble::tibble(
      term      = amos_raw$term,
      canonical = amos_raw$canonical_term,   # column rename for display schema
      source    = "amos",
      active    = TRUE
    )
  } else {
    tibble::tibble(term = character(), canonical = character(),
                   source = character(), active = logical())
  }

  if (!is.null(user_map) && nrow(user_map) > 0) {
    amos_fallback <- amos_map[!amos_map$term %in% user_map$term, ]
    dplyr::bind_rows(user_map, amos_fallback)
  } else {
    amos_map
  }
}
```

**`load_all_reference_lists` extension** — copy lines 414-426, add one entry (lines 414-426):
```r
# Current return (lines 414-426):
load_all_reference_lists <- function(cache_dir) {
  list(
    stop_words            = load_stop_words(cache_dir),
    block_patterns        = load_block_patterns(cache_dir),
    functional_categories = load_functional_categories(cache_dir),
    strip_terms           = load_strip_terms(cache_dir),
    corrections           = load_corrections(cache_dir),
    isotope_lookup        = load_isotope_lookup(cache_dir),
    unit_map              = load_unit_map(cache_dir),
    unit_synonyms         = load_unit_synonyms(cache_dir),
    toxval_schema         = load_toxval_schema(cache_dir)
  )
}

# Modified — add one line:
    media_map             = load_media_map(cache_dir)   # NEW: Phase 42
```

---

### `inst/extdata/reference_cache/user_media_map.rds` (config, file-I/O)
**This file does not exist yet — created on first user save.**

**Analog:** `inst/extdata/reference_cache/corrections.rds` — same lifecycle: absent on first run, created by `saveRDS()` on first user action, read by `load_media_map()` on subsequent sessions.

**Schema (4 columns, matches MEDIT-01 D-08):**
```r
tibble::tibble(
  term      = character(),   # normalized (trimws + tolower) raw media string
  canonical = character(),   # user-supplied canonical label
  source    = "user",        # always "user" for rows in this file
  active    = logical()      # TRUE = active mapping
)
```

**Write pattern** (from `R/cleaning_reference.R` line 34 — `saveRDS` with compress = FALSE):
```r
saveRDS(user_rows, file.path(cache_path, "user_media_map.rds"), compress = FALSE)
```

**Read-or-empty fallback** (used inside `load_media_map()`):
```r
user_map <- if (file.exists(user_path)) readRDS(user_path) else NULL
```

---

## Shared Patterns

### Button Disable/Enable Guard
**Source:** `R/mod_harmonize.R` lines 163-173 and `R/mod_clean_data.R` lines 133-135
**Apply to:** `mod_clean_data.R` new "Run Pipeline" button; any button that wraps a long operation

Pattern: wrap in `shinyjs::disabled()` in UI; `shinyjs::enable("id")` / `shinyjs::disable("id")` in observer; re-enable in `finally {}` block of `tryCatch`.

```r
# UI
shinyjs::disabled(actionButton(ns("run_pipeline"), "Run Pipeline", class = "btn-success btn-lg"))

# Server — enable when preconditions met
observe({
  if (preconditions_met) shinyjs::enable("run_pipeline") else shinyjs::disable("run_pipeline")
})

# Execution observer — always re-enable in finally
tryCatch({...}, error = function(e) {...}, finally = { shinyjs::enable("run_pipeline") })
```

### Modal Pattern (showModal/modalDialog)
**Source:** `R/mod_harmonize.R` lines 909-951
**Apply to:** Pre-flight modal, media edit modal, media add modal, AMOS override confirmation

Invariants that must be preserved across all modals:
- `easyClose = FALSE` on any modal with a save action
- Footer always: `tagList(modalButton("Discard"), actionButton(ns("save_*"), ..., class = "btn-primary"))`
- Hidden input stores original key value for upsert discrimination (`""` = insert, non-empty = update)
- `removeModal()` called inside the save observer after state is updated

### Working Copy One-Shot Initialization
**Source:** `R/mod_harmonize.R` lines 180-189 (unit_map) and lines 191-200 (corrections)
**Apply to:** `media_map_working` initialization in `mod_harmonize.R`

Pattern: `reactiveVal(FALSE)` flag + `observe()` that fires exactly once when working copy is NULL and source is not NULL. Never resets the working copy after initialization.

### Re-run Notification After Reference Edit
**Source:** `R/mod_harmonize.R` lines 750-764
**Apply to:** Post-save notification in media editor

```r
# Notification with inline action link
showNotification(
  tagList(
    "Media mappings updated. Re-run harmonization to apply changes?",
    actionLink(session$ns("media_rerun_now"), "Re-run now", class = "alert-link ms-2")
  ),
  type = "message", duration = 8
)

observeEvent(input$media_rerun_now, {
  shinyjs::click("run_harmonization")
})
```

### RDS Cache Load/Save
**Source:** `R/cleaning_reference.R` lines 21-38 (`load_or_fetch_reference`)
**Apply to:** `load_media_map()` (user map side); `save_media_mapping` observer

Load: `readRDS(cache_path)` inside `load_or_fetch_reference()`.
Save: `saveRDS(result, cache_path, compress = FALSE)` — always `compress = FALSE` per existing convention.

### showNotification Types
**Source:** `R/mod_harmonize.R` lines 374-380, `R/mod_clean_data.R` lines 316-321
**Apply to:** All user-facing status messages

Convention used throughout the project:
- `type = "message"` — success / informational
- `type = "warning"` — partial success (e.g., unmatched items remain)
- `type = "error"` — failure; use `duration = NULL` so it stays until dismissed
- `duration = 5` for transient success; `duration = 8` for messages with action links

---

## No Analog Found

All 6 files have close analogs. No entries in this section.

---

## Metadata

**Analog search scope:** `R/mod_clean_data.R`, `R/mod_harmonize.R`, `R/cleaning_pipeline.R`, `R/media_harmonizer.R`, `R/cleaning_reference.R`, `inst/extdata/reference_cache/`
**Files scanned:** 5 source files read in full or substantial part
**Pattern extraction date:** 2026-04-28
