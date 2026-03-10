---
phase: 13
slug: reference-filters-editable-lists
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-06
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | none — existing test infrastructure |
| **Quick run command** | `testthat::test_file("tests/test_{module}.R")` |
| **Full suite command** | `testthat::test_dir("tests")` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `testthat::test_file("tests/test_{module}.R")` for changed module
- **After every plan wave:** Run `testthat::test_dir("tests")` full suite
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | FILT-01 | unit | `testthat::test_file("tests/test_reference_provenance.R")` | ❌ W0 | ⬜ pending |
| 13-01-02 | 01 | 1 | FILT-03 | unit | `testthat::test_file("tests/test_flag_matching.R")` | ❌ W0 | ⬜ pending |
| 13-01-03 | 01 | 1 | FILT-04 | unit | `testthat::test_file("tests/test_bare_formula_detection.R")` | ❌ W0 | ⬜ pending |
| 13-02-01 | 02 | 1 | FILT-02, FILT-05 | integration | `testthat::test_file("tests/test_reference_editing.R")` | ❌ W0 | ⬜ pending |
| 13-02-02 | 02 | 1 | UIUX-05 | integration | `testthat::test_file("tests/test_cascade_reset.R")` | ❌ Extend | ⬜ pending |
| 13-03-01 | 03 | 2 | FILT-06 | smoke | Manual: inspect DT conditional formatting | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test_reference_provenance.R` — stubs for FILT-01 (provenance columns, ComptoxR seeding)
- [ ] `tests/test_flag_matching.R` — stubs for FILT-03 (exact vs substring, match source)
- [ ] `tests/test_bare_formula_detection.R` — stubs for FILT-04 (validator reuse, H2O/NaCl/CuSO4 cases)
- [ ] `tests/test_reference_editing.R` — stubs for FILT-02, FILT-05 (add/remove, hot_to_r(), CSV upload)
- [ ] `tests/test_cascade_reset.R` — extend existing cascade tests for reference list re-run (UIUX-05)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Blocking flags (red) vs warning flags (yellow) visual distinction | FILT-06 | DT conditional formatting is visual, cannot assert CSS colors in unit tests | 1. Run cleaning on data with known functional categories and bare formulas. 2. Verify blocking rows appear red, warning rows appear yellow. 3. Verify flag column shows `BLOCK:` and `WARN:` prefixes. |
| rhandsontable editor UX (add/remove/suppress) | FILT-05 | Interactive table editing requires browser context | 1. Open reference list accordion panels. 2. Right-click to add row, type new term. 3. Toggle active checkbox to suppress entry. 4. Verify changes persist after "Apply & Re-run". |
| Smoke test: app starts without error | SC-1 | Runtime startup check | 1. Run `shiny::runApp('app.R')`. 2. Verify no console errors. 3. Verify reference list editors and flag UI render. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
