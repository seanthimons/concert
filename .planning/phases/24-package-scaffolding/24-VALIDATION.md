---
phase: 24
slug: package-scaffolding
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-13
---

# Phase 24 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.2.3 (for existing tests) + devtools smoke verification |
| **Config file** | None — `tests/testthat/` structure does not exist yet (Phase 28) |
| **Quick run command** | `devtools::document()` + `library(chemreg)` no errors |
| **Full suite command** | `testthat::test_dir("tests")` (existing flat structure) |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Verify specific artifact created (DESCRIPTION, LICENSE, NAMESPACE exists and non-empty)
- **After every plan wave:** `devtools::document()` succeeds + `library(chemreg)` loads cleanly
- **Before `/gsd:verify-work`:** All three PKG requirements verified
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 24-01-01 | 01 | 1 | PKG-02 | file | `test -f DESCRIPTION && grep -q "^Package: chemreg" DESCRIPTION` | ❌ W0 | ⬜ pending |
| 24-01-02 | 01 | 1 | PKG-02 | file | `grep -q "Remotes:" DESCRIPTION` | ❌ W0 | ⬜ pending |
| 24-01-03 | 01 | 1 | n/a | file | `test -f LICENSE` | ❌ W0 | ⬜ pending |
| 24-01-04 | 01 | 1 | PKG-03 | smoke | `Rscript -e "devtools::document()"` exits 0 | ❌ W0 | ⬜ pending |
| 24-01-05 | 01 | 1 | PKG-03 | file | `test -f NAMESPACE && grep -q "export" NAMESPACE` | ❌ W0 | ⬜ pending |
| 24-01-06 | 01 | 1 | PKG-01 | smoke | `Rscript -e "devtools::install(upgrade='never'); library(chemreg)"` exits 0 | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- Existing infrastructure covers all phase requirements.

*Phase 24 success is verified by devtools commands and file existence, not unit tests. No test file stubs needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Imports list accuracy | PKG-02 | Requires semantic review of package usage | Verify each Import is actually used in R/*.R files |
| Suggests list accuracy | PKG-02 | Requires semantic review | Verify each Suggest is only used in app.R or tests |

*Most behaviors have automated verification via devtools::document() and library() success.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
