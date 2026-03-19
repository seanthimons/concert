# Phase 21: Unicode Cleaning Coverage - Context

**Gathered:** 2026-03-19
**Status:** Ready for planning
**Source:** Auto-mode (recommended defaults selected)

<domain>
## Phase Boundary

The cleaning pipeline must catch all known chemistry-relevant unicode characters (specifically Greek alpha α and prime ′) before post-curation QC runs, and the test suite must align with the current ComptoxR mapping format. This is primarily a test alignment fix — the pipeline already handles both characters correctly via `ComptoxR::clean_unicode()` at Step 1, but the tests expect an outdated dot-notation format.

</domain>

<decisions>
## Implementation Decisions

### Root cause
- ComptoxR's `clean_unicode()` currently returns `"alpha"` for α (plain text), NOT `".alpha."` (dot notation)
- ComptoxR's `clean_unicode()` currently returns `"'"` (apostrophe) for ′ (prime symbol)
- Both characters ARE already cleaned by the pipeline at Step 1 (line 1402 of `cleaning_pipeline.R`)
- The 3 failing tests in `test_cleaning_pipeline.R` expect the old dot-notation format — this is the only bug

### Test format alignment
- Update all `.alpha.` and `.beta.` expected values in `test_cleaning_pipeline.R` to match current ComptoxR output (`alpha`, `beta`)
- Specifically: line 12 (`.alpha.-tocopherol` → `alpha-tocopherol`), line 15 (`.beta.-carotene` → `beta-carotene`), line 62 (`.alpha.-tocopherol` → `alpha-tocopherol`)
- Update comments that reference "dot-notation" to reflect the current plain-text format
- Add a test for prime symbol (′) conversion to apostrophe (')

### Pipeline coverage verification
- No code changes needed to the pipeline itself — Step 1 already applies `ComptoxR::clean_unicode` to all character columns
- Verify (don't assume) that α → alpha and ′ → ' conversions work at the pipeline integration level, not just unit level
- No custom mapping tables needed — ComptoxR handles both characters

### Validation CSV updates
- Add unicode rows to `data/chemical_validation_test.csv` with `issue_type = unicode_cleaning`
- At minimum: one row with α in the name, one row with ′ in the name
- These feed into the end-to-end validation test suite (`tests/test_cleaning_pipeline_validation.R`)

### Claude's Discretion
- Exact number and content of new validation CSV rows beyond the required α and ′ cases
- Whether to add additional unicode edge case tests (e.g., micro sign µ, degree °)
- Test assertion grouping and naming within test files

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — UNIC-01 (α cleaned), UNIC-02 (′ cleaned), UNIC-03 (tests use current format)

### Existing implementation
- `R/cleaning_pipeline.R` line 1402 — Step 1: unicode_to_ascii, where `ComptoxR::clean_unicode` is applied to all character columns
- `R/cleaning_pipeline.R` lines 1300-1350 — `perform_unicode_qc()` post-curation QC function (read-only detection, NOT the cleaning step)

### Test files
- `tests/test_cleaning_pipeline.R` lines 10-20 — The 3 failing tests with dot-notation expected values that need updating
- `tests/test_cleaning_pipeline.R` lines 42-67 — Integration test for `run_cleaning_pipeline` with dot-notation assertion on line 62
- `tests/test_cleaning_pipeline_validation.R` — End-to-end validation tests using chemical_validation_test.csv
- `data/chemical_validation_test.csv` — Validation dataset; add unicode rows

### Prior decisions
- `.planning/PROJECT.md` Key Decisions table — "ComptoxR direct usage" (v1.3): clean_unicode called directly, no custom implementations

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ComptoxR::clean_unicode()` — Already handles α → alpha and ′ → ' correctly; no wrapper needed
- `data/chemical_validation_test.csv` — Structured validation dataset with `issue_type` column for categorizing test rows

### Established Patterns
- Unicode cleaning runs as Step 1 in `run_cleaning_pipeline()` — earliest possible position, before any text manipulation
- Validation CSV rows use `issue_type` tags (e.g., `roman_numeral_oxidation`, `stoichiometric_ratio`) for systematic categorization
- Tests in `test_cleaning_pipeline.R` test both unit-level (`ComptoxR::clean_unicode` directly) and integration-level (`run_cleaning_pipeline` end-to-end)

### Integration Points
- `run_cleaning_pipeline()` Step 1 (line 1402) applies clean_unicode — this is the fix point (tests, not code)
- `test_cleaning_pipeline_validation.R` reads chemical_validation_test.csv for end-to-end assertions

</code_context>

<specifics>
## Specific Ideas

- The root cause verification: `ComptoxR::clean_unicode("α-tocopherol")` returns `"alpha-tocopherol"` (confirmed via live R session)
- The root cause verification: `ComptoxR::clean_unicode("2′-deoxyadenosine")` returns `"2'-deoxyadenosine"` (confirmed via live R session)
- All 3 current test failures are in `test_cleaning_pipeline.R` and are format-mismatch only — no actual cleaning bug exists

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 21-unicode-cleaning-coverage*
*Context gathered: 2026-03-19 via auto-mode*
