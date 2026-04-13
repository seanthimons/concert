# ChemReg TODO

**Last synced:** 2026-03-20

---

## Pending PRs (Resolve Immediately)
- [ ] PR #21: v1.6: Cleaning Ruleset Fixes [open] — feature/multi-locant-protection

## High Priority (No Milestone)

### [ ] Curation functions have zero test coverage (#3)
- **Impact:** Core feature completely untested - ComptoxR integration changes could break silently
- **Files:** `R/curation.R`, `tests/test_data_detection.R`
- high impact, high complexity (45d)

### [ ] CAS validation fails silently on API errors (#4)
- **Impact:** Users think curation succeeded when all validations actually failed
- **Files:** `R/curation.R` (lines 13-14)
- high impact, medium complexity (45d)

### [ ] ComptoxR package not version-pinned (#5)
- **Impact:** Breaking API changes could silently break entire curation workflow
- **Files:** `load_packages.R` (line 180)
- **Note:** Dedicated solution planned - do not fix ad-hoc
- high impact, low complexity (45d)

### [ ] API key setup not documented (#6)
- **Impact:** Users can't use curation without knowing to set `ctx_api_key`
- **Files:** `app.R` (line 927), README.md
- high impact, low complexity (45d)

### [ ] File upload edge cases not tested (#7)
- **Impact:** App crashes on real-world messy data
- **Files:** `R/file_handlers.R`, `app.R`
- high impact, medium complexity (45d)

---

## Medium Priority (No Milestone)

### [ ] Column names with special characters break tagging UI (#8)
- **Files:** `app.R` (lines 849, 869)
- medium impact, medium complexity (45d)

### [ ] Detection mode switch fails silently with no data (#9)
- **Files:** `app.R` (lines 447-499)
- medium impact, low complexity (45d)

### [ ] Manual header row validation missing (#10)
- **Files:** `app.R` (lines 109-116, 447)
- medium impact, low complexity (45d)

### [ ] Reactive values lack type safety (#11)
- **Files:** `app.R` (lines 281-293)
- medium impact, medium complexity (45d)

### [ ] Hardcoded detection thresholds (#12)
- **Files:** `R/data_detection.R` (lines 11, 185)
- medium impact, medium complexity (45d)

### [ ] UI verification (#19)
- medium impact, medium complexity (17d)

### [ ] Add string hashing workflow (#20)
- medium impact, medium complexity (11d)

### [ ] Revisit Review Results table column visibility (#24) [gsd]
- **Impact:** Condensed table view may hide too much info for real-world data
- **Files:** `app.R`
- medium impact, medium complexity (19d)

### [ ] Reference list editors (rhandsontable) are crushed (#25)
- **Impact:** Stop Words and Block Patterns tables have truncated columns
- **Files:** `R/modules/mod_clean_data.R` (lines 488-526)
- medium impact, low complexity (19d)

### [x] ComptoxR functional use API drifted — ct_functional_use() broken (#26)
- **Resolution:** Replaced with `ct_exposure_functional_use_category()` — returns 131 categories, cache populated with 140 terms after alias expansion
- **Files:** `R/cleaning_reference.R` (lines 124-151)
- Resolved 2026-04-13

---

## Low Priority (No Milestone)

### [ ] Dead code: checkpoint.R never used (#13)
- low impact, low complexity (45d)

### [ ] Performance: Detection scans row-by-row (#14)
- low impact, medium complexity (45d)

### [ ] Performance: No progress indicator for curation (#15)
- low impact, low complexity (45d)

### [ ] No authentication for deployed app (#16)
- low impact, low complexity (45d)

### [ ] Reactive UI logic not tested (#17)
- low impact, high complexity (45d)

### [ ] Detection ensemble doesn't handle confidence ties (#18)
- low impact, low complexity (45d)

### [ ] Name constant for split_synonyms max protection iterations (#22)
- Cosmetic: replace magic number 10 with named constant
- low impact, low complexity (0d)

### [ ] Remove redundant V alternative in ROMAN_NUMERAL_PATTERN (#23)
- Cosmetic: simplify regex alternation
- low impact, low complexity (0d)

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

### [ ] Feature: Add tie-breaking for CASRN vs Name (#2)

---

*Last updated: 2026-03-20*
