# Phase 38: Benchmark Harness - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-24
**Phase:** 38-benchmark-harness
**Areas discussed:** Test data strategy, Before/after capture, Output & documentation, Pipeline scope, Subset strategy, Iteration & warmup config

---

## Test Data Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Synthetic generator | Script builds 100K-row dataset by sampling from realistic patterns. Reproducible, no data sharing concerns. | |
| Real dataset you provide | Use an actual regulatory/benchmark file. Most realistic uniqueness rates. | ✓ |
| Published dataset download | Download a public chemical dataset (e.g., EPA TRI, ECOTOX) at runtime. | |

**User's choice:** Real dataset you provide
**Notes:** None

### Follow-up: Data Path

| Option | Description | Selected |
|--------|-------------|----------|
| CLI argument path | Script takes file path as command-line argument. | |
| Fixed path, gitignored | Script looks for data/benchmark/ convention. Gitignored so real data stays local. | ✓ |
| Fixed path, committed | Commit 100K-row file to repo. Always available but adds bulk. | |

**User's choice:** Fixed path, gitignored
**Notes:** None

---

## Before/After Capture

| Option | Description | Selected |
|--------|-------------|----------|
| Dedup toggle flag | Add use_dedup=TRUE/FALSE parameter. Benchmark runs both modes in same session. | ✓ |
| Git checkout comparison | Check out pre-Phase-37 commit, run timing, switch back. | |
| Separate baseline script | Run baseline before Phase 37, commit results, compare later. | |

**User's choice:** Dedup toggle flag
**Notes:** None

---

## Output & Documentation

| Option | Description | Selected |
|--------|-------------|----------|
| CSV + Markdown summary | Raw CSV gitignored, Markdown with speedup table committed. | ✓ |
| Console-only with commit narrative | Print to console, manually copy numbers. | |
| Full rendered report | R Markdown/Quarto with charts and tables. Adds dependency. | |

**User's choice:** CSV + Markdown summary
**Notes:** None

---

## Pipeline Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Cleaning + harmonization separately | Separate bench::press() runs. Shows where speedup comes from. | ✓ |
| Cleaning pipeline only | Focus on run_cleaning_pipeline() only. | |
| Full curate_headless() end-to-end | Complete pipeline as one unit. | |

**User's choice:** Cleaning + harmonization separately
**Notes:** None

### Follow-up: API Calls

| Option | Description | Selected |
|--------|-------------|----------|
| Local-only | No CompTox API calls. Eliminates network variance. | ✓ |
| Include curation | Add third segment for curation with API. | |

**User's choice:** Local-only
**Notes:** None

---

## Subset Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Random sample | set.seed() + slice_sample(). Reproducible, preserves uniqueness distribution. | ✓ |
| First-N rows | head(df, N). Simplest but may over-represent one data region. | |
| Stratified sample | Sample proportionally from distinct value groups. Most representative but complex. | |

**User's choice:** Random sample
**Notes:** None

---

## Iteration & Warmup Config

| Option | Description | Selected |
|--------|-------------|----------|
| bench defaults + min_iterations=3 | Adaptive timing, 3-run floor, cold-start as first iteration. | ✓ |
| Fixed 5 iterations, no warmup | Exactly 5 iterations per level. Consistent but slow. | |
| You decide | Let Claude pick based on bench::press() best practices. | |

**User's choice:** bench defaults + min_iterations=3
**Notes:** None

---

## Claude's Discretion

- Exact gitignored path convention within data/benchmark/
- Markdown summary file location
- bench::press() grid structure
- Cold-start isolation method
- Uniqueness rate reporting granularity
- use_dedup parameter implementation style

## Deferred Ideas

None — discussion stayed within phase scope
