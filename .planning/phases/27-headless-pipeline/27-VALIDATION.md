---
phase: 27
slug: headless-pipeline
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-13
---

# Phase 27 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat (>= 3.0.0) |
| **Config file** | None yet — tests/testthat/ migration is Phase 28 |
| **Quick run command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests')"` |
| **Full suite command** | Same (legacy test layout) |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `devtools::check()` for namespace validation
- **After every plan wave:** Run full test suite
- **Before `/gsd:verify-work`:** Full suite must be green + manual smoke test
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 27-01-01 | 01 | 1 | HDL-01 | Smoke | `devtools::document()` + NAMESPACE grep | ✅ | ⬜ pending |
| 27-01-02 | 01 | 1 | HDL-02 | Integration | Manual smoke test with `uncurated_sswqs.csv` | ❌ W0 | ⬜ pending |
| 27-01-03 | 01 | 1 | HDL-03 | Integration | `readxl::excel_sheets()` returns 7 names | ❌ W0 | ⬜ pending |
| 27-01-04 | 01 | 1 | HDL-04 | Unit | Return value structure check | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] NAMESPACE generation via `devtools::document()` — already configured
- [x] `devtools::check()` passes — established in Phase 25
- [ ] Manual smoke test script for `curate_headless()` with sample data

*Existing infrastructure covers most phase requirements. Full automated test coverage is Phase 28 scope.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full pipeline runs on real data | HDL-02 | Requires live CompTox API key | Run `curate_headless("uncurated_sswqs.csv", "out.xlsx", tag_map = list(chemical_name = "Name", cas_number = "CASRN"))` with valid `ctx_api_key` |
| Output XLSX has 7 sheets | HDL-03 | Part of integration test | `readxl::excel_sheets("out.xlsx")` returns 7 sheet names |
| `?curate_headless` shows help | HDL-01 | Requires installed package | After `devtools::install()`, run `?chemreg::curate_headless` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
