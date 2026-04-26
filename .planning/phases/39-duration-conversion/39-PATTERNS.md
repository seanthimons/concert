# Phase 39: Duration Conversion - Pattern Map

**Mapped:** 2026-04-26
**Files analyzed:** 6 (2 RDS data files, 3 R source files, 1 test file)
**Analogs found:** 6 / 6

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `R/unit_harmonizer.R` | service/utility | transform | self (adding `category` param) | self-extend |
| `inst/extdata/unit_conversion.rds` | config/data | batch | existing "time" category rows (rows 96-114) | exact schema |
| `inst/extdata/unit_synonyms.rds` | config/data | batch | existing synonym rows (rows 1-10, body-weight pattern) | exact schema |
| `R/mod_harmonize.R` | Shiny module | request-response | Stage 3 unit harmonization block (lines 341-366) | exact pattern |
| `R/curate_headless.R` | service | batch | Stage 3 harmonization block (lines 237-261) | exact pattern |
| `tests/testthat/test-unit-harmonizer.R` | test | — | Sections 11-13 (ppb/ppm flag tests, lines 470-674) | exact pattern |

---

## Pattern Assignments

### `R/unit_harmonizer.R` — add `category` parameter

**Analog:** self (current signature at line 273)

**Current signature** (lines 273-281):
```r
harmonize_units <- function(
  values,
  units,
  unit_map,
  media = NULL,
  dtxsid = NULL,
  molecular_weight = NULL,
  use_dedup = TRUE
) {
```

**New signature with `category` parameter** — insert after `use_dedup`:
```r
harmonize_units <- function(
  values,
  units,
  unit_map,
  media = NULL,
  dtxsid = NULL,
  molecular_weight = NULL,
  use_dedup = TRUE,
  category = NULL   # NEW: filter conversion table to this category (D-12)
) {
  # NEW: category filter — applied before dedup key construction (D-12)
  if (!is.null(category)) {
    unit_map <- unit_map[unit_map$category == category, , drop = FALSE]
  }

  # Step 0: Handle empty input  <--- rest of function unchanged from here
```

**Insertion point:** After the opening `{` of `harmonize_units`, before "Step 0: Handle empty input" (line 282). The filter must run before the dedup key construction at line 373.

**"m" ambiguity flag** — post-processing step after the dedup if/else block, before building the output tibble (after line 589):
```r
  # D-01: Flag ambiguous "m" rows (mapped to minutes via synonym, but inherently ambiguous)
  # Applied after all conversion paths to avoid polluting the dedup key logic.
  ambiguous_orig <- c("m")   # extend if D-02 identifies others
  ambiguous_mask <- trimws(tolower(orig_unit)) %in% ambiguous_orig
  if (any(ambiguous_mask)) {
    unit_flag[ambiguous_mask] <- "ambiguous_unit"
  }
```

---

### `inst/extdata/unit_conversion.rds` — add duration rows

**Analog:** existing "time" category rows (verified from file, rows 96-114)

**Existing "time" schema** (exact column names and types confirmed):
```
from_unit  to_unit  multiplier  category  confidence  source
"day"      "day"    1.0         "time"    "HIGH"      "ECOTOX"
"hr"       "day"    0.04166667  "time"    "HIGH"      "ECOTOX"
"min"      "day"    0.00069444  "time"    "HIGH"      "ECOTOX"
...
```

**Build script pattern** — use a temp R script (per project CLAUDE.md convention). The new rows follow the identical 6-column schema with `category="duration"`, `to_unit="hr"`:

```r
# Script to append duration rows to unit_conversion.rds
uc <- readRDS("inst/extdata/unit_conversion.rds")

duration_rows <- tibble::tibble(
  from_unit  = c("hr","h","hour","hours","day","d","days",
                 "wk","week","weeks","mo","month","months",
                 "yr","year","years","min","minute","minutes",
                 "s","sec","second","seconds"),
  to_unit    = rep("hr", 23),
  multiplier = c(1, 1, 1, 1,           # hr variants
                 24, 24, 24,             # day variants
                 168, 168, 168,          # week variants (7*24)
                 730.5, 730.5, 730.5,    # month variants (30.4375*24)
                 8766, 8766, 8766,       # year variants (365.25*24)
                 1/60, 1/60, 1/60,       # minute variants (exact fraction)
                 1/3600, 1/3600, 1/3600, 1/3600),  # second variants
  category   = rep("duration", 23),
  confidence = rep("HIGH", 23),
  source     = rep("ECOTOX", 23)
)

uc_new <- dplyr::bind_rows(uc, duration_rows)
saveRDS(uc_new, "inst/extdata/unit_conversion.rds")
```

**Key difference from "time" category:** multipliers are TO hours (not to days). Example: `day` → multiplier `24` (not `1` as in the "time" category). Use exact fractions (`1/60`, `1/3600`) not rounded decimals.

**Conflict note:** Both "time" and "duration" categories have `from_unit="day"`, `"hr"`, etc. The `category="duration"` filter in `harmonize_units()` isolates the correct rows. Unfiltered calls see both — whichever appears first wins for duplicate `from_unit` keys.

---

### `inst/extdata/unit_synonyms.rds` — add duration synonym rows

**Analog:** existing exact-match rows (rows 1-10, body-weight pattern, confirmed schema)

**Existing schema** (4 columns, confirmed):
```
input_pattern    normalized_unit    is_regex    notes
"mg/kg bw/day"   "mg/kg/d"          FALSE       "Body weight qualifier removed"
```

**Build script pattern:**
```r
us <- readRDS("inst/extdata/unit_synonyms.rds")

duration_synonyms <- tibble::tibble(
  input_pattern = c(
    # hr variants
    "hrs","Hr","HR","Hrs","HRS",
    # day variants
    "Day","DAY","Days","DAYS",
    # week variants
    "Wk","WK","Week","WEEK","Weeks","WEEKS",
    # month variants
    "Mo","MO","Month","MONTH","Months","MONTHS",
    # year variants
    "Yr","YR","Year","YEAR","Years","YEARS",
    # minute variants
    "Min","MIN","Minute",
    # second variants
    "Sec","SEC","Second",
    # AMBIGUOUS: "m" -> minutes (D-01)
    "m"
  ),
  normalized_unit = c(
    "hr","hr","hr","hr","hr",
    "day","day","day","day",
    "wk","wk","week","week","week","week",
    "mo","mo","month","month","month","month",
    "yr","yr","year","year","year","year",
    "min","min","minute",
    "sec","sec","second",
    "min"   # "m" maps to minutes; ambiguous_unit flag added post-synonym in harmonize_units()
  ),
  is_regex = FALSE,
  notes = c(
    rep("Duration plural/case abbreviation", 5),
    rep("Duration capitalized/uppercase", 4),
    rep("Duration capitalized/uppercase", 6),
    rep("Duration capitalized/uppercase", 6),
    rep("Duration capitalized/uppercase", 6),
    rep("Duration capitalized/uppercase", 3),
    rep("Duration capitalized/uppercase", 3),
    "AMBIGUOUS — maps to minutes per D-01; ambiguous_unit flag set by harmonize_units()"
  )
)

us_new <- dplyr::bind_rows(us, duration_synonyms)
saveRDS(us_new, "inst/extdata/unit_synonyms.rds")
```

**Note:** `is_regex=FALSE` for all entries (exact-match lookup path, O(1) hash lookup in `apply_synonyms()`). The "m" entry's ambiguity flag is NOT set here — it is set by post-processing in `harmonize_units()` after synonym normalization.

---

### `R/mod_harmonize.R` — insert duration stage

**Analog:** Stage 3 unit harmonization block (lines 341-366) + Stage 5 expanded_curated construction (lines 387-409)

**Stage 3 pattern to mirror** (lines 341-366):
```r
# Stage 3: Harmonize units (if a Unit column is tagged)
incProgress(0.30, detail = "Harmonizing units...")
if (length(unit_cols) > 0) {
  unit_values <- as.character(input_df[[unit_cols[1]]])
  # Ranges expand rows -- re-broadcast unit via orig_row_id
  if (nrow(parse_tibble) > length(unit_values)) {
    unit_values_expanded <- unit_values[parse_tibble$orig_row_id]
  } else {
    unit_values_expanded <- unit_values
  }
  harmonize_tibble <- harmonize_units(
    values   = parse_tibble$numeric_value,
    units    = unit_values_expanded,
    unit_map = data_store$unit_map_working
  )
} else { ... }
```

**Stage 4 store pattern** (lines 368-385) — stores results, builds audit. Duration results stored similarly.

**Stage 5 pattern** (lines 387-408) — key lines:
```r
# Stage 5: Map to ToxVal schema
incProgress(0.10, detail = "Mapping to ToxVal schema...")
expanded_curated <- data_store$resolution_state[harmonize_tibble$orig_row_id, ]
toxval_tibble <- tryCatch(
  map_to_toxval_schema(
    curated_data   = expanded_curated,
    harmonized_data = harmonize_tibble,
    source_name    = data_store$file_info$name
  ),
  error = function(e) { ... }
)
data_store$toxval_output <- toxval_tibble
```

**New duration stage — insert between Stage 4 and Stage 5** (after line 385, before line 387):
```r
# Stage 4.5: Duration harmonization (D-13)
incProgress(0.05, detail = "Harmonizing durations...")
duration_cols      <- names(numeric_tags_vec)[numeric_tags_vec == "Duration"]
duration_unit_cols <- names(numeric_tags_vec)[numeric_tags_vec == "DurationUnit"]
data_store$duration_results <- NULL  # reset

if (length(duration_cols) > 0 && length(duration_unit_cols) > 0) {
  dur_tibble <- harmonize_units(
    values   = as.numeric(input_df[[duration_cols[1]]]),
    units    = as.character(input_df[[duration_unit_cols[1]]]),
    unit_map = data_store$unit_map_working,
    category = "duration"
  )
  data_store$duration_results <- tibble::tibble(
    orig_row_id          = dur_tibble$orig_row_id,
    study_duration_value = dur_tibble$harmonized_value,
    study_duration_units = dur_tibble$harmonized_unit,
    duration_unit_flag   = dur_tibble$unit_flag
  )
}
```

**Stage 5 modification** — merge duration columns onto `expanded_curated` before mapper call. Insert after `expanded_curated <- ...` (line 392), before `toxval_tibble <- tryCatch(...)`:
```r
expanded_curated <- data_store$resolution_state[harmonize_tibble$orig_row_id, ]

# Merge duration columns if present (D-10)
if (!is.null(data_store$duration_results)) {
  expanded_curated <- dplyr::left_join(
    expanded_curated,
    data_store$duration_results[, c("orig_row_id", "study_duration_value", "study_duration_units")],
    by = "orig_row_id"
  )
}
```

**Critical assumption to verify before implementing:** `data_store$resolution_state` must have an `orig_row_id` column for the join. If not, join by row position instead. Check `R/curate_headless.R` line 177 where `resolution_state` is produced — it comes from `pipeline_result$results`.

---

### `R/curate_headless.R` — insert duration stage

**Analog:** Stage 3 harmonization block (lines 237-261) + Stage 4 mapper call (lines 275-282)

**Stage 3 pattern to mirror** (lines 237-261):
```r
# Stage 3: Harmonize units
message("[headless] Stage 3: Harmonizing units...")
if (length(unit_cols) > 0) {
  unit_values <- as.character(input_df[[unit_cols[1]]])
  if (nrow(parse_tibble) > length(unit_values)) {
    unit_values_expanded <- unit_values[parse_tibble$orig_row_id]
  } else {
    unit_values_expanded <- unit_values
  }
  harmonize_tibble <- harmonize_units(
    values   = parse_tibble$numeric_value,
    units    = unit_values_expanded,
    unit_map = unit_map,          # <-- variable name in headless is "unit_map"
    media    = media
  )
} else { ... }
```

**Confirmed variable name:** In `curate_headless.R`, the unit map variable is `unit_map` (loaded at line 192: `unit_map <- load_unit_map(cache_dir_ref)`).

**Stage 4 call** (lines 275-282):
```r
# Stage 4: Map to ToxVal schema
message("[headless] Stage 4: Mapping to ToxVal schema...")
toxval_tibble <- map_to_toxval_schema(
  curated_data    = input_df,    # <-- headless uses input_df directly, NOT expanded form
  harmonized_data = harmonize_tibble,
  source_name     = tools::file_path_sans_ext(basename(input_path))
)
```

**New duration stage — insert between Stage 3 and Stage 4** (after line 273, before line 275):
```r
# Stage 3.5: Duration harmonization (D-13)
message("[headless] Stage 3.5: Harmonizing durations...")
duration_cols      <- names(merged_tags)[merged_tags == "Duration"]
duration_unit_cols <- names(merged_tags)[merged_tags == "DurationUnit"]

if (length(duration_cols) > 0 && length(duration_unit_cols) > 0) {
  dur_tibble <- harmonize_units(
    values   = as.numeric(input_df[[duration_cols[1]]]),
    units    = as.character(input_df[[duration_unit_cols[1]]]),
    unit_map = unit_map,
    category = "duration"
  )
  # Join by position: dur_tibble$orig_row_id is 1:nrow(input_df) (no range expansion)
  input_df$study_duration_value <- dur_tibble$harmonized_value[
    match(seq_len(nrow(input_df)), dur_tibble$orig_row_id)
  ]
  input_df$study_duration_units <- dur_tibble$harmonized_unit[
    match(seq_len(nrow(input_df)), dur_tibble$orig_row_id)
  ]
}
# Stage 4: map_to_toxval_schema(curated_data = input_df, ...)  -- unchanged
```

**Tag variable:** In headless, tags come from `merged_tags` (line 170: `merged_tags <- c(tag_map, cleaning_result$new_tags)`). Use `merged_tags` not `numeric_tags_vec`.

---

### `tests/testthat/test-unit-harmonizer.R` — add duration tests

**Analog:** Section 11 ppb/ppm flag tests (lines 470-563) for flag pattern; Section 4 unmatched pass-through (lines 130-155) for D-06 behavior.

**Helper pattern to copy** (lines 8-17):
```r
make_test_unit_map <- function() {
  tibble::tibble(
    from_unit  = c("mg/L", "ug/L", ...),
    to_unit    = c("mg/L", "mg/L", ...),
    multiplier = c(1, 0.001, ...),
    category   = c("concentration", ...),
    confidence = rep("HIGH", 6),
    source     = rep("test", 6)
  )
}
```

**New helper to add — duration unit map:**
```r
make_duration_unit_map <- function() {
  tibble::tibble(
    from_unit  = c("hr","h","day","d","wk","week","mo","month","yr","year",
                   "min","minute","s","sec","second"),
    to_unit    = rep("hr", 15),
    multiplier = c(1, 1, 24, 24, 168, 168, 730.5, 730.5, 8766, 8766,
                   1/60, 1/60, 1/3600, 1/3600, 1/3600),
    category   = rep("duration", 15),
    confidence = rep("HIGH", 15),
    source     = rep("test", 15)
  )
}
```

**Test section structure pattern** (Section 11, lines 470-563):
```r
# Section header with requirement refs
test_that("ppb media: aqueous -> mg/L", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1000), c("ppb"), unit_map, media = "aqueous")
  expect_equal(result$harmonized_value, 1)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$unit_flag, "")
})
```

**Flag test pattern** (Section 13, lines 622-675) — exact structure to copy for `ambiguous_unit`:
```r
test_that("unit_flag: 'media_inferred' for ppb/ppm default media", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(10), c("ppb"), unit_map)
  expect_equal(result$unit_flag, "media_inferred")
})
```

**New duration test sections to add** (append after Section 15 "Edge cases"):

```r
# ==============================================================================
# SECTION 16: Duration category filter (D-12)
# ==============================================================================

test_that("duration category: category=NULL uses all rows (backward compat)", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(24), c("day"), unit_map, category = NULL)
  expect_equal(result$harmonized_unit, "hr")
  expect_equal(result$harmonized_value, 576)  # 24 * 24
})

test_that("duration category: category='duration' filters to hr-base rows", {
  # Combined map: time rows (to=day) + duration rows (to=hr)
  time_rows <- tibble::tibble(
    from_unit="day", to_unit="day", multiplier=1,
    category="time", confidence="HIGH", source="test"
  )
  dur_rows <- tibble::tibble(
    from_unit="day", to_unit="hr", multiplier=24,
    category="duration", confidence="HIGH", source="test"
  )
  combined_map <- dplyr::bind_rows(time_rows, dur_rows)

  result <- harmonize_units(c(1), c("day"), combined_map, category = "duration")
  expect_equal(result$harmonized_unit, "hr")
  expect_equal(result$harmonized_value, 24)
})

test_that("duration category: unrecognized unit passes through with 'unmatched' flag (D-06)", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(5), c("dph"), unit_map, category = "duration")
  expect_equal(result$harmonized_value, 5)
  expect_equal(result$harmonized_unit, "dph")
  expect_equal(result$unit_flag, "unmatched")
})

# ==============================================================================
# SECTION 17: Duration conversion arithmetic (DUR-02)
# ==============================================================================

test_that("duration: hr -> hr (identity)", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(96), c("hr"), unit_map, category = "duration")
  expect_equal(result$harmonized_value, 96)
  expect_equal(result$harmonized_unit, "hr")
})

test_that("duration: day -> hr (* 24)", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(14), c("day"), unit_map, category = "duration")
  expect_equal(result$harmonized_value, 336)
  expect_equal(result$harmonized_unit, "hr")
})

test_that("duration: min -> hr (* 1/60)", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(120), c("min"), unit_map, category = "duration")
  expect_equal(result$harmonized_value, 2, tolerance = 1e-10)
  expect_equal(result$harmonized_unit, "hr")
})

test_that("duration: wk -> hr (* 168)", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(2), c("wk"), unit_map, category = "duration")
  expect_equal(result$harmonized_value, 336)
})

test_that("duration: yr -> hr (* 8766)", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(1), c("yr"), unit_map, category = "duration")
  expect_equal(result$harmonized_value, 8766)
})

test_that("duration: decimal fraction '1.5 days' -> 36 hr", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(1.5), c("day"), unit_map, category = "duration")
  expect_equal(result$harmonized_value, 36)  # D-03: decimal fractions work
})

# ==============================================================================
# SECTION 18: Duration synonym normalization (DUR-05)
# ==============================================================================
# Note: These tests rely on the package-installed unit_synonyms.rds.
# Skip if the duration synonyms have not yet been added to the RDS.

test_that("duration synonym: 'hrs' -> normalized to 'hr'", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(48), c("hrs"), unit_map, category = "duration")
  expect_equal(result$harmonized_unit, "hr")
  expect_equal(result$harmonized_value, 48)
})

test_that("duration synonym: 'Days' -> normalized to 'day'", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(7), c("Days"), unit_map, category = "duration")
  expect_equal(result$harmonized_value, 168)  # 7 * 24
})

# ==============================================================================
# SECTION 19: "m" ambiguity flag (D-01, DUR-05)
# ==============================================================================

test_that("ambiguous_unit: 'm' maps to minutes and sets ambiguous_unit flag", {
  unit_map <- make_duration_unit_map()
  # "m" synonym -> "min", then converted to hr, but flagged ambiguous
  result <- harmonize_units(c(60), c("m"), unit_map, category = "duration")
  expect_equal(result$harmonized_unit, "hr")
  expect_equal(result$harmonized_value, 1, tolerance = 1e-10)  # 60 min -> 1 hr
  expect_equal(result$unit_flag, "ambiguous_unit")
})

test_that("ambiguous_unit: non-ambiguous 'min' does NOT get ambiguous flag", {
  unit_map <- make_duration_unit_map()
  result <- harmonize_units(c(60), c("min"), unit_map, category = "duration")
  expect_equal(result$unit_flag, "")
})
```

---

## Shared Patterns

### `category` parameter filter pattern
**Source:** `R/unit_harmonizer.R` (new, added in this phase)
**Apply to:** Both `mod_harmonize.R` and `curate_headless.R` when calling `harmonize_units()` for duration
```r
# Filter is applied inside harmonize_units() — callers just pass category="duration"
harmonize_units(..., unit_map = <working_unit_map>, category = "duration")
```

### `incProgress` stage pattern
**Source:** `R/mod_harmonize.R` lines 331-388 (withProgress block)
**Apply to:** Duration stage in `mod_harmonize.R`
```r
incProgress(0.05, detail = "Harmonizing durations...")
```
Total progress must still sum to 1.0 across all stages. Reduce existing `incProgress` values proportionally (e.g., reduce Stage 3's 0.30 to 0.25, use 0.05 for Stage 4.5).

### `dplyr::left_join` by `orig_row_id` pattern
**Source:** `R/mod_harmonize.R` line 392 (`expanded_curated <- data_store$resolution_state[harmonize_tibble$orig_row_id, ]`)
**Apply to:** Merging duration results into `expanded_curated` before mapper
```r
expanded_curated <- dplyr::left_join(
  expanded_curated,
  data_store$duration_results[, c("orig_row_id", "study_duration_value", "study_duration_units")],
  by = "orig_row_id"
)
```

### `match(seq_len(nrow(df)), tibble$orig_row_id)` join pattern
**Source:** `R/curate_headless.R` pattern (headless uses `input_df` directly, no range expansion for duration)
**Apply to:** Joining duration tibble rows back onto `input_df` columns in headless path
```r
input_df$study_duration_value <- dur_tibble$harmonized_value[
  match(seq_len(nrow(input_df)), dur_tibble$orig_row_id)
]
```

### Unit-key dedup — duration inherits for free
**Source:** `R/unit_harmonizer.R` lines 366-589 (dedup path)
**Note to planner:** No action required. Because duration uses `harmonize_units()` directly, it inherits the Phase 37 dedup optimization automatically. Duration unit strings are low-cardinality (few unique values), so dedup will fire for any dataset with more than ~20 rows sharing the same unit.

---

## No Analog Found

All files have close analogs. No entries here.

---

## Assumptions That Require Verification Before Implementation

| # | What to verify | Where to check | Impact if wrong |
|---|---|---|---|
| A1 | `resolution_state` has `orig_row_id` column for left_join | `R/mod_harmonize.R` line 392 behavior; or `R/curation_pipeline.R` output | Must fall back to row-position join |
| A2 | `merged_tags` is the correct tag variable name in headless path | `R/curate_headless.R` line 170 (confirmed in read) | Wrong variable name → R error |
| A3 | `unit_map` is the correct variable name for the unit map in headless | `R/curate_headless.R` line 192 (confirmed in read) | Wrong variable name → R error |
| A4 | `incProgress` fractions still sum to 1.0 after inserting Stage 4.5 | Count all `incProgress` calls in the withProgress block | Progress bar shows >100% |
| A5 | `data_store$duration_results` is safe to set/clear inside the FULL MODE block | Pattern from `data_store$toxval_output <- NULL` (line 297) | Stale duration results shown after incremental mode |

---

## Metadata

**Analog search scope:** `R/`, `inst/extdata/`, `tests/testthat/`
**Files read:** `R/unit_harmonizer.R` (601 lines), `R/mod_harmonize.R` (1188 lines), `R/curate_headless.R` (351 lines), `tests/testthat/test-unit-harmonizer.R` (930 lines), `inst/extdata/unit_conversion.rds` (151 rows), `inst/extdata/unit_synonyms.rds` (80 rows)
**Pattern extraction date:** 2026-04-26
