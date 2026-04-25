---
phase: 38
slug: benchmark-harness
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-24
---

# Phase 38 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | `tests/testthat.R` or `testthat::test_dir("tests")` |
| **Quick run command** | `Rscript -e "testthat::test_dir('tests')"` |
| **Full suite command** | `Rscript -e "testthat::test_dir('tests')"` |
| **Estimated runtime** | ~30 seconds (excluding benchmark execution) |

---

## Sampling Rate

- **After every task commit:** Run `Rscript -e "testthat::test_dir('tests')"`
- **After every plan wave:** Run `Rscript -e "testthat::test_dir('tests')"`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 38-01-01 | 01 | 1 | BENCH-01 | — | N/A | integration | `Rscript scripts/benchmark_pipeline.R` | ❌ W0 | ⬜ pending |
| 38-01-02 | 01 | 1 | BENCH-02 | — | N/A | integration | `Rscript scripts/benchmark_pipeline.R` | ❌ W0 | ⬜ pending |
| 38-01-03 | 01 | 1 | BENCH-03 | — | N/A | integration | `Rscript scripts/benchmark_pipeline.R` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `bench` package added to Suggests in DESCRIPTION
- [ ] `data/benchmark/` directory created and added to `.gitignore`
- [ ] `scripts/benchmark_pipeline.R` stub created

*Benchmark is validated by running the script end-to-end — unit tests verify pipeline functions, benchmark script validates performance claims.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Speedup factor > 1.0x | BENCH-03 | Depends on real data and hardware | Run benchmark, inspect results table for speedup > 1.0 |
| Memory allocation reported | BENCH-01 | `bench::mark()` output must include `mem_alloc` column | Run benchmark, verify `mem_alloc` column in results.csv |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
