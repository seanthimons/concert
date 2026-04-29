---
phase: 40
slug: date-parser
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-26
---

# Phase 40 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | `tests/testthat.R` |
| **Quick run command** | `Rscript -e "testthat::test_file('tests/testthat/test-date-parser.R')"` |
| **Full suite command** | `Rscript -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `Rscript -e "testthat::test_file('tests/testthat/test-date-parser.R')"`
- **After every plan wave:** Run `Rscript -e "testthat::test_dir('tests/testthat')"`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 40-01-01 | 01 | 1 | DATE-01 | — | N/A | unit | `Rscript -e "testthat::test_file('tests/testthat/test-date-parser.R')"` | ❌ W0 | ⬜ pending |
| 40-01-02 | 01 | 1 | DATE-02 | — | N/A | unit | `Rscript -e "testthat::test_file('tests/testthat/test-date-parser.R')"` | ❌ W0 | ⬜ pending |
| 40-01-03 | 01 | 1 | DATE-03 | — | N/A | unit | `Rscript -e "testthat::test_file('tests/testthat/test-date-parser.R')"` | ❌ W0 | ⬜ pending |
| 40-01-04 | 01 | 1 | DATE-04 | — | N/A | unit | `Rscript -e "testthat::test_file('tests/testthat/test-date-parser.R')"` | ❌ W0 | ⬜ pending |
| 40-02-01 | 02 | 2 | DATE-05 | — | N/A | integration | `Rscript -e "testthat::test_dir('tests/testthat')"` | ❌ W0 | ⬜ pending |
| 40-02-02 | 02 | 2 | DATE-06 | — | N/A | integration | `Rscript -e "testthat::test_dir('tests/testthat')"` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-date-parser.R` — stubs for DATE-01 through DATE-04
- [ ] `tests/testthat/test-date-integration.R` — stubs for DATE-05, DATE-06

*Existing testthat infrastructure covers framework needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| QC dashboard ambiguity count value box | DATE-03 | UI rendering requires Shiny session | Start app, upload sample with ambiguous dates, verify value box shows count |
| Tag Columns dropdown third optgroup | DATE-05 | UI dropdown rendering | Start app, check Tag Columns dropdown shows "Study/Contextual" group with StudyDate |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
