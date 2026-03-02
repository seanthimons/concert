# Codebase Concerns

**Analysis Date:** 2026-02-26

## Tech Debt

### Curation Module Lacks Test Coverage
- **Issue:** `R/curation.R` has zero unit tests - core chemical validation feature is completely untested
- **Files:** `R/curation.R` (lines 1-165), `tests/test_data_detection.R`
- **Impact:** ComptoxR API integration changes, validation logic bugs, and error handling failures go undetected until user-facing runtime
- **Fix approach:**
  1. Create `tests/test_curation.R` with comprehensive test suite
  2. Add tests for CAS validation (valid/invalid/empty/NA inputs)
  3. Add tests for chemical name lookup (exact match/fuzzy match/no match scenarios)
  4. Add tests for error handling when ComptoxR API unavailable
  5. Test mixed CAS + Name column curation workflows
- **Current coverage:** Detection algorithms tested (test_data_detection.R), file handlers partially tested, curation untested

### CAS Validation Fails Silently on API Errors
- **Issue:** `validate_cas_numbers()` in `R/curation.R` (lines 9-16) doesn't handle API failures - returns invalid data without warning
- **Files:** `R/curation.R` (lines 9-16), `R/curation.R` (lines 105-123)
- **Impact:** Users believe validation succeeded when all CAS numbers actually failed validation, producing unreliable curated datasets
- **Fix approach:**
  1. Wrap ComptoxR calls in `tryCatch()` to catch API errors
  2. Check for NA results in validated_cas column - indicates failed validation
  3. Add warning if validation success rate drops below threshold (e.g., < 50%)
  4. Log API errors with timestamp and context for debugging
  5. Display validation rate in UI (currently no feedback on API failures)

### ComptoxR Package Not Version-Pinned
- **Issue:** `load_packages.R` uses ComptoxR without version specification - breaking API changes could silently break entire curation pipeline
- **Files:** `load_packages.R` (line 180 referenced in app.R line 24)
- **Impact:** HIGH - Library updates could change function signatures, return formats, or API endpoints without warning
- **Fix approach:**
  1. Pin ComptoxR to specific CRAN release (e.g., `pak::pkg_install("ComptoxR@0.1.0")`)
  2. Add version compatibility check at app startup - halt with user-friendly message if incompatible
  3. Document minimum/maximum compatible versions in README
  4. Set up CI/CD to test against package updates before merging

### API Key Setup Not Documented
- **Issue:** ComptoxR API key setup is completely undocumented - users won't know to set `ctx_api_key` environment variable
- **Files:** `app.R` (line 927 checks for key), README.md (no documentation)
- **Impact:** Curation feature silently fails with cryptic "API key not set" error, users assume app is broken
- **Fix approach:**
  1. Create `.env.example` template with `ctx_api_key=your_key_here` comment
  2. Add setup section to README with step-by-step API key generation instructions
  3. Validate API key exists at app startup (not just when curation runs) - show warning in sidebar if missing
  4. Add visual indicator in UI (e.g., orange warning badge) if key not configured
  5. Provide link to ComptoxR API documentation in error message

### File Upload Edge Cases Not Tested
- **Issue:** `R/file_handlers.R` detection algorithms designed for typical cases but untested on real-world edge cases
- **Files:** `R/file_handlers.R` (lines 10-131), `app.R` (lines 318-443)
- **Impact:** App crashes on legitimate but unusual files (non-Latin encodings, single-column, 1000+ column files)
- **Fix approach:**
  1. Create `tests/test_file_handlers_edge_cases.R` with edge case coverage
  2. Add tests for very large files near 50MB limit
  3. Add tests for single-column files (edge case for fill_ratio calculation)
  4. Add tests for 1000+ column files (potential performance/memory issue)
  5. Add tests for corrupted/truncated files (partial reads)
  6. Add tests for non-Latin encodings (Big5, Shift-JIS, GB2312)
  7. Test recovery and error messaging for each case

## Known Bugs

### Column Names with Special Characters Break Tagging UI
- **Issue:** Columns with special characters like "Conc (µg/L)" produce invalid Shiny input IDs when passed to `paste0("tag_", make.names(col))`
- **Files:** `app.R` (lines 848, 869), `R/data_detection.R`
- **Trigger:** Upload file with chemistry column headers containing units like "ppm", "µg/L", "(w/w)", brackets
- **Symptoms:** Tagging UI doesn't render dropdown for affected columns, or JS console shows invalid ID errors
- **Workaround:** None - users must remove/rename columns before upload
- **Fix approach:**
  1. Use index-based input IDs instead of column names (e.g., `tag_col_3` instead of `tag_Conc_(µg/L)`)
  2. Store mapping between index and column name in reactive value
  3. Retrieve tags by index and map back to column name in apply_tags handler
  4. Update all validation logic to use index-based lookups

### Detection Mode Switch Fails Silently with No Data
- **Issue:** Switching between auto/manual detection modes when no file is loaded doesn't trigger validation or show feedback
- **Files:** `app.R` (lines 447-499 - observeEvent for detection_mode/manual_header_row)
- **Impact:** Confusing UX - user changes setting but nothing happens, appears broken
- **Trigger:** Click detection mode radio buttons before uploading file
- **Fix approach:**
  1. Add `req(data_store$raw)` check at start of observeEvent handler
  2. Show `showNotification()` with helpful message if precondition not met: "Please upload a file first"
  3. Add visual indication in UI (disabled state or tooltip) when file required

### Manual Header Row Validation Missing
- **Issue:** Manual header row input accepts any value - user can enter row 500 in a 100-row file, causing silent failures
- **Files:** `app.R` (lines 109-116 - manual_header_row input, lines 447 detection mode change)
- **Impact:** User enters invalid row number, detection runs with garbage result, data appears corrupted
- **Trigger:** Manually type large number into "Header Row Number" field
- **Fix approach:**
  1. Set numericInput `max` dynamically based on file dimensions: `max = nrow(data_store$raw)`
  2. Add validation in detection change observeEvent: `if (input$manual_header_row > nrow(data_store$raw)) { showNotification(...); return() }`
  3. Disable manual_header_row input until file is loaded
  4. Update max value every time new file is loaded

## Fragile Areas

### Reactive Values Lack Type Safety
- **Issue:** `data_store` is untyped `reactiveValues()` - no enforcement of expected structure
- **Files:** `app.R` (lines 281-293)
- **Why fragile:** Typos in store keys (`data_store$clean` vs `data_store$clea`), missing initialization, type mismatches cause runtime errors in downstream observers
- **Impact:** Refactoring becomes dangerous - renaming or restructuring data_store is error-prone, hard to track all dependent code
- **Safe modification:**
  1. Create validation function `validate_data_store()` that checks all expected keys exist and have correct types
  2. Call at app startup and after any modifications to data_store
  3. Use consistent naming patterns and document expected structure in comments
  4. Consider R6 class or list-based store with accessor methods for more type safety

### Detection Ensemble Doesn't Handle Confidence Ties
- **Issue:** When multiple detection methods produce identical confidence scores, `which.max()` arbitrarily selects first method
- **Files:** `R/data_detection.R` (lines 313-330)
- **Trigger:** Unusual files where heuristic and pattern methods produce identical 0.65 confidence
- **Impact:** Random method selection in tie cases makes results unpredictable, hard to debug when switching between identical-confidence methods
- **Fix approach:**
  1. Add tiebreaker logic: prefer method order (heuristic > pattern > type_consistency)
  2. Document tiebreaker in function comments
  3. Add test case for tie scenario: create file that produces identical confidence scores
  4. Consider weighted voting instead of max selection for more robust ensemble

### Large app.R File with Mixed Concerns
- **Issue:** `app.R` (1127 lines) contains UI definition, server logic, reactive patterns, and data handling in single file
- **Files:** `app.R`
- **Why fragile:** Changes to UI inadvertently break server logic, hard to navigate, testing reactive behavior requires sourcing entire file
- **Scalability:** Adding new curation steps will push file to 1500+ lines, making maintenance very difficult
- **Safe modification:**
  1. Consider extracting curation UI/server into Shiny module (`R/mod_curation.R`)
  2. Extract column selection logic into separate module
  3. Extract data preview tab into module
  4. Use module namespacing to avoid reactive value conflicts
  5. Keep app.R focused on top-level layout and composition

## Performance Bottlenecks

### Detection Scans Row-by-Row Without Vectorization
- **Issue:** Heuristic method in `R/data_detection.R` (lines 23-42) uses `purrr::map_dfr()` to calculate row statistics one at a time
- **Files:** `R/data_detection.R` (lines 23-42)
- **Impact:** Slower than necessary for large files - scans first 50 rows individually instead of vectorized dplyr operations
- **Improvement path:**
  1. Replace `purrr::map_dfr()` loop with `dplyr::across()` vectorized calculation
  2. Use `rowSums(!is.na(df))` instead of manual counting
  3. Benchmark with 10k+ row files to measure improvement
  4. Expected improvement: 5-10x faster on large files

### No Progress Indicator for Curation
- **Issue:** ComptoxR lookups happen synchronously without progress feedback - users don't know if app is working on large files
- **Files:** `R/curation.R` (lines 125-143), `app.R` (lines 923-984)
- **Impact:** With 1000+ rows × 2 chemical columns, curation can take 30-60 seconds with no feedback, appears frozen
- **Improvement path:**
  1. Add `shiny::withProgress()` wrapper in `curate_chemical_data()`
  2. Update progress bar every 50 rows processed
  3. Show estimated time remaining based on rows processed so far
  4. Allow cancellation via reactive stop button (requires async refactoring)
  5. Consider parallel processing with `future::future_apply()` for CPU-bound lookups

### Type Consistency Detection Scans All Candidates Serially
- **Issue:** `detect_by_type_consistency()` (lines 196-244) tests candidates sequentially instead of vectorized
- **Files:** `R/data_detection.R` (lines 196-244)
- **Current approach:** Tests first 20 candidate header rows, each scanning 50 data rows, 20 scoring operations
- **Improvement path:**
  1. Vectorize type checking with `apply()` or `dplyr::across()` per candidate
  2. Stop early if high-confidence candidate found (confidence > 0.9)
  3. Benchmark improvement on 1000+ row files
  4. Expected improvement: 3-5x faster

## Scaling Limits

### ComptoxR API Rate Limiting Not Handled
- **Issue:** No retry logic or rate limiting awareness in curation functions
- **Files:** `R/curation.R` (lines 40-45, lines 130)
- **Current capacity:** Unknown - depends on ComptoxR API plan tier
- **Limit:** API calls will fail silently after hitting rate limit
- **Scaling path:**
  1. Add `Sys.sleep()` delay between batch requests (e.g., 0.5s per API call)
  2. Implement exponential backoff retry for failed requests (max 3 retries)
  3. Cache lookup results in temp table to avoid re-querying same chemical
  4. Document API rate limits in README and warn if processing large batches

### File Upload Temporary Storage
- **Issue:** No cleanup of uploaded files in Shiny's default temp directory
- **Files:** `app.R` (lines 322)
- **Current capacity:** 50MB per file × unknown session count = potential disk fill
- **Limit:** Server disk could fill up if many concurrent users upload and don't clear sessions
- **Scaling path:**
  1. Set Shiny session timeout to 1 hour (cleanup temp files)
  2. Add explicit file cleanup on reset button: `unlink(input$file_upload$datapath)`
  3. Monitor `/tmp` or equivalent for orphaned Shiny temp files
  4. Document deployment recommendations for production cleanup

## Security Considerations

### No Authentication for Deployed App
- **Issue:** Application has no login/auth mechanism - currently local-only, but if deployed publicly, anyone can access
- **Files:** `app.R` (no auth module)
- **Risk:** If deployed without auth, users can:
  - Upload sensitive chemical inventory data
  - Access others' uploaded files (if stored on server)
  - Abuse API key if exposed in environment
- **Current mitigation:** Runs locally during development
- **Recommendations:**
  1. For production deployment, add `shinymanager::secure_app()` wrapper
  2. Use environment-based auth enable/disable (auth only if `DEPLOY_ENV=production`)
  3. Implement session timeout (30 min inactivity)
  4. Log all data curation requests with user/timestamp
  5. Encrypt uploaded files if stored on server
  6. Add security notice in README if public deployment planned

### ComptoxR API Key in Environment
- **Issue:** API key stored as plain text environment variable, visible in `Sys.getenv("ctx_api_key")`
- **Files:** `app.R` (line 927), `load_packages.R`
- **Risk:** If code is debugged/logged, API key could be exposed in console output
- **Mitigation:**
  1. Use `.Renviron` or `.env` file (never commit to git)
  2. Add `.env` and `.Renviron` to `.gitignore` (verify with `git status`)
  3. Mask key in error messages: `substr(key, 1, 4)` + "****"
  4. Consider secrets management tool for production

## Missing Critical Features

### No Batch File Processing
- **Issue:** App processes one file at a time - users with 100 chemical inventory files must upload manually one-by-one
- **Files:** Affects UI flow and curation module
- **Blocks:** Organizations with multiple chemical sources can't efficiently curate all inventories
- **Workaround:** Users can manually concatenate files before upload (error-prone)

### No Session Persistence
- **Issue:** Curation progress lost when user closes app or session expires
- **Files:** `app.R` (no persistence layer)
- **Blocks:** For large datasets (1000+ rows), user must restart entire curation if connection drops
- **Workaround:** None - must re-run from beginning

### No Partial Curation Recovery
- **Issue:** If curation fails on row 500/1000, no checkpoint system - must re-run entire dataset
- **Files:** `R/curation.R` (no checkpointing)
- **Blocks:** Large-scale deployments can't efficiently recover from API failures
- **Workaround:** Run in smaller batches, manually join results

## Test Coverage Gaps

### Reactive UI Logic Untested
- **Issue:** No shinytest2 tests for interactive behaviors
- **Files:** `app.R` (lines 783-824 column selection, lines 863-900 curation UI, lines 447-499 detection switching)
- **What's not tested:** Specific functionality untested
  - Column selection: select all/deselect all buttons
  - Detection mode switching: auto to manual to auto
  - Curation summary UI: displayed with correct counts
  - Download functionality: file format and content validation
- **Risk:** Refactoring reactive patterns could break UI without detection
- **Priority:** HIGH - UI is primary user interface

### Data Export/Join Logic Untested
- **Issue:** No tests for the complex left_join/pivot_wider export logic
- **Files:** `app.R` (lines 1040-1122 download handler)
- **What's not tested:**
  - Export with multiple Name columns
  - Export with multiple CASRN columns
  - Export when curation has no matches
  - Column naming conflicts in pivot_wider
  - XLSX sheet creation with multiple tables
- **Risk:** Users download corrupted/malformed export files without detection
- **Priority:** MEDIUM - affects data integrity after curation

### Detection Method Comparison Untested
- **Issue:** No tests for ensemble method selection and confidence calculation
- **Files:** `R/data_detection.R` (lines 313-330)
- **What's not tested:**
  - Confidence score calculation accuracy
  - Method selection when methods return different header rows
  - Edge case where all methods fail
  - Confidence tie scenarios
- **Risk:** Detection confidence displayed to user could be incorrect or misleading
- **Priority:** MEDIUM

---

*Concerns audit: 2026-02-26*
