---
phase: 12
slug: name-cleaning
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-06
---

# Phase 12 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | tests/test_name_cleaning.R (Wave 0 creates) |
| **Quick run command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/test_name_cleaning.R')"` |
| **Full suite command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick command (name cleaning tests)
- **After every plan wave:** Run full suite command (all tests)
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 12-01-01 | 01 | 1 | NAME-01,02,03,04 | unit (RED) | `Rscript -e "testthat::test_file('tests/test_name_cleaning.R')"` | ❌ W0 | ⬜ pending |
| 12-01-02 | 01 | 1 | NAME-01,02,03,04 | unit (GREEN) | `Rscript -e "testthat::test_file('tests/test_name_cleaning.R')"` | ❌ W0 | ⬜ pending |
| 12-02-01 | 02 | 2 | UIUX-03 | smoke + unit | `Rscript -e "shiny::runApp('app.R', port=3838, launch.browser=FALSE)"` | ✅ | ⬜ pending |
| 12-02-02 | 02 | 2 | UIUX-03 | manual | N/A (human-verify) | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test_name_cleaning.R` — stubs for NAME-01 through NAME-04
- Existing infrastructure (testthat, R 4.5.1) covers all phase requirements

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Value boxes display name cleaning stats | UIUX-03 | Visual layout verification | Start app, upload test data, tag columns, run cleaning, verify value boxes |
| Audit trail accordion collapses/expands | UIUX-03 | Interactive UI behavior | Click accordion header, verify trail table renders |
| Synonym split rows appear in cleaned table | NAME-03 | Row count change visible | Upload multi-synonym data, verify new rows appear with original_row_id |

*Smoke test (app startup) is automated via Rscript shiny::runApp check.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
