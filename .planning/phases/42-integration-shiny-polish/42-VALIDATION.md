---
phase: 42
slug: integration-shiny-polish
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-28
---

# Phase 42 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | `tests/testthat.R` |
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
| 42-01-01 | 01 | 1 | RECO-01 | — | N/A | unit | `Rscript -e "testthat::test_dir('tests')"` | ❌ W0 | ⬜ pending |
| 42-01-02 | 01 | 1 | RECO-02 | — | N/A | unit | `Rscript -e "testthat::test_dir('tests')"` | ❌ W0 | ⬜ pending |
| 42-02-01 | 02 | 2 | MEDIT-01 | — | N/A | unit | `Rscript -e "testthat::test_dir('tests')"` | ❌ W0 | ⬜ pending |
| 42-02-02 | 02 | 2 | MEDIT-02 | — | N/A | unit | `Rscript -e "testthat::test_dir('tests')"` | ❌ W0 | ⬜ pending |
| 42-02-03 | 02 | 2 | MEDIT-03 | — | N/A | unit | `Rscript -e "testthat::test_dir('tests')"` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-preflight-modal.R` — stubs for RECO-01, RECO-02
- [ ] `tests/testthat/test-media-editor.R` — stubs for MEDIT-01, MEDIT-02, MEDIT-03
- [ ] `tests/testthat/test-harmonization-prechecks.R` — stubs for new precheck functions

*Existing test infrastructure covers framework installation.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Pre-flight modal renders with fire/skip indicators | RECO-01 | Shiny UI rendering requires browser | Start app, upload data, click "Run Pipeline", verify modal shows step list with indicators |
| Subset run executes only checked steps | RECO-02 | Requires interactive modal interaction | Uncheck some steps in pre-flight modal, run, verify only checked steps execute |
| Media editor modal opens on row click | MEDIT-01 | DT row click requires browser interaction | Navigate to Harmonize tab, click media table row, verify edit modal opens |
| Re-run cascade after media edit | MEDIT-02 | Full reactive chain requires live app | Edit a media mapping, save, verify re-run prompt appears, click re-run, verify pipeline runs |
| Unmatched terms surfaced at top of table | MEDIT-03 | Visual layout verification | Upload data with unmatched media terms, verify they appear highlighted at top of table |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
