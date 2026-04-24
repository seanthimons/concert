# Benchmark Results: ChemReg Pipeline

_Generated: [Run `source("scripts/benchmark_pipeline.R")` with real data to populate]_
_R version: [auto-populated] | bench version: [auto-populated]_

## Dataset

- **File:** `[regulatory CSV/XLSX placed in data/benchmark/]`
- **Total rows:** [auto-populated]
- **Columns:** [auto-populated]

## Subset Uniqueness Rates

| Subset | Rows | Uniqueness |
|--------|------|------------|
| 1K | 1,000 | [auto-populated] |
| 10K | 10,000 | [auto-populated] |
| 100K | 100,000 | [auto-populated] |

## Cold-Start Cost

First run (1K rows, use_dedup = TRUE): **[auto-populated]** | memory: **[auto-populated]**

_Cold-start includes initial compilation and cache initialization costs._

## Cleaning Pipeline

| Rows | Dedup | Median Time | Memory | Iterations |
|------|-------|-------------|--------|------------|
| 1,000 | Yes | [auto] | [auto] | [auto] |
| 1,000 | No | [auto] | [auto] | [auto] |
| 10,000 | Yes | [auto] | [auto] | [auto] |
| 10,000 | No | [auto] | [auto] | [auto] |
| 100,000 | Yes | [auto] | [auto] | [auto] |
| 100,000 | No | [auto] | [auto] | [auto] |

## Harmonization Pipeline

| Rows | Dedup | Median Time | Memory | Iterations |
|------|-------|-------------|--------|------------|
| 1,000 | Yes | [auto] | [auto] | [auto] |
| 1,000 | No | [auto] | [auto] | [auto] |
| 10,000 | Yes | [auto] | [auto] | [auto] |
| 10,000 | No | [auto] | [auto] | [auto] |
| 100,000 | Yes | [auto] | [auto] | [auto] |
| 100,000 | No | [auto] | [auto] | [auto] |

## Speedup Summary

_Speedup = median(no_dedup) / median(dedup). Values > 1.0x mean dedup is faster._

| Pipeline | Rows | Speedup |
|----------|------|---------|
| cleaning | 1,000 | [auto] |
| cleaning | 10,000 | [auto] |
| cleaning | 100,000 | [auto] |
| harmonization | 1,000 | [auto] |
| harmonization | 10,000 | [auto] |
| harmonization | 100,000 | [auto] |

_Cleaning pipeline achieves **[auto]x** speedup at 100K rows with dedup enabled._

## Methodology

- Subsets generated with `set.seed(42)` + `dplyr::slice_sample()` for reproducibility
- Cold-start measured separately (`min_iterations = 1, max_iterations = 1`)
- Warm benchmark uses `bench::press()` with `min_iterations = 3` adaptive defaults
- `use_dedup = TRUE/FALSE` toggle compares same data in same R session (D-03)
- No CompTox API calls -- cleaning and harmonization only (D-06)
- Raw timing data in `data/benchmark/results.csv` (gitignored)

---

_To regenerate: place a regulatory CSV/XLSX with >= 100K rows in `data/benchmark/`, then run `source("scripts/benchmark_pipeline.R")` from the chemreg project root._
