# Phase 44: Matching Engine + Prototype - Pattern Map

**Mapped:** 2026-05-05
**Files analyzed:** 4 (3 new files + 1 modified config)
**Analogs found:** 4 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `R/wqx_matching.R` | service | transform (lookup/resolve) | `R/curation.R` (tiered search) + `R/cleaning_reference.R` (loader functions) | role-match |
| `scripts/prototype_wqx_matching.R` | utility (standalone script) | batch | `scripts/build_wqx_dictionary.R` + `scripts/benchmark_pipeline.R` | exact |
| `tests/testthat/test-wqx-matching.R` | test | request-response | `tests/testthat/test-wqx-dictionary.R` | exact |
| `DESCRIPTION` | config | — | `DESCRIPTION` (existing) | exact |

---

## Pattern Assignments

### `R/wqx_matching.R` (service, transform)

**Primary analog:** `R/curation.R` — tiered search orchestration  
**Secondary analog:** `R/cleaning_reference.R` lines 590-603 — exported function with roxygen block

**File header pattern** (from `R/cleaning_reference.R` lines 1-6 and `R/curation.R` lines 1-6):
```r
# wqx_matching.R
# Three-tier WQX Characteristic Name matcher
#
# Tier 1: exact canonical lookup (O(1) named vector)
# Tier 2: alias lookup resolving to canonical_name (O(1) named vector)
# Tier 3: Jaro-Winkler fuzzy fallback against canonical names only
```

**Roxygen + export pattern** (from `R/cleaning_reference.R` lines 591-603):
```r
#' Match chemical names against WQX Characteristic Name dictionary
#'
#' Runs a three-tier lookup: (1) exact canonical, (2) alias crosswalk,
#' (3) Jaro-Winkler fuzzy against canonical names only. Returns a tibble
#' with one row per input name.
#'
#' @param names Character vector of analyte names to match
#' @param dictionary Tibble from load_wqx_dictionary() — columns: name, canonical_name, type
#' @param threshold Numeric similarity threshold for fuzzy acceptance (default 0.85).
#'   Internally converted to JW distance cutoff: distance <= (1 - threshold).
#' @param verbose Logical. If TRUE, emits per-name cli output (default FALSE).
#' @return Tibble with columns: input_name, wqx_name, match_tier, match_distance, alias_type
#' @export
match_wqx <- function(names, dictionary, threshold = 0.85, verbose = FALSE) {
```

**Namespace prefix convention** (consistent across all R/ files — never bare function calls):
```r
# All package functions called with explicit :: prefix
canonical_rows <- dplyr::filter(dictionary, type == "canonical")
alias_rows <- dplyr::filter(dictionary, type %in% c("synonym", "standardize", "retired"))
tier1_map <- stats::setNames(canonical_rows$name, tolower(canonical_rows$name))
tier2_map <- stats::setNames(alias_rows$canonical_name, tolower(alias_rows$name))
tier2_type_map <- stats::setNames(alias_rows$type, tolower(alias_rows$name))
```

**Tiered search orchestration pattern** (from `R/curation.R` lines 366-483 — `run_tiered_search()`):
```r
# Pattern: collect tier results into a list, bind_rows at end
# Identify misses at each tier; pass only unresolved to next tier
all_results <- list()

# Tier 1: Exact canonical
matched_names <- exact_results$searchValue[!is.na(exact_results$dtxsid)]
missed_names <- setdiff(dedup_result$unique_names, matched_names)

# Tier 2: Alias fallback on tier 1 misses
cas_matched <- cas_from_names$original_cas[!is.na(cas_from_names$dtxsid)]
still_missed <- setdiff(missed_names, cas_matched)

# Tier 3: Fuzzy fallback on tier 2 misses
# ... only the unresolved remainder reaches tier 3

# Final: bind all result lists
combined <- dplyr::bind_rows(all_results)
```

**Named-vector O(1) lookup pattern** (from `R/curation.R` lines 503-508 — `map_results_to_rows()`):
```r
# Build named index for O(1) lookup — same technique for tier1_map / tier2_map
lookup_deduped <- lookup_results |>
  dplyr::arrange(rank) |>
  dplyr::distinct(searchValue, .keep_all = TRUE)

lookup_idx <- stats::setNames(seq_len(nrow(lookup_deduped)), lookup_deduped$searchValue)
```

**Empty-input guard pattern** (from `R/curation.R` lines 99-110 and 284-288):
```r
# Every function guards against empty input before processing
empty_result <- tibble::tibble(
  input_name = character(0),
  wqx_name = character(0),
  match_tier = character(0),
  match_distance = numeric(0),
  alias_type = character(0)
)

if (length(names) == 0) {
  return(empty_result)
}
```

**Summary message pattern** (from `R/curation.R` lines 474-481):
```r
# Summary message after tier escalation completes
n_exact <- sum(combined$source_tier == "exact", na.rm = TRUE)
n_sw <- sum(combined$source_tier == "starts_with", na.rm = TRUE)
n_cas <- sum(combined$source_tier == "cas", na.rm = TRUE)
n_miss <- sum(combined$source_tier == "miss", na.rm = TRUE)
message(sprintf(
  "Results: %d exact, %d starts-with, %d CAS, %d misses",
  n_exact, n_sw, n_cas, n_miss
))
```
For `match_wqx()` the cli analog replaces `message()` per D-04/D-05 — see Shared Patterns: cli Logging.

**Result tibble construction** (from `R/curation.R` lines 128-134 and `R/cleaning_reference.R` lines 586-587):
```r
# Always construct return tibble explicitly with typed NA columns
tibble::tibble(
  input_name = names,
  wqx_name = NA_character_,
  match_tier = "none",
  match_distance = NA_real_,
  alias_type = NA_character_
)
```

---

### `scripts/prototype_wqx_matching.R` (utility, batch)

**Primary analog:** `scripts/build_wqx_dictionary.R` lines 1-86  
**Secondary analog:** `scripts/benchmark_pipeline.R` lines 1-60

**File header pattern** (from `scripts/build_wqx_dictionary.R` lines 1-14):
```r
# prototype_wqx_matching.R
# Standalone WQX matcher prototype -- validates match_wqx() against training data.
# No Shiny dependency -- runs in any R session.
#
# Prerequisites:
#   1. inst/extdata/reference_cache/wqx_dictionary.rds (built by Phase 43)
#   2. detections_uat_sample_50.csv in repo root
#
# Usage: source("scripts/prototype_wqx_matching.R")
#
# Output: tier breakdown + fuzzy matches printed to console
```

**CHEMREG_ROOT + source() pattern** (from `scripts/build_wqx_dictionary.R` line 15 and `scripts/benchmark_pipeline.R` lines 22-26):
```r
CHEMREG_ROOT <- here::here()

source(file.path(CHEMREG_ROOT, "R", "cleaning_reference.R"))
source(file.path(CHEMREG_ROOT, "R", "wqx_matching.R"))
```

**stopifnot() prerequisite guard pattern** (from `scripts/build_wqx_dictionary.R` lines 18-19 and `scripts/benchmark_pipeline.R` lines 28-33):
```r
# Guard required files before proceeding
cache_path <- file.path(CHEMREG_ROOT, "inst", "extdata", "reference_cache", "wqx_dictionary.rds")
stopifnot(
  "wqx_dictionary.rds not found -- run scripts/build_wqx_dictionary.R first" = file.exists(cache_path)
)

train_path <- file.path(CHEMREG_ROOT, "detections_uat_sample_50.csv")
stopifnot(
  "detections_uat_sample_50.csv not found in repo root" = file.exists(train_path)
)
```

**Section separator comment pattern** (from `scripts/benchmark_pipeline.R` lines 17-19, 35-37, etc.):
```r
# ============================================================================
# 1. LOAD DICTIONARY
# ============================================================================
```

**Data loading pattern** (from `scripts/benchmark_pipeline.R` lines 47-54):
```r
message("=== LOADING TRAINING DATA ===")
train <- readr::read_csv(
  file.path(CHEMREG_ROOT, "detections_uat_sample_50.csv"),
  show_col_types = FALSE
)
message(sprintf(
  "  Loaded: %s (%d rows x %d cols)",
  basename(train_path),
  nrow(train),
  ncol(train)
))
```

**Accuracy report section pattern** (from `scripts/benchmark_pipeline.R` lines 142-155 — cold-start measurement section):
```r
message("=== MATCH RESULTS ===")
print(table(results$match_tier))

message("=== FUZZY MATCHES FOR REVIEW ===")
fuzzy_hits <- results[results$match_tier == "fuzzy", ]
print(fuzzy_hits[, c("input_name", "wqx_name", "match_distance")])

message("=== UNRESOLVED ===")
unresolved <- results[results$match_tier == "none", ]
print(unresolved[, c("input_name", "match_distance")])
```

---

### `tests/testthat/test-wqx-matching.R` (test)

**Primary analog:** `tests/testthat/test-wqx-dictionary.R` lines 1-122  
**Secondary analog:** `tests/testthat/test-data-detection.R` lines 1-77

**Test file location:** `tests/testthat/` (not `tests/` root — the project uses the standard testthat layout confirmed by `tests/testthat.R`)

**File header pattern** (from `tests/testthat/test-wqx-dictionary.R` lines 1-3):
```r
# Test file for wqx_matching.R
# Tests MATCH-01 through MATCH-04 requirements
```

**Mock dictionary pattern** (from `tests/testthat/test-wqx-dictionary.R` lines 7-14):
```r
# Shared minimal mock dictionary — used across all tests
mock_dict <- tibble::tibble(
  name = c("Arsenic", "Dissolved oxygen", "DO", "Arsenic, Total", "Lead"),
  canonical_name = c("Arsenic", "Dissolved oxygen", "Dissolved oxygen", "Arsenic", "Lead"),
  type = c("canonical", "canonical", "synonym", "standardize", "canonical"),
  cas_number = c("7440-38-2", "7782-44-7", NA_character_, NA_character_, "7439-92-1"),
  group_name = c("Metals", "Inorganics, Major, Non-metals", NA, NA, "Metals"),
  description = c(NA_character_, NA_character_, NA_character_, NA_character_, NA_character_)
)
```

**test_that() structure** (from `tests/testthat/test-data-detection.R` lines 5-17):
```r
# One test_that() block per requirement
test_that("match_wqx returns exact tier for canonical name match", {
  result <- match_wqx("Arsenic", mock_dict)

  expect_equal(nrow(result), 1L)
  expect_equal(result$match_tier, "exact")
  expect_equal(result$wqx_name, "Arsenic")
  expect_true(is.na(result$match_distance))
  expect_true(is.na(result$alias_type))
})
```

**withr::with_tempdir() pattern** — not needed for `match_wqx()` (no file I/O). Use direct mock tibble instead of tempdir (simpler than the `test-wqx-dictionary.R` pattern which needed disk I/O).

**Case-insensitive and whitespace test pattern** (inferred from RESEARCH.md Pitfalls 2-3 — must be tested):
```r
test_that("match_wqx is case-insensitive and trims whitespace", {
  result <- match_wqx(c("ARSENIC", " Arsenic "), mock_dict)

  expect_equal(nrow(result), 2L)
  expect_true(all(result$match_tier == "exact"))
})
```

**NA/empty input test pattern** (from `R/curation.R` guard patterns — must test the discretion case):
```r
test_that("match_wqx handles NA and empty string inputs", {
  result <- match_wqx(c("Arsenic", NA_character_, ""), mock_dict)

  expect_equal(nrow(result), 3L)
  expect_equal(result$match_tier[1], "exact")
  expect_equal(result$match_tier[2], "none")  # or "skip" per implementation choice
  expect_equal(result$match_tier[3], "none")
})
```

**Return schema test pattern** (from `tests/testthat/test-wqx-dictionary.R` lines 102-106):
```r
test_that("match_wqx returns correct column schema", {
  result <- match_wqx("Arsenic", mock_dict)

  expect_s3_class(result, "tbl_df")
  expect_named(result, c("input_name", "wqx_name", "match_tier", "match_distance", "alias_type"))
})
```

---

### `DESCRIPTION` (config)

**Analog:** Current `DESCRIPTION` (lines 13-43)

**Imports block insertion pattern** — alphabetical order within the `Imports:` section:
```
Imports:
    arrow,
    bsicons,
    bslib,
    cli,               # ADD — new dependency (D-04)
    ComptoxR,
    digest,
    dplyr,
    ...
    stringdist,        # ADD — new dependency (D-01/D-03), after stringi
    stringi,
    stringr,
    ...
```

Exact current Imports block for reference (lines 13-43 of DESCRIPTION) — `cli` goes after `bslib,`, `stringdist` goes between `stringi,` and `stringr,`.

---

## Shared Patterns

### cli Logging (D-04/D-05)

**Source:** RESEARCH.md Pattern 3 (no existing analog — `cli` is installed but not yet used in any R/ file per DESCRIPTION)  
**Apply to:** `R/wqx_matching.R` — summary always, per-name when `verbose = TRUE`

```r
# Summary (always printed, regardless of verbose flag)
cli::cli_inform(c(
  "v" = "WQX match complete: {n_exact} exact, {n_alias} alias, {n_fuzzy} fuzzy, {n_none} unresolved"
))

# Per-name verbose output (only when verbose = TRUE)
if (verbose) {
  # Resolved match
  cli::cli_alert_success("'{input}' -> '{wqx}' [{tier}]")
  # Fuzzy match with distance
  cli::cli_alert_success("'{input}' -> '{wqx}' [fuzzy, dist={dist:.3f}]")
  # Unresolved — show nearest candidate
  cli::cli_alert_warning("'{input}' -> unresolved (nearest: '{candidate}', dist={dist:.3f})")
}
```

### Explicit Namespace Prefixes

**Source:** All R/ files in the project — universal convention  
**Apply to:** `R/wqx_matching.R` — every package function call uses `pkg::fn()` syntax

Key namespaces for `match_wqx()`:
- `dplyr::filter()`, `dplyr::distinct()`
- `tibble::tibble()`
- `stats::setNames()`
- `stringdist::stringdistmatrix()`
- `cli::cli_inform()`, `cli::cli_alert_success()`, `cli::cli_alert_warning()`

### Input Normalization

**Source:** `scripts/build_wqx_dictionary.R` line 29 (`trimws(name)`) + RESEARCH.md Pitfall 3  
**Apply to:** `R/wqx_matching.R` — apply once at function entry before any tier

```r
# Apply both trimws() and tolower() once upfront — not per-tier
names_clean <- tolower(trimws(names))
```

### Air Formatting

**Source:** `CLAUDE.md` — mandatory after every R file write  
**Apply to:** `R/wqx_matching.R`, `scripts/prototype_wqx_matching.R`, `tests/testthat/test-wqx-matching.R`

```bash
air format R/wqx_matching.R
air format scripts/prototype_wqx_matching.R
air format tests/testthat/test-wqx-matching.R
```

---

## No Analog Found

No files in this phase lack analogs. All four files have direct structural matches in the existing codebase.

The only pattern sourced from RESEARCH.md rather than the codebase is the `cli::` logging API — `cli` is installed but has no existing usage pattern in any `R/` file, so the RESEARCH.md Pattern 3 excerpts are authoritative for that specific call style.

---

## Metadata

**Analog search scope:** `R/`, `scripts/`, `tests/testthat/`, `DESCRIPTION`  
**Files scanned:** `R/cleaning_reference.R`, `R/curation.R`, `scripts/build_wqx_dictionary.R`, `scripts/benchmark_pipeline.R`, `tests/testthat/test-wqx-dictionary.R`, `tests/testthat/test-data-detection.R`, `tests/testthat/test-cleaning-reference.R`, `DESCRIPTION`  
**Pattern extraction date:** 2026-05-05
