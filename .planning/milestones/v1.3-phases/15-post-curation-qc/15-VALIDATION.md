---
phase: 15
slug: post-curation-qc
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-09
---

# Phase 15 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.2+ |
| **Config file** | tests/ directory with testthat conventions |
| **Quick run command** | `Rscript -e "source('load_packages.R'); testthat::test_file('tests/test_cleaning_pipeline.R')"` |
| **Full suite command** | `Rscript -e "source('load_packages.R'); testthat::test_dir('tests')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `Rscript -e "source('load_packages.R'); testthat::test_file('tests/test_cleaning_pipeline.R')"`
- **After every plan wave:** Run `Rscript -e "source('load_packages.R'); testthat::test_dir('tests')"`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 15-01-01 | 01 | 1 | POST-01 | unit (existing) | `Rscript -e "source('load_packages.R'); testthat::test_file('tests/test_cas_pipeline.R')"` | ✅ | ⬜ pending |
| 15-01-02 | 01 | 1 | POST-02 | unit | `Rscript -e "source('load_packages.R'); testthat::test_file('tests/test_cleaning_pipeline.R')"` | ✅ | ⬜ pending |
| 15-02-01 | 02 | 2 | POST-02 | unit | `Rscript -e "source('load_packages.R'); testthat::test_file('tests/test_unicode_qc.R')"` | ❌ W0 | ⬜ pending |
| 15-02-02 | 02 | 2 | POST-02 | smoke | Shiny smoke test | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test_unicode_qc.R` — stubs for POST-02 (perform_unicode_qc, detect_unhandled_unicode, QC integration)
- [ ] Update `tests/test_cleaning_pipeline.R` — change unicode test expectations from stringi behavior to ComptoxR behavior (`.alpha.` not `a`)

*Existing infrastructure covers POST-01 via tests/test_cas_pipeline.R.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| QC value boxes render correctly in Review Results | POST-02 | Visual layout validation | Upload test file → run curation → verify value boxes show non-ASCII count and unhandled character count |
| QC summary card displays unhandled character details | POST-02 | UI rendering with dynamic content | Upload file with unmapped unicode → verify card shows U+XXXX codes and row counts |
| Re-run QC button triggers fresh QC pass | POST-02 | Interactive UI behavior | Click Re-run QC → verify results update without page reload |
| Shiny app starts without error after all changes | POST-01, POST-02 | Integration smoke test | Run `shiny::runApp()` → verify "Listening on" without errors |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
