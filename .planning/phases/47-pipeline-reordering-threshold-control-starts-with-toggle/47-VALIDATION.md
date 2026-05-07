---
phase: 47
slug: pipeline-reordering-threshold-control-starts-with-toggle
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-06
---

# Phase 47 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat (detected in tests/testthat/) |
| **Config file** | tests/testthat.R |
| **Quick run command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "devtools::load_all(); testthat::test_file('tests/testthat/test-pipeline-reorder-toggle.R')"` |
| **Full suite command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "devtools::load_all(); testthat::test_dir('tests')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "devtools::load_all(); testthat::test_file('tests/testthat/test-pipeline-reorder-toggle.R')"`
- **After every plan wave:** Run `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "devtools::load_all(); testthat::test_dir('tests')"`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 47-01-01 | 01 | 1 | ORD-01 | — | N/A | unit | `testthat::test_file('tests/testthat/test-pipeline-reorder-toggle.R')` | ❌ W0 | ⬜ pending |
| 47-01-02 | 01 | 1 | ORD-02 | — | N/A | unit | `testthat::test_file('tests/testthat/test-pipeline-reorder-toggle.R')` | ❌ W0 | ⬜ pending |
| 47-01-03 | 01 | 1 | CONF-02 | — | N/A | unit | `testthat::test_file('tests/testthat/test-pipeline-reorder-toggle.R')` | ❌ W0 | ⬜ pending |
| 47-01-04 | 01 | 1 | TOG-02 | — | N/A | unit | `testthat::test_file('tests/testthat/test-pipeline-reorder-toggle.R')` | ❌ W0 | ⬜ pending |
| 47-02-01 | 02 | 2 | CONF-01 | — | N/A | smoke | Shiny cold boot | ✅ | ⬜ pending |
| 47-02-02 | 02 | 2 | TOG-01 | — | N/A | smoke | Shiny cold boot | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-pipeline-reorder-toggle.R` — stubs for ORD-01, ORD-02, CONF-02, TOG-02

*Existing infrastructure covers framework install.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Slider/numeric sync in modal | CONF-01 | Requires browser interaction | Open pre-flight modal, drag slider, verify numeric updates; type in numeric, verify slider moves |
| Toggle off hides starts-with results | TOG-01 | Visual verification | Open modal, confirm toggle starts unchecked; run pipeline, verify no starts-with tier in results |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
