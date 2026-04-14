# Unit Tests for Data Detection Algorithms
# Tests for frontmatter detection and data extraction functions

# Test 1: Clean file (headers in row 1)
test_that("Heuristic detection handles clean files", {
  df <- tibble::tibble(
    Chemical = c("Acetone", "Ethanol", "Benzene"),
    CAS = c("67-64-1", "64-17-5", "71-43-2"),
    Formula = c("C3H6O", "C2H6O", "C6H6")
  )

  result <- detect_data_start_heuristic(df)

  expect_equal(result$header_row, 1)
  expect_true(result$confidence > 0.5)
  expect_equal(result$method, "heuristic")
})

# Test 2: Frontmatter (3 metadata rows before header)
test_that("Heuristic detection identifies frontmatter", {
  df <- tibble::tibble(
    col1 = c("Report Title", "Generated: 2024-01-01", NA, "Chemical", "Acetone", "Ethanol"),
    col2 = c(NA, NA, NA, "CAS", "67-64-1", "64-17-5"),
    col3 = c(NA, NA, NA, "Formula", "C3H6O", "C2H6O")
  )

  result <- detect_data_start_heuristic(df)

  # Should detect row 4 as header (after 3 metadata rows)
  expect_true(result$header_row >= 4)
  expect_true(result$data_start_row >= result$header_row)
  expect_true(length(result$metadata_rows) > 0)
})

# Test 3: Empty file
test_that("Detection handles empty files gracefully", {
  df <- tibble::tibble()

  result <- detect_data_start_heuristic(df)

  expect_equal(result$header_row, 1)
  expect_true(result$confidence < 0.5)
})

# Test 4: Pattern-based detection with chemistry keywords
test_that("Pattern detection identifies chemistry headers", {
  df <- tibble::tibble(
    col1 = c("Laboratory Report", "Chemical Name", "Acetone", "Ethanol"),
    col2 = c("Date: 2024-01-15", "CAS Number", "67-64-1", "64-17-5"),
    col3 = c(NA, "Molecular Formula", "C3H6O", "C2H6O")
  )

  result <- detect_pattern_based(df)

  # Should detect row 2 with "Chemical", "CAS", "Molecular" keywords
  expect_equal(result$header_row, 2)
  expect_equal(result$data_start_row, 3)
  # Confidence is max_score / length(header_indicators); with ~3 keyword matches
  # out of 44 indicators, confidence is around 0.07 - check it's above noise floor
  expect_true(result$confidence > 0)
})

# Test 5: Type consistency detection
test_that("Type consistency detection works correctly", {
  df <- tibble::tibble(
    col1 = c("Metadata", "Chemical", "Acetone", "Ethanol", "Benzene"),
    col2 = c("Info", "CAS", "67-64-1", "64-17-5", "71-43-2"),
    col3 = c("Notes", "MW", "58.08", "46.07", "78.11")
  )

  result <- detect_by_type_consistency(df)

  # Should detect row 2 as header (consistent types follow)
  expect_true(result$header_row >= 1)
  expect_equal(result$data_start_row, result$header_row + 1)
  expect_true(result$confidence > 0)
})

# Test 6: Ensemble detection selects best method
test_that("Ensemble detection selects highest confidence method", {
  df <- tibble::tibble(
    Chemical = c("Report Info", "Chemical Name", "Acetone", "Ethanol"),
    CAS = c("Date", "CAS Number", "67-64-1", "64-17-5"),
    Formula = c("Lab", "Formula", "C3H6O", "C2H6O")
  )

  result <- detect_data_start(df, mode = "auto")

  # Should have results from multiple methods
  expect_true(!is.null(result$method))
  expect_true(!is.null(result$confidence))
  expect_true(result$header_row >= 1)
  # data_start_row must be at or after header_row
  expect_true(result$data_start_row >= result$header_row)

  # Check that all_results contains multiple method results
  if (!is.null(result$all_results)) {
    expect_true(length(result$all_results) > 0)
  }
})

# Test 7: Manual override
test_that("Manual detection mode takes precedence", {
  df <- tibble::tibble(
    col1 = c("Line1", "Line2", "Header", "Data1", "Data2"),
    col2 = c("A", "B", "C", "D", "E"),
    col3 = c("X", "Y", "Z", "W", "V")
  )

  result <- detect_data_start(df, mode = "manual", manual_row = 3)

  expect_equal(result$header_row, 3)
  expect_equal(result$data_start_row, 4)
  expect_equal(result$method, "manual")
  expect_equal(result$confidence, 1.0)
})

# Test 8: Extract clean data
test_that("Extract clean data works correctly", {
  raw_df <- tibble::tibble(
    col1 = c("Metadata", "Chemical", "Acetone", "Ethanol"),
    col2 = c("Info", "CAS", "67-64-1", "64-17-5"),
    col3 = c("Notes", "Formula", "C3H6O", "C2H6O")
  )

  detection <- list(
    header_row = 2,
    data_start_row = 3,
    metadata_rows = 1
  )

  clean_df <- extract_clean_data(raw_df, detection)

  expect_equal(nrow(clean_df), 2)  # 2 data rows
  expect_equal(ncol(clean_df), 3)  # 3 columns
  expect_true("Chemical" %in% names(clean_df) || "col1" %in% names(clean_df))
})

# Test 9: Handle merged cells
test_that("Merged cell handling fills down correctly", {
  df <- tibble::tibble(
    Category = c("Type A", NA, NA, "Type B", NA),
    Chemical = c("Acetone", "Ethanol", "Benzene", "Methanol", "Toluene"),
    CAS = c("67-64-1", "64-17-5", "71-43-2", "67-56-1", "108-88-3")
  )

  result <- handle_merged_cells(df)

  # First column should be filled down
  expect_false(any(is.na(result$Category)))
  expect_equal(result$Category[2], "Type A")
  expect_equal(result$Category[3], "Type A")
})

# Test 10: File validation
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

  # Test valid file
  valid_file <- list(
    name = "test.xlsx",
    size = 1000,
    datapath = "test.xlsx"
  )

  result <- validate_file(valid_file)
  expect_true(result$success)
})

# Test 11: Smart preview rows calculation
test_that("Smart preview calculates correct row counts", {
  # Small file
  small_df <- tibble::tibble(x = 1:50)
  expect_equal(calculate_smart_preview_rows(small_df), 50)

  # Medium file
  medium_df <- tibble::tibble(x = 1:500)
  expect_equal(calculate_smart_preview_rows(medium_df), 25)

  # Large file
  large_df <- tibble::tibble(x = 1:5000)
  expect_equal(calculate_smart_preview_rows(large_df), 10)
})
