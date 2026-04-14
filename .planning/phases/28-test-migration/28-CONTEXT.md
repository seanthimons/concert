# Phase 28: Test Migration - Context

**Gathered:** 2026-04-14
**Status:** Ready for planning
**Mode:** Auto (decisions made without interactive questioning)

<domain>
## Phase Boundary

All tests run under `devtools::test()` with a green result — no failures, standard testthat structure. This is the final phase of v1.8 R Package Migration.

**Input state:** 17 test files in `tests/test_*.R` format, no testthat structure, 1 known failure.
**Output state:** `tests/testthat/test-*.R` structure, testthat.R runner, all tests pass.

</domain>

<decisions>
## Implementation Decisions

### Directory structure
- **D-01:** Create `tests/testthat/` directory with `tests/testthat.R` runner file
- **D-02:** Runner file contains standard pattern: `library(testthat); library(chemreg); test_check("chemreg")`
- **D-03:** Delete `tests/_snaps/` (verified empty — no snapshot files to relocate)
- **D-04:** Move `tests/data/` to `tests/testthat/data/` (testthat fixture convention)
- **D-05:** Move `tests/air.toml` to project root or delete (air config belongs at project level)

### File renaming
- **D-06:** Rename all 17 test files from `test_*.R` to `test-*.R` (dash convention per TST-02)
- **D-07:** File list: test-data-detection.R, test-prototype-pipeline.R, test-consensus.R, test-cas-pipeline.R, test-reference-provenance.R, test-cleaning-reference.R, test-export-import.R, test-unicode-qc.R, test-bare-formula-detection.R, test-flag-matching.R, test-cleaning-pipeline.R, test-name-cleaning.R, test-unicode-comptoxr.R, test-cleaning-pipeline-validation.R, test-enrichment.R, test-isotope-chiral-multianalyte.R, test-modules-render.R

### Test file cleanup
- **D-08:** Remove `library(testthat)` calls from individual test files (runner handles this)
- **D-09:** Remove `library(here)` calls from test files (not needed after migration)
- **D-10:** Remove `source(here::here("R", "*.R"))` calls from test files — functions are in package namespace after `library(chemreg)`
- **D-11:** Keep `library(withr)` calls where tests use `withr::with_tempdir()` (withr is a test dependency, not auto-loaded)
- **D-12:** Add `withr` to Suggests in DESCRIPTION if not present (required for test isolation)

### Pre-existing failure fix
- **D-13:** Update `test-cleaning-reference.R` line 99: change `expect_named(result, c("stop_words", "block_patterns", "functional_categories"))` to include all 5 keys: `"stop_words", "block_patterns", "functional_categories", "strip_terms", "isotope_lookup"`
- **D-14:** Also update any documentation comments that reference 3-key structure to reflect 5-key structure

### Claude's Discretion
- Exact order of test file processing (alphabetical vs dependency order)
- Whether to consolidate related test files (defer — keep 1:1 mapping for traceability)
- Test fixture organization within tests/testthat/data/

</decisions>

<specifics>
## Specific Ideas

- This is a structural migration, not a rewrite — keep test logic unchanged except for namespace/import fixes
- The `tests/` directory stays in `.Rbuildignore` (added in Phase 25) since we're using `tests/testthat/` structure now
- Some tests may need `skip_if_not_installed()` guards for optional dependencies (shiny, bslib, etc.)

</specifics>

<canonical_refs>
## Canonical References

### Test migration requirements
- `.planning/REQUIREMENTS.md` — TST-01 through TST-04 define success criteria
- `.planning/ROADMAP.md` Phase 28 — Success criteria, dependencies on Phase 27

### Package structure
- `DESCRIPTION` — Current Imports/Suggests split; withr needs to be in Suggests
- `NAMESPACE` — Exported functions that tests will call via package namespace
- `.Rbuildignore` — Already ignores tests/ directory (Phase 25 decision)

### Current test structure
- `tests/test_cleaning_reference.R` — Contains the pre-existing failure at line 99
- `R/cleaning_reference.R` lines 277-285 — `load_all_reference_lists()` returns 5 keys

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `tests/_snaps/` — Existing snapshot files, relocate to `tests/testthat/_snaps/`
- `tests/data/` — Test fixtures including sample Excel/CSV files for import tests

### Established Patterns
- All test files use `testthat::test_that()` blocks — no structural changes needed
- Many tests use `withr::with_tempdir()` for isolation — withr must be available
- Some tests use `shiny::testServer()` — shiny must be in Suggests

### Integration Points
- `load_all_reference_lists()` — Now returns 5 keys per Phase 13 + Phase 23 changes
- `run_app()` — Tests for modules use the relocated app structure from Phase 26
- Module functions — All exported in Phase 26, accessible via `chemreg::mod_*`

</code_context>

<deferred>
## Deferred Ideas

- Test coverage reporting (codecov integration) — future enhancement
- Parallel test execution — performance optimization for later
- CI/CD GitHub Actions for test runs — listed in REQUIREMENTS.md Future Requirements

</deferred>

---

*Phase: 28-test-migration*
*Context gathered: 2026-04-14*
