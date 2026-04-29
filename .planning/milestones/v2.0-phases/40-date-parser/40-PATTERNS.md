# Phase 40: Date Parser - Pattern Map

**Mapped:** 2026-04-26
**Files analyzed:** 9 (1 new function file, 1 new test file, 7 modifications)
**Analogs found:** 9 / 9

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `R/date_parser.R` | service | transform | `R/unit_harmonizer.R` (`harmonize_units()`) | role-match (same output contract, same flag pattern) |
| `R/tag_helpers.R` | utility | — | `R/tag_helpers.R` itself (extend `classify_tags()`) | self |
| `R/tag_dispatch.R` | — | — | Does not exist — `tag_helpers.R` is the only tag file | N/A — no separate dispatch file |
| `R/mod_harmonize.R` | module/server | request-response | `R/mod_harmonize.R` Stage 4.5 duration block (lines 387–430) | self-template |
| `R/curate_headless.R` | script | batch | `R/curate_headless.R` Stage 3.5 duration block (lines 275–294) | self-template |
| `R/mod_tag_columns.R` | module/UI | request-response | `R/mod_tag_columns.R` optgroup at lines 84–91 | self |
| `R/toxval_mapper.R` | service | transform | `R/toxval_mapper.R` line 153 | self (verify only, no change) |
| `DESCRIPTION` | config | — | `DESCRIPTION` Imports block | self |
| `tests/testthat/test-date-parser.R` | test | — | `tests/testthat/test-unit-harmonizer.R` | role-match |

---

## Pattern Assignments

### `R/date_parser.R` (new file — service, transform)

**Analog:** `R/unit_harmonizer.R` — `harmonize_units()` function

**File header pattern** (unit_harmonizer.R lines 1–5):
```r
# date_parser.R
# Date string parsing engine: format detection, partial date handling, ambiguity flagging.
#
# Public API: parse_dates()
# Internal: 2-digit year detection via regex pre-scan
```

**Empty-input guard pattern** (unit_harmonizer.R lines 302–312):
```r
n <- length(raw_dates)
if (n == 0) {
  return(tibble::tibble(
    orig_row_id = integer(0),
    raw_date    = character(0),
    parsed_date = character(0),
    date_year   = integer(0),
    date_flag   = character(0)
  ))
}
```

**Output tibble construction** (unit_harmonizer.R lines 629–637 — adapt column names):
```r
tibble::tibble(
  orig_row_id = as.integer(orig_row_id),
  raw_date    = as.character(raw_dates),
  parsed_date = parsed_date,        # ISO-8601 "YYYY-MM-DD" or NA_character_
  date_year   = as.integer(date_year),
  date_flag   = date_flag           # "" | "partial" | "inferred_format" | "ambiguous" | "unparseable"
)
```

**Flag assignment priority pattern** (unit_harmonizer.R lines 619–626 — ambiguous flag, adapt for date flags):
The unit harmonizer assigns `unit_flag` with last-write-wins. For `parse_dates()`, use `dplyr::case_when()` instead to enforce strict priority (`"unparseable"` > `"partial"` > `"inferred_format"` > `"ambiguous"` > `""`). This is the pattern provided in RESEARCH.md §Architecture Patterns.

**Vectorized approach** (unit_harmonizer.R lines 340–343):
```r
# Initialize output vectors — no per-row loop; parse_date_time() is already vectorized
harmonized_value <- values
harmonized_unit  <- orig_unit
conversion_factor <- rep(1, n)
unit_flag        <- rep("", n)
```
For `parse_dates()`, apply the same pattern: pre-allocate scalar result vectors before the `dplyr::case_when()` flag assignment, avoid row-level iteration.

**Roxygen `@export` pattern** (unit_harmonizer.R line 284):
```r
#' @importFrom tibble tibble
#' @export
parse_dates <- function(raw_dates, orig_row_id = seq_along(raw_dates)) {
```

**Full implementation skeleton** (from RESEARCH.md §Architecture Patterns — verified against codebase conventions):
```r
parse_dates <- function(raw_dates, orig_row_id = seq_along(raw_dates)) {
  # Pre-compiled orders (bY/BY before mdy — critical ordering, PITFALL-02)
  ORDERS <- c("ymd", "Ymd", "bY", "BY", "dBY", "BdY", "mdy", "dmy", "Y", "Ym")
  # 2-digit year detection (PITFALL-03: cutoff_2000 does not exist in parse_date_time)
  TWO_DIGIT_PAT <- "[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}$"

  n <- length(raw_dates)
  if (n == 0) {
    return(tibble::tibble(
      orig_row_id = integer(0), raw_date = character(0),
      parsed_date = character(0), date_year = integer(0), date_flag = character(0)
    ))
  }

  # Vectorized parse — train=FALSE required for heterogeneous formats (PITFALL-01)
  parsed_posix <- lubridate::parse_date_time(raw_dates, orders = ORDERS,
                                              train = FALSE, quiet = TRUE)
  parsed_date <- format(as.Date(parsed_posix), "%Y-%m-%d")
  parsed_date[is.na(parsed_posix)] <- NA_character_
  date_year <- lubridate::year(parsed_posix)
  date_year[is.na(parsed_posix)] <- NA_integer_

  # Flag vectors (priority: unparseable > partial > inferred_format > ambiguous > "")
  is_unparseable <- is.na(parsed_posix)
  is_partial     <- !is_unparseable & (
    grepl("^[0-9]{4}$", trimws(raw_dates)) |
    grepl("^[0-9]{4}[-/][0-9]{1,2}$", trimws(raw_dates)) |
    grepl("^[A-Za-z]+ [0-9]{4}$", trimws(raw_dates))
  )
  is_inferred    <- !is_unparseable & grepl(TWO_DIGIT_PAT, raw_dates, perl = TRUE)
  # PITFALL-04: partial check must precede ambiguity to avoid year-only "2015" false-positive
  is_ambiguous   <- !is_unparseable & !is_partial &
    lubridate::day(parsed_posix) <= 12 &
    lubridate::month(parsed_posix) <= 12

  date_flag <- dplyr::case_when(
    is_unparseable ~ "unparseable",
    is_partial     ~ "partial",
    is_inferred    ~ "inferred_format",
    is_ambiguous   ~ "ambiguous",
    TRUE           ~ ""
  )

  tibble::tibble(
    orig_row_id = as.integer(orig_row_id),
    raw_date    = as.character(raw_dates),
    parsed_date = parsed_date,
    date_year   = as.integer(date_year),
    date_flag   = date_flag
  )
}
```

---

### `R/tag_helpers.R` — extend `classify_tags()` (modify)

**Analog:** `R/tag_helpers.R` itself — the existing three-group partition pattern (lines 35–83)

**Type membership vectors** (lines 37–39 — add fourth vector below existing three):
```r
chemical_types <- c("Name", "CASRN", "Other")
numeric_types  <- c("Result", "Unit", "Qualifier", "Duration", "DurationUnit")
metadata_types <- c("Species", "ExposureRoute")
study_types    <- c("StudyDate")       # NEW — Phase 40 (D-13)
```

**Empty return slot** (lines 44–48 — add fourth slot):
```r
return(list(
  chemical_tags  = list(),
  numeric_tags   = list(),
  metadata_tags  = list(),
  study_type_tags = list()    # NEW
))
```

**Index and build pattern** (lines 55–76 — add fourth block, copy existing block exactly):
```r
study_type_idx <- which(tag_values %in% study_types)

study_type_tags <- if (length(study_type_idx) > 0) {
  stats::setNames(as.list(tag_values[study_type_idx]), tag_names[study_type_idx])
} else {
  list()
}
```

**Return list** (lines 78–82 — add fourth element):
```r
list(
  chemical_tags   = chemical_tags,
  numeric_tags    = numeric_tags,
  metadata_tags   = metadata_tags,
  study_type_tags = study_type_tags   # NEW
)
```

**PITFALL-05 note:** Every caller that destructures `classify_tags()` output must be updated. Known callers to search: `mod_harmonize.R`, `mod_tag_columns.R`, `tests/testthat/test-tag-dispatch.R` (lines 9, 53 — `expect_named()` assertions will fail if slot not added there too).

**Roxygen @return block** (lines 14–19 — add fourth item):
```r
#'   \item{study_type_tags}{Named list of study/contextual tags (StudyDate)}
```

---

### `R/mod_harmonize.R` — Stage 4.6 insertion (modify)

**Analog:** Stage 4.5 duration harmonization block (lines 387–430) — exact structural template

**Stage 4.5 template to mirror** (lines 387–406):
```r
# Stage 4.5: Duration harmonization (D-13, DUR-03)
incProgress(0.05, detail = "Harmonizing durations...")
duration_cols      <- names(numeric_tags_vec)[numeric_tags_vec == "Duration"]
duration_unit_cols <- names(numeric_tags_vec)[numeric_tags_vec == "DurationUnit"]
data_store$duration_results <- NULL

if (length(duration_cols) > 0 && length(duration_unit_cols) > 0) {
  dur_tibble <- harmonize_units(...)
  data_store$duration_results <- tibble::tibble(...)
}
```

**Stage 4.6 to insert after line 406** (before "Stage 5: Map to ToxVal schema"):
```r
# Stage 4.6: Date parsing (DATE-01, DATE-05)
incProgress(0.05, detail = "Parsing dates...")
study_type_tags_vec <- unlist(data_store$study_type_tags)
date_cols <- names(study_type_tags_vec)[study_type_tags_vec == "StudyDate"]
data_store$date_results <- NULL

if (length(date_cols) > 0) {
  date_tibble <- parse_dates(
    raw_dates   = as.character(input_df[[date_cols[1]]]),
    orig_row_id = seq_len(nrow(input_df))
  )
  data_store$date_results <- date_tibble
}
```

**Duration merge into `expanded_curated` template** (lines 415–430 — mirror for date):
```r
# Merge duration columns if present (D-10)
if (!is.null(data_store$duration_results)) {
  dur_for_merge <- data_store$duration_results[, c(
    "orig_row_id", "study_duration_value", "study_duration_units"
  )]
  dur_values_expanded <- dur_for_merge$study_duration_value[harmonize_tibble$orig_row_id]
  dur_units_expanded  <- dur_for_merge$study_duration_units[harmonize_tibble$orig_row_id]
  expanded_curated$study_duration_value <- dur_values_expanded
  expanded_curated$study_duration_units <- dur_units_expanded
}
```

**Date merge block to insert after the duration merge block** (before `map_to_toxval_schema()` call at line 432):
```r
# Merge date_year into expanded_curated for original_year ToxVal mapping (DATE-06, D-16)
if (!is.null(data_store$date_results)) {
  year_expanded <- data_store$date_results$date_year[harmonize_tibble$orig_row_id]
  expanded_curated$year <- year_expanded
}
```

**QC dashboard value_box pattern** (lines 493–519 — add ambiguous date count box):
```r
bslib::value_box(
  title   = "Rows Parsed",
  value   = n_parsed,
  showcase = bsicons::bs_icon("123"),
  theme   = "primary"
)
```
New box follows the same four-argument call with `col_widths` adjusted (from `c(3,3,3,3)` to `c(3,3,2,2,2)` to fit a fifth box, or wrap into a second row). Label: `"Ambiguous Dates"`, icon: `"calendar-x"`, theme: `"warning"`. Count derived from:
```r
n_ambiguous_dates <- if (!is.null(data_store$date_results)) {
  sum(data_store$date_results$date_flag == "ambiguous", na.rm = TRUE)
} else {
  0L
}
```

**`data_store$study_type_tags` wiring note:** The call at line 389 uses `numeric_tags_vec <- unlist(data_store$numeric_tags)`. For the date stage, `data_store$study_type_tags` must be populated by `mod_tag_columns.R` in the same `observeEvent(input$apply_tags, ...)` block where `data_store$numeric_tags` is currently set. Search that block in `mod_tag_columns.R` to add the parallel assignment.

---

### `R/curate_headless.R` — Stage 3c insertion (modify)

**Analog:** Stage 3.5 duration block (lines 275–294) — exact structural template

**Stage 3.5 template** (lines 275–294):
```r
# Stage 3.5: Duration harmonization (D-13, DUR-03)
message("[headless] Stage 3.5: Harmonizing durations...")
duration_cols      <- names(tag_map)[tag_map == "Duration"]
duration_unit_cols <- names(tag_map)[tag_map == "DurationUnit"]

if (length(duration_cols) > 0 && length(duration_unit_cols) > 0) {
  dur_tibble <- harmonize_units(
    values   = as.numeric(input_df[[duration_cols[1]]]),
    units    = as.character(input_df[[duration_unit_cols[1]]]),
    unit_map = unit_map,
    category = "duration"
  )
  # Join by position via match()
  input_df$study_duration_value <- dur_tibble$harmonized_value[
    match(seq_len(nrow(input_df)), dur_tibble$orig_row_id)
  ]
  input_df$study_duration_units <- dur_tibble$harmonized_unit[
    match(seq_len(nrow(input_df)), dur_tibble$orig_row_id)
  ]
}
```

**Stage 3c to insert after line 294** (before "Stage 4: Map to ToxVal schema"):
```r
# Stage 3c: Date parsing (DATE-05, DATE-06)
message("[headless] Stage 3c: Parsing dates...")
date_cols <- names(tag_map)[tag_map == "StudyDate"]

if (length(date_cols) > 0) {
  date_tibble <- parse_dates(
    raw_dates   = as.character(input_df[[date_cols[1]]]),
    orig_row_id = seq_len(nrow(input_df))
  )
  # Join by position via match() — same pattern as duration (lines 288-293)
  input_df$year <- date_tibble$date_year[
    match(seq_len(nrow(input_df)), date_tibble$orig_row_id)
  ]
}
```

---

### `R/mod_tag_columns.R` — optgroup rename and StudyDate addition (modify)

**Analog:** `R/mod_tag_columns.R` optgroup block (lines 84–91)

**Current "Study" optgroup** (lines 88–91):
```r
"Study" = c(
  "Duration" = "Duration", "Duration Unit" = "DurationUnit",
  "Species" = "Species", "Exposure Route" = "ExposureRoute"
)
```

**Required replacement** (D-14, rename optgroup key and add StudyDate):
```r
"Study / Contextual" = c(
  "Duration" = "Duration", "Duration Unit" = "DurationUnit",
  "Species" = "Species", "Exposure Route" = "ExposureRoute",
  "Study Date" = "StudyDate"
)
```

**`data_store$study_type_tags` assignment** — find the `observeEvent(input$apply_tags, ...)` block where `data_store$numeric_tags` and `data_store$metadata_tags` are assigned from `classify_tags()` output, and add:
```r
data_store$study_type_tags <- classified$study_type_tags
```

---

### `R/toxval_mapper.R` — `original_year` wiring (verify only, no code change)

**Existing wiring at line 153:**
```r
original_year = safe_extract_num(curated_data, "year", n_rows)
```
No change needed. The date stage (Stage 4.6 / Stage 3c) must populate `expanded_curated$year` / `input_df$year` before the mapper is called. The mapper already reads the `year` column by name.

---

### `DESCRIPTION` — `lubridate` to Imports (modify)

**Analog:** Existing Imports block (lines 13–42)

**Current state:** `lubridate` is absent from both `Imports:` and `Suggests:`. The RESEARCH.md statement that it is in `Suggests:` is incorrect per the actual file — it is entirely missing.

**Required change:** Add `lubridate,` to the Imports block in alphabetical order (after `jsonlite,`, before `magrittr,`):
```
Imports:
    arrow,
    bsicons,
    bslib,
    ComptoxR,
    digest,
    dplyr,
    fs,
    here,
    janitor,
    jsonlite,
    lubridate,        # ADD HERE
    magrittr,
    ...
```

**Alphabetical position:** `lubridate` sorts between `jsonlite` and `magrittr`.

---

### `tests/testthat/test-date-parser.R` (new file — test)

**Analog:** `tests/testthat/test-unit-harmonizer.R` — section-organized `test_that()` blocks with helper fixtures

**File header and helper pattern** (test-unit-harmonizer.R lines 1–17):
```r
# test-date-parser.R
# Tests for parse_dates() — DATE-01 through DATE-03
# Covers: format families, output schema, partial dates, ambiguity flagging,
#         2-digit year detection, unparseable strings

# ---- Helper: canonical test vector ----
make_test_dates <- function() {
  c(
    "2015-03-15",    # ymd ISO
    "03/15/2015",    # mdy US
    "15/03/2015",    # dmy European
    "15MAR2015",     # SAS dBY
    "2015",          # year-only partial
    "Mar 2015",      # month-year partial (bY)
    "2015-03",       # month-year numeric (Ym)
    "03/04/15",      # 2-digit year -> inferred_format
    "01/02/2015",    # ambiguous (day=1<=12, month=2<=12 — or month=1, day=2)
    "N/A",           # unparseable
    NA_character_    # NA input
  )
}
```

**Section organization pattern** (test-unit-harmonizer.R — section headers):
```r
# ==============================================================================
# SECTION 1: Output schema (DATE-02)
# ==============================================================================

test_that("parse_dates returns 5-column tibble with correct types", {
  result <- parse_dates(c("2015-03-15"))

  expect_s3_class(result, "tbl_df")
  expect_named(result, c("orig_row_id", "raw_date", "parsed_date", "date_year", "date_flag"))
  expect_type(result$orig_row_id, "integer")
  expect_type(result$raw_date, "character")
  expect_type(result$parsed_date, "character")
  expect_type(result$date_year, "integer")
  expect_type(result$date_flag, "character")
})

# ==============================================================================
# SECTION 2: Format families (DATE-01)
# ==============================================================================

test_that("parse_dates handles ISO ymd format", {
  result <- parse_dates(c("2015-03-15"))
  expect_equal(result$parsed_date, "2015-03-15")
  expect_equal(result$date_year, 2015L)
  expect_equal(result$date_flag, "")
})

# ... one test_that block per format family

# ==============================================================================
# SECTION 3: Ambiguity flagging (DATE-03)
# ==============================================================================

test_that("parse_dates flags ambiguous date (day<=12, month<=12)", {
  result <- parse_dates(c("01/02/2015"))
  expect_equal(result$date_flag, "ambiguous")
})

test_that("parse_dates does NOT flag unambiguous date (day=13)", {
  result <- parse_dates(c("13/02/2015"))
  expect_equal(result$date_flag, "")
})

# ==============================================================================
# SECTION 4: Partial dates (D-03, D-04)
# ==============================================================================
# ==============================================================================
# SECTION 5: 2-digit year (D-08, D-09)
# ==============================================================================
# ==============================================================================
# SECTION 6: Unparseable / empty (D-10)
# ==============================================================================
# ==============================================================================
# SECTION 7: Empty input guard
# ==============================================================================
```

**Single-assertion test style** (test-unit-harmonizer.R lines 79–83):
```r
test_that("single behavior described precisely", {
  result <- parse_dates(c("2015-03-15"))
  expect_equal(result$parsed_date, "2015-03-15")
  expect_equal(result$date_year, 2015L)
  expect_equal(result$date_flag, "")
})
```

**Extension to `test-tag-dispatch.R`** — add after line 164, following the same `test_that("classify_tags handles all N tag types")` pattern:
```r
test_that("classify_tags partitions study_type tags correctly", {
  tags <- list(col1 = "StudyDate")
  result <- classify_tags(tags)

  expect_named(result, c("chemical_tags", "numeric_tags", "metadata_tags", "study_type_tags"))
  expect_equal(result$study_type_tags, list(col1 = "StudyDate"))
  expect_equal(result$chemical_tags, list())
  expect_equal(result$numeric_tags, list())
  expect_equal(result$metadata_tags, list())
})

test_that("classify_tags empty return includes study_type_tags slot", {
  result <- classify_tags(list())
  expect_named(result, c("chemical_tags", "numeric_tags", "metadata_tags", "study_type_tags"))
})
```
The existing `expect_named(result, c("chemical_tags", "numeric_tags", "metadata_tags"))` assertions at lines 9 and 53 must also be updated to include `"study_type_tags"`.

---

## Shared Patterns

### Vectorized output tibble with `orig_row_id`
**Source:** `R/unit_harmonizer.R` lines 317–318 and 629–637
**Apply to:** `R/date_parser.R`
```r
orig_row_id <- seq_len(n)   # established early, carried through to tibble construction
# ...
tibble::tibble(
  orig_row_id = as.integer(orig_row_id),
  ...
)
```
All harmonization output tibbles anchor to `orig_row_id` for join-by-position expansion later. `parse_dates()` must follow the same contract.

### `match()` join for headless path
**Source:** `R/curate_headless.R` lines 288–293
**Apply to:** Stage 3c in `curate_headless.R`
```r
input_df$study_duration_value <- dur_tibble$harmonized_value[
  match(seq_len(nrow(input_df)), dur_tibble$orig_row_id)
]
```
The headless path uses `match()` rather than subscript indexing because `input_df` is not range-expanded (unlike `harmonize_tibble` in the Shiny path).

### `harmonize_tibble$orig_row_id` subscript for Shiny path
**Source:** `R/mod_harmonize.R` lines 426–429
**Apply to:** Date merge block in Stage 4.6
```r
dur_values_expanded <- dur_for_merge$study_duration_value[harmonize_tibble$orig_row_id]
expanded_curated$study_duration_value <- dur_values_expanded
```
The Shiny path uses direct subscript indexing into the result tibble because `harmonize_tibble$orig_row_id` is already in 1:n order with possible repeats from range expansion.

### `bslib::value_box()` QC metric
**Source:** `R/mod_harmonize.R` lines 494–519
**Apply to:** New ambiguous-dates box in `qc_dashboard` renderUI
```r
bslib::value_box(
  title    = "...",
  value    = n_...,
  showcase = bsicons::bs_icon("..."),
  theme    = "warning"
)
```
Box is conditional on `!is.null(data_store$date_results)` to avoid showing zero when no StudyDate column is tagged.

### `purrr::safely()` / `tryCatch()` error isolation
**Source:** `R/mod_harmonize.R` lines 432–446
**Apply to:** Date parse call in Stage 4.6 (optional — apply if robustness needed)
```r
toxval_tibble <- tryCatch(
  map_to_toxval_schema(...),
  error = function(e) {
    showNotification(paste("... failed:", conditionMessage(e)), type = "warning", duration = 8)
    NULL
  }
)
```
Wrap `parse_dates()` call in `tryCatch()` with `showNotification()` if failure should degrade gracefully rather than crash the pipeline.

---

## No Analog Found

All files have analogs. No entries in this section.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| — | — | — | — |

---

## Metadata

**Analog search scope:** `R/`, `tests/testthat/`, project root
**Files scanned:** 12 source files read directly
**Pattern extraction date:** 2026-04-26

### Key Implementation Notes

1. `R/tag_dispatch.R` referenced in the context prompt does not exist as a file. Tag dispatch logic lives entirely in `R/tag_helpers.R`. No separate dispatch file to modify.

2. `lubridate` is completely absent from DESCRIPTION (not in Imports or Suggests). The RESEARCH.md note saying it is in "Suggests" is incorrect — planner should treat this as an unconditional add to Imports, not a move.

3. The `classify_tags()` return list signature change (adding `study_type_tags`) is the highest-risk modification because test assertions at `test-tag-dispatch.R` lines 9 and 53 use `expect_named()` with an explicit 3-element vector that will fail. Both must be updated.

4. `data_store$study_type_tags` must be assigned in `mod_tag_columns.R` (inside `observeEvent(input$apply_tags)`) alongside the existing `data_store$numeric_tags` and `data_store$metadata_tags` assignments. Search `mod_tag_columns.R` for those assignments to find the exact insertion point.
