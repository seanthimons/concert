# Phase 35: Export Extension + Headless - Pattern Map

**Mapped:** 2026-04-17
**Files analyzed:** 5 (3 modified, 1 created, 1 metadata)
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `R/curate_headless.R` | service | batch, request-response | `R/curate_headless.R` (self — extension) | exact |
| `R/export_helpers.R` | utility | transform, batch | `R/export_helpers.R` (self — extension) | exact |
| `DESCRIPTION` | config | — | `DESCRIPTION` (self — extension) | exact |
| `tests/testthat/test-parquet-roundtrip.R` | test | file-I/O | `tests/testthat/test-toxval-mapper.R` | role-match |

---

## Pattern Assignments

### `R/curate_headless.R` (service, batch) — extend with `harmonize`, `format` params

**Analog:** `R/curate_headless.R` (self, lines 1–177)

**Current function signature** (lines 38–44):
```r
curate_headless <- function(input_path,
                             output_path,
                             tag_map,
                             skip_flags = NULL,
                             header_row = NULL,
                             reference_lists = NULL,
                             verbose = TRUE) {
```

**Extended signature per D-08** — new params added after existing ones:
```r
curate_headless <- function(input_path,
                             output_path,
                             tag_map,
                             skip_flags = NULL,
                             header_row = NULL,
                             reference_lists = NULL,
                             verbose = TRUE,
                             harmonize = FALSE,       # NEW
                             format = "parquet",      # NEW: "parquet", "csv", or "both"
                             unit_map = NULL,         # NEW: custom unit map (NULL = load from cache)
                             corrections = NULL,      # NEW: one-off corrections tibble
                             media = NULL)            # NEW: media context vector for ppb/ppm routing
```

**Pipeline inner function pattern** — the entire body lives inside `pipeline <- function() { ... }` and verbose dispatches at the end (lines 47–176). New harmonize steps slot between Step 8 (curation) and Step 9 (export):
```r
pipeline <- function() {
  # Steps 1–8 unchanged ...

  # ------------------------------------------------------------------
  # Step 8b: Run harmonization pipeline (when harmonize = TRUE)
  # ------------------------------------------------------------------
  if (harmonize) {
    message("[headless] Running harmonization pipeline...")
    # Load unit_map from cache if not provided
    if (is.null(unit_map)) {
      cache_dir <- system.file("extdata", "reference_cache", package = "chemreg")
      unit_map <- load_unit_map(cache_dir)
    }
    if (is.null(corrections)) {
      corrections <- tibble::tibble(pattern = character(), replacement = character())
    }

    # Follow mod_harmonize.R stages 1–3
    # Stage 1: apply corrections
    # Stage 2: parse_numeric_results()
    # Stage 3: harmonize_units()
    # Stage 4: map_to_toxval_schema()
  }

  # ------------------------------------------------------------------
  # Step 9: Build export sheets and write XLSX (modified)
  # ------------------------------------------------------------------
  toxval_tibble <- if (harmonize) {
    data_store_toxval  # 56-col tibble from map_to_toxval_schema()
  } else {
    NULL  # Sheet 8 gets the placeholder note row per D-10
  }

  sheets <- build_export_sheets(
    raw              = raw_df,
    resolution_state = resolution_state,
    consensus_summary = pipeline_result$consensus_summary,
    cleaning_audit   = cleaning_result$audit_trail,
    reference_lists  = reference_lists,
    column_tags      = merged_tags,
    detection        = detection,
    file_info        = file_info,
    toxval_output    = toxval_tibble   # NEW param
  )

  # ------------------------------------------------------------------
  # Step 9b: Write parquet/CSV (when harmonize = TRUE)
  # ------------------------------------------------------------------
  if (harmonize) {
    # D-03 file naming: derive from output_path basename
    toxval_base <- sub("\\.xlsx$", "", output_path, ignore.case = TRUE)

    if (format %in% c("parquet", "both")) {
      arrow::write_parquet(toxval_tibble, paste0(toxval_base, "_toxval.parquet"))
      message(sprintf("[headless] Parquet written: %s_toxval.parquet", basename(toxval_base)))
    }
    if (format %in% c("csv", "both")) {
      readr::write_csv(toxval_tibble, paste0(toxval_base, "_toxval.csv"))
      message(sprintf("[headless] CSV written: %s_toxval.csv", basename(toxval_base)))
    }
  }

  # ------------------------------------------------------------------
  # Step 10: Return invisibly (modified per D-05, D-06)
  # ------------------------------------------------------------------
  if (harmonize) {
    invisible(list(
      data           = toxval_tibble,         # 56-col tibble replaces resolution_state
      audit_trail    = cleaning_result$audit_trail,
      harmonize_audit = harmonize_audit_tibble  # NEW per D-06
    ))
  } else {
    invisible(list(data = resolution_state, audit_trail = cleaning_result$audit_trail))
  }
}
```

**Verbose dispatch pattern** (lines 168–176) — unchanged, wraps entire `pipeline()` call:
```r
if (verbose) {
  pipeline()
} else {
  withCallingHandlers(
    pipeline(),
    message = function(m) invokeRestart("muffleMessage")
  )
}
```

**tag_map validation pattern for new tag values** (lines 115–122) — existing pattern validates column existence; same check applies for new tag types ("Result", "Unit", etc.) since D-04 simply expands the vocabulary without changing the validation logic:
```r
missing_cols <- setdiff(names(tag_map), names(clean_data))
if (length(missing_cols) > 0) {
  stop(sprintf(
    "curate_headless: tag_map column names not found after normalization: %s\nActual columns: %s",
    paste(missing_cols, collapse = ", "),
    paste(names(clean_data), collapse = ", ")
  ))
}
```

**format param validation pattern** — follow the file_ext validation pattern (lines 56–63):
```r
if (!format %in% c("parquet", "csv", "both")) {
  stop(sprintf(
    "curate_headless: invalid format '%s'. Use 'parquet', 'csv', or 'both'.",
    format
  ))
}
```

**message() progress reporting pattern** (lines 85–102) — all status messages follow this form:
```r
message(sprintf("[headless] Step description: %s", value))
```

---

### `R/export_helpers.R` (utility, transform) — add Sheet 8 "ToxVal Output"

**Analog:** `R/export_helpers.R` (self, lines 22–145)

**Current function signature** (line 22–24):
```r
build_export_sheets <- function(raw, resolution_state, consensus_summary,
                                 cleaning_audit, reference_lists, column_tags,
                                 detection, file_info, enrichment_cache = NULL) {
```

**Extended signature** — add `toxval_output = NULL` as final optional param:
```r
build_export_sheets <- function(raw, resolution_state, consensus_summary,
                                 cleaning_audit, reference_lists, column_tags,
                                 detection, file_info, enrichment_cache = NULL,
                                 toxval_output = NULL) {
```

**Null-guard sheet pattern** — the Cleaning Audit null-guard (lines 77–89) is the exact pattern to copy for Sheet 8 when harmonization has not run (D-10):
```r
# Sheet 4: Cleaning Audit (may be NULL) — COPY THIS NULL GUARD PATTERN
cleaning_audit_sheet <- if (!is.null(cleaning_audit)) {
  cleaning_audit
} else {
  tibble::tibble(
    row_id = integer(),
    field = character(),
    step = character(),
    original_value = character(),
    new_value = character(),
    reason = character()
  )
}
```

**Sheet 8 null-guard pattern** following the exact same convention (D-09, D-10, D-11):
```r
# Sheet 8: ToxVal Output (always present per D-09)
toxval_output_sheet <- if (!is.null(toxval_output) && nrow(toxval_output) > 0) {
  toxval_output  # 56-col tibble from map_to_toxval_schema()
} else {
  # D-10: placeholder note row when harmonization has not run
  tibble::tibble(
    note = "Harmonization not run — run harmonization to populate this sheet"
  )
}
```

**Named list return pattern** (lines 136–144) — Sheet 8 appended at position 8:
```r
list(
  "Raw Data"        = raw_data_sheet,
  "Curated Data"    = curated_data_sheet,
  "Summary"         = summary_sheet,
  "Cleaning Audit"  = cleaning_audit_sheet,
  "Reference Lists" = reference_lists_sheet,
  "Column Tags"     = column_tags_sheet,
  "Pipeline Config" = config_sheet,
  "ToxVal Output"   = toxval_output_sheet   # NEW Sheet 8
)
```

**Roxygen param pattern** — follow existing param style in the function's roxygen block (lines 6–20):
```r
#' @param toxval_output Tibble with 56 ToxVal columns from map_to_toxval_schema(),
#'   or NULL (default). When NULL, Sheet 8 contains a placeholder note row.
```

---

### `DESCRIPTION` (config) — add `arrow` to Imports

**Analog:** `DESCRIPTION` (self, lines 13–40)

**Current Imports block** (lines 13–40):
```
Imports:
    bsicons,
    bslib,
    ComptoxR,
    digest,
    dplyr,
    fs,
    here,
    janitor,
    magrittr,
    purrr,
    reactable,
    reactable.extras,
    readr,
    readxl,
    rio,
    rlang,
    shiny,
    shinyjs,
    stats,
    stringi,
    stringr,
    tibble,
    tidyr,
    tidyselect,
    tools,
    units (>= 0.8-0),
    writexl
```

**Change required** — add `arrow` in alphabetical position (between existing entries, per D-02):
```
Imports:
    arrow,
    bsicons,
    ...
```

No version constraint needed — arrow is widely available and the project does not pin minor versions for other packages.

---

### `tests/testthat/test-parquet-roundtrip.R` (test, file-I/O)

**Analog:** `tests/testthat/test-toxval-mapper.R` (closest match: file-based round-trip with tibble schema assertions)

**Test file header convention** (test-toxval-mapper.R lines 1–20):
```r
# test-parquet-roundtrip.R
# Round-trip validation for ToxVal parquet export: write known tibble, read back,
# assert column types + values match (D-12: test-only validation, no runtime check).

# Test fixtures — minimal valid 56-column toxval tibble
```

**Fixture pattern** — use the same curated/harmonized fixtures from test-toxval-mapper.R and derive a toxval tibble via `map_to_toxval_schema()`:
```r
# Build fixture via the mapper (avoids duplicating column construction)
curated_fixture <- tibble::tibble(
  dtxsid = "DTXSID7020182",
  casrn  = "71-43-2",
  name   = "Benzene"
)
harmonized_fixture <- tibble::tibble(
  orig_row_id      = 1L,
  orig_unit        = "ug/L",
  harmonized_value = 0.5,
  harmonized_unit  = "mg/L",
  conversion_factor = 0.001,
  unit_flag        = ""
)
toxval_fixture <- map_to_toxval_schema(curated_fixture, harmonized_fixture)
```

**Tempfile + cleanup pattern** — from test-export-import.R lines 380–393:
```r
temp_file <- tempfile(fileext = ".parquet")
withr::defer(unlink(temp_file))  # preferred over manual unlink() in testthat

arrow::write_parquet(toxval_fixture, temp_file)
result <- arrow::read_parquet(temp_file)
```

**Column type assertion pattern** — from test-toxval-mapper.R lines 70–102:
```r
test_that("parquet round-trip: column types preserved", {
  temp_file <- tempfile(fileext = ".parquet")
  withr::defer(unlink(temp_file))

  arrow::write_parquet(toxval_fixture, temp_file)
  result <- arrow::read_parquet(temp_file)

  types_orig <- vapply(toxval_fixture, typeof, "")
  types_rt   <- vapply(result, typeof, "")

  expect_equal(types_rt, types_orig)
})
```

**Value assertion pattern** — from test-toxval-mapper.R lines 135–148:
```r
test_that("parquet round-trip: values match original", {
  temp_file <- tempfile(fileext = ".parquet")
  withr::defer(unlink(temp_file))

  arrow::write_parquet(toxval_fixture, temp_file)
  result <- arrow::read_parquet(temp_file)

  expect_equal(result$dtxsid, toxval_fixture$dtxsid)
  expect_equal(result$toxval_numeric, toxval_fixture$toxval_numeric)
  expect_equal(result$toxval_units, toxval_fixture$toxval_units)
})
```

**Section grouping convention** — test-toxval-mapper.R uses `# ===` banners to group related tests; follow the same pattern:
```r
# ============================================================================
# Round-trip: write + read via arrow
# ============================================================================

# ============================================================================
# Column structure validation
# ============================================================================

# ============================================================================
# Named output file path convention
# ============================================================================
```

**Recommended additional test cases** (beyond D-12 round-trip requirement):
- `test_that("parquet round-trip: 56 columns preserved")` — ncol assertion
- `test_that("parquet round-trip: zero-row tibble produces valid parquet")` — edge case
- `test_that("parquet round-trip: no logical columns after read")` — type fidelity
- `test_that("curate_headless writes _toxval.parquet with correct basename")` — file naming per D-03 (uses `withr::local_tempdir()`)

---

## Shared Patterns

### Headless Progress Reporting
**Source:** `R/curate_headless.R` lines 85–102
**Apply to:** All new steps in `curate_headless()` (harmonize stages, write steps)
```r
message(sprintf("[headless] Running harmonization pipeline..."))
message(sprintf("[headless] Parquet written: %s", basename(output_file)))
```

### `invisible()` Return for Headless Functions
**Source:** `R/curate_headless.R` line 165
**Apply to:** `curate_headless()` return — both the `harmonize=TRUE` and `harmonize=FALSE` branches must use `invisible(list(...))`:
```r
invisible(list(data = ..., audit_trail = ..., harmonize_audit = ...))
```

### Null-Guard Sheet Pattern
**Source:** `R/export_helpers.R` lines 77–89 (Cleaning Audit sheet)
**Apply to:** Sheet 8 "ToxVal Output" in `build_export_sheets()`
```r
sheet <- if (!is.null(input) && nrow(input) > 0) {
  input
} else {
  tibble::tibble(note = "... not run — ...")
}
```

### `system.file()` Cache Loading
**Source:** `R/curate_headless.R` lines 68–70
**Apply to:** `unit_map` loading when `unit_map = NULL` in headless harmonize path
```r
cache_dir <- system.file("extdata", "reference_cache", package = "chemreg")
unit_map <- load_unit_map(cache_dir)
```

### `fs::dir_create()` Output Directory
**Source:** `R/curate_headless.R` line 157
**Apply to:** Any new file-write operations in headless (parquet/CSV paths); the parent dir is already guaranteed by the XLSX step, but new sibling files share the same dirname so no re-check needed.

### `data_store$harmonize_results` Contract
**Source:** `R/mod_harmonize.R` lines 346–351, confirmed in `inst/app/app.R` line 125
```r
# Structure consumed by curate_headless() when harmonize=TRUE:
list(
  parsed     = <tibble from parse_numeric_results()>,
  harmonized = <tibble from harmonize_units()>,
  input_data = <data.frame passed into the pipeline>
)
```

### Error Validation Stop Pattern
**Source:** `R/curate_headless.R` lines 56–63 (file_ext check)
**Apply to:** `format` parameter validation in `curate_headless()`
```r
if (!format %in% c("parquet", "csv", "both")) {
  stop(sprintf(
    "curate_headless: invalid format '%s'. Use 'parquet', 'csv', or 'both'.",
    format
  ))
}
```

### Roxygen `@importFrom` for New Dependencies
**Source:** `R/curate_headless.R` line 37 (`@importFrom tools file_ext`)
**Apply to:** `curate_headless()` roxygen block — add `@importFrom arrow write_parquet`; `readr::write_csv` is already in Imports via namespace prefix, no additional `@importFrom` required for readr.

---

## No Analog Found

All files have close analogs. No files require falling back to RESEARCH.md patterns.

---

## Integration Points to Verify Before Planning

1. **`mod_harmonize.R` data contract** — `data_store$harmonize_results$harmonized` is the tibble passed to `harmonize_units()`. In headless mode, this is reconstructed by calling the same functions directly rather than going through the Shiny module. Confirm `parse_numeric_results()` and `harmonize_units()` signatures from `R/numeric_parser.R` and `R/unit_harmonizer.R`.

2. **`build_export_sheets()` call sites** — the function is called in two places: `R/curate_headless.R` (line 146) and likely in the Shiny server (`inst/app/app.R` or `R/mod_review_results.R`). Adding `toxval_output = NULL` as an optional param with a default keeps both call sites backward-compatible without modification.

3. **`data_store$toxval_output`** — per `inst/app/app.R` line 127, this slot already exists in the reactive store. The planner should confirm whether Phase 35 wires `toxval_output` to `build_export_sheets()` from the Shiny server, or only from headless mode.

4. **`load_unit_map()`** — referenced in `R/cleaning_reference.R` per Phase 34 context. Verify function name and signature before using in headless path.

---

## Metadata

**Analog search scope:** `R/`, `tests/testthat/`, `inst/app/`, `DESCRIPTION`
**Files scanned:** 12 source files + 4 context files
**Pattern extraction date:** 2026-04-17
