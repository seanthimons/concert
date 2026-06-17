# Test file for reference list provenance tracking
# Tests that reference lists return tibbles with (term, source, active) columns

library(withr)

reference_schema <- c("term", "pattern", "match_mode", "source", "active", "notes")

test_that("load_stop_words returns tibble with provenance columns", {
  withr::with_tempdir({
    cache_dir <- "test_cache"

    result <- load_stop_words(cache_dir)

    # Check structure: should be tibble with term, source, active columns
    expect_true(tibble::is_tibble(result))
    expect_named(result, reference_schema)

    # Check column types
    expect_type(result$term, "character")
    expect_type(result$pattern, "character")
    expect_type(result$match_mode, "character")
    expect_type(result$source, "character")
    expect_type(result$active, "logical")

    # Check content
    expect_true(nrow(result) > 0)
    expect_true("test" %in% result$term)
    expect_true("sample" %in% result$term)
    expect_true("unknown" %in% result$term)

    # All stop words should have source = "app_default" and active = TRUE
    expect_true(all(result$source == "app_default"))
    expect_true(all(result$active == TRUE))
  })
})

test_that("load_block_patterns returns tibble with provenance columns", {
  withr::with_tempdir({
    cache_dir <- "test_cache"

    result <- load_block_patterns(cache_dir)

    # Check structure
    expect_true(tibble::is_tibble(result))
    expect_named(result, reference_schema)

    # Check column types
    expect_type(result$term, "character")
    expect_type(result$pattern, "character")
    expect_type(result$match_mode, "character")
    expect_type(result$source, "character")
    expect_type(result$active, "logical")

    # Check content
    expect_true(nrow(result) > 0)
    expect_true(any(grepl("proprietary", result$term, ignore.case = TRUE)))
    expect_true(any(grepl("confidential", result$term, ignore.case = TRUE)))

    # All block patterns should have source = "app_default" and active = TRUE
    expect_true(all(result$source == "app_default"))
    expect_true(all(result$active == TRUE))
  })
})

test_that("load_functional_categories returns tibble with provenance columns when ComptoxR available", {
  withr::with_tempdir({
    cache_dir <- "test_cache"

    result <- load_functional_categories(cache_dir)

    # Check structure
    expect_true(tibble::is_tibble(result))
    expect_named(result, reference_schema)

    # Check column types
    expect_type(result$term, "character")
    expect_type(result$pattern, "character")
    expect_type(result$match_mode, "character")
    expect_type(result$source, "character")
    expect_type(result$active, "logical")

    # If ComptoxR is available, entries should have source = "comptoxr"
    # If not available, should be empty tibble with correct columns
    if (nrow(result) > 0) {
      expect_true(all(grepl("^comptoxr", result$source, ignore.case = TRUE)))
      expect_true(all(result$active == TRUE))
    }
  })
})

test_that("load_functional_categories returns empty tibble with correct columns when ComptoxR unavailable", {
  withr::with_tempdir({
    cache_dir <- "test_cache"

    # Force ComptoxR to be unavailable by mocking requireNamespace
    local_mocked_bindings(
      requireNamespace = function(...) FALSE,
      .package = "base"
    )

    result <- load_functional_categories(cache_dir)

    # Should return empty tibble with correct columns
    expect_true(tibble::is_tibble(result))
    expect_named(result, reference_schema)
    expect_equal(nrow(result), 0)

    # Check column types
    expect_type(result$term, "character")
    expect_type(result$pattern, "character")
    expect_type(result$match_mode, "character")
    expect_type(result$source, "character")
    expect_type(result$active, "logical")
  })
})

test_that("load_all_reference_lists returns named list with all three tibbles", {
  withr::with_tempdir({
    cache_dir <- "test_cache"

    result <- load_all_reference_lists(cache_dir)

    # Check structure
    expect_type(result, "list")
    expected_names <- c("stop_words", "block_patterns", "functional_categories", "strip_terms", "isotope_lookup")
    expect_true(all(expected_names %in% names(result)))

    # Check all are tibbles (isotope_lookup is a list with $lookup tibble)
    expect_true(tibble::is_tibble(result$stop_words))
    expect_true(tibble::is_tibble(result$block_patterns))
    expect_true(tibble::is_tibble(result$functional_categories))
    expect_true(tibble::is_tibble(result$strip_terms))
    expect_type(result$isotope_lookup, "list")
    expect_true(tibble::is_tibble(result$isotope_lookup$lookup))

    # Check all have correct columns
    expect_named(result$stop_words, reference_schema)
    expect_named(result$block_patterns, reference_schema)
    expect_named(result$functional_categories, reference_schema)
  })
})
