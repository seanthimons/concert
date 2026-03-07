# Test file for cleaning_reference.R
# Tests reference list loading with caching

library(testthat)
library(here)
library(withr)

# Source the reference module
source(here::here("R", "cleaning_reference.R"))

test_that("load_or_fetch_reference reads from existing cache", {
  withr::with_tempdir({
    # Create a test cache directory
    cache_dir <- "test_cache"
    dir.create(cache_dir)
    cache_path <- file.path(cache_dir, "test_data.rds")

    # Create a cache file with known data
    test_data <- c("item1", "item2", "item3")
    saveRDS(test_data, cache_path)

    # Track if fetch_fn was called
    fetch_called <- FALSE
    fetch_fn <- function() {
      fetch_called <<- TRUE
      return(c("should", "not", "see", "this"))
    }

    # Load from cache
    result <- load_or_fetch_reference(cache_path, fetch_fn, "test_data")

    # Verify: should return cached data, not call fetch_fn
    expect_equal(result, test_data)
    expect_false(fetch_called)
  })
})

test_that("load_or_fetch_reference calls fetch_fn when cache missing", {
  withr::with_tempdir({
    # Create a test cache directory
    cache_dir <- "test_cache"
    cache_path <- file.path(cache_dir, "test_data.rds")

    # No cache file exists yet
    expect_false(file.exists(cache_path))

    # Track if fetch_fn was called
    fetch_called <- FALSE
    test_data <- c("fetched", "data")
    fetch_fn <- function() {
      fetch_called <<- TRUE
      return(test_data)
    }

    # Load (should fetch and cache)
    result <- load_or_fetch_reference(cache_path, fetch_fn, "test_data")

    # Verify: should call fetch_fn and save to disk
    expect_true(fetch_called)
    expect_equal(result, test_data)
    expect_true(file.exists(cache_path))

    # Verify cached data is correct
    cached_data <- readRDS(cache_path)
    expect_equal(cached_data, test_data)
  })
})

test_that("load_or_fetch_reference creates cache directory if missing", {
  withr::with_tempdir({
    # Create a nested cache path where parent directory doesn't exist
    cache_path <- file.path("deep", "nested", "cache", "test_data.rds")

    # Verify directory doesn't exist
    expect_false(dir.exists(dirname(cache_path)))

    # Fetch function
    test_data <- c("data")
    fetch_fn <- function() test_data

    # Load (should create directory and cache)
    result <- load_or_fetch_reference(cache_path, fetch_fn, "test_data")

    # Verify: directory was created and file was saved
    expect_true(dir.exists(dirname(cache_path)))
    expect_true(file.exists(cache_path))
    expect_equal(result, test_data)
  })
})

test_that("load_all_reference_lists returns expected structure", {
  withr::with_tempdir({
    cache_dir <- "test_cache"

    result <- load_all_reference_lists(cache_dir)

    # Check structure
    expect_type(result, "list")
    expect_named(result, c("stop_words", "block_patterns", "functional_categories"))

    # Check types - all should be tibbles now (Phase 13 change)
    expect_true(tibble::is_tibble(result$stop_words))
    expect_true(tibble::is_tibble(result$block_patterns))
    expect_true(tibble::is_tibble(result$functional_categories))
  })
})

test_that("load_stop_words returns expected default stop words", {
  withr::with_tempdir({
    cache_dir <- "test_cache"

    result <- load_stop_words(cache_dir)

    # Check type - now returns tibble (Phase 13 change)
    expect_true(tibble::is_tibble(result))
    expect_named(result, c("term", "source", "active"))

    # Check for expected keywords in term column
    expect_true("test" %in% result$term)
    expect_true("sample" %in% result$term)
    expect_true("unknown" %in% result$term)
    expect_true("blank" %in% result$term)
    expect_true("standard" %in% result$term)
  })
})

test_that("load_block_patterns returns expected default block patterns", {
  withr::with_tempdir({
    cache_dir <- "test_cache"

    result <- load_block_patterns(cache_dir)

    # Check type - now returns tibble (Phase 13 change)
    expect_true(tibble::is_tibble(result))
    expect_named(result, c("term", "source", "active"))

    # Check for expected patterns in term column (partial match since they're regex)
    expect_true(any(grepl("proprietary", result$term, ignore.case = TRUE)))
    expect_true(any(grepl("confidential", result$term, ignore.case = TRUE)))

    # Should be regex patterns (not empty strings)
    expect_true(all(nchar(result$term) > 0))
  })
})
