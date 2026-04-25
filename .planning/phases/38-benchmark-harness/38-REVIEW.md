---
phase: 38-benchmark-harness
reviewed: 2026-04-24T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - R/cleaning_pipeline.R
  - R/unit_harmonizer.R
  - scripts/benchmark_pipeline.R
  - docs/benchmark_results.md
  - DESCRIPTION
  - .gitignore
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
status: issues_found
---

# Phase 38: Code Review Report

**Reviewed:** 2026-04-24T00:00:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Phase 38 introduced the benchmark harness (`scripts/benchmark_pipeline.R`), added `use_dedup` as a forward-compatible no-op parameter to `run_cleaning_pipeline()` and `harmonize_units()`, added `bench` to DESCRIPTION Suggests, and added `data/benchmark/` to `.gitignore`. The `use_dedup` no-op is intentional pending Phase 37 plans 02-04 and is excluded from findings per review instructions.

The benchmark script is methodologically sound: `set.seed(42)` ensures reproducible subsets, cold-start is isolated from the warm grid, `bench::press()` crosses the full n × dedup grid, and raw data is correctly gitignored. Two warnings were found — a media string mismatch causing a silent wrong-path execution in the harmonization benchmark, and an unguarded `readxl` call inconsistent with the explicit package checks for `dplyr`, `bench`, and `readr`. Two info items flag a placeholder-as-committed-result concern and a minor documentation gap.

## Warnings

### WR-01: `"soil"` passed to `harmonize_units()` but the API only recognises `"solid"`

**File:** `scripts/benchmark_pipeline.R:235`

**Issue:** The harmonization benchmark samples test media from `c("aqueous", "soil", "air")`. The `get_media_target()` function in `R/unit_harmonizer.R:199` uses a `switch()` that only matches `"aqueous"`, `"air"`, and `"solid"`. Any benchmark row with `media = "soil"` falls through to the default `"mg/L"` fallback instead of routing to `"mg/kg"`, and those rows also receive `unit_flag = "media_inferred"` (the no-media-context path) rather than `unit_flag = ""` (the clean conversion path). The benchmark will not crash, but roughly one-third of ppb/ppm rows silently exercise the wrong branch, meaning the harmonization timing results do not accurately represent the production use-case. This also means the benchmark cannot faithfully compare `use_dedup = TRUE` vs `use_dedup = FALSE` for the solid-media ppb/ppm path once Phase 37 wires the dedup step in.

**Fix:**
```r
# scripts/benchmark_pipeline.R line 235
# Change:
test_media <- sample(c("aqueous", "soil", "air"), n, replace = TRUE)
# To:
test_media <- sample(c("aqueous", "solid", "air"), n, replace = TRUE)
```

---

### WR-02: `readxl::read_xlsx()` called without a `requireNamespace()` guard in standalone context

**File:** `scripts/benchmark_pipeline.R:51`

**Issue:** The script is explicitly documented as a standalone file sourced outside the package. In that context DESCRIPTION Imports are not enforced — only `dplyr`, `bench`, and `readr` are loaded via `library()` at lines 18-20. If someone places an XLSX file in `data/benchmark/` and `readxl` is not installed, R emits an obscure `Error in loadNamespace("readxl")` at line 51, not a diagnostic `stopifnot()` message consistent with the other package checks at lines 28-32. Given that `readxl` is in DESCRIPTION Imports it will always be present in a properly installed package environment, but standalone sourcing does not guarantee that.

**Fix:** Add a `readxl` guard consistent with the existing style, either unconditionally at startup or conditionally at the point of use:

```r
# Option A: add to the stopifnot() block at lines 28-32
stopifnot(
  "bench package is required -- run: pak::pak('bench')" = requireNamespace("bench", quietly = TRUE),
  "dplyr package is required" = requireNamespace("dplyr", quietly = TRUE),
  "readr package is required" = requireNamespace("readr", quietly = TRUE),
  "readxl package is required for XLSX input -- run: pak::pak('readxl')" = requireNamespace("readxl", quietly = TRUE)
)

# Option B: guard only when an XLSX file is actually detected
if (file_ext == "xlsx") {
  stopifnot(
    "readxl required for XLSX input -- run: pak::pak('readxl')" =
      requireNamespace("readxl", quietly = TRUE)
  )
}
```

---

## Info

### IN-01: `docs/benchmark_results.md` committed as a placeholder is potentially misleading

**File:** `docs/benchmark_results.md`

**Issue:** `docs/benchmark_results.md` is committed to source control with `[auto-populated]` placeholder text in every data field. The script at line 451 overwrites this file with real numbers each time a benchmark is run. Committing the placeholder under a path that reads as a results artifact means a future reviewer reading the git log could interpret the presence of the file as evidence that a real benchmark was executed. This is low risk now (while Phase 37 is pending and no benchmark can yet produce meaningful dedup speedup numbers), but it will become misleading once real results are expected.

**Fix (two options):** Add a prominent status note at the top of the placeholder file, or move the file to `.gitignore` until real results exist:

```markdown
<!-- Status: PLACEHOLDER — benchmark has not yet been run with real data.
     Run source("scripts/benchmark_pipeline.R") with a >= 100K row dataset
     to populate real values. -->
```

---

### IN-02: `tidyr` is used via `::` but not mentioned in the prerequisites comment

**File:** `scripts/benchmark_pipeline.R:294`

**Issue:** `tidyr::pivot_wider()` is called at line 294 inside `compute_speedup()`. The top-of-file prerequisites comment (lines 4-12) and the `stopifnot()` guards (lines 28-32) say nothing about `tidyr`. The `::` operator handles the namespace lookup without `library(tidyr)`, and `tidyr` is in DESCRIPTION Imports so it will always be installed alongside the package. However, someone following the standalone prerequisites comment to set up a bare R environment would not know to install `tidyr`, and there is no runtime error until the script reaches line 294 (after the 5-15 minute benchmarks at sections 6 and 7 have already run).

**Fix:** Add `tidyr` to the prerequisites comment:

```r
# Prerequisites:
#   1. Place a regulatory CSV or XLSX file in data/benchmark/
#   2. Install required packages: pak::pak(c("bench", "dplyr", "readr", "tidyr"))
#   3. Source this file: source("scripts/benchmark_pipeline.R")
```

---

_Reviewed: 2026-04-24T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
