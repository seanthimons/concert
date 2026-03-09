# ChemReg TODO

**Generated:** 2026-02-03
**Source:** `.planning/codebase/CONCERNS.md`

---

## Priority Legend

| Priority | Impact | Effort | Action |
|----------|--------|--------|--------|
| P0 - Critical | High | Any | Fix immediately |
| P1 - High | High | Low-Med | Fix soon |
| P2 - Medium | Medium | Medium | Plan for next cycle |
| P3 - Low | Low | Any | Backlog |

---

## P0 - Critical

### [ ] Curation functions have zero test coverage
- **Impact:** Core feature completely untested - ComptoxR integration changes could break silently
- **Files:** `R/curation.R`, `tests/test_data_detection.R`
- **Tests needed:**
  - CAS validation with valid/invalid/empty inputs
  - Chemical name lookup with exact/fuzzy/no-match scenarios
  - Mixed CAS + Name column curation
  - Error handling when ComptoxR API unavailable
- **Issue:** [#3](https://github.com/seanthimons/chem_janitor/issues/3)

### [ ] CAS validation fails silently on API errors
- **Impact:** Users think curation succeeded when all validations actually failed
- **Files:** `R/curation.R` (lines 13-14)
- **Fix:** Wrap ComptoxR calls in tryCatch, check for NA results, warn if validation rate < threshold
- **Issue:** [#4](https://github.com/seanthimons/chem_janitor/issues/4)

---

## P1 - High

### [ ] ComptoxR package not version-pinned
- **Impact:** HIGH - Breaking API changes could silently break entire curation workflow
- **Effort:** LOW - Single line change + documentation
- **Files:** `load_packages.R` (line 180)
- **Fix:** Pin to specific release, add version compatibility check
- **Note:** Dedicated solution planned - do not fix ad-hoc
- **Issue:** [#5](https://github.com/seanthimons/chem_janitor/issues/5)

### [ ] API key setup not documented
- **Impact:** Users can't use curation without knowing to set `ctx_api_key`
- **Files:** `app.R` (line 927), README.md
- **Fix:**
  - Add `.env.example` template
  - Document in README
  - Validate key exists at startup (not just when curation runs)
- **Issue:** [#6](https://github.com/seanthimons/chem_janitor/issues/6)

### [ ] File upload edge cases not tested
- **Impact:** App crashes on real-world messy data
- **Files:** `R/file_handlers.R`, `app.R`
- **Tests needed:**
  - Very large files (near 50MB limit)
  - Single column files
  - 1000+ column files
  - Corrupted/truncated files
  - Non-Latin encodings (Big5, Shift-JIS)
- **Issue:** [#7](https://github.com/seanthimons/chem_janitor/issues/7)

---

## P2 - Medium

### [ ] Column names with special characters break tagging UI
- **Impact:** Columns like "Conc (µg/L)" produce invalid Shiny input IDs
- **Files:** `app.R` (lines 849, 869)
- **Fix:** Sanitize column names before creating input IDs, or use index-based IDs
- **Issue:** [#8](https://github.com/seanthimons/chem_janitor/issues/8)

### [ ] Detection mode switch fails silently with no data
- **Impact:** Confusing UX - user changes mode but nothing happens
- **Files:** `app.R` (lines 447-499)
- **Fix:** Show notification if preconditions not met
- **Issue:** [#9](https://github.com/seanthimons/chem_janitor/issues/9)

### [ ] Manual header row validation missing
- **Impact:** User can enter row > file length, causing silent failures
- **Files:** `app.R` (lines 109-116, 447)
- **Fix:** Set max dynamically based on file size, validate before applying
- **Issue:** [#10](https://github.com/seanthimons/chem_janitor/issues/10)

### [ ] Reactive values lack type safety
- **Impact:** Unexpected data types cause downstream crashes
- **Files:** `app.R` (lines 281-293)
- **Fix:** Add validation function for data_store structure
- **Issue:** [#11](https://github.com/seanthimons/chem_janitor/issues/11)

### [ ] Hardcoded detection thresholds
- **Impact:** Can't tune sensitivity for different data sources
- **Files:** `R/data_detection.R` (lines 11, 185)
- **Fix:** Move to config or expose in UI
- **Issue:** [#12](https://github.com/seanthimons/chem_janitor/issues/12)

---

## P2.5 - UAT Findings (Phase 14)

### [ ] Reference list editors (rhandsontable) are crushed and hard to interact with
- **Impact:** Stop Words and Block Patterns tables have truncated columns — text like "app_de..." is unreadable, checkboxes are cramped
- **Source:** Phase 13 editors, discovered during Phase 14 UAT
- **Files:** `R/modules/mod_clean_data.R` (lines 488-526)
- **Fix:** Set explicit column widths via `rhandsontable::hot_col()` width parameter, or increase table height/use `stretchH = "all"`

### [ ] ComptoxR functional use API has drifted — ct_functional_use() broken
- **Impact:** Functional categories list is always empty; no categories available for reference matching
- **Source:** ComptoxR package API changed — `ct_functional_use("", domain = "func_use")` no longer works
- **Files:** `R/cleaning_reference.R` (lines 124-151) — marked with `#TODO` block
- **Fix:** Identify correct ComptoxR function/endpoint for fetching functional use category lists, update the call

---

## P3 - Low

### [ ] Dead code: checkpoint.R never used
- **Impact:** Maintenance burden, confusion
- **Files:** `checkpoint.R`
- **Fix:** Integrate or remove with documentation
- **Issue:** [#13](https://github.com/seanthimons/chem_janitor/issues/13)

### [ ] Performance: Detection scans row-by-row
- **Impact:** Slower than necessary for large files
- **Files:** `R/data_detection.R` (lines 23-42)
- **Fix:** Vectorize with dplyr::across()
- **Issue:** [#14](https://github.com/seanthimons/chem_janitor/issues/14)

### [ ] Performance: No progress indicator for curation
- **Impact:** Users don't know if app is working on large files
- **Files:** `R/curation.R`, `app.R`
- **Fix:** Add shiny progress bar
- **Issue:** [#15](https://github.com/seanthimons/chem_janitor/issues/15)

### [ ] No authentication for deployed app
- **Impact:** Security risk if deployed publicly (currently local-only)
- **Files:** `app.R`
- **Fix:** Add shinymanager if public deployment needed
- **Issue:** [#16](https://github.com/seanthimons/chem_janitor/issues/16)

### [ ] Reactive UI logic not tested
- **Impact:** Refactoring could break UI without detection
- **Files:** `app.R` (lines 783-824, 863-900)
- **Fix:** Add shinytest2 tests
- **Issue:** [#17](https://github.com/seanthimons/chem_janitor/issues/17)

### [ ] Detection ensemble doesn't handle confidence ties
- **Impact:** Arbitrary method selection when methods tie
- **Files:** `R/data_detection.R` (lines 313-330)
- **Fix:** Add tiebreaker logic or document behavior
- **Issue:** [#18](https://github.com/seanthimons/chem_janitor/issues/18)

---

## Feature Requests (Future)

### [ ] Persistent session storage
- Save/resume curation progress across sessions
- Requires SQLite or similar

### [ ] Batch file processing
- Upload multiple files, queue for curation
- Aggregate results

### [ ] Partial curation recovery
- Checkpoint every N rows
- Resume from failure point

---

*Last updated: 2026-03-09*
