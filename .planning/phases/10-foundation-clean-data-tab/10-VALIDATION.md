---
phase: 10
slug: foundation-clean-data-tab
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-05
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | tests/ directory (existing) |
| **Quick run command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests')"` |
| **Full suite command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | INFRA-01 | unit | `Rscript -e "testthat::test_file('tests/test_cleaning_pipeline.R')"` | ❌ W0 | ⬜ pending |
| 10-01-02 | 01 | 1 | INFRA-03 | unit | `Rscript -e "testthat::test_file('tests/test_cleaning_pipeline.R')"` | ❌ W0 | ⬜ pending |
| 10-01-03 | 01 | 1 | INFRA-04 | unit | `Rscript -e "testthat::test_file('tests/test_cleaning_pipeline.R')"` | ❌ W0 | ⬜ pending |
| 10-02-01 | 02 | 1 | INFRA-02 | unit | `Rscript -e "testthat::test_file('tests/test_cleaning_reference.R')"` | ❌ W0 | ⬜ pending |
| 10-03-01 | 03 | 2 | UIUX-01 | manual | App smoke test | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test_cleaning_pipeline.R` — stubs for INFRA-01, INFRA-03, INFRA-04
- [ ] `tests/test_cleaning_reference.R` — stubs for INFRA-02

*Existing testthat infrastructure covers framework needs. Only new test files needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Clean Data tab renders between Data Preview and Tag Columns | UIUX-01 | UI position requires visual inspection | 1. Start app 2. Upload a CSV 3. Verify "Clean Data" tab appears after Data Preview, before Tag Columns |
| Sidebar hides on Clean Data tab | UIUX-01 | Sidebar toggle behavior requires browser | 1. Navigate to Clean Data tab 2. Verify sidebar collapses |
| Tab gating works (Tag Columns hidden until cleaning runs) | UIUX-01 | Navigation gating requires browser interaction | 1. Upload file 2. Verify Tag Columns not accessible 3. Run cleaning 4. Verify Tag Columns unlocks |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
