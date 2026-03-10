---
phase: 11
slug: cas-pipeline
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-06
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | None — tests in tests/ directory |
| **Quick run command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/test_cas_pipeline.R')"` |
| **Full suite command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command (< 10 seconds)
- **After every plan wave:** Run full suite command (< 30 seconds)
- **Before `/gsd:verify-work`:** Full suite must be green + Shiny smoke test
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 11-00-01 | 00 | 0 | CAS-01, CAS-02, CAS-03, CAS-04 | unit stubs | `Rscript -e "testthat::test_file('tests/test_cas_pipeline.R')"` | ❌ W0 | ⬜ pending |
| 11-01-01 | 01 | 1 | CAS-01, CAS-02 | unit | `Rscript -e "testthat::test_file('tests/test_cas_pipeline.R')"` | ❌ W0 | ⬜ pending |
| 11-01-02 | 01 | 1 | CAS-03 | unit | `Rscript -e "testthat::test_file('tests/test_cas_pipeline.R')"` | ❌ W0 | ⬜ pending |
| 11-01-03 | 01 | 1 | CAS-04 | unit | `Rscript -e "testthat::test_file('tests/test_cas_pipeline.R')"` | ❌ W0 | ⬜ pending |
| 11-02-01 | 02 | 2 | UIUX-02 | manual | Launch app, verify value boxes render | ✅ (manual) | ⬜ pending |
| 11-02-02 | 02 | 2 | UIUX-04 | manual | Launch app, verify progress messages | ✅ (manual) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test_cas_pipeline.R` — stubs for CAS-01, CAS-02, CAS-03, CAS-04
- [ ] Test data fixtures from chemical_validation_test.csv (CAS placeholders, multi-CAS, embedded CAS)

*Wave 0 creates test stubs that initially fail, proving coverage exists before implementation.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Value boxes render with correct stats | UIUX-02 | Requires Shiny UI rendering | Launch app → upload test CSV → tag columns → run cleaning → verify 5 value boxes with correct counts |
| Progress indicator shows CAS steps | UIUX-04 | Requires visual confirmation of progress bar | Launch app → upload test CSV → tag columns → run cleaning → verify progress messages appear in sequence |
| Shiny smoke test (app starts) | SC-1 | Requires full app startup | Run `Rscript -e "shiny::runApp('app.R', port=3838, launch.browser=FALSE)"` → verify "Listening on" |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
