# Phase 41: Media Harmonizer & AMOS Pipeline - Pattern Map

**Mapped:** 2026-04-27
**Files analyzed:** 6 new/modified files
**Analogs found:** 6 / 6

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `R/media_harmonizer.R` | service | transform | `R/date_parser.R` | exact |
| `scripts/build_amos_media.R` | utility | batch | `scripts/benchmark_pipeline.R` | role-match |
| `inst/extdata/reference_cache/amos_media.rds` | config | batch | `inst/extdata/reference_cache/unit_conversion.rds` (pattern) | role-match |
| `R/tag_helpers.R` | utility | request-response | self (1-line edit) | exact |
| `R/mod_tag_columns.R` | component | request-response | self (1-line edit) | exact |
| `R/mod_harmonize.R` | component | event-driven | self (stage insertion) | exact |
| `R/curate_headless.R` | service | batch | self (stage insertion) | exact |
| `tests/testthat/test-media-harmonizer.R` | test | transform | `tests/testthat/test-date-parser.R` | exact |

---

## Pattern Assignments

### `R/media_harmonizer.R` (service, transform)

**Analog:** `R/date_parser.R`

The date parser is the direct structural template: a pure-logic R file with a single exported function, typed empty-tibble guard, vectorized processing, flag-based status column, and join-by-position `orig_row_id` output contract.

**File header + roxygen pattern** (`R/date_parser.R` lines 1-26):
```r
# media_harmonizer.R
# Environmental media harmonization engine: string normalization, exact/parent-walk
# lookup against curated ENVO subset, canonical resolution with category routing.
#
# Public API: harmonize_media()
# Internal: load_media_table(), walk_parent()

#' Harmonize environmental media strings to canonical ENVO terms
#'
#' @param raw_media Character vector of media strings to harmonize.
#' @param orig_row_id Integer vector of row IDs. Defaults to seq_along(raw_media).
#' @return A tibble with columns:
#'   \describe{
#'     \item{orig_row_id}{Integer row position for join-by-position merge.}
#'     \item{raw_media}{Original input string, preserved for audit.}
#'     \item{canonical_media}{Canonical ENVO term, or NA_character_ if unmatched.}
#'     \item{envo_id}{ENVO identifier for the matched term, or NA_character_.}
#'     \item{media_category}{Top-level routing value: "aqueous", "air", "solid", or NA.}
#'     \item{media_flag}{One of: "" (exact), "parent_walk", "media_unmatched".}
#'   }
#' @importFrom tibble tibble
#' @export
harmonize_media <- function(raw_media, orig_row_id = seq_along(raw_media)) {
```

**Empty-input guard pattern** (`R/date_parser.R` lines 40-49):
```r
  n <- length(raw_media)
  if (n == 0) {
    return(tibble::tibble(
      orig_row_id   = integer(0),
      raw_media     = character(0),
      canonical_media = character(0),
      envo_id       = character(0),
      media_category = character(0),
      media_flag    = character(0)
    ))
  }
```

**Internal cache loader pattern** (`R/unit_harmonizer.R` lines 39-46):
```r
get_media_table <- function() {
  path <- system.file("extdata/reference_cache/amos_media.rds", package = "concert")
  if (nzchar(path) && file.exists(path)) {
    readRDS(path)
  } else {
    NULL
  }
}
```

**Vectorized lookup + flag assignment pattern** (`R/date_parser.R` lines 93-101):
```r
  # Pre-build hash for O(1) exact match
  media_tbl <- get_media_table()
  lookup_hash <- stats::setNames(seq_len(nrow(media_tbl)), tolower(media_tbl$term))

  normalized <- trimws(tolower(raw_media))
  match_idx  <- lookup_hash[normalized]

  # Resolution: exact -> parent-walk -> unmatched
  media_flag <- dplyr::case_when(
    !is.na(match_idx)               ~ "",
    can_walk_parent(normalized, media_tbl) ~ "parent_walk",
    TRUE                             ~ "media_unmatched"
  )
```

**Output tibble pattern** (`R/date_parser.R` lines 103-110):
```r
  tibble::tibble(
    orig_row_id     = as.integer(orig_row_id),
    raw_media       = as.character(raw_media),
    canonical_media = canonical_out,
    envo_id         = envo_out,
    media_category  = category_out,
    media_flag      = media_flag
  )
```

---

### `scripts/build_amos_media.R` (utility, batch/discovery)

**Analog:** `scripts/benchmark_pipeline.R`

Standalone analysis script — no Shiny dependency. Sections delimited by numbered comments. `stopifnot()` guards for prerequisites. `source()` loads only the pure-logic R files needed. Writes output files and console summary at the end.

**Script header + section delimiter pattern** (`scripts/benchmark_pipeline.R` lines 1-18):
```r
# build_amos_media.R
# AMOS media extraction and coverage pipeline
# Extracts environmental media terms from ComptoxR::chemi_amos_method_pagination(),
# maps against curated ENVO subset, expands parentheticals, deduplicates,
# reports coverage gaps, and writes amos_media.rds runtime cache.
#
# No Shiny dependency -- runs in any R session with ComptoxR configured.
#
# Prerequisites:
#   1. ComptoxR API key configured
#   2. ENVO subset defined in inst/extdata/envo_subset.rds (or inline)
#   3. Source this file: source("scripts/build_amos_media.R")
#
# Output:
#   - inst/extdata/reference_cache/amos_media.rds  (runtime cache)
#   - coverage report to console

# ============================================================================
# 0. CONFIGURATION
# ============================================================================
```

**Prerequisites guard pattern** (`scripts/benchmark_pipeline.R` lines 28-33):
```r
stopifnot(
  "ComptoxR package is required" = requireNamespace("ComptoxR", quietly = TRUE),
  "stringr package is required"  = requireNamespace("stringr", quietly = TRUE),
  "dplyr package is required"    = requireNamespace("dplyr", quietly = TRUE)
)
```

**here::here() root + source pattern** (`scripts/benchmark_pipeline.R` lines 22-26):
```r
CONCERT_ROOT <- here::here()

source(file.path(CONCERT_ROOT, "R", "media_harmonizer.R"))
```

**Paginated API extraction pattern** (referenced in `.planning/research/STACK.md`):
```r
# ============================================================================
# 1. FETCH AMOS METHOD DESCRIPTIONS
# ============================================================================
message("=== FETCHING AMOS METHOD DESCRIPTIONS ===")
amos_raw <- tryCatch(
  ComptoxR::chemi_amos_method_pagination(
    start = 0,
    rows  = 10000,
    verbose = FALSE
  ),
  error = function(e) {
    stop(sprintf("AMOS fetch failed: %s", conditionMessage(e)))
  }
)
message(sprintf("  Fetched %d AMOS method records", nrow(amos_raw)))
```

**Coverage report + cache write pattern** (`scripts/benchmark_pipeline.R` lines 430-447):
```r
# ============================================================================
# N. WRITE CACHE + COVERAGE REPORT
# ============================================================================
message("=== WRITING CACHE ===")
cache_path <- file.path(CONCERT_ROOT, "inst", "extdata", "reference_cache", "amos_media.rds")
saveRDS(media_map, cache_path)
message(sprintf("  Cache written: %s (%d term mappings)", basename(cache_path), nrow(media_map)))

message("=== COVERAGE REPORT ===")
message(sprintf("  AMOS terms extracted:  %d", n_amos_extracted))
message(sprintf("  Matched to ENVO subset: %d (%.1f%%)", n_matched, 100 * n_matched / n_amos_extracted))
message(sprintf("  Unmatched (gaps):       %d", n_unmatched))
```

---

### `inst/extdata/reference_cache/amos_media.rds` (reference data, batch)

**Analog:** `inst/extdata/reference_cache/unit_conversion.rds` (provenance pattern), `R/unit_harmonizer.R` lines 39-46 (load pattern).

This is a tibble written by `build_amos_media.R` and read by `get_media_table()`. The schema mirrors the hierarchical media table design from D-07/D-08/D-09.

**Expected tibble schema (D-07, D-09):**
```r
tibble::tibble(
  term           = character(),   # normalized lowercase term string
  canonical_term = character(),   # display-form canonical ENVO term
  envo_id        = character(),   # e.g. "ENVO:00002042"
  parent         = character(),   # parent canonical_term or NA for root
  media_category = character(),   # "aqueous" | "air" | "solid"
  source         = character(),   # "envo_curated" | "amos_derived"
  fetch_timestamp = character()   # ISO-8601 timestamp from build script
)
```

---

### `R/tag_helpers.R` — `classify_tags()` modification (utility, request-response)

**Analog:** Self — 1-line edit at line 41.

**Current pattern** (`R/tag_helpers.R` line 41):
```r
  study_types <- c("StudyDate")
```

**New pattern** (D-15):
```r
  study_types <- c("StudyDate", "Media")
```

The `study_type_tags` output list already exists. No structural change needed — the planner only needs to add `"Media"` to the vector.

---

### `R/mod_tag_columns.R` — selectInput choices modification (component, request-response)

**Analog:** Self — 1-line edit at lines 87-94.

**Current "Study / Contextual" optgroup** (`R/mod_tag_columns.R` lines 87-93):
```r
                    "Study / Contextual" = c(
                      "Duration" = "Duration",
                      "Duration Unit" = "DurationUnit",
                      "Species" = "Species",
                      "Exposure Route" = "ExposureRoute",
                      "Study Date" = "StudyDate"
                    )
```

**New pattern** (D-15):
```r
                    "Study / Contextual" = c(
                      "Duration" = "Duration",
                      "Duration Unit" = "DurationUnit",
                      "Species" = "Species",
                      "Exposure Route" = "ExposureRoute",
                      "Study Date" = "StudyDate",
                      "Media" = "Media"
                    )
```

---

### `R/mod_harmonize.R` — Stage 4.7 media insertion (component, event-driven)

**Analog:** Self — Stage 4.6 date parsing block (lines 443-501) is the direct template.

**Date stage pattern to copy** (`R/mod_harmonize.R` lines 443-501):
```r
              # Stage 4.6: Date parsing (DATE-01, DATE-05)
              incProgress(0.05, detail = "Parsing dates...")
              study_type_tags_vec <- unlist(data_store$study_type_tags)
              date_cols <- if (!is.null(study_type_tags_vec)) {
                names(study_type_tags_vec)[study_type_tags_vec == "StudyDate"]
              } else {
                character(0)
              }
              data_store$date_results <- NULL

              if (length(date_cols) > 0) {
                date_tibble <- tryCatch(
                  parse_dates(
                    raw_dates  = as.character(input_df[[date_cols[1]]]),
                    orig_row_id = seq_len(nrow(input_df))
                  ),
                  error = function(e) {
                    showNotification(
                      paste0("Date parsing failed for column '", date_cols[1], "': ",
                             conditionMessage(e), ". Column skipped."),
                      type = "error", duration = 10
                    )
                    NULL
                  }
                )
                if (!is.null(date_tibble)) {
                  data_store$date_results <- date_tibble
                  # ... QC notifications ...
                }
              }
```

**Media stage adaptation** (insert after Stage 4.6, before Stage 5; D-17, D-18):
```r
              # Stage 4.7: Media harmonization (MEDIA-01, D-18)
              incProgress(0.05, detail = "Harmonizing media...")
              media_cols <- if (!is.null(study_type_tags_vec)) {
                names(study_type_tags_vec)[study_type_tags_vec == "Media"]
              } else {
                character(0)
              }
              data_store$media_results <- NULL

              if (length(media_cols) > 0) {
                media_tibble <- tryCatch(
                  harmonize_media(
                    raw_media   = as.character(input_df[[media_cols[1]]]),
                    orig_row_id = seq_len(nrow(input_df))
                  ),
                  error = function(e) {
                    showNotification(
                      paste0("Media harmonization failed for column '", media_cols[1], "': ",
                             conditionMessage(e), ". Column skipped."),
                      type = "error", duration = 10
                    )
                    NULL
                  }
                )
                if (!is.null(media_tibble)) {
                  data_store$media_results <- media_tibble
                }
              }
```

**`expanded_curated` merge pattern** (`R/mod_harmonize.R` lines 508-531 — duration and date merge; D-16):
```r
              # Merge media_category into expanded_curated BEFORE ToxVal mapper (D-16)
              if (!is.null(data_store$media_results)) {
                media_category_expanded <- data_store$media_results$media_category[
                  harmonize_tibble$orig_row_id
                ]
                expanded_curated$media <- media_category_expanded
              }
```

---

### `R/curate_headless.R` — Stage 3d media insertion (service, batch)

**Analog:** Self — Stage 3c date parsing block (lines 315-327) is the direct template.

**Date stage pattern to copy** (`R/curate_headless.R` lines 315-327):
```r
      # Stage 3c: Date parsing (DATE-05, DATE-06)
      message("[headless] Stage 3c: Parsing dates...")
      date_cols <- names(tag_map)[tag_map == "StudyDate"]

      if (length(date_cols) > 0) {
        date_tibble <- parse_dates(
          raw_dates   = as.character(input_df[[date_cols[1]]]),
          orig_row_id = seq_len(nrow(input_df))
        )
        # Join by position via match() -- same pattern as duration (lines 288-293)
        input_df$year <- date_tibble$date_year[
          match(seq_len(nrow(input_df)), date_tibble$orig_row_id)
        ]
      }
```

**Media stage adaptation** (insert after Stage 3c, before Stage 4; D-18, D-13):
```r
      # Stage 3d: Media harmonization (MEDIA-01, D-18)
      message("[headless] Stage 3d: Harmonizing media...")
      media_cols <- names(tag_map)[tag_map == "Media"]

      if (length(media_cols) > 0) {
        media_tibble <- harmonize_media(
          raw_media   = as.character(input_df[[media_cols[1]]]),
          orig_row_id = seq_len(nrow(input_df))
        )
        # Join by position via match() -- same pattern as date stage above
        input_df$media <- media_tibble$media_category[
          match(seq_len(nrow(input_df)), media_tibble$orig_row_id)
        ]
      } else if (!is.null(media)) {
        # D-13 fallback: dataset-wide media parameter populates column
        input_df$media <- media
      }
```

Also: the `media` parameter on `harmonize_units()` call (line 249) gains per-row values from `input_df$media` when a Media column is tagged:

**Current call** (`R/curate_headless.R` line 249-255):
```r
        harmonize_tibble <- harmonize_units(
          values  = parse_tibble$numeric_value,
          units   = unit_values_expanded,
          unit_map = unit_map,
          media   = media          # <-- dataset-wide scalar
        )
```

**Updated call** (D-12 three-tier cascade):
```r
        # Three-tier cascade (D-12): tagged column > manual param > NULL (aqueous default)
        media_for_harmonize <- if ("media" %in% names(input_df)) {
          input_df$media[parse_tibble$orig_row_id]   # per-row from tagged column
        } else {
          media                                        # dataset-wide fallback
        }
        harmonize_tibble <- harmonize_units(
          values  = parse_tibble$numeric_value,
          units   = unit_values_expanded,
          unit_map = unit_map,
          media   = media_for_harmonize
        )
```

---

### `tests/testthat/test-media-harmonizer.R` (test, transform)

**Analog:** `tests/testthat/test-date-parser.R`

**File header + helper pattern** (`tests/testthat/test-date-parser.R` lines 1-21):
```r
# test-media-harmonizer.R
# Tests for harmonize_media() -- MEDIA-01 through MEDIA-06
# Covers: output schema, exact match, parent-walk, compound/MEDIA-03 ambiguous,
#         unmatched flagging, empty-input guard, category routing

# ---- Helper: canonical test vector ----
make_test_media <- function() {
  c(
    "water",               # exact match -> aqueous
    "freshwater",          # exact match -> aqueous
    "freshwater sediment", # compound first-class -> solid
    "soil",                # exact match -> solid
    "air",                 # exact match -> air
    "blood",               # may be present/absent in ENVO subset
    "unknown_matrix_xyz",  # unmatched -> media_unmatched flag
    NA_character_          # NA input
  )
}
```

**Output schema test pattern** (`tests/testthat/test-date-parser.R` lines 27-42):
```r
test_that("harmonize_media returns 6-column tibble with correct names", {
  result <- harmonize_media(c("water"))

  expect_s3_class(result, "tbl_df")
  expect_named(result, c("orig_row_id", "raw_media", "canonical_media",
                          "envo_id", "media_category", "media_flag"))
})

test_that("harmonize_media returns correct column types", {
  result <- harmonize_media(c("water"))

  expect_type(result$orig_row_id,     "integer")
  expect_type(result$raw_media,       "character")
  expect_type(result$canonical_media, "character")
  expect_type(result$envo_id,         "character")
  expect_type(result$media_category,  "character")
  expect_type(result$media_flag,      "character")
})
```

**Empty-input test pattern** (`tests/testthat/test-date-parser.R` lines ~70+):
```r
test_that("harmonize_media handles empty input", {
  result <- harmonize_media(character(0))

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
  expect_named(result, c("orig_row_id", "raw_media", "canonical_media",
                          "envo_id", "media_category", "media_flag"))
})
```

**MEDIA-03 compound/ambiguous test pattern** (unique to this file; no direct analog):
```r
test_that("harmonize_media flags ambiguous multi-match as media_unmatched (MEDIA-03)", {
  # A string that partially matches two distinct canonical terms at the same
  # hierarchy level should be flagged, not silently resolved
  result <- harmonize_media(c("sediment"))   # exists; not ambiguous
  expect_equal(result$media_flag, "")

  # Construct a string that maps to multiple candidates at same level
  # (exact test values depend on final ENVO subset; use real entries)
})
```

---

## Shared Patterns

### `orig_row_id` Join-by-Position Merge
**Source:** `R/mod_harmonize.R` lines 508-531 (duration/date merge blocks)
**Apply to:** `mod_harmonize.R` media stage, `curate_headless.R` Stage 3d

Media tibble results merge into `expanded_curated` using the same positional indexing pattern as duration and date results:
```r
# Pattern: tibble$column[harmonize_tibble$orig_row_id]
expanded_curated$media <- data_store$media_results$media_category[
  harmonize_tibble$orig_row_id
]
```

### `system.file()` Cache Loading
**Source:** `R/unit_harmonizer.R` lines 39-46 (`get_unit_synonyms()`)
**Apply to:** `R/media_harmonizer.R` internal `get_media_table()`

All reference data loaded via `system.file("extdata/reference_cache/<file>.rds", package = "concert")`. Returns `NULL` if not found (graceful degradation).

### `tryCatch()` Stage Error Handling
**Source:** `R/mod_harmonize.R` lines 452-501 (date stage tryCatch block)
**Apply to:** `R/mod_harmonize.R` Stage 4.7 media block

Stage failures show `showNotification(..., type = "error", duration = 10)` and return NULL, which skips the merge step downstream.

### `dedup_step()` Wrapping for Dedup Eligibility
**Source:** `R/cleaning_pipeline.R` lines 184-229 (`dedup_step()` function, usage lines 1963-1964)
**Apply to:** `R/mod_harmonize.R` Stage 4.7 / orchestrator call site (D-19)

Media strings are highly duplicative. Per D-19, `harmonize_media()` is wrapped with `dedup_step()` at the orchestrator level, not inside the function itself:
```r
# At call site in mod_harmonize.R Stage 4.7 (when dedup is warranted):
media_tibble <- dedup_step(
  harmonize_media,
  input_df,
  dedup_cols = media_cols[1]
)
```

### Audit Vector Pre-Allocation
**Source:** `CLAUDE.md` "Audit Trail Building in Cleaning Functions" section
**Apply to:** Any audit-trail-producing code in `R/media_harmonizer.R`

Do not use growing list pattern. Pre-allocate `integer()` / `character()` vectors, build single tibble at end.

### `message()` Progress Reporting in Headless Path
**Source:** `R/curate_headless.R` lines 219-336 (Stage messages)
**Apply to:** `R/curate_headless.R` Stage 3d

Use consistent `[headless] Stage Xd:` prefix matching existing stages:
```r
message("[headless] Stage 3d: Harmonizing media...")
```

---

## No Analog Found

All files have close analogs in the codebase. No files require falling back to RESEARCH.md patterns as primary reference.

---

## Metadata

**Analog search scope:** `R/`, `scripts/`, `tests/testthat/`, `inst/extdata/reference_cache/`
**Key files read:** `R/date_parser.R`, `R/unit_harmonizer.R`, `R/tag_helpers.R`, `R/mod_tag_columns.R`, `R/mod_harmonize.R`, `R/curate_headless.R`, `R/cleaning_pipeline.R` (dedup_step), `scripts/benchmark_pipeline.R`, `tests/testthat/test-date-parser.R`, `tests/testthat/test-tag-dispatch.R`
**Pattern extraction date:** 2026-04-27
