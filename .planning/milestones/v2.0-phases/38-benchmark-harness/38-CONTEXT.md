# Phase 38: Benchmark Harness - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning

<domain>
## Phase Boundary

A standalone benchmark script (`scripts/benchmark_pipeline.R`) that measures and documents the performance improvement from Phase 37's dedup architecture. Proves the dedup pattern delivers measurable speedup at 1K, 10K, and 100K rows with before/after comparison. No new pipeline features, no UI changes, no new cleaning steps.

</domain>

<decisions>
## Implementation Decisions

### Test Data Strategy
- **D-01:** Benchmark uses a real regulatory dataset provided by the user, NOT synthetic data. The dataset lives at a fixed gitignored path (e.g., `data/benchmark/`) so the script can find it without CLI arguments.
- **D-02:** 1K and 10K subsets are derived via `set.seed()` + `dplyr::slice_sample()` for reproducible random samples that preserve realistic uniqueness distribution.

### Before/After Comparison
- **D-03:** A `use_dedup=TRUE/FALSE` toggle parameter is added to the pipeline orchestrator (`run_cleaning_pipeline()` and `harmonize_units()`). The benchmark runs both modes in the same session for apples-to-apples comparison — same data, same R session, only dedup on/off differs.

### Output Format
- **D-04:** Raw timing data saved to `data/benchmark/results.csv` (gitignored alongside the input data). A human-readable Markdown summary with the speedup table is committed to the repository (location at Claude's discretion — `.planning/` or `docs/`).

### Pipeline Scope
- **D-05:** Cleaning pipeline and harmonization are benchmarked as separate `bench::press()` runs. Each dedup architecture gets measured independently so the speedup contribution is clear.
- **D-06:** Benchmark is local-only — no CompTox API calls. Curation is excluded. Eliminates network variance from timing measurements.

### Iteration Config
- **D-07:** Use `bench::mark()` adaptive timing defaults with `min_iterations=3` floor to ensure at least 3 runs even at 100K. Cold-start cost measured as the first iteration before any warm runs.

### Claude's Discretion
- Exact gitignored path convention within `data/benchmark/`
- Markdown summary file location (`.planning/` vs `docs/`)
- `bench::press()` grid structure and expression organization
- How cold-start is isolated from warm iterations (separate bench::mark call or first-iteration extraction)
- Uniqueness rate reporting granularity (per-step vs overall)
- Whether `use_dedup` is a function parameter or an option/env var

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` -- BENCH-01, BENCH-02, BENCH-03 requirements (benchmark grid, cold-start/uniqueness/median, before/after speedup)

### Roadmap
- `.planning/ROADMAP.md` -- Phase 38 success criteria (3 criteria)

### Phase 37 Context (Dedup Architecture)
- `.planning/phases/37-performance-architecture/37-CONTEXT.md` -- Dedup decisions D-01 through D-13 that define the architecture being benchmarked

### Pipeline Code to Benchmark
- `R/cleaning_pipeline.R` -- `run_cleaning_pipeline()` orchestrator with `dedup_step()` wrapper and pre-check predicates
- `R/unit_harmonizer.R` -- `harmonize_units()` with unit-key dedup pattern

### Existing Scripts
- `scripts/curate_dataset.R` -- Existing standalone pipeline runner pattern (no Shiny dependency) — similar structure to what the benchmark script will follow

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/curate_dataset.R`: Standalone pipeline runner that sources R/ files directly — benchmark script follows similar pattern
- `dedup_step()` and `remap_audit_to_parent()` already implemented in `R/cleaning_pipeline.R` — benchmark exercises these directly
- `data/` directory already has sample CSV files — `data/benchmark/` extends this convention

### Established Patterns
- Pipeline functions return `list(cleaned_data, audit_trail)` — benchmark wraps these calls in `bench::mark()`
- `bench` package is not yet a dependency — will be added to Suggests in DESCRIPTION
- Tag-dependent steps receive `tag_map` — benchmark needs a realistic tag_map matching the test data

### Integration Points
- `run_cleaning_pipeline()` is the single entry point for cleaning — benchmark wraps this
- `harmonize_units()` is the single entry point for unit harmonization — benchmark wraps this separately
- The `use_dedup` toggle introduced here becomes a permanent API parameter (useful for debugging/testing beyond benchmarks)

</code_context>

<specifics>
## Specific Ideas

- User wants the benchmark to use their own real regulatory data, not synthetic — the uniqueness rates and data patterns will be authentic
- The `use_dedup` toggle approach was chosen specifically for clean before/after comparison in the same R session — no git checkout gymnastics needed
- `bench` adaptive defaults with `min_iterations=3` keeps runtime reasonable at 100K while ensuring statistical validity

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 38-benchmark-harness*
*Context gathered: 2026-04-24*
