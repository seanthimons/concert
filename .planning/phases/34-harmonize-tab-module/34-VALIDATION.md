---
phase: 34
slug: harmonize-tab-module
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 34 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | tests/testthat.R |
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
| 34-01-01 | 01 | 1 | UITG-04 | — | N/A | integration | `shiny::runApp()` cold boot | ✅ | ⬜ pending |
| 34-01-02 | 01 | 1 | DATA-04 | — | N/A | unit | `Rscript -e "testthat::test_dir('tests')"` | ❌ W0 | ⬜ pending |
| 34-01-03 | 01 | 1 | PARS-06 | — | N/A | unit | `Rscript -e "testthat::test_dir('tests')"` | ❌ W0 | ⬜ pending |
| 34-01-04 | 01 | 1 | UNIT-06 | — | N/A | unit | `Rscript -e "testthat::test_dir('tests')"` | ❌ W0 | ⬜ pending |
| 34-01-05 | 01 | 1 | UITG-05 | — | N/A | integration | `shiny::runApp()` cold boot | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-mod-harmonize.R` — stubs for UITG-04, UITG-05, DATA-04
- [ ] `tests/testthat/test-corrections.R` — stubs for PARS-06
- [ ] `tests/testthat/test-unmatched-units.R` — stubs for UNIT-06

*Existing testthat infrastructure covers framework; test files for new module needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Chip editor click/edit interactions | DATA-04 | Shiny JS events require browser | Open app, click unit chip, verify modal opens with 6 fields |
| Unmatched unit batch actions | UNIT-06 | Dynamic UI rendering requires browser | Upload file with unknown units, run harmonization, verify unmatched panel |
| QC value boxes display after pipeline | UITG-05 | Visual rendering requires browser | Run harmonization, verify 4 value boxes appear with correct counts |
| Accordion expand/collapse | UITG-04 | UI interaction requires browser | Click each accordion panel, verify content loads |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
