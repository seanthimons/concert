# Test file for cleaning_reference.R
# Tests reference list loading with caching

library(withr)

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

    # Check structure - function now returns 7 keys:
    # stop_words, block_patterns, functional_categories added Phase 13;
    # strip_terms added Phase 21; isotope_lookup added Phase 23;
    # unit_map added Phase 29-01; toxval_schema added Phase 29-02
    expect_type(result, "list")
    expected_names <- c(
      "stop_words", "block_patterns", "functional_categories", "strip_terms",
      "isotope_lookup", "unit_map", "toxval_schema"
    )
    expect_true(all(expected_names %in% names(result)))

    # Check types - all should be tibbles
    expect_true(tibble::is_tibble(result$stop_words))
    expect_true(tibble::is_tibble(result$block_patterns))
    expect_true(tibble::is_tibble(result$functional_categories))
    expect_true(tibble::is_tibble(result$strip_terms))
    # isotope_lookup is a list with $lookup (tibble) and $elem_alt_names (character vector)
    expect_type(result$isotope_lookup, "list")
    expect_true(tibble::is_tibble(result$isotope_lookup$lookup))
    # unit_map is a tibble
    expect_true(tibble::is_tibble(result$unit_map))
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

test_that("load_user_reference_lists returns empty typed lists when sidecar is missing", {
  withr::with_tempdir({
    cache_dir <- "test_cache"
    dir.create(cache_dir)

    result <- load_user_reference_lists(cache_dir)

    expect_named(result, c("stop_words", "block_patterns", "strip_terms"))
    expect_true(all(vapply(result, tibble::is_tibble, logical(1))))
    expect_true(all(vapply(result, nrow, integer(1)) == 0L))
    expect_named(result$stop_words, c("term", "source", "active"))
  })
})

test_that("load_user_reference_lists returns empty typed lists when sidecar is malformed", {
  withr::with_tempdir({
    cache_dir <- "test_cache"
    dir.create(cache_dir)
    saveRDS(tibble::tibble(not_term = "bad"), file.path(cache_dir, "user_reference_lists.rds"))

    expect_warning(
      result <- load_user_reference_lists(cache_dir),
      regexp = "malformed"
    )

    expect_true(all(vapply(result, nrow, integer(1)) == 0L))
    expect_named(result$block_patterns, c("term", "source", "active"))
  })
})

test_that("load_user_reference_lists reads empty and populated sidecars", {
  withr::with_tempdir({
    cache_dir <- "test_cache"
    dir.create(cache_dir)
    empty_lists <- list(
      stop_words = tibble::tibble(term = character(), source = character(), active = logical()),
      block_patterns = tibble::tibble(term = character(), source = character(), active = logical()),
      strip_terms = tibble::tibble(term = character(), source = character(), active = logical())
    )
    saveRDS(empty_lists, file.path(cache_dir, "user_reference_lists.rds"))

    empty_result <- load_user_reference_lists(cache_dir)
    expect_true(all(vapply(empty_result, nrow, integer(1)) == 0L))

    populated <- empty_lists
    populated$stop_words <- tibble::tibble(term = "not provided", source = "legacy_seed", active = TRUE)
    populated$strip_terms <- tibble::tibble(term = "modified", source = "legacy_review", active = FALSE)
    saveRDS(populated, file.path(cache_dir, "user_reference_lists.rds"))

    result <- load_user_reference_lists(cache_dir)
    expect_equal(result$stop_words$term, "not provided")
    expect_true(result$stop_words$active)
    expect_equal(result$strip_terms$term, "modified")
    expect_false(result$strip_terms$active)
  })
})

test_that("save_user_reference_lists writes only non-default sidecar rows", {
  withr::with_tempdir({
    cache_dir <- "test_cache"
    refs <- list(
      stop_words = tibble::tibble(
        term = c("test", "custom"),
        source = c("app_default", "user"),
        active = c(TRUE, TRUE)
      ),
      block_patterns = tibble::tibble(term = character(), source = character(), active = logical()),
      strip_terms = tibble::tibble(term = "modified", source = "legacy_review", active = FALSE)
    )

    save_user_reference_lists(refs, cache_dir)
    saved <- readRDS(file.path(cache_dir, "user_reference_lists.rds"))

    expect_equal(saved$stop_words$term, "custom")
    expect_equal(saved$strip_terms$term, "modified")
    expect_false(any(saved$stop_words$source == "app_default"))
  })
})

test_that("load_all_reference_lists merges sidecar rows after defaults and sidecar wins by term", {
  withr::with_tempdir({
    cache_dir <- "test_cache"
    dir.create(cache_dir)
    saveRDS(
      tibble::tibble(
        term = c("unknown", "test"),
        source = "app_default",
        active = TRUE
      ),
      file.path(cache_dir, "stop_words.rds")
    )
    saveRDS(
      list(
        stop_words = tibble::tibble(term = "unknown", source = "user", active = FALSE),
        block_patterns = tibble::tibble(term = character(), source = character(), active = logical()),
        strip_terms = tibble::tibble(term = character(), source = character(), active = logical())
      ),
      file.path(cache_dir, "user_reference_lists.rds")
    )

    result <- load_all_reference_lists(cache_dir)
    unknown_rows <- result$stop_words[result$stop_words$term == "unknown", ]

    expect_equal(nrow(unknown_rows), 1)
    expect_equal(unknown_rows$source, "user")
    expect_false(unknown_rows$active)
  })
})

test_that("update_user_reference_list toggles defaults through sidecar and remove reverts default", {
  withr::with_tempdir({
    cache_dir <- "test_cache"
    dir.create(cache_dir)
    saveRDS(
      tibble::tibble(term = "na", source = "app_default", active = TRUE),
      file.path(cache_dir, "stop_words.rds")
    )

    toggled <- update_user_reference_list("stop_words", "na", action = "toggle", cache_dir = cache_dir)
    na_row <- toggled[toggled$term == "na", ]
    expect_equal(na_row$source, "user")
    expect_false(na_row$active)

    removed <- update_user_reference_list("stop_word", "na", action = "remove", cache_dir = cache_dir)
    reverted_row <- removed[removed$term == "na", ]
    expect_equal(reverted_row$source, "app_default")
    expect_true(reverted_row$active)

    sidecar <- readRDS(file.path(cache_dir, "user_reference_lists.rds"))
    expect_false("na" %in% sidecar$stop_words$term)
  })
})

test_that("load_unit_map returns correct structure", {
  # Locate inst/extdata: when devtools::test() runs, wd is package root;
  # when test_file() runs directly, wd is tests/testthat/. Probe both.
  candidates <- c(
    file.path(getwd(), "inst", "extdata"),
    file.path(getwd(), "..", "..", "inst", "extdata")
  )
  cache_dir <- candidates[sapply(candidates, function(d) file.exists(file.path(d, "unit_conversion.rds")))][1]
  if (is.na(cache_dir)) skip("unit_conversion.rds not found")

  result <- load_unit_map(cache_dir)

  # Check type
  expect_s3_class(result, "tbl_df")

  # Check required columns
  expected_cols <- c("from_unit", "to_unit", "multiplier", "category", "confidence", "source")
  expect_true(all(expected_cols %in% names(result)))

  # Check column types
  expect_type(result$from_unit, "character")
  expect_type(result$to_unit, "character")
  expect_type(result$multiplier, "double")
  expect_type(result$category, "character")
  expect_type(result$confidence, "character")
  expect_type(result$source, "character")

  # Check minimum row count
  expect_gte(nrow(result), 100)
})

test_that("load_unit_map contains expected conversions", {
  # Locate inst/extdata: when devtools::test() runs, wd is package root;
  # when test_file() runs directly, wd is tests/testthat/. Probe both.
  candidates <- c(
    file.path(getwd(), "inst", "extdata"),
    file.path(getwd(), "..", "..", "inst", "extdata")
  )
  cache_dir <- candidates[sapply(candidates, function(d) file.exists(file.path(d, "unit_conversion.rds")))][1]
  if (is.na(cache_dir)) skip("unit_conversion.rds not found")

  result <- load_unit_map(cache_dir)

  # Check for ppb -> mg/L conversion
  ppb_row <- result[result$from_unit == "ppb" & result$to_unit == "mg/L", ]
  expect_equal(nrow(ppb_row), 1)
  expect_equal(ppb_row$multiplier, 0.001)

  # Check for ug/L -> mg/L conversion
  ugl_row <- result[result$from_unit == "ug/L" & result$to_unit == "mg/L", ]
  expect_equal(nrow(ugl_row), 1)
  expect_equal(ugl_row$multiplier, 0.001)
})

test_that("load_all_reference_lists includes unit_map", {
  withr::with_tempdir({
    cache_dir <- "test_cache"
    result <- load_all_reference_lists(cache_dir)

    expect_true("unit_map" %in% names(result))
  })
})

test_that("load_toxval_schema returns zero-row typed tibble", {
  # Locate inst/extdata: when devtools::test() runs, wd is package root;
  # when test_file() runs directly, wd is tests/testthat/. Probe both.
  candidates <- c(
    file.path(getwd(), "inst", "extdata"),
    file.path(getwd(), "..", "..", "inst", "extdata")
  )
  cache_dir <- candidates[sapply(candidates, function(d) file.exists(file.path(d, "toxval_schema.rds")))][1]
  if (is.na(cache_dir)) skip("toxval_schema.rds not found")

  result <- load_toxval_schema(cache_dir)

  # Check type
  expect_s3_class(result, "tbl_df")

  # Check zero rows
  expect_equal(nrow(result), 0)

  # Check 56 columns
  expect_equal(ncol(result), 56)
})

test_that("load_toxval_schema has required columns", {
  candidates <- c(
    file.path(getwd(), "inst", "extdata"),
    file.path(getwd(), "..", "..", "inst", "extdata")
  )
  cache_dir <- candidates[sapply(candidates, function(d) file.exists(file.path(d, "toxval_schema.rds")))][1]
  if (is.na(cache_dir)) skip("toxval_schema.rds not found")

  result <- load_toxval_schema(cache_dir)

  # Core identifier columns
  expect_true("dtxsid" %in% names(result))
  expect_true("casrn" %in% names(result))
  expect_true("name" %in% names(result))

  # Toxicity value columns
  expect_true("toxval_type" %in% names(result))
  expect_true("toxval_numeric" %in% names(result))
  expect_true("toxval_units" %in% names(result))
  expect_true("toxval_numeric_qualifier" %in% names(result))

  # Audit columns
  expect_true("toxval_numeric_original" %in% names(result))
  expect_true("toxval_units_original" %in% names(result))
  expect_true("conversion_factor" %in% names(result))
  expect_true("parse_flag" %in% names(result))
})

test_that("load_toxval_schema uses typed NA values", {
  candidates <- c(
    file.path(getwd(), "inst", "extdata"),
    file.path(getwd(), "..", "..", "inst", "extdata")
  )
  cache_dir <- candidates[sapply(candidates, function(d) file.exists(file.path(d, "toxval_schema.rds")))][1]
  if (is.na(cache_dir)) skip("toxval_schema.rds not found")

  result <- load_toxval_schema(cache_dir)

  # Check that character columns are character type (not logical from bare NA)
  col_types <- sapply(result, typeof)

  # No logical types (indicates bare NA)
  expect_false(any(col_types == "logical"))

  # dtxsid should be character
  expect_equal(typeof(result$dtxsid), "character")

  # toxval_numeric should be double
  expect_equal(typeof(result$toxval_numeric), "double")

  # year should be integer
  expect_equal(typeof(result$year), "integer")
})

test_that("load_all_reference_lists includes toxval_schema", {
  withr::with_tempdir({
    cache_dir <- "test_cache"
    result <- load_all_reference_lists(cache_dir)

    expect_true("toxval_schema" %in% names(result))
  })
})
