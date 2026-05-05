---
phase: 44
slug: matching-engine-prototype
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-05
---

# Phase 44 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat >= 3.0.0 |
| **Config file** | none — run via `testthat::test_dir("tests")` |
| **Quick run command** | `testthat::test_file("tests/test_wqx_matching.R")` |
| **Full suite command** | `testthat::test_dir("tests")` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `testthat::test_file("tests/test_wqx_matching.R")`
- **After every plan wave:** Run `testthat::test_dir("tests")`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 44-01-01 | 01 | 1 | MATCH-01 | — | N/A | unit | `testthat::test_file("tests/test_wqx_matching.R")` | ❌ W0 | ⬜ pending |
| 44-01-02 | 01 | 1 | MATCH-02 | — | N/A | unit | `testthat::test_file("tests/test_wqx_matching.R")` | ❌ W0 | ⬜ pending |
| 44-01-03 | 01 | 1 | MATCH-03 | — | N/A | unit | `testthat::test_file("tests/test_wqx_matching.R")` | ❌ W0 | ⬜ pending |
| 44-01-04 | 01 | 1 | MATCH-04 | — | N/A | unit | `testthat::test_file("tests/test_wqx_matching.R")` | ❌ W0 | ⬜ pending |
| 44-02-01 | 02 | 1 | INTG-01 | — | N/A | smoke | `source("scripts/prototype_wqx_matching.R")` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test_wqx_matching.R` — stubs for MATCH-01 through MATCH-04
- [ ] `scripts/prototype_wqx_matching.R` — covers INTG-01

*Existing infrastructure covers test framework — no additional setup needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Fuzzy match distance values make sense for chemical names | MATCH-03 | Requires human review of nearest-candidate quality | Review prototype output: fuzzy matches should show chemically plausible candidates |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
