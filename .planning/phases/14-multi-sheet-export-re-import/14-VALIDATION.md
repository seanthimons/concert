---
phase: 14
slug: multi-sheet-export-re-import
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-07
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.2+ |
| **Config file** | none — tests run via `testthat::test_dir("tests")` |
| **Quick run command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/test_export_import.R')"` |
| **Full suite command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/test_export_import.R')"`
- **After every plan wave:** Run `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests')"`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 1 | EXPO-01 | unit | `Rscript -e "testthat::test_file('tests/test_export_import.R', filter='multi-sheet export')"` | ❌ W0 | ⬜ pending |
| 14-01-02 | 01 | 1 | EXPO-03 | unit | `Rscript -e "testthat::test_file('tests/test_export_import.R', filter='audit document')"` | ❌ W0 | ⬜ pending |
| 14-01-03 | 01 | 1 | EXPO-01 | unit | `Rscript -e "testthat::test_file('tests/test_export_import.R', filter='excel validation')"` | ❌ W0 | ⬜ pending |
| 14-02-01 | 02 | 2 | EXPO-02 | unit | `Rscript -e "testthat::test_file('tests/test_export_import.R', filter='config import')"` | ❌ W0 | ⬜ pending |
| 14-02-02 | 02 | 2 | EXPO-02 | unit | `Rscript -e "testthat::test_file('tests/test_export_import.R', filter='reference list merge')"` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test_export_import.R` — stubs for EXPO-01, EXPO-02, EXPO-03
  - Multi-sheet export creates 7 sheets with correct names
  - Pipeline Config sheet contains chemreg_export marker
  - Reference Lists sheet has correct type column format
  - Config import detects ChemReg exports and rejects non-ChemReg files
  - Reference list merge preserves existing + imported entries
  - Excel size validation blocks oversized exports
- [ ] `tests/test_excel_validation.R` — covers validate_excel_size() edge cases
  - Row limit validation (1,048,576 threshold)
  - Column limit validation (16,384 threshold)

*Existing test infrastructure covers framework setup.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Modal dialog renders correctly on import | EXPO-02 | Shiny UI modal requires browser context | Upload a ChemReg export file, verify modal appears with checkboxes for reference lists and pipeline state |
| Exported Excel opens cleanly in Excel/LibreOffice | EXPO-03 | Requires desktop application | Open exported .xlsx in Excel, verify all 7 sheets are readable and properly formatted |
| Smoke test: app starts without error | ALL | Full Shiny startup check | Run `shiny::runApp('app.R')`, verify "Listening on" message and no console errors |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
