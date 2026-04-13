# Phase 27: Headless Pipeline - Research

**Researched:** 2026-04-13
**Domain:** R package function authoring — wiring existing pipeline stages into a single exported entry point
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** `verbose = TRUE/FALSE` parameter. Default TRUE (messages shown). When FALSE, suppress all `message()` calls from pipeline functions.
- **D-02:** `reference_lists = NULL` parameter. When NULL, load package defaults from `system.file("extdata", "reference_cache", package = "chemreg")`. When provided, use custom list (must match structure: stop_words, functional_categories, block_patterns, strip_terms, isotope_lookup).
- **D-03:** `header_row = NULL` parameter. When NULL, run 3-algorithm ensemble detection (`detect_data_start()`). When specified (integer), skip detection and use that row as header.
- **D-04:** Fail fast on first error with informative message. No partial results.
- **D-05:** Return a list with `$data` (curated data frame) and `$audit_trail` (cleaning audit tibble). Return invisibly so XLSX export is primary output.

### Confirmed Function Signature

```r
curate_headless(
  input_path,
  output_path,
  tag_map,
  skip_flags = NULL,
  header_row = NULL,
  reference_lists = NULL,
  verbose = TRUE
)
```

### Claude's Discretion

- Internal helper functions (if any) vs. inline implementation
- Exact error message wording
- Whether to add `@examples` in roxygen docs (nice to have, not required)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HDL-01 | `curate_headless(input_path, output_path, tag_map, skip_flags)` is an exported function in the package | New file `R/curate_headless.R` with `@export` + roxygen docs; `devtools::document()` regenerates NAMESPACE |
| HDL-02 | `curate_headless()` runs the full pipeline: file read → frontmatter detect → clean data → cleaning pipeline → dedup → CompTox search → consensus → XLSX export | All 7 stages map to existing functions; orchestration pattern confirmed below |
| HDL-03 | `curate_headless()` produces a valid XLSX output when run against `uncurated_sswqs.csv` | `writexl::write_xlsx()` must be moved from Suggests to Imports; `build_export_sheets()` + `write_xlsx()` are the export path |
| HDL-04 | `curate_headless()` returns a list with `data` and `audit_trail` invisibly | `invisible(list(data = ..., audit_trail = ...))` pattern; confirmed via D-05 |

</phase_requirements>

---

## Summary

Phase 27 is a **pure orchestration task**: all seven pipeline stages already exist as tested, exported R functions. The job is to wire them together in a new file `R/curate_headless.R` with a single exported function `curate_headless()`. No new algorithms are needed.

The main technical decisions are (1) how to suppress messages when `verbose = FALSE` using `withCallingHandlers()` or `suppressMessages()`, (2) how to adapt `safely_read_file()` which currently expects a Shiny file-input object rather than a plain path, and (3) confirming that `writexl` needs to move from `Suggests` to `Imports` since headless users will always write XLSX output.

The pipeline stages are: `safely_read_file()` → `detect_data_start()` → `extract_clean_data()` + `handle_merged_cells()` → `janitor::clean_names()` → `run_cleaning_pipeline()` → `run_curation_pipeline()` → `build_export_sheets()` → `writexl::write_xlsx()`.

**Primary recommendation:** Implement `curate_headless()` as a single ~80-line function in `R/curate_headless.R`. Use `withCallingHandlers()` to suppress messages when `verbose = FALSE`. Adapt file I/O by extracting the file extension from `input_path` directly (bypassing `validate_file()` which expects a Shiny input object). Move `writexl` to Imports.

---

## Standard Stack

### Core (all already in DESCRIPTION Imports)

| Library | Version in DESCRIPTION | Purpose | Role in curate_headless |
|---------|------------------------|---------|--------------------------|
| readr / readxl / rio | (inherited) | File reading | Called via `safely_read_file()` |
| dplyr, tibble, tidyr | (inherited) | Data manipulation | Used by all pipeline stages |
| janitor | (inherited) | Column name cleaning | `clean_names()` + `remove_empty()` post-extraction |
| purrr | (inherited) | Ensemble detection safety | `purrr::safely()` inside `detect_data_start()` |
| ComptoxR | (remote: seanthimons/ComptoxR) | API search | Called by `run_curation_pipeline()` |
| fs | (inherited) | Directory/path operations | `fs::dir_create()` for output path parent |

### Needs Promotion: Suggests → Imports

| Library | Current | Needs to be | Reason |
|---------|---------|-------------|--------|
| writexl | Suggests | Imports | `curate_headless()` always writes XLSX — it is a required dependency, not optional |

**DESCRIPTION change required:** Move `writexl` from `Suggests:` to `Imports:`.

### No New Dependencies

This phase requires zero new packages. All logic is already present in the codebase.

---

## Architecture Patterns

### Recommended Project Structure

New file only:
```
R/
└── curate_headless.R    # single exported function ~80 lines
```

DESCRIPTION update: `writexl` promoted from Suggests to Imports.

### Pattern 1: Verbose Suppression via withCallingHandlers

**What:** Wrap the entire pipeline body in `withCallingHandlers()` to intercept and discard `message` conditions when `verbose = FALSE`.

**When to use:** When a caller wants silent operation and cannot modify the message calls inside library functions.

**Example:**
```r
# Source: R internals / standard R pattern
run_pipeline <- function(..., verbose = TRUE) {
  body <- function() {
    # ... pipeline calls that use message() ...
  }

  if (verbose) {
    body()
  } else {
    withCallingHandlers(
      body(),
      message = function(m) invokeRestart("muffleMessage")
    )
  }
}
```

This is preferred over `suppressMessages()` because `withCallingHandlers` does not catch warnings or errors — fail-fast errors still propagate normally.

### Pattern 2: File I/O Without Shiny Input Object

**What:** `safely_read_file(filepath, file_ext)` takes a path and extension directly. `validate_file()` expects a Shiny `fileInput` list (`$name`, `$size`). In headless mode, bypass `validate_file()` and call `safely_read_file()` directly with `tools::file_ext(input_path)`.

**When to use:** Any non-Shiny caller.

**Example:**
```r
file_ext <- tolower(tools::file_ext(input_path))
if (!file_ext %in% c("csv", "xlsx", "xls")) {
  stop(sprintf("curate_headless: unsupported file type '%s'. Use csv, xlsx, or xls.", file_ext))
}
if (!file.exists(input_path)) {
  stop(sprintf("curate_headless: file not found: %s", input_path))
}
raw_df <- safely_read_file(input_path, file_ext)
```

### Pattern 3: Invisible Return with Named List

**What:** Return the result invisibly so XLSX is the "natural" output when the function is called without assignment, but the list is accessible when assigned.

**Example:**
```r
result <- list(
  data = resolution_state,
  audit_trail = cleaning_result$audit_trail
)
invisible(result)
```

### Pattern 4: Fake file_info and detection for export_sheets

**What:** `build_export_sheets()` expects `file_info` (list with `$name`, `$size`) and `detection` (list with `$method`, `$confidence`). In headless mode, construct these from `input_path` and the detection result.

**Example:**
```r
file_info <- list(
  name = basename(input_path),
  size = file.info(input_path)$size
)
# detection is the direct result of detect_data_start()
```

### Pattern 5: header_row Override for detect_data_start

**What:** `detect_data_start()` already supports `mode = "manual"` + `manual_row` parameter. Map `header_row` parameter to this.

**Example:**
```r
if (!is.null(header_row)) {
  detection <- detect_data_start(raw_df, mode = "manual", manual_row = header_row)
} else {
  detection <- detect_data_start(raw_df, mode = "auto")
}
```

### Pattern 6: Reference List Loading

**What:** When `reference_lists = NULL`, load from package's installed extdata. When provided by user, use as-is with a structure validation stop.

**Example:**
```r
if (is.null(reference_lists)) {
  cache_dir <- system.file("extdata", "reference_cache", package = "chemreg")
  reference_lists <- load_all_reference_lists(cache_dir)
} else {
  expected_keys <- c("stop_words", "functional_categories", "block_patterns", "strip_terms", "isotope_lookup")
  missing_keys <- setdiff(expected_keys, names(reference_lists))
  if (length(missing_keys) > 0) {
    stop(sprintf("curate_headless: reference_lists missing required keys: %s",
                 paste(missing_keys, collapse = ", ")))
  }
}
```

### Complete Pipeline Wiring Order

```
1. Validate input_path exists, extension supported
2. Load reference_lists (NULL → package extdata; provided → validate structure)
3. safely_read_file(input_path, file_ext)  → raw_df
4. detect_data_start(raw_df, ...)          → detection
5. extract_clean_data(raw_df, detection)   → clean_data
6. handle_merged_cells(clean_data)         → clean_data
7. janitor::clean_names(clean_data)        → clean_data
8. janitor::remove_empty(clean_data)       → clean_data
9. run_cleaning_pipeline(clean_data, tag_map, reference_lists) → cleaning_result
   # cleaning_result$cleaned_data, $audit_trail, $new_tags
10. merged_tags <- c(tag_map, cleaning_result$new_tags)
11. run_curation_pipeline(cleaning_result$cleaned_data, merged_tags) → pipeline_result
    # pipeline_result$results (resolution_state), $consensus_summary
12. build_export_sheets(raw_df, resolution_state, consensus_summary,
                        cleaning_result$audit_trail, reference_lists,
                        merged_tags, detection, file_info)  → sheets
13. writexl::write_xlsx(sheets, output_path)
14. invisible(list(data = resolution_state, audit_trail = cleaning_result$audit_trail))
```

### Anti-Patterns to Avoid

- **Calling validate_file() in headless mode:** It expects a Shiny fileInput object (`$name`, `$size`). Use plain `file.exists()` + `tools::file_ext()` instead.
- **Using suppressMessages() alone:** It also catches warning escalations; `withCallingHandlers` is more surgical.
- **Returning $data from cleaning_result instead of resolution_state:** The requirement is curated data (post-CompTox consensus), not just cleaned data.
- **Forgetting new_tags from cleaning_result:** `run_cleaning_pipeline()` may return `$new_tags` (e.g., auto-extracted CAS columns). These must be merged into `tag_map` before passing to `run_curation_pipeline()`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Message suppression | Custom flag-passing through all pipeline functions | `withCallingHandlers(..., message = function(m) invokeRestart("muffleMessage"))` | All pipeline functions use `message()` — intercepting at the handler level is the only non-invasive approach |
| XLSX writing | Custom Excel serialization | `writexl::write_xlsx()` (called via `build_export_sheets()`) | Already integrated; 7-sheet structure already built |
| File extension detection | Custom string parsing | `tools::file_ext()` | Built into base R, handles edge cases |
| Reference list loading | Inline tibble construction | `load_all_reference_lists(cache_dir)` | Already handles RDS caching, fallbacks, ComptoxR errors |
| Column name merging | Custom dedup logic | `c(tag_map, cleaning_result$new_tags)` | Standard R list merge for named lists |

---

## Common Pitfalls

### Pitfall 1: writexl in Suggests, Not Imports

**What goes wrong:** `curate_headless()` calls `writexl::write_xlsx()`. If `writexl` is only in Suggests, users who install the package without running `install.packages("writexl")` get a cryptic namespace error at runtime, not at install time.

**Why it happens:** Phase 24 put `writexl` in Suggests because Shiny UI exports were considered optional. Headless export is not optional — it is the primary output.

**How to avoid:** Move `writexl` from `Suggests` to `Imports` in DESCRIPTION before implementing `curate_headless()`.

**Warning signs:** `R CMD check` NOTE "writexl called but not in Imports".

### Pitfall 2: Dropping new_tags From Cleaning Pipeline

**What goes wrong:** `run_cleaning_pipeline()` can auto-detect and extract CAS numbers from text columns, returning them in `$new_tags` (e.g., `list(cas_extract_name = "CASRN")`). If only the original `tag_map` is passed to `run_curation_pipeline()`, these auto-extracted columns are not searched.

**Why it happens:** The caller doesn't realize `run_cleaning_pipeline()` produces additional tags.

**How to avoid:** Always merge: `merged_tags <- c(tag_map, cleaning_result$new_tags)` before calling `run_curation_pipeline()`.

### Pitfall 3: wrong $data in Return Value

**What goes wrong:** Returning `cleaning_result$cleaned_data` as `$data` instead of `resolution_state`. The requirement (HDL-04) says `$data` is the **curated** data frame — the one with `consensus_dtxsid`, `consensus_status`, `qc_tier` columns from `run_curation_pipeline()`.

**Why it happens:** Confusion between "cleaned" (post-cleaning pipeline) and "curated" (post-CompTox + consensus).

**How to avoid:** `$data` = `pipeline_result$results` (the resolution_state tibble), not `cleaning_result$cleaned_data`.

### Pitfall 4: output_path Parent Directory Missing

**What goes wrong:** `writexl::write_xlsx()` will error if the parent directory of `output_path` doesn't exist.

**Why it happens:** writexl does not auto-create directories.

**How to avoid:** Add `fs::dir_create(dirname(output_path), recurse = TRUE)` before the `write_xlsx()` call.

### Pitfall 5: tag_map Columns Not Present in clean_data After janitor::clean_names

**What goes wrong:** `janitor::clean_names()` lowercases and snake_cases column names. If `tag_map` uses original casing (e.g., `"Chemical Name"` → becomes `"chemical_name"`), the tag_map keys won't match.

**Why it happens:** `tag_map` is provided by the caller with column names as they appear in the raw file. After `clean_names()`, those names change.

**How to avoid:** Apply `janitor::clean_names()` to `clean_data` first, then validate that all keys in `tag_map` exist in `names(clean_data)`. If they don't, try to auto-map or fail fast with a clear error listing the discrepancy.

**Implementation approach:** After `clean_names()`, check `setdiff(names(tag_map), names(clean_data))`. If non-empty, stop with: `"curate_headless: tag_map keys not found in cleaned data after column name normalization: {missing}. Column names after normalization: {actual}"`.

### Pitfall 6: run_curation_pipeline Returns pipeline_result$results, Not a Direct Tibble

**What goes wrong:** `run_curation_pipeline()` returns a named list: `$results` (resolution_state tibble), `$dedup_summary`, `$search_summary`, `$consensus_summary`. Accessing `pipeline_result` directly instead of `pipeline_result$results` produces a list, not a tibble.

**How to avoid:** Explicitly extract: `resolution_state <- pipeline_result$results`.

---

## Code Examples

### Full curate_headless skeleton

```r
# Source: derived from existing codebase patterns
#' Run the full curation pipeline headlessly
#'
#' @param input_path Path to input file (csv, xlsx, xls)
#' @param output_path Path for output XLSX file
#' @param tag_map Named list mapping column names to types ("Name", "CASRN", "Other")
#' @param skip_flags Optional character vector of cleaning_flag values to skip from API search
#' @param header_row Optional integer. If NULL, auto-detect. If integer, use as header row.
#' @param reference_lists Optional list. If NULL, load from package extdata.
#' @param verbose Logical. If FALSE, suppress progress messages. Default TRUE.
#' @return Invisibly: list with $data (curated tibble) and $audit_trail (audit tibble)
#' @export
curate_headless <- function(input_path, output_path, tag_map,
                             skip_flags = NULL, header_row = NULL,
                             reference_lists = NULL, verbose = TRUE) {

  pipeline <- function() {
    # 1. Validate input
    if (!file.exists(input_path)) {
      stop(sprintf("curate_headless: file not found: %s", input_path))
    }
    file_ext <- tolower(tools::file_ext(input_path))
    if (!file_ext %in% c("csv", "xlsx", "xls")) {
      stop(sprintf("curate_headless: unsupported file type '%s'", file_ext))
    }

    # 2. Reference lists
    if (is.null(reference_lists)) {
      cache_dir <- system.file("extdata", "reference_cache", package = "chemreg")
      reference_lists <- load_all_reference_lists(cache_dir)
    } else {
      expected <- c("stop_words", "functional_categories", "block_patterns",
                    "strip_terms", "isotope_lookup")
      missing <- setdiff(expected, names(reference_lists))
      if (length(missing) > 0) {
        stop(sprintf("curate_headless: reference_lists missing keys: %s",
                     paste(missing, collapse = ", ")))
      }
    }

    # 3. Read file
    raw_df <- safely_read_file(input_path, file_ext)

    # 4. Detect frontmatter
    if (!is.null(header_row)) {
      detection <- detect_data_start(raw_df, mode = "manual", manual_row = header_row)
    } else {
      detection <- detect_data_start(raw_df, mode = "auto")
    }

    # 5. Extract + post-process
    clean_data <- extract_clean_data(raw_df, detection)
    clean_data <- handle_merged_cells(clean_data)
    clean_data <- janitor::clean_names(clean_data)
    clean_data <- janitor::remove_empty(clean_data, which = c("rows", "cols"))

    # 6. Validate tag_map against actual column names
    missing_cols <- setdiff(names(tag_map), names(clean_data))
    if (length(missing_cols) > 0) {
      stop(sprintf(
        "curate_headless: tag_map keys not found after column normalization: %s\nActual columns: %s",
        paste(missing_cols, collapse = ", "),
        paste(names(clean_data), collapse = ", ")
      ))
    }

    # 7. Cleaning pipeline
    cleaning_result <- run_cleaning_pipeline(clean_data, tag_map, reference_lists)
    merged_tags <- c(tag_map, cleaning_result$new_tags)

    # 8. Curation pipeline
    pipeline_result <- run_curation_pipeline(cleaning_result$cleaned_data, merged_tags)
    resolution_state <- pipeline_result$results

    # 9. Export
    file_info <- list(name = basename(input_path), size = file.info(input_path)$size)
    sheets <- build_export_sheets(
      raw                = raw_df,
      resolution_state   = resolution_state,
      consensus_summary  = pipeline_result$consensus_summary,
      cleaning_audit     = cleaning_result$audit_trail,
      reference_lists    = reference_lists,
      column_tags        = merged_tags,
      detection          = detection,
      file_info          = file_info
    )
    fs::dir_create(dirname(output_path), recurse = TRUE)
    writexl::write_xlsx(sheets, output_path)

    # 10. Return
    invisible(list(
      data        = resolution_state,
      audit_trail = cleaning_result$audit_trail
    ))
  }

  if (verbose) {
    pipeline()
  } else {
    withCallingHandlers(
      pipeline(),
      message = function(m) invokeRestart("muffleMessage")
    )
  }
}
```

### Verbosity suppression pattern (confirmed R idiom)

```r
# withCallingHandlers is preferred over suppressMessages() for fail-fast compatibility.
# Errors still propagate; only message() conditions are muffled.
withCallingHandlers(
  expr,
  message = function(m) invokeRestart("muffleMessage")
)
```

---

## Environment Availability

> Step 2.6: Dependencies are all already present in the package — no external tools required beyond what Phase 24-26 already established.

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| R 4.5.1 | Runtime | ✓ | Confirmed in global CLAUDE.md |
| writexl | XLSX export | ✓ (in Suggests) | Must be promoted to Imports |
| ComptoxR | API search | ✓ (in Imports, via Remotes) | Already wired in Phase 24 |
| devtools | `@export` + document | ✓ | Used in all prior phases |
| All other dependencies | (inherited) | ✓ | Unchanged from Phase 26 |

**Missing dependencies with no fallback:** None.

**Action required:** Promote `writexl` from Suggests to Imports in DESCRIPTION.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat (>= 3.0.0) |
| Config file | None yet — tests/testthat/ migration is Phase 28 |
| Quick run command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests')"` |
| Full suite command | Same (legacy test layout) |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Notes |
|--------|----------|-----------|-------|
| HDL-01 | `curate_headless` is exported and discoverable | Smoke | Verify `?curate_headless` works after `devtools::document()` + `devtools::install()` |
| HDL-02 | Full pipeline runs without error on `uncurated_sswqs.csv` | Integration | Requires live CompTox API — manual-only in CI-less environment |
| HDL-03 | Output XLSX is a valid file with expected sheets | Integration | `file.exists(output_path)` + `readxl::excel_sheets()` returns 7 sheet names |
| HDL-04 | Return value contains `$data` and `$audit_trail` | Unit | Can be tested without API if a mock/stub is available, otherwise integration |

### Wave 0 Gaps

The legacy test layout (`tests/test_*.R`) does not yet have a test for `curate_headless`. However, since Phase 28 handles test migration, the minimum for Phase 27 is:

- [ ] Manual smoke test: run `curate_headless(input_path = "uncurated_sswqs.csv", output_path = "out.xlsx", tag_map = list(...))` against the repo's sample data file and verify the XLSX is produced and return value has `$data` and `$audit_trail`.
- [ ] `devtools::document()` succeeds with no errors.
- [ ] `devtools::check()` produces no new errors (HDL-01 verified via NAMESPACE export).

Full automated test coverage is Phase 28 scope (TST-01 through TST-04).

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 27 |
|-----------|-------------------|
| Always use explicit `ggplot2::` namespace prefixes | Not applicable (no plots in this phase) |
| No bare `library()` calls in R/ files | `curate_headless.R` must use `::` notation or `@importFrom` — no `library()` |
| After Shiny UI/server changes, run smoke test | Not applicable — no Shiny changes in this phase |
| Write R code to temp file, never `Rscript -e` for multi-statement | Applies to any test commands during implementation |
| Always use explicit `ggplot2::` namespace | Not applicable |
| `devtools::check()` must pass with no new errors | Phase 27 must not introduce new check errors |
| Branch strategy: feature branch for all non-trivial work | Already on `feature/26-app-relocation` — verify correct branch for phase 27 |

**Namespace / DESCRIPTION rules extracted:**
- New `writexl::write_xlsx()` call requires `writexl` in Imports (not Suggests).
- `tools::file_ext()` is in base R (`tools` package) — already in Imports via `stats`; however `tools` itself must be added to Imports if not already present.
- Check: `tools` is NOT currently listed in DESCRIPTION Imports — must be added, or use `tools::file_ext()` with `@importFrom tools file_ext` in roxygen.

---

## Open Questions

1. **Does `tools` need to be added to DESCRIPTION Imports?**
   - What we know: `tools::file_ext()` is used in `R/file_handlers.R` but `tools` is not in DESCRIPTION Imports. This has not caused issues because `tools` is a base package loaded by default in R sessions.
   - What's unclear: Whether `devtools::check()` will flag this as a missing import in strict mode.
   - Recommendation: Add `@importFrom tools file_ext` in the roxygen block for `curate_headless()` to be explicit, and add `tools` to Imports in DESCRIPTION. Low risk.

2. **Does `run_curation_pipeline()` expose `skip_flags` directly?**
   - What we know: Looking at `curation.R` line 540, `run_curation_pipeline()` does NOT accept `skip_flags` as a parameter — it hardcodes `skip_flags = "isotope_match"` internally at line 561. The `skip_flags` parameter in `curate_headless()` signature (from CONTEXT.md) was intended for the dedup stage.
   - What's unclear: Whether the planner should pass `skip_flags` through to `deduplicate_tagged_columns()` separately, or whether the existing `run_curation_pipeline()` hardcoded behavior is sufficient.
   - Recommendation: The locked signature includes `skip_flags`. The planner should add `skip_flags` as a parameter to `run_curation_pipeline()` OR handle it inside `curate_headless()` by pre-filtering rows before calling `run_curation_pipeline()`. The path of least resistance: add `skip_flags` forwarding as an additional parameter to `run_curation_pipeline()` (one-line change) so `curate_headless()` can pass it through.

---

## Sources

### Primary (HIGH confidence)
- Direct code read: `R/curation.R` — `run_curation_pipeline()` signature, skip_flags usage, message() patterns
- Direct code read: `R/cleaning_pipeline.R` — `run_cleaning_pipeline()` signature and return structure (`$cleaned_data`, `$audit_trail`, `$new_tags`)
- Direct code read: `R/export_helpers.R` — `build_export_sheets()` parameter list
- Direct code read: `R/file_handlers.R` — `safely_read_file()` signature; `validate_file()` Shiny dependency
- Direct code read: `R/data_detection.R` — `detect_data_start()` `mode`/`manual_row` interface
- Direct code read: `R/cleaning_reference.R` — `load_all_reference_lists()` and cache_dir pattern
- Direct code read: `DESCRIPTION` — writexl in Suggests, tools not listed
- Direct code read: `inst/extdata/reference_cache/` — confirmed 5 RDS files match expected keys

### Secondary (MEDIUM confidence)
- R language reference: `withCallingHandlers` + `muffleMessage` restart — standard R idiom, widely documented

---

## Metadata

**Confidence breakdown:**
- Pipeline wiring order: HIGH — read actual function signatures; no guessing
- verbose suppression pattern: HIGH — standard R idiom confirmed by code inspection
- writexl Imports promotion: HIGH — direct DESCRIPTION read
- skip_flags forwarding gap: MEDIUM — identified structural gap in run_curation_pipeline() signature; resolution approach is clear but requires one additional code change not mentioned in CONTEXT.md
- tools package import: MEDIUM — known base package behavior; low risk either way

**Research date:** 2026-04-13
**Valid until:** Stable (no external API — all internal code); valid until any pipeline function signatures change
