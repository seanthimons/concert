# Benchmark Results: CONCERT Pipeline

_Generated: 2026-04-26 02:12 UTC_
_R version: 4.5.1 | bench version: 1.1.4_

## Dataset

- **File:** `detections.csv`
- **Total rows:** 127,992
- **Columns:** 19

## Subset Uniqueness Rates

| Subset | Rows | Uniqueness |
|--------|------|------------|
| 1K | 1,000 | 7.4% |
| 10K | 10,000 | 0.7% |
| 100K | 100,000 | 0.1% |

## Cold-Start Cost

First run (1K rows, use_dedup = TRUE): **304ms** | memory: **9.46MB**

_Cold-start includes initial compilation and cache initialization costs._

## Cleaning Pipeline

| Rows | Dedup | Median Time | Memory | Iterations |
|------|-------|-------------|--------|------------|
| 1,000 | Yes | 0.294s | 3.5MB | 2 |
| 1,000 | No | 0.351s | 6.7MB | 1 |
| 10,000 | Yes | 1.184s | 27.0MB | 3 |
| 10,000 | No | 1.755s | 61.8MB | 3 |
| 100,000 | Yes | 10.253s | 252.7MB | 3 |
| 100,000 | No | 16.094s | 605.9MB | 3 |

## Harmonization Pipeline

| Rows | Dedup | Median Time | Memory | Iterations |
|------|-------|-------------|--------|------------|
| 1,000 | Yes | 0.005s | 2.6MB | 102 |
| 1,000 | No | 0.006s | 0.4MB | 84 |
| 10,000 | Yes | 0.020s | 4.1MB | 26 |
| 10,000 | No | 0.030s | 4.3MB | 15 |
| 100,000 | Yes | 0.155s | 39.9MB | 3 |
| 100,000 | No | 0.259s | 42.2MB | 2 |

## Speedup Summary

_Speedup = median(no_dedup) / median(dedup). Values > 1.0x mean dedup is faster._

| Pipeline | Rows | Speedup |
|----------|------|---------|
| cleaning |   1,000 | 1.20x |
| cleaning |  10,000 | 1.48x |
| cleaning | 100,000 | 1.57x |
| harmonization |   1,000 | 1.26x |
| harmonization |  10,000 | 1.53x |
| harmonization | 100,000 | 1.68x |

_Cleaning pipeline achieves **1.6x** speedup at 100K rows with dedup enabled._

## Methodology

- Subsets generated with `set.seed(42)` + `dplyr::slice_sample()` for reproducibility
- Cold-start measured separately (`min_iterations = 1, max_iterations = 1`)
- Warm benchmark uses `bench::press()` with `min_iterations = 3` adaptive defaults
- `use_dedup = TRUE/FALSE` toggle compares same data in same R session (D-03)
- No CompTox API calls -- cleaning and harmonization only (D-06)
- Raw timing data in `data/benchmark/results.csv` (gitignored)

