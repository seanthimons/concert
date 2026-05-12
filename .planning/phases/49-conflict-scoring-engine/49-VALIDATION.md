---
phase: 49
slug: conflict-scoring-engine
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-08
---

# Phase 49 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | `tests/testthat.R` or `testthat::test_dir("tests")` |
| **Quick run command** | `Rscript -e "testthat::test_dir('tests')"` |
| **Full suite command** | `Rscript -e "testthat::test_dir('tests')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `Rscript -e "testthat::test_dir('tests')"`
- **After every plan wave:** Run `Rscript -e "testthat::test_dir('tests')"`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 49-01-01 | 01 | 0 | SCORE-01 | — | N/A | prototype | `Rscript scripts/test_scoring.R` | ❌ W0 | ⬜ pending |
| 49-02-01 | 02 | 1 | SCORE-02 | — | N/A | unit | `Rscript -e "testthat::test_dir('tests')"` | ❌ W0 | ⬜ pending |
| 49-03-01 | 03 | 2 | SCORE-01 | — | N/A | integration | Shiny smoke test | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test_similarity_scoring.R` — stubs for SCORE-01, SCORE-02
- [ ] Prototype script `scripts/test_scoring.R` — validates formula against known disagree row

*Existing infrastructure covers test framework — no new framework install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Sim. Score column visible in Review Results table | SCORE-01 | UI rendering requires browser | Start app, upload test file, run curation, check disagree rows show score |
| Per-candidate scores in comparison modal | SCORE-01 | Modal interaction requires browser | Click disagree row, verify each candidate shows individual score |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
