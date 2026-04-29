# Phase 38: Benchmark Harness - Pattern Map

**Mapped:** 2026-04-24
**Files analyzed:** 4 (1 new script, 2 modified R functions, 1 config change)
**Analogs found:** 4 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `scripts/benchmark_pipeline.R` | utility (standalone script) | batch | `scripts/curate_dataset.R` | exact |
| `R/cleaning_pipeline.R` → `run_cleaning_pipeline()` | service / orchestrator | batch | self (signature extension) | exact |
| `R/unit_harmonizer.R` → `harmonize_units()` | service | transform | self (signature extension) | exact |
| `DESCRIPTION` (Suggests field) | config | — | self | exact |

## Pattern Assignments

### `scripts/benchmark_pipeline.R` (utility, batch)

**Analog:** `scripts/curate_dataset.R`

**Script header and sourcing pattern** (curate_dataset.R lines 1–33):
```r
# benchmark_pipeline.R
# Standalone benchmark — no Shiny dependency
library(dplyr)
library(bench)

CHEMREG_ROOT <- here::here()
source(file.path(CHEMREG_ROOT, "R", "cleaning_pipeline.R"))
source(file.path(CHEMREG_ROOT, "R", "unit_harmonizer.R"))
source(file.path(CHEMREG_ROOT, "R", "cleaning_reference.R"))
```

**Guard/stopifnot pattern** (curate_dataset.R lines 44–47):
```r
stopifnot(
  "No benchmark data found in data/benchmark/" = length(bench_files) > 0
)
```

**message() progress reporting pattern** (curate_dataset.R lines 76–105):
```r
message("=== CLEANING ===")
# ... work ...
message(sprintf("  Cleaned: %d rows, %d audit entries", nrow(cleaned_df), nrow(audit_trail)))
```

**Result capture pattern** (curate_dataset.R lines 92–98):
```r
cleaning_result <- run_cleaning_pipeline(df = raw_df, tag_map = tag_map, reference_lists = ref_lists)
cleaned_df <- cleaning_result$cleaned_data
audit_trail <- cleaning_result$audit_trail
```

**Benchmark-specific additions** (from RESEARCH.md patterns):
```r
# Pre-generate subsets BEFORE bench::press() — avoids contaminating timings
set.seed(42)
df_1k   <- dplyr::slice_sample(benchmark_df, n = 1000L)
df_10k  <- dplyr::slice_sample(benchmark_df, n = 10000L)
df_100k <- dplyr::slice_sample(benchmark_df, n = 100000L)

# Cold-start: isolated single-iteration run before warm grid
cold_result <- bench::mark(
  run_cleaning_pipeline(df_1k, tag_map, ref_lists, use_dedup = TRUE),
  min_iterations = 1, max_iterations = 1,
  memory = TRUE, check = FALSE
)

# Warm grid: check = FALSE required — use_dedup TRUE/FALSE produce different audit row_ids
cleaning_results <- bench::press(
  n = c(1000L, 10000L, 100000L),
  use_dedup = c(TRUE, FALSE),
  {
    df_sub <- switch(as.character(n),
      "1000" = df_1k, "10000" = df_10k, "100000" = df_100k
    )
    bench::mark(
      run_cleaning_pipeline(df_sub, tag_map, ref_lists, use_dedup = use_dedup),
      min_iterations = 3, memory = TRUE, check = FALSE
    )
  }
)

# Save raw results (gitignored path)
readr::write_csv(
  dplyr::select(cleaning_results, n, use_dedup, median, mem_alloc),
  file.path(CHEMREG_ROOT, "data", "benchmark", "results.csv")
)
```

---

### `R/cleaning_pipeline.R` → `run_cleaning_pipeline()` (orchestrator, batch)

**Analog:** self — parameter extension only

**Current signature** (cleaning_pipeline.R line 1727):
```r
run_cleaning_pipeline <- function(df, tag_map = NULL, reference_lists = NULL) {
```

**Target signature** — add `use_dedup = TRUE` as last parameter:
```r
run_cleaning_pipeline <- function(df, tag_map = NULL, reference_lists = NULL,
                                  use_dedup = TRUE) {
```

**`dedup_step()` signature to bypass** (cleaning_pipeline.R lines 184–199):
```r
dedup_step <- function(step_fn, df, ..., dedup_cols, uniqueness_threshold = 0.5) {
  # ... builds dedup key, bypasses when uniqueness > threshold ...
  if (n_total == 0 || n_distinct / n_total > uniqueness_threshold) {
    return(step_fn(df, ...))  # already a direct call when cardinality is high
  }
  # ... dedup path ...
}
```

**Toggle wiring pattern** (from RESEARCH.md Pattern 1):
```r
step_runner <- if (use_dedup) {
  function(fn, df, ...) dedup_step(fn, df, ...)
} else {
  function(fn, df, ...)   fn(df, ...)
}
# All pipeline steps use step_runner() instead of direct fn() calls
```

---

### `R/unit_harmonizer.R` → `harmonize_units()` (service, transform)

**Analog:** self — parameter extension only

**Current signature** (unit_harmonizer.R line 261):
```r
harmonize_units <- function(values, units, unit_map,
                            media = NULL,
                            dtxsid = NULL,
                            molecular_weight = NULL) {
```

**Target signature** — add `use_dedup = TRUE`:
```r
harmonize_units <- function(values, units, unit_map,
                            media = NULL,
                            dtxsid = NULL,
                            molecular_weight = NULL,
                            use_dedup = TRUE) {
```

The unit-key dedup pattern (Phase 37) uses a unit string as the dedup key. The `use_dedup = FALSE` path calls the underlying unit conversion directly without dedup pre-filtering.

---

### `DESCRIPTION` (config)

**Current Suggests field** (DESCRIPTION lines 43–45):
```
Suggests:
    testthat (>= 3.0.0),
    withr
```

**Target** — add `bench`:
```
Suggests:
    bench,
    testthat (>= 3.0.0),
    withr
```

---

## Shared Patterns

### Script Section Header Convention
**Source:** `scripts/curate_dataset.R` throughout
**Apply to:** `scripts/benchmark_pipeline.R`
```r
# ============================================================================
# 0. CONFIGURATION
# ============================================================================
```
Use numbered sections (0 CONFIG, 1 INPUT DATA, 2 SUBSETS, 3 COLD START, 4 CLEANING BENCHMARK, 5 HARMONIZATION BENCHMARK, 6 RESULTS).

### .gitignore Path for Data Directory
**Source:** `.gitignore` existing entries (e.g., `data/reference_cache/`, `storage/`)
**Apply to:** `.gitignore` — add `data/benchmark/` entry before any benchmark directory is created.

### Markdown Summary Output
**Location discretion (from RESEARCH.md open question 3):** Use `docs/benchmark_results.md`. The `docs/` directory does not yet exist — create it. This is a committed artifact for users, not a planning artifact.

---

## No Analog Found

None. All files have direct analogs or are self-extensions.

---

## Critical Implementation Notes for Planner

1. **`dedup_step()` wiring status:** Phase 37 research confirms `run_cleaning_pipeline()` at line 1727 calls step functions directly (no `dedup_step()` wrappers visible). The `use_dedup` toggle depends on Phase 37 having wired `dedup_step()` into the orchestrator. Planner must include a verification step before implementing the toggle.

2. **`check = FALSE` is mandatory** in every `bench::mark()` call — `use_dedup=TRUE` vs `FALSE` produce different audit trail row_ids so value equality checks will error.

3. **Subsets generated outside `bench::press()`** — `slice_sample()` must run before any timing call. The `bench::press()` expression uses pre-built `df_1k` / `df_10k` / `df_100k` via `switch()`.

4. **`data/benchmark/` must be gitignored before creation** — current `.gitignore` does not include this path.

5. **`bench` not installed** — must be added to DESCRIPTION Suggests and installed with `pak::pak("bench")` before the script can run.

## Metadata

**Analog search scope:** `scripts/`, `R/`, `DESCRIPTION`, `.gitignore`
**Files scanned:** 6 (curate_dataset.R, cleaning_pipeline.R, unit_harmonizer.R, DESCRIPTION, .gitignore, existing tests dir)
**Pattern extraction date:** 2026-04-24
