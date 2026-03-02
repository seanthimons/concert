# Testing Patterns

**Analysis Date:** 2026-02-26

## Test Framework

**Runner:**
- `testthat` (in `booster_pack` of `load_packages.R` line 148)
- Version: Latest available via pak
- Config: `tests/test_data_detection.R`

**Assertion Library:**
- `testthat` built-in expectations: `expect_equal()`, `expect_true()`, `expect_false()`, `expect_gt()`

**Run Commands:**
```bash
# Run all tests from R console
source("load_packages.R")
testthat::test_dir("tests")

# Or run single test file
source("tests/test_data_detection.R")

# From command line (if Rscript available)
Rscript -e "source('load_packages.R'); testthat::test_dir('tests')"
```

**Test Output:**
- Wrapped in header/footer messages (test_data_detection.R:212-214):
```r
cat("\n=== Running Chem-Janitor Data Detection Tests ===\n\n")
test_dir(here::here("tests"))
cat("\n=== Tests Complete ===\n")
```

## Test File Organization

**Location:**
- All tests in `tests/` directory
- Currently only `tests/test_data_detection.R` (11 test cases)

**Naming:**
- Pattern: `test_<module>.R`
- Example: `test_data_detection.R` tests functions in `R/data_detection.R`

**Structure:**
```
tests/
└── test_data_detection.R    # Tests for detection and file handling logic
```

## Test Structure

**Suite Organization (test_data_detection.R):**
```r
library(testthat)
library(here)
library(tibble)
library(dplyr)

# Source the functions being tested
source(here::here("R", "data_detection.R"))
source(here::here("R", "file_handlers.R"))

# Test case 1
test_that("Description of what is being tested", {
  # Setup
  df <- tibble::tibble(...)

  # Execute
  result <- some_function(df)

  # Assert
  expect_equal(result$field, expected_value)
  expect_true(result$confidence > 0.5)
})

# Test case 2
test_that("Another test case", {
  # Setup and assertions
})
```

**Patterns:**

1. **Setup Pattern:** Create test data using `tibble::tibble()`:
```r
# Test 1 (test_data_detection.R:14-26)
test_that("Heuristic detection handles clean files", {
  df <- tibble::tibble(
    Chemical = c("Acetone", "Ethanol", "Benzene"),
    CAS = c("67-64-1", "64-17-5", "71-43-2"),
    Formula = c("C3H6O", "C2H6O", "C6H6")
  )
})
```

2. **Teardown Pattern:** None explicitly defined; relies on R's automatic cleanup of local variables

3. **Assertion Pattern:** Mix of state-checking and value-matching assertions:
```r
expect_equal(result$header_row, 1)           # Exact equality
expect_true(result$confidence > 0.5)          # Logical conditions
expect_equal(result$method, "heuristic")      # String matching
expect_true(length(result$metadata_rows) > 0) # Length checks
expect_false(any(is.na(result$Category)))     # Aggregate checks
```

## Mocking

**Framework:** `purrr::safely()` for wrapped error handling in tests

**Patterns:**
- No explicit mocking library used (no mockr, testthat::with_mock, etc.)
- Tests work with actual functions, not mocks
- External API calls (ComptoxR) not tested yet; would need mocking infrastructure

**What to Mock:**
- External API calls to ComptoxR `ct_search()` and EPA CompTox Dashboard
- File I/O operations (read_csv_robust, read_excel_robust) when testing detection logic

**What NOT to Mock:**
- Core detection algorithms (should test with real tibbles)
- Data frame manipulation (tests should use real dplyr/tidyr operations)
- Validation logic (test with real edge cases)

## Fixtures and Factories

**Test Data:**
All test data created inline using `tibble::tibble()` with synthetic chemical data:

```r
# Test 3 - Frontmatter case (test_data_detection.R:29-42)
df <- tibble::tibble(
  col1 = c("Report Title", "Generated: 2024-01-01", NA, "Chemical", "Acetone", "Ethanol"),
  col2 = c(NA, NA, NA, "CAS", "67-64-1", "64-17-5"),
  col3 = c(NA, NA, NA, "Formula", "C3H6O", "C2H6O")
)

# Test 7 - Manual override (test_data_detection.R:110-122)
df <- tibble::tibble(
  col1 = c("Line1", "Line2", "Header", "Data1", "Data2"),
  col2 = c("A", "B", "C", "D", "E"),
  col3 = c("X", "Y", "Z", "W", "V")
)
```

**Common Chemical Test Values:**
- `"Acetone"` with CAS `"67-64-1"`
- `"Ethanol"` with CAS `"64-17-5"`
- `"Benzene"` with CAS `"71-43-2"`
- Formulas: `"C3H6O"`, `"C2H6O"`, `"C6H6"`

**Location:**
- Inline in test functions (no separate fixtures directory)
- Could be extracted to `tests/fixtures/` if test suite expands

## Coverage

**Requirements:** Not enforced; no coverage threshold configuration

**View Coverage:** Not configured; would need `covr` package

**Current Coverage:**
- 11 test cases covering:
  - Heuristic detection (test 1-3)
  - Pattern-based detection (test 4)
  - Type consistency detection (test 5)
  - Ensemble selection (test 6)
  - Manual override (test 7)
  - Data extraction (test 8)
  - Merged cells handling (test 9)
  - File validation (test 10)
  - Smart preview calculation (test 11)

**Untested Areas:**
- Shiny UI/server logic (no Shiny testing infrastructure)
- Curation functions (`R/curation.R` - validate_cas_numbers, lookup_chemical_names, curate_chemical_data)
- File reading functions with actual files (only logic tested)
- Integration tests with real CSV/XLSX files
- Error conditions in Shiny handlers

## Test Types

**Unit Tests:**
- Scope: Individual functions in isolation
- Approach: Call function with controlled inputs, verify output
- Examples: `detect_data_start_heuristic()`, `validate_file()`, `calculate_smart_preview_rows()`
- Found in: `tests/test_data_detection.R` (tests 1-11)

**Integration Tests:**
- Scope: Detection ensemble using multiple methods together
- Approach: Test `detect_data_start()` which combines heuristic + pattern + type_consistency
- Example (test 6): Verify all_results contains multiple method outputs
- Currently: Single integration test (test 6)

**E2E Tests:**
- Framework: Not used
- Status: No end-to-end tests for full upload/process/download workflow
- Would require: ShinyTest or shinytest2 framework

## Common Patterns

**Async Testing:**
Not applicable - R code is synchronous. Shiny handlers use `observeEvent()` but are not tested.

**Error Testing:**
```r
# Test 10 - File validation (test_data_detection.R:162-194)
test_that("File validation catches invalid files", {
  # Test invalid extension
  invalid_file <- list(
    name = "test.txt",
    size = 1000,
    datapath = "test.txt"
  )

  result <- validate_file(invalid_file)
  expect_false(result$success)
  expect_true(grepl("Invalid file type", result$message))

  # Test oversized file
  large_file <- list(
    name = "test.csv",
    size = 60 * 1024^2,  # 60MB
    datapath = "test.csv"
  )

  result <- validate_file(large_file, max_size_mb = 50)
  expect_false(result$success)
  expect_true(grepl("too large", result$message))
})
```

**Edge Case Testing:**
```r
# Test 2 - Empty file (test_data_detection.R:44-52)
test_that("Detection handles empty files gracefully", {
  df <- tibble::tibble()

  result <- detect_data_start_heuristic(df)

  expect_equal(result$header_row, 1)
  expect_true(result$confidence < 0.5)
})

# Test 9 - Merged cells (test_data_detection.R:145-159)
test_that("Merged cell handling fills down correctly", {
  df <- tibble::tibble(
    Category = c("Type A", NA, NA, "Type B", NA),
    Chemical = c("Acetone", "Ethanol", "Benzene", "Methanol", "Toluene"),
    CAS = c("67-64-1", "64-17-5", "71-43-2", "67-56-1", "108-88-3")
  )

  result <- handle_merged_cells(df)

  expect_false(any(is.na(result$Category)))
  expect_equal(result$Category[2], "Type A")
})
```

## Test Dependencies

**Required Packages (from tests):**
- `testthat` - Test framework
- `here` - File path management
- `tibble` - Test data creation
- `dplyr` - Data manipulation in tests
- Plus all packages sourced: `data_detection.R`, `file_handlers.R`

**Setup (test_data_detection.R:1-11):**
```r
library(testthat)
library(here)
library(tibble)
library(dplyr)

source(here::here("R", "data_detection.R"))
source(here::here("R", "file_handlers.R"))
```

## Known Test Gaps

**Critical Untested Areas:**
1. **Shiny Handlers** - No tests for `observeEvent()`, `renderUI()`, `renderDT()` logic
2. **Curation Functions** - `validate_cas_numbers()`, `lookup_chemical_names()`, `curate_chemical_data()` not tested
3. **Real File I/O** - CSV/XLSX reading not tested with actual files
4. **External APIs** - ComptoxR integration not tested
5. **Data Pipeline Validation** - End-to-end workflow not tested

**Recommended Additions:**
- Add `tests/test_curation.R` for chemical lookup functions
- Add `tests/test_file_handlers.R` for robust CSV/Excel reading
- Consider ShinyTest or shinytest2 for UI integration tests
- Mock ComptoxR API calls when testing curation logic

---

*Testing analysis: 2026-02-26*
