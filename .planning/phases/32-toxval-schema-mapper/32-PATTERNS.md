# Phase 32: ToxVal Schema Mapper - Pattern Map

**Mapped:** 2026-04-15
**Files analyzed:** 3 (R/toxval_mapper.R, inst/extdata/reference_cache/toxval_schema.rds, tests/testthat/test-toxval-mapper.R)
**Analogs found:** 3 / 3

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `R/toxval_mapper.R` | transform-service | request-response (tibble in, tibble out) | `R/unit_harmonizer.R` (`harmonize_units()`) | exact |
| `inst/extdata/reference_cache/toxval_schema.rds` | config / reference data | static load | `R/cleaning_reference.R` (`load_toxval_schema()` + all `load_*` functions) | exact |
| `tests/testthat/test-toxval-mapper.R` | test | transform | `tests/testthat/test-unit-harmonizer.R` | exact |

---

## Pattern Assignments

### `R/toxval_mapper.R` (transform-service, request-response)

**Primary analog:** `R/unit_harmonizer.R`

**Imports pattern** (unit_harmonizer.R lines 226-228):
```r
#' @importFrom tibble tibble
#' @importFrom dplyr bind_rows
#' @export
harmonize_units <- function(values, units, unit_map, ...)
```
Copy: use `@importFrom tibble tibble` and `@importFrom dplyr bind_rows` in the roxygen block. All column construction goes through `tibble::tibble()` with explicit column types.

**Empty-input guard pattern** (unit_harmonizer.R lines 232-242):
```r
n <- length(values)
if (n == 0) {
  return(tibble::tibble(
    orig_row_id = integer(0),
    orig_unit = character(0),
    harmonized_value = numeric(0),
    harmonized_unit = character(0),
    conversion_factor = numeric(0),
    unit_flag = character(0)
  ))
}
```
Copy: `map_to_toxval_schema()` should return a zero-row tibble conforming to the schema when `nrow(curated_data) == 0`, using the same guard shape. Return `load_toxval_schema("inst/extdata/reference_cache")[0, ]`.

**Typed NA vector pre-allocation pattern** (unit_harmonizer.R lines 260-263):
```r
harmonized_value <- numeric(n)
harmonized_unit <- character(n)
conversion_factor <- numeric(n)
unit_flag <- character(n)
```
Copy: pre-allocate all 56 output columns as typed vectors of length `n` before the row loop. Use:
- `character(n)` for VARCHAR columns
- `numeric(n)` for DOUBLE columns

This avoids `NA` logical coercion in the final tibble assembly.

**Output tibble construction with explicit types** (unit_harmonizer.R lines 387-394):
```r
tibble::tibble(
  orig_row_id = as.integer(orig_row_id),
  orig_unit = orig_unit,
  harmonized_value = harmonized_value,
  harmonized_unit = harmonized_unit,
  conversion_factor = conversion_factor,
  unit_flag = unit_flag
)
```
Copy: build the result tibble with every column named explicitly. Apply `as.integer()`, `as.character()`, `as.numeric()` casts inline to guarantee types. Do not rely on R type inference.

**Secondary analog for column mapping:** `R/curation.R` `map_results_to_rows()` (lines 427-526)

**Column-by-column assignment from source to target** (curation.R lines 454-490):
```r
# Pre-allocate result vectors matching df row count
dtxsid_vec <- rep(NA_character_, input_rows)
pref_vec   <- rep(NA_character_, input_rows)
rank_vec   <- rep(NA_integer_,   input_rows)
tier_vec   <- rep(NA_character_, input_rows)

# Fill from source
for (i in seq_len(nrow(col_keys))) {
  ridx   <- col_keys$row_idx[i]
  # ... assign by position
}

# Assign back to output df
df$dtxsid       <- dtxsid_vec
df$preferredName <- pref_vec
```
Copy: for `map_to_toxval_schema()`, pre-allocate each of the 56 output columns using `rep(NA_character_, n)` or `rep(NA_real_, n)`, then fill from `curated_data` or `harmonized_data` column lookup. Keeps row count stable with no joins.

**Source_hash generation pattern** (checkpoint.R line 43):
```r
hash = digest::digest(f, file = TRUE, algo = "md5"),
```
For row-level hashing, use `digest::digest()` with `algo = "sha256"` (per CONTEXT.md D-08). Apply per-row:
```r
source_hash_vec <- vapply(seq_len(n), function(i) {
  row_str <- paste(
    dtxsid_vec[i], casrn_vec[i], name_vec[i],
    toxval_type_vec[i], toxval_numeric_vec[i], toxval_units_vec[i],
    sep = "|"
  )
  digest::digest(row_str, algo = "sha256")
}, character(1))
```

**Typed-NA assertion guard** (per CONTEXT.md D-16):
```r
# Assert no bare NAs remain (logical type signals a missed type assignment)
stopifnot(all(vapply(result, typeof, "") != "logical"))
```
Add this assertion before `return(result)` in `map_to_toxval_schema()`.

**`%||%` null-coalescing operator** (used throughout curation.R and export_helpers.R):
```r
# From export_helpers.R line 127
detection$method %||% "unknown"
```
Copy: use `%||%` from `rlang` (already a transitive dependency) or define locally:
```r
`%||%` <- function(x, y) if (is.null(x) || (length(x) == 1 && is.na(x))) y else x
```
Apply for every column mapping: `curated_data$dtxsid %||% NA_character_`.

**tryCatch / error-return pattern** (cleaning_reference.R lines 125-175, unit_harmonizer.R lines 112-134):
```r
tryCatch({
  # ... operation
}, error = function(e) {
  result <- rep(NA_real_, length(dtxsids))
  names(result) <- dtxsids
  result
})
```
Copy: wrap hash generation and any conditional column derivation in `tryCatch()` that returns a typed NA value rather than propagating the error.

---

### `inst/extdata/reference_cache/toxval_schema.rds` (config, static load)

**Primary analog:** `R/cleaning_reference.R` `load_toxval_schema()` (lines 351-370) + the existing minimal schema

**Current schema (7 columns) pattern** (cleaning_reference.R lines 354-369):
```r
fetch_fn <- function() {
  warning("toxval_schema.rds not found - returning minimal schema")
  tibble::tibble(
    source_hash    = NA_character_,
    dtxsid         = NA_character_,
    casrn          = NA_character_,
    name           = NA_character_,
    toxval_type    = NA_character_,
    toxval_numeric = NA_real_,
    toxval_units   = NA_character_
  )[0, ]
}
```
Copy this exact pattern for the full 56-column expansion:
- Every VARCHAR column → `NA_character_`
- Every DOUBLE column → `NA_real_`
- Trailing `[0, ]` to zero-row slice preserving column types

**Full 56-column schema to implement** (from CONTEXT.md canonical ToxVal column list):
```r
tibble::tibble(
  # Identity
  dtxsid                         = NA_character_,
  casrn                          = NA_character_,
  name                           = NA_character_,
  source                         = NA_character_,
  sub_source                     = NA_character_,
  # Toxicity value
  toxval_type                    = NA_character_,
  toxval_subtype                 = NA_character_,
  toxval_type_supercategory      = NA_character_,
  qualifier                      = NA_character_,
  toxval_numeric                 = NA_real_,
  toxval_units                   = NA_character_,
  # Risk
  risk_assessment_class          = NA_character_,
  # Study design
  study_type                     = NA_character_,
  study_duration_class           = NA_character_,
  study_duration_value           = NA_real_,
  study_duration_units           = NA_character_,
  # Species
  species_common                 = NA_character_,
  strain                         = NA_character_,
  latin_name                     = NA_character_,
  species_supercategory          = NA_character_,
  sex                            = NA_character_,
  generation                     = NA_character_,
  lifestage                      = NA_character_,
  # Exposure
  exposure_route                 = NA_character_,
  exposure_method                = NA_character_,
  exposure_form                  = NA_character_,
  media                          = NA_character_,
  # Effects
  toxicological_effect           = NA_character_,
  toxicological_effect_category  = NA_character_,
  # Study metadata
  experimental_record            = NA_character_,
  study_group                    = NA_character_,
  year                           = NA_real_,
  # QC
  qc_category                    = NA_character_,
  qc_status                      = NA_character_,
  # Provenance
  source_hash                    = NA_character_,
  source_url                     = NA_character_,
  subsource_url                  = NA_character_,
  # Audit: *_original columns (harmonized fields)
  toxval_type_original           = NA_character_,
  toxval_subtype_original        = NA_character_,
  toxval_numeric_original        = NA_real_,
  toxval_units_original          = NA_character_,
  study_type_original            = NA_character_,
  study_duration_class_original  = NA_character_,
  study_duration_value_original  = NA_real_,
  study_duration_units_original  = NA_character_,
  species_original               = NA_character_,
  strain_original                = NA_character_,
  sex_original                   = NA_character_,
  generation_original            = NA_character_,
  lifestage_original             = NA_character_,
  exposure_route_original        = NA_character_,
  exposure_method_original       = NA_character_,
  exposure_form_original         = NA_character_,
  media_original                 = NA_character_,
  toxicological_effect_original  = NA_character_,
  original_year                  = NA_real_
)[0, ]
```

**Saving the schema** (same as other reference files, cleaning_reference.R lines 31-36):
```r
fs::dir_create(dirname(cache_path), recurse = TRUE)
saveRDS(result, cache_path, compress = FALSE)
```

The schema RDS is generated by a script (not by `fetch_fn` at runtime) because it is static. Create `data-raw/build_toxval_schema.R` that runs the tibble construction and saves to `inst/extdata/reference_cache/toxval_schema.rds`.

---

### `tests/testthat/test-toxval-mapper.R` (test, transform)

**Primary analog:** `tests/testthat/test-unit-harmonizer.R`

**Test file header / helper factory pattern** (test-unit-harmonizer.R lines 1-17):
```r
# test-unit-harmonizer.R
# TDD tests for harmonize_units() and normalize_unit_string()
# Covers: normalization, case-safe lookup, conversion arithmetic, output shape,
#         molarity conversion, ppb/ppm media routing, synonym normalization

# ---- Helper: create minimal unit_map for testing ----
make_test_unit_map <- function() {
  tibble::tibble(
    from_unit = c("mg/L", "ug/L", ...),
    ...
  )
}
```
Copy: define `make_test_curated_data()` and `make_test_harmonized_data()` helper factories that produce minimal well-typed tibbles for use across test cases. Keep them at the top of the file.

**Section heading pattern** (test-unit-harmonizer.R lines 31-33):
```r
# ==============================================================================
# SECTION 1: Normalization (UNIT-02)
# ==============================================================================
```
Copy: organise tests into named sections: SECTION 1: Output shape, SECTION 2: Column mapping, SECTION 3: Typed NAs, SECTION 4: *_original audit columns, SECTION 5: source_hash, SECTION 6: Empty input.

**Output shape test pattern** (test-unit-harmonizer.R lines 35-40):
```r
test_that("normalize: whitespace is trimmed from edges", {
  unit_map <- make_test_unit_map()
  result <- harmonize_units(c(1), c("  mg/L  "), unit_map)
  expect_equal(result$harmonized_unit, "mg/L")
  expect_equal(result$unit_flag, "")
})
```
Copy: each `test_that()` block constructs minimal inputs via helper, calls the function, then asserts against named columns. One assertion cluster per `test_that()`.

**withr::with_tempdir pattern for cache tests** (test-cleaning-reference.R lines 7-30):
```r
test_that("load_or_fetch_reference reads from existing cache", {
  withr::with_tempdir({
    cache_dir <- "test_cache"
    dir.create(cache_dir)
    cache_path <- file.path(cache_dir, "test_data.rds")
    saveRDS(test_data, cache_path)
    result <- load_or_fetch_reference(cache_path, fetch_fn, "test_data")
    expect_equal(result, test_data)
  })
})
```
Copy for any schema-load tests that need a temp directory.

---

## Shared Patterns

### Typed NA Construction (apply to all new code in Phase 32)

**Source:** `R/cleaning_reference.R` lines 358-366 AND `R/curation.R` lines 454-460

Character columns:
```r
some_col_vec <- rep(NA_character_, n)
# or in tibble construction:
some_col = NA_character_
```

Numeric columns:
```r
some_numeric_vec <- rep(NA_real_, n)
# or in tibble construction:
some_numeric = NA_real_
```

Integer columns:
```r
some_int_vec <- rep(NA_integer_, n)
```

Never use bare `NA`. Every column must have an explicit R type suffix or `rep()` with the typed NA constant.

### Audit Trail / `*_original` Column Pattern

**Source:** `R/cleaning_pipeline.R` `build_audit_trail()` (lines 50-92) + `R/export_helpers.R` lines 43-46

The codebase captures originals before transformation:

```r
# export_helpers.R lines 43-46 - adding _original columns when absent
} else {
  curated_data_sheet$consensus_casrn  <- NA_character_
  curated_data_sheet$consensus_formula <- NA_character_
  curated_data_sheet$consensus_mw     <- NA_real_
}
```

And the audit trail records step/original/new (cleaning_pipeline.R lines 67-74):
```r
audit_rows[[length(audit_rows) + 1]] <- tibble::tibble(
  row_id         = as.integer(idx),
  field          = col_name,
  step           = step_name,
  original_value = original_vals[idx],
  new_value      = cleaned_vals[idx],
  reason         = reason_fn(col_name)
)
```

For Phase 32, the `*_original` pattern is a column-level parallel, not a row-level audit tibble. The mapper should:
1. Capture `toxval_units_original` from `harmonized_data$orig_unit` (captured before normalization in harmonize_units step 1)
2. Capture `toxval_numeric_original` from `harmonized_data$orig_result` (or from `parse_numeric_results()` output `orig_result` column)
3. All other `*_original` columns sourced from the matching raw input column before any harmonization step

### Reference Loading Pattern

**Source:** `R/cleaning_reference.R` `load_or_fetch_reference()` (lines 21-38) + all `load_*` functions

```r
load_some_reference <- function(cache_dir) {
  cache_path <- file.path(cache_dir, "filename.rds")

  fetch_fn <- function() {
    # Build/generate the data
    tibble::tibble(...)
  }

  load_or_fetch_reference(cache_path, fetch_fn, "human readable name")
}
```

`load_toxval_schema()` already follows this pattern exactly (cleaning_reference.R lines 351-370). The expanded schema just needs the `fetch_fn` body updated to return a 56-column zero-row tibble. No structural change to `load_toxval_schema()` itself is required.

### Empty-Result Tibble Sentinel Pattern

**Source:** `R/curation.R` `search_exact()` (lines 88-94), `R/unit_harmonizer.R` lines 232-242

When a function must return a typed empty tibble on early exit:
```r
empty_result <- tibble::tibble(
  col_a = character(0),
  col_b = numeric(0),
  col_c = integer(0)
)
if (length(input) == 0) return(empty_result)
```
Apply in `map_to_toxval_schema()`: when `nrow(curated_data) == 0`, return the schema template directly via `load_toxval_schema(cache_dir)[0, ]`.

### Message Logging Pattern (progress reporting)

**Source:** `R/cleaning_reference.R` lines 23-27, `R/curation.R` lines 439-441

```r
message(sprintf("Loading %s from cache: %s", name, cache_path))
message(sprintf("[map_results_to_rows] Input: %d rows, %d lookup results (%d unique searchValues)",
  input_rows, nrow(lookup_results), nrow(lookup_deduped)))
```
Copy: `map_to_toxval_schema()` should emit at minimum:
```r
message(sprintf("[map_to_toxval_schema] Mapping %d rows to 56-column ToxVal schema", n))
message(sprintf("[map_to_toxval_schema] source_name = '%s'", effective_source_name))
```

---

## No Analog Found

All three Phase 32 files have close analogs. No file is entirely novel.

| File | Aspect with no exact analog | Recommendation |
|---|---|---|
| `R/toxval_mapper.R` | Row-level SHA256 hashing of output columns | Follow `checkpoint.R` MD5 pattern; substitute `algo = "sha256"` and `digest::digest(row_string, algo = "sha256")` |
| `R/toxval_mapper.R` | `qc_status` derivation from upstream flags | No existing analog for flag-to-status logic; implement simple `ifelse()` based on CONTEXT.md D-22/D-23 decisions |

---

## Metadata

**Analog search scope:** `R/`, `tests/testthat/`, `checkpoint.R`, `inst/extdata/reference_cache/`
**Files scanned:** 10 source files read in full + 2 partial reads
**Pattern extraction date:** 2026-04-15
