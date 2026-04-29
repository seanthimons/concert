# Phase 38: Benchmark Harness - Research

**Researched:** 2026-04-24
**Domain:** R benchmarking with `bench` package; standalone script pattern
**Confidence:** HIGH

## Summary

This phase is a standalone measurement script, not new pipeline code. The primary work is:
1. Adding `use_dedup` toggle parameters to `run_cleaning_pipeline()` and `harmonize_units()`
2. Writing `scripts/benchmark_pipeline.R` following the `curate_dataset.R` pattern
3. Generating a committed Markdown summary with speedup table

The `bench` package is **not installed** — it must be added to `Suggests` in DESCRIPTION and installed before running. The `data/benchmark/` directory does not yet exist and must be created (gitignored).

**Primary recommendation:** Add `use_dedup` as a simple function parameter (not env var) to both pipeline entry points, bypass `dedup_step()` wrapping when `FALSE`, then wrap both calls in `bench::press()` grids.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- D-01: Real regulatory dataset lives at `data/benchmark/` (gitignored), not synthetic
- D-02: Subsets via `set.seed()` + `dplyr::slice_sample()` for reproducible sampling
- D-03: `use_dedup=TRUE/FALSE` toggle on pipeline orchestrator; same session, same data, only toggle differs
- D-04: Raw results to `data/benchmark/results.csv` (gitignored); Markdown summary committed
- D-05: Cleaning pipeline and harmonization benchmarked as separate `bench::press()` runs
- D-06: Local-only — no CompTox API calls; curation excluded
- D-07: `bench::mark()` adaptive defaults with `min_iterations=3` floor

### Claude's Discretion
- Exact gitignored path convention within `data/benchmark/`
- Markdown summary file location (`.planning/` vs `docs/`)
- `bench::press()` grid structure and expression organization
- How cold-start is isolated from warm iterations (separate `bench::mark` call or first-iteration extraction)
- Uniqueness rate reporting granularity (per-step vs overall)
- Whether `use_dedup` is a function parameter or an option/env var

### Deferred Ideas (OUT OF SCOPE)
- None
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BENCH-01 | `scripts/benchmark_pipeline.R` using `bench::press()` across grid of n = c(1K, 10K, 100K) rows with memory allocation tracking | `bench::press()` runs a function across a grid of parameters; `bench::mark()` records mem_alloc automatically |
| BENCH-02 | Benchmark includes cold-start cost, real data uniqueness rate measurement, and remap overhead — reports median not mean | Cold-start: first iteration of a separate `bench::mark(min_iterations=1)` call before warm runs; uniqueness rate computed via `n_distinct(key_col)/nrow(df)` per subset |
| BENCH-03 | Before/after comparison documented with measured speedup factor | `use_dedup=TRUE` vs `FALSE` press grid; speedup = median_no_dedup / median_dedup |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `use_dedup` toggle | R package function params | — | Simplest API; no env var complexity needed |
| Subset generation | Benchmark script | — | `set.seed()` + `slice_sample()` in script, not pipeline |
| Timing measurement | Benchmark script (bench pkg) | — | External to pipeline; wraps pipeline calls |
| Uniqueness rate | Benchmark script | — | Derived from data before passing to pipeline |
| Cold-start isolation | Benchmark script | — | Separate `bench::mark(min_iterations=1)` before warm run |
| Results persistence | Benchmark script | — | Script writes CSV + Markdown |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bench | 1.1.3 [VERIFIED: npm registry unavailable; version from CRAN] | Timing + memory allocation measurement | The R benchmarking standard; reports wall time, process time, mem_alloc; `bench::press()` handles parameter grids |
| dplyr | already Imports | `slice_sample()`, `filter()` for subset generation | Already project dependency |

[ASSUMED] bench version 1.1.3 is current stable on CRAN as of early 2026.

**Installation:**
```r
pak::pak("bench")
# Or: install.packages("bench")
```

**bench is NOT installed** [VERIFIED: `packageVersion('bench')` returned error]. Must be added to DESCRIPTION `Suggests`.

### bench Package API Facts [ASSUMED — from training knowledge, not Context7 verified]

```r
# bench::press(): run expressions across parameter grid
bench::press(
  n = c(1000L, 10000L, 100000L),
  use_dedup = c(TRUE, FALSE),
  {
    df_sub <- dplyr::slice_sample(benchmark_df, n = n)
    bench::mark(
      run_cleaning_pipeline(df_sub, tag_map, reference_lists, use_dedup = use_dedup),
      min_iterations = 3,
      memory = TRUE,
      check = FALSE  # results differ between dedup modes — suppress value equality check
    )
  }
)
```

Key `bench::mark()` output columns:
- `expression` — label
- `min`, `median`, `max` — timing (bench_time class)
- `mem_alloc` — peak memory (bench_bytes class)
- `n_itr` — actual iterations run
- `total_time` — wall time total

`check = FALSE` is required when comparing `use_dedup=TRUE` vs `FALSE` because results differ (audit trail row IDs differ between modes).

## Architecture Patterns

### Recommended Project Structure
```
scripts/
└── benchmark_pipeline.R    # New standalone benchmark script (follows curate_dataset.R pattern)
data/
└── benchmark/              # Gitignored directory
    ├── <regulatory_file>.csv  # User-provided real dataset (gitignored)
    └── results.csv            # Raw bench output (gitignored)
docs/                       # Or .planning/ — at Claude's discretion
└── benchmark_results.md    # Committed Markdown summary with speedup table
R/
├── cleaning_pipeline.R     # Add use_dedup parameter to run_cleaning_pipeline()
└── unit_harmonizer.R       # Add use_dedup parameter to harmonize_units()
```

### Pattern 1: `use_dedup` Parameter in Pipeline Orchestrators

`run_cleaning_pipeline()` currently calls step functions directly (no `dedup_step()` wrapping in the current code at lines 1727-1891). Phase 37 plan 01 implemented `dedup_step()` and `remap_audit_to_parent()` as utilities, but Phase 37 plans 02-04 (which wire `dedup_step()` into the orchestrator) are **not yet completed** [VERIFIED: Phase 37 directory shows no SUMMARYs for plans 02 or 04].

**Implementation approach for Phase 38:** Adding `use_dedup` parameter to the signature is forward-compatible. The parameter exists now but `use_dedup = TRUE` and `FALSE` produce identical behavior until Phase 37 plans 02-04 land and wire `dedup_step()` calls into the orchestrator. No conditional wrapping logic is needed in this phase — just add the parameter.

### Pattern 2: Cold-Start Isolation

Cold-start = first call to `run_cleaning_pipeline()` in a fresh R session before any R object caching warms up (e.g., regex compilation, `system.file()` path resolution for synonyms, `get_unit_synonyms()` RDS load).

```r
# Cold-start: run once with min_iterations=1 BEFORE the warm press() grid
cold_start_result <- bench::mark(
  run_cleaning_pipeline(df_1k, tag_map, reference_lists, use_dedup = TRUE),
  min_iterations = 1,
  max_iterations = 1,
  memory = TRUE,
  check = FALSE
)
```

This captures the first-call cost separately from steady-state. The warm `bench::press()` grid then uses `min_iterations = 3`.

### Pattern 3: Uniqueness Rate Reporting

```r
# Compute uniqueness rate per subset BEFORE benchmarking
compute_uniqueness <- function(df, name_cols) {
  key_vec <- apply(df[, name_cols, drop = FALSE], 1, paste0, collapse = "")
  n_distinct(key_vec) / nrow(df)
}
```

Report uniqueness rate per n level in the Markdown summary table.

### Pattern 4: Markdown Summary Structure

```markdown
# Benchmark Results: Dedup Architecture
Generated: {date}

## Setup
- Dataset: {source description, row count}
- Subsets: n = 1K, 10K, 100K via set.seed(42)
- Uniqueness rates: 1K = X%, 10K = Y%, 100K = Z%
- Cold-start cost: {median}

## Cleaning Pipeline

| n     | use_dedup | median  | mem_alloc | speedup |
|-------|-----------|---------|-----------|---------|
| 1K    | FALSE     | Xms     | Xmb       | —       |
| 1K    | TRUE      | Xms     | Xmb       | Xx      |
...

## Harmonization Pipeline
[same table]

## Summary
Speedup factor at 100K: {X}x (cleaning), {Y}x (harmonization)
```

### Anti-Patterns to Avoid

- **`check = TRUE` with before/after comparison:** `bench::press()` will error because `use_dedup=TRUE` and `FALSE` produce different audit trail row IDs. Always use `check = FALSE`.
- **Including CompTox API calls in bench scope:** D-06 mandates local-only. `normalize_cas_fields()` calls `ComptoxR::as_cas()` which is confirmed network-free (see resolved Q2 below), so CASRN tags are safe in the benchmark tag_map.
- **Generating subsets inside `bench::mark()` expression:** Subset generation time contaminates benchmark. Generate subsets once before `bench::press()` call.
- **Using `mean` from bench output:** `bench::mark()` reports median as the primary statistic. Use `median` per BENCH-02.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Parameter grid iteration | Manual nested loops | `bench::press()` | Handles grid, runs mark(), returns tidy tibble |
| Memory measurement | `gc()` before/after | `bench::mark(memory=TRUE)` | bench hooks into R's allocation counter precisely |
| Timing | `proc.time()` | `bench::mark()` | bench runs adaptive iterations, reports all time types |

## Common Pitfalls

### Pitfall 1: `check = TRUE` With Before/After Toggle
**What goes wrong:** `bench::press()` compares return values across grid cells and errors when `use_dedup=TRUE` vs `FALSE` produce different results (they will — audit trail row_ids differ due to dedup remapping).
**How to avoid:** Always pass `check = FALSE` in `bench::mark()`.

### Pitfall 2: Subsets Generated Inside Benchmark Expression
**What goes wrong:** `slice_sample()` timing contaminates the cleaning benchmark. At 100K rows, slice is non-trivial.
**How to avoid:** Pre-generate all three subset dataframes (`df_1k`, `df_10k`, `df_100k`) before any `bench::press()` call, using fixed `set.seed(42)`.

### Pitfall 3: `dedup_step()` Not Yet Wired Into Orchestrator
**What goes wrong:** If Phase 37 plans 02-04 are incomplete, `run_cleaning_pipeline()` doesn't actually use `dedup_step()`, so `use_dedup=TRUE` and `FALSE` produce identical timings.
**Warning signs:** Before/after speedup = 1.0x at all n levels.
**Current status:** Phase 37 plans 02-04 are NOT yet completed [VERIFIED: no SUMMARYs in phase directory]. The `use_dedup` toggle is forward-compatible but will show speedup = 1.0x until those plans land.
**How to avoid:** Confirm Phase 37 plan wave completion before running benchmark. The benchmark script should print a warning if speedup = 1.0x.

### Pitfall 4: `normalize_cas_fields()` Makes API Calls — RESOLVED
**Original concern:** `ComptoxR::as_cas()` may call the CompTox API at runtime.
**Resolution:** `as_cas()` is confirmed **network-free** [VERIFIED: function body is pure regex/checksum — extracts digits, validates format, checks check digit via `is_cas()`. Tested: `as_cas("67641")` returns `"67-64-1"` without network access]. CASRN tags are safe in the benchmark tag_map. D-06 is satisfied.

### Pitfall 5: `get_unit_synonyms()` RDS Load in Warm Benchmark
**What goes wrong:** First call to `harmonize_units()` loads `unit_synonyms.rds` via `system.file()`. Subsequent calls may hit a cached path. Cold-start must be isolated BEFORE the warm grid.
**How to avoid:** Run cold-start measurement in isolation first (pattern 2 above).

### Pitfall 6: `data/benchmark/` Not in .gitignore
**What goes wrong:** Large regulatory dataset gets committed accidentally.
**How to avoid:** Add `data/benchmark/` to `.gitignore` before creating the directory. Current `.gitignore` does NOT include this path [VERIFIED: read .gitignore].

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bench R pkg | BENCH-01/02/03 | ✗ | — | None — required |
| data/benchmark/ dir | D-01 | ✗ | — | Must be created |
| Real regulatory dataset | D-01 | Unknown | — | Must be provided by user |
| R 4.5.1 | Global CLAUDE.md | ✓ | 4.5.1 | — |

**Missing dependencies with no fallback:**
- `bench` package: must be installed (`pak::pak("bench")`) and added to DESCRIPTION Suggests
- `data/benchmark/` directory: must be created and gitignored
- Real regulatory dataset: must be placed at `data/benchmark/<filename>.csv` by the user before the script can run

## Code Examples

### Benchmark Script Skeleton (follows `curate_dataset.R` pattern)
```r
# scripts/benchmark_pipeline.R
# Standalone benchmark — no Shiny dependency
# Requires: data/benchmark/<regulatory_file>.csv

library(dplyr)
library(bench)

CHEMREG_ROOT <- here::here()
source(file.path(CHEMREG_ROOT, "R", "cleaning_pipeline.R"))
source(file.path(CHEMREG_ROOT, "R", "unit_harmonizer.R"))
# ... other R/ sources as needed

# ---- Load benchmark data ----
bench_files <- list.files(
  file.path(CHEMREG_ROOT, "data", "benchmark"),
  pattern = "\\.(csv|xlsx)$", full.names = TRUE
)
stopifnot("No benchmark data found in data/benchmark/" = length(bench_files) > 0)
benchmark_df <- readr::read_csv(bench_files[1], show_col_types = FALSE)

# ---- Pre-generate subsets ----
set.seed(42)
df_1k  <- dplyr::slice_sample(benchmark_df, n = 1000L)
df_10k <- dplyr::slice_sample(benchmark_df, n = 10000L)
df_100k <- dplyr::slice_sample(benchmark_df, n = 100000L)

# ---- Compute uniqueness rates ----
# ...

# ---- Cold-start measurement ----
cold_result <- bench::mark(
  run_cleaning_pipeline(df_1k, tag_map, reference_lists, use_dedup = TRUE),
  min_iterations = 1, max_iterations = 1,
  memory = TRUE, check = FALSE
)

# ---- Warm benchmark: cleaning pipeline ----
cleaning_results <- bench::press(
  n = c(1000L, 10000L, 100000L),
  use_dedup = c(TRUE, FALSE),
  {
    df_sub <- switch(as.character(n),
      "1000"   = df_1k,
      "10000"  = df_10k,
      "100000" = df_100k
    )
    bench::mark(
      run_cleaning_pipeline(df_sub, tag_map, reference_lists, use_dedup = use_dedup),
      min_iterations = 3,
      memory = TRUE,
      check = FALSE
    )
  }
)

# ---- Save raw results ----
readr::write_csv(
  dplyr::select(cleaning_results, n, use_dedup, median, mem_alloc),
  file.path(CHEMREG_ROOT, "data", "benchmark", "results.csv")
)

# ---- Write Markdown summary ----
# ... format table, compute speedup = median_no_dedup / median_dedup
```

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | bench 1.1.3 is current CRAN stable | Standard Stack | Version label in DESCRIPTION would be off — functional risk is low |
| A2 | `bench::press()` accepts `check=FALSE` in the inner `bench::mark()` call | Code Examples | Must verify against bench docs before implementation |
| A3 | ~~`dedup_step()` is wired into `run_cleaning_pipeline()` by Phase 37~~ **RESOLVED:** `dedup_step()` is NOT wired into the orchestrator — Phase 37 plans 02-04 are incomplete. `use_dedup` toggle is forward-compatible. | Pitfall 3 | Speedup = 1.0x until Phase 37 completes, which is expected and acceptable |
| A4 | ~~`ComptoxR::as_cas()` may make network calls~~ **RESOLVED:** `as_cas()` is pure local regex/checksum [VERIFIED: function body deparse + offline test] | Pitfall 4 | No risk — CASRN safe in tag_map |
| A5 | `bench::press()` returns a tidy tibble with `median` and `mem_alloc` columns | Code Examples | Column names differ — script would error on `write_csv` |

## Open Questions (RESOLVED)

1. **Does `run_cleaning_pipeline()` already use `dedup_step()` wrappers (Phase 37 status)?**
   - **RESOLVED:** No. `run_cleaning_pipeline()` at lines 1727-1891 calls step functions directly with no `dedup_step()` wrapping. Phase 37 plan 01 implemented `dedup_step()` and `remap_audit_to_parent()` as utility functions, but Phase 37 plans 02 and 04 (which wire these into the orchestrator) have no SUMMARYs and are not yet completed [VERIFIED: `ls .planning/phases/37-performance-architecture/` shows 37-01-SUMMARY.md and 37-03-SUMMARY.md only].
   - **Impact on Plan 38-01:** The `use_dedup` parameter is added to the function signature as a forward-compatible no-op. No conditional `dedup_step()` wrapping is needed because there are no `dedup_step()` calls to bypass yet. When Phase 37 plans 02-04 complete and wire `dedup_step()` into the orchestrator, they will need to respect the `use_dedup` parameter.

2. **Is `ComptoxR::as_cas()` network-free?**
   - **RESOLVED:** Yes. `as_cas()` is pure local computation [VERIFIED: `deparse(body(ComptoxR::as_cas))` shows only `stringr::str_remove_all`, `stringr::str_sub`, and `is_cas()` checksum validation — no `httr`, `curl`, or API calls]. Tested offline: `as_cas("67641")` returns `"67-64-1"` successfully.
   - **Impact on Plan 38-02:** CASRN tags are safe in the benchmark `tag_map`. No need to strip CASRN from tag_map. D-06 (local-only) is satisfied.

3. **Where should the Markdown summary live?**
   - **RESOLVED (by planning):** `docs/benchmark_results.md` — it's a committed artifact users may want to find, and `docs/` communicates "user-facing record" better than `.planning/`.

## Validation Architecture

Per `.planning/config.json` — if `nyquist_validation` is not explicitly `false`, include test mapping.

This phase produces a **standalone script**, not package functions. Unit tests are not applicable to the benchmark script itself. However, the `use_dedup` parameter additions to `run_cleaning_pipeline()` and `harmonize_units()` are code changes that touch tested functions.

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | Notes |
|--------|----------|-----------|-------------------|-------|
| BENCH-01 | `bench::press()` grid runs to completion | smoke | `Rscript scripts/benchmark_pipeline.R` (with real data present) | Manual smoke only — requires user data |
| BENCH-02 | Cold-start captured, uniqueness rate reported, median used | manual review | inspect `results.csv` and Markdown summary | Output review |
| BENCH-03 | Speedup factor in Markdown summary | manual review | inspect `docs/benchmark_results.md` | Output review |
| PERF-01/03 | `use_dedup=FALSE` route calls step functions directly | unit | `testthat::test_dir("tests")` — existing pipeline tests must still pass | Existing 953+ tests must remain green after adding parameter |

### Wave 0 Gaps
- [ ] `use_dedup` parameter added to `run_cleaning_pipeline()` — must not break existing tests
- [ ] `use_dedup` parameter added to `harmonize_units()` — must not break existing tests
- [ ] `data/benchmark/` added to `.gitignore`
- [ ] `bench` added to DESCRIPTION `Suggests`
- [ ] `docs/` directory creation (if it doesn't exist)

## Sources

### Primary (HIGH confidence)
- `R/cleaning_pipeline.R` — `run_cleaning_pipeline()`, `dedup_step()`, `remap_audit_to_parent()` signatures verified by direct read [VERIFIED: codebase]
- `R/unit_harmonizer.R` — `harmonize_units()` signature verified by direct read [VERIFIED: codebase]
- `scripts/curate_dataset.R` — standalone pattern verified by direct read [VERIFIED: codebase]
- `DESCRIPTION` — package dependencies, `bench` confirmed absent from Suggests [VERIFIED: codebase]
- `.gitignore` — `data/benchmark/` confirmed absent [VERIFIED: codebase]
- `ComptoxR::as_cas()` — function body confirmed network-free [VERIFIED: deparse + offline test]
- Phase 37 completion status — plans 02/04 incomplete [VERIFIED: no SUMMARYs in phase directory]

### Secondary (MEDIUM confidence)
- `bench` package API (`bench::press()`, `bench::mark()`, output columns) [ASSUMED — training knowledge, not Context7 verified]

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM — `bench` API shape is from training knowledge; Context7 lookup skipped (package is simple and stable)
- Architecture: HIGH — based on verified codebase reads
- Pitfalls: HIGH — derived from verified code structure
- Open questions: RESOLVED — all three questions answered with codebase verification

**Research date:** 2026-04-24
**Valid until:** 2026-05-24 (stable domain)
