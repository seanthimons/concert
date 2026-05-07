# Phase 47: Pipeline Reordering, Threshold Control & Starts-With Toggle - Pattern Map

**Mapped:** 2026-05-06
**Files analyzed:** 4 modified files
**Analogs found:** 4 / 4 (all modifications to existing files — no net-new files)

---

## File Classification

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `R/curation.R` | service / pipeline orchestrator | batch, transform | Self — `run_curation_pipeline()` existing tier blocks (lines 683–801) | self-analog (in-place reorder) |
| `R/mod_clean_data.R` | Shiny UI module | request-response | Self — existing `accordion_panel` blocks at lines 294–300; `build_mask_from_inputs()` at lines 304–318; `run_all` observer at lines 631–645 | self-analog (extension) |
| `R/mod_run_curation.R` | Shiny server module | request-response | Self — `run_curation_pipeline()` call site at lines 161–166; notification at lines 258–264 | self-analog (extension) |
| `R/curate_headless.R` | headless API function | batch | Self — `curate_headless()` signature at lines 63–76; `run_curation_pipeline()` call at line 176 | self-analog (extension) |

---

## Pattern Assignments

### `R/curation.R` — `run_curation_pipeline()` (service, batch/transform)

**Change:** Reorder WQX from Tier 3b (after starts-with) to Tier 3 (before starts-with), add `wqx_threshold` and `starts_with` parameters, gate starts-with tier on the boolean flag.

**Current function signature** (line 629):
```r
run_curation_pipeline <- function(clean_data, column_tags, progress_callback = NULL, dedup_only = FALSE) {
```

**New signature — copy this pattern:**
```r
run_curation_pipeline <- function(
  clean_data,
  column_tags,
  progress_callback = NULL,
  dedup_only = FALSE,
  wqx_threshold = 0.85,
  starts_with = FALSE
) {
```

**Current counter initialization block** (lines 676–681) — `n_wqx` is already declared here, no change needed:
```r
n_exact <- 0
n_starts_with <- 0
n_cas_from_names <- 0
n_cas_from_columns <- 0
n_miss <- 0
n_wqx <- 0L
```

**Current (wrong) Tier 3 block** (lines 737–786) — this entire block must be restructured:
```r
# Tier 3: Starts-with on remaining misses (MOVED TO LAST, with 3-char minimum)
if (length(still_missed) > 0) {
  sw_candidates <- still_missed[nchar(still_missed) >= 3]
  ...
  final_missed <- setdiff(still_missed, sw_matched)

  # Tier 3b: WQX matching on names that failed all CompTox tiers (per D-01)
  if (length(final_missed) > 0) {
    cache_dir <- system.file("extdata", "reference_cache", package = "chemreg")
    wqx_dict <- load_wqx_dictionary(cache_dir)
    wqx_raw <- match_wqx(final_missed, wqx_dict, verbose = FALSE)
    ...
  }
}
```

**New Tier 3+4 block — replace the above with this pattern:**
```r
# Tier 3: WQX — no character minimum (D-01: local dictionary, no API cost)
if (length(still_missed) > 0) {
  cache_dir <- system.file("extdata", "reference_cache", package = "chemreg")
  wqx_dict <- load_wqx_dictionary(cache_dir)
  wqx_raw <- match_wqx(still_missed, wqx_dict, threshold = wqx_threshold, verbose = FALSE)

  wqx_resolved <- wqx_raw[wqx_raw$match_tier != "none", ]
  n_wqx <- nrow(wqx_resolved)

  if (n_wqx > 0) {
    wqx_rows <- tibble::tibble(
      searchValue = wqx_resolved$input_name,
      dtxsid = NA_character_,
      preferredName = wqx_resolved$wqx_name,
      searchName = NA_character_,
      rank = NA_integer_,
      source_tier = paste0("wqx_", wqx_resolved$match_tier)
    )
    all_results[[length(all_results) + 1]] <- wqx_rows
  }

  wqx_matched_names <- wqx_resolved$input_name
  final_missed <- setdiff(still_missed, wqx_matched_names)

  if (!is.null(progress_callback)) {
    progress_callback("wqx", sprintf("WQX match: %d more found...", n_wqx))
  }

  # Tier 4: Starts-with — only when enabled AND names remain (D-02, D-05)
  if (starts_with && length(final_missed) > 0) {
    sw_candidates <- final_missed[nchar(final_missed) >= 3]
    if (length(sw_candidates) > 0) {
      sw_results <- search_starts_with(sw_candidates)
      if (nrow(sw_results) > 0) {
        sw_results$source_tier <- "starts_with"
        all_results[[length(all_results) + 1]] <- sw_results
        n_starts_with <- sum(!is.na(sw_results$dtxsid))
      }
      if (!is.null(progress_callback)) {
        progress_callback("starts_with", sprintf("Starts-with: %d more found...", n_starts_with))
      }
      sw_matched <- sw_results$searchValue[!is.na(sw_results$dtxsid)]
      final_missed <- setdiff(final_missed, sw_matched)
    }
  }

  n_miss <- length(final_missed)
  if (length(final_missed) > 0) {
    miss_rows <- tibble::tibble(
      searchValue = final_missed,
      dtxsid = NA_character_,
      preferredName = NA_character_,
      searchName = NA_character_,
      rank = NA_integer_,
      source_tier = "miss"
    )
    all_results[[length(all_results) + 1]] <- miss_rows
  }
}
```

**`search_summary` return value** (lines 910–915) — `n_wqx` is already present, no schema change needed:
```r
search_summary = list(
  n_exact = n_exact,
  n_starts_with = n_starts_with,
  n_cas_valid = n_cas_from_columns + n_cas_from_names,
  n_wqx = n_wqx,
  n_miss = n_miss
),
```

**Key pitfall:** `wqx_matched_names <- wqx_resolved$input_name` must use `wqx_resolved` (a subset), not `wqx_raw`. If accidentally set to `wqx_raw$input_name`, all names (including non-matches) are excluded from `final_missed`. This is the exact bug pattern from RESEARCH.md Pitfall 1.

---

### `R/mod_clean_data.R` — Pre-flight modal (Shiny UI module, request-response)

**Change 1: Add new accordion panel to `output$preflight_checklist` renderUI**

**Existing accordion pattern to extend** (lines 294–300):
```r
bslib::accordion(
  id = session$ns("preflight_accordion"),
  open = TRUE,
  multiple = TRUE,
  bslib::accordion_panel(title = "Cleaning Steps", value = "cleaning", cleaning_rows),
  bslib::accordion_panel(title = "Harmonization Steps", value = "harmonization", harmonize_rows)
)
```

**New third panel — append after "Harmonization Steps":**
```r
bslib::accordion_panel(
  title = "Search Settings",
  value = "search_settings",
  div(
    class = "mb-3",
    tags$label(class = "form-label fw-semibold", "WQX Fuzzy Match Threshold"),
    tags$small(
      class = "text-muted d-block mb-2",
      "Minimum similarity score for fuzzy WQX matches (0.50 = permissive, 1.00 = exact only)"
    ),
    bslib::layout_columns(
      col_widths = c(8, 4),
      sliderInput(
        session$ns("wqx_threshold"),
        label = NULL,
        min = 0.50, max = 1.00, step = 0.01, value = 0.85,
        ticks = FALSE
      ),
      numericInput(
        session$ns("wqx_threshold_num"),
        label = NULL,
        value = 0.85, min = 0.50, max = 1.00, step = 0.01
      )
    )
  ),
  div(
    checkboxInput(
      session$ns("starts_with_enabled"),
      label = "Enable CompTox starts-with search",
      value = FALSE
    ),
    tags$small(
      class = "text-muted",
      "Off by default. Enable for datasets where exact + CAS + WQX resolution is insufficient."
    )
  )
)
```

**Key namespacing rule:** All IDs inside `renderUI({})` blocks must use `session$ns(...)`, not bare strings. The existing `checkboxInput(session$ns(paste0("step_", key)), ...)` pattern at line 267 is the exact model to follow.

**Change 2: Extend `build_mask_from_inputs()`** (lines 304–318)

**Current pattern:**
```r
build_mask_from_inputs <- function() {
  list(
    unicode = isTRUE(input$step_unicode),
    whitespace = isTRUE(input$step_whitespace),
    cas = isTRUE(input$step_cas),
    names = isTRUE(input$step_names),
    isotopes = isTRUE(input$step_isotopes),
    multi = isTRUE(input$step_multi),
    chiral = isTRUE(input$step_chiral),
    units = isTRUE(input$step_units),
    duration = isTRUE(input$step_duration),
    dates = isTRUE(input$step_dates),
    media = isTRUE(input$step_media)
  )
}
```

**Extend by appending two fields:**
```r
wqx_threshold = input$wqx_threshold,
starts_with = isTRUE(input$starts_with_enabled)
```

**Change 3: Extend `run_all` observer** (lines 631–645)

**Current hardcoded mask — must add search settings:**
```r
observeEvent(input$run_all, {
  mask <- list(
    unicode = TRUE,
    whitespace = TRUE,
    cas = TRUE,
    names = TRUE,
    isotopes = TRUE,
    multi = TRUE,
    chiral = TRUE,
    units = TRUE,
    duration = TRUE,
    dates = TRUE,
    media = TRUE
    # ADD:
    # wqx_threshold = input$wqx_threshold,
    # starts_with = isTRUE(input$starts_with_enabled)
  )
  execute_pipeline(mask)
})
```

The `run_all` observer hardcodes all cleaning steps to `TRUE` but must still read the search setting inputs (not force them). Add `wqx_threshold = input$wqx_threshold` and `starts_with = isTRUE(input$starts_with_enabled)` to honor the toggle even on "Run All Steps" (RESEARCH.md Open Question 1 recommendation).

**Change 4: Add slider ↔ numeric sync observers** (new server-side code in the module server function)

**Pattern — place after the `build_mask_from_inputs` definition:**
```r
observeEvent(input$wqx_threshold, {
  updateNumericInput(session, "wqx_threshold_num", value = input$wqx_threshold)
}, ignoreInit = TRUE)

observeEvent(input$wqx_threshold_num, {
  val <- input$wqx_threshold_num
  if (!is.null(val) && !is.na(val) && val >= 0.50 && val <= 1.00) {
    updateSliderInput(session, "wqx_threshold", value = val)
  }
}, ignoreInit = TRUE)
```

`ignoreInit = TRUE` prevents double-fire on modal open. The bounds check on `wqx_threshold_num` prevents invalid values from propagating to the slider.

---

### `R/mod_run_curation.R` — Curation execution module (Shiny server, request-response)

**Change 1: Pass new parameters to `run_curation_pipeline()`**

**Current call site** (lines 161–166):
```r
pipeline_result <- run_curation_pipeline(
  clean_data = input_data,
  column_tags = data_store$column_tags,
  progress_callback = progress_callback,
  dedup_only = FALSE
)
```

**New call site — add two arguments:**
```r
pipeline_result <- run_curation_pipeline(
  clean_data = input_data,
  column_tags = data_store$column_tags,
  progress_callback = progress_callback,
  dedup_only = FALSE,
  wqx_threshold = data_store$wqx_threshold,
  starts_with = isTRUE(data_store$starts_with)
)
```

The values arrive via `data_store` fields set by `mod_clean_data.R`'s `execute_pipeline()` function. The planner must decide whether `execute_pipeline()` stores to `data_store` or passes directly — the existing pattern in `execute_pipeline()` (lines 321+) passes the mask directly into `run_curation_pipeline()` within the same call chain (not via data_store). If `mod_run_curation.R` calls `run_curation_pipeline()` independently, it needs its own access to the mask values. See Shared Patterns > Execute Pipeline Wiring below.

**Change 2: Update tier breakdown notification string** (lines 258–264)

**Current notification:**
```r
notification_msg <- sprintf(
  "Search complete: %d exact, %d CAS, %d starts-with, %d no match",
  pipeline_result$search_summary$n_exact,
  pipeline_result$search_summary$n_cas_valid,
  pipeline_result$search_summary$n_starts_with,
  pipeline_result$search_summary$n_miss
)
```

**Updated notification — add WQX count:**
```r
notification_msg <- sprintf(
  "Search complete: %d exact, %d CAS, %d WQX, %d starts-with, %d no match",
  pipeline_result$search_summary$n_exact,
  pipeline_result$search_summary$n_cas_valid,
  pipeline_result$search_summary$n_wqx,
  pipeline_result$search_summary$n_starts_with,
  pipeline_result$search_summary$n_miss
)
```

`pipeline_result$search_summary$n_wqx` is already populated by `run_curation_pipeline()` (line 914 confirmed).

---

### `R/curate_headless.R` — Headless API (headless/batch function, request-response)

**Change: Extend function signature and thread parameters to `run_curation_pipeline()`**

**Current signature** (lines 63–76):
```r
curate_headless <- function(
  input_path,
  output_path,
  tag_map,
  skip_flags = NULL,
  header_row = NULL,
  reference_lists = NULL,
  verbose = TRUE,
  harmonize = FALSE,
  format = "parquet",
  unit_map = NULL,
  corrections = NULL,
  media = NULL
) {
```

**New signature — append two arguments at end:**
```r
curate_headless <- function(
  input_path,
  output_path,
  tag_map,
  skip_flags = NULL,
  header_row = NULL,
  reference_lists = NULL,
  verbose = TRUE,
  harmonize = FALSE,
  format = "parquet",
  unit_map = NULL,
  corrections = NULL,
  media = NULL,
  wqx_threshold = 0.85,
  starts_with = FALSE
) {
```

**Current `run_curation_pipeline()` call** (line 176):
```r
pipeline_result <- run_curation_pipeline(cleaning_result$cleaned_data, merged_tags)
```

**New call — thread both new parameters:**
```r
pipeline_result <- run_curation_pipeline(
  cleaning_result$cleaned_data,
  merged_tags,
  wqx_threshold = wqx_threshold,
  starts_with = starts_with
)
```

---

## Shared Patterns

### Execute Pipeline Wiring: mask → run_curation_pipeline()

**Source:** `R/mod_clean_data.R` lines 321–628 (`execute_pipeline()` function)
**Apply to:** Understanding how `wqx_threshold` and `starts_with` flow from modal inputs to the pipeline.

The critical architectural fact: `execute_pipeline()` in `mod_clean_data.R` and the `observeEvent(input$run_curation)` in `mod_run_curation.R` are **two separate call paths** both calling `run_curation_pipeline()`. The `mod_clean_data.R` path (cleaning + pipeline) runs when the user clicks "Run Checked/All Steps" in the pre-flight modal. The `mod_run_curation.R` path runs when the user clicks "Start Curation" from the curation tab (bypassing the pre-flight modal).

For the pre-flight modal path (`mod_clean_data.R`), `execute_pipeline(mask)` already has access to `input$wqx_threshold` and `input$starts_with_enabled` from the same module's input namespace. Extend `build_mask_from_inputs()` and the hardcoded `run_all` mask to include them, then pass `mask$wqx_threshold` and `mask$starts_with` into `run_curation_pipeline()` at the point where it's called within `execute_pipeline()`.

For the `mod_run_curation.R` path, the new parameters need to reach it via `data_store` (reactive values shared across modules). The planner should decide whether to store `wqx_threshold` and `starts_with` into `data_store` from the pre-flight modal (so `mod_run_curation.R` can read them), or apply defaults directly in the `mod_run_curation.R` call. The simplest safe approach: store into `data_store$wqx_threshold` and `data_store$starts_with` at the end of `execute_pipeline()` or when the mask is built, then read from `data_store` in `mod_run_curation.R`.

### Modal Input Namespacing

**Source:** `R/mod_clean_data.R` line 267
**Apply to:** All new `sliderInput`, `numericInput`, `checkboxInput` added inside `renderUI({})`.

```r
# Existing model — all renderUI inputs use session$ns():
checkboxInput(
  session$ns(paste0("step_", key)),
  label = NULL,
  value = check$should_run && check$est_changes > 0,
  width = "auto"
)
```

All new inputs must follow this exact pattern. Bare string IDs inside `renderUI` will fail silently — `input$wqx_threshold` returns NULL even after slider interaction.

### Progress Callback Stage Pattern

**Source:** `R/curation.R` lines 696–705, 733–735, 749–751, 783–785
**Apply to:** New WQX and starts-with progress callback calls after reorder.

```r
if (!is.null(progress_callback)) {
  progress_callback(
    "stage_key",
    sprintf("Human-readable message: %d found...", count)
  )
}
```

Stage keys used in this pipeline: `"dedup"`, `"exact"`, `"cas_names"`, `"starts_with"`, `"wqx"`, `"cas_columns"`, `"consensus"`. After reorder, `"wqx"` fires before `"starts_with"`.

### Error Handling — tryCatch in Shiny Observers

**Source:** `R/mod_clean_data.R` lines 325–627, `R/mod_run_curation.R` lines 144–285
**Apply to:** Any new `observe()` or `observeEvent()` blocks added for slider sync.

The slider ↔ numeric sync observers do **not** need `tryCatch` — they are lightweight value-sync operations. The existing `execute_pipeline()` already wraps the full pipeline in `tryCatch`. The new observers only need `ignoreInit = TRUE` and a bounds guard on the numeric input path.

---

## No Analog Found

None. All four files are modifications to existing well-understood files. No net-new files are created in this phase.

---

## Metadata

**Analog search scope:** `R/curation.R`, `R/mod_clean_data.R`, `R/mod_run_curation.R`, `R/curate_headless.R`, `R/wqx_matching.R`
**Files read:** 5 source files (full reads of relevant sections)
**Pattern extraction date:** 2026-05-06
