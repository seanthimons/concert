---
phase: 43
slug: wqx-dictionary
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-05
---

# Phase 43 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | `tests/testthat.R` (standard testthat runner) |
| **Quick run command** | `devtools::test(filter = "wqx")` |
| **Full suite command** | `devtools::test()` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `devtools::test(filter = "wqx")`
- **After every plan wave:** Run `devtools::test()`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 43-01-01 | 01 | 1 | DICT-01 | — | N/A | unit | `devtools::test(filter = "wqx")` | Wave 0 (43-01 Task 1 creates it) | ⬜ pending |
| 43-01-02 | 01 | 1 | DICT-02 | — | N/A | unit | `devtools::test(filter = "wqx")` | Wave 0 (43-01 Task 1 creates it) | ⬜ pending |
| 43-01-03 | 01 | 1 | DICT-03 | — | N/A | unit | `devtools::test(filter = "wqx")` | Wave 0 (43-01 Task 1 creates it) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `tests/testthat/test-wqx-dictionary.R` — stubs for DICT-01, DICT-02, DICT-03 (created by Plan 43-01 Task 1)
- [ ] Test fixtures for mocked EPA responses (offline testing — inline mock tibbles in test file)

*Plan 43-01 Task 1 is a TDD task that creates the test file as its first action, satisfying Wave 0.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| EPA download works from live endpoint | DICT-01 | Network dependency; CI may not have access | Run `refresh_wqx_cache()` from R console, verify RDS created |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** ready
