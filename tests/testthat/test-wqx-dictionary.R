# Test file for WQX dictionary loader functions
# Tests DICT-01, DICT-02, DICT-03 requirements

library(withr)

# Shared mock tibble used across tests 1-3
mock_wqx <- tibble::tibble(
  name           = c("Dissolved oxygen", "DO"),
  canonical_name = c("Dissolved oxygen", "Dissolved oxygen"),
  type           = c("canonical", "synonym"),
  cas_number     = c("7782-44-7", NA_character_),
  group_name     = c("Inorganics, Major, Non-metals", NA_character_),
  description    = c("A measure of dissolved O2", "Alias for dissolved oxygen")
)

test_that("load_wqx_dictionary returns cached tibble when RDS exists", {
  withr::with_tempdir({
    # Pre-create wqx_dictionary.rds with mock tibble
    saveRDS(mock_wqx, "wqx_dictionary.rds", compress = FALSE)

    # Track if .build_wqx_dictionary was called
    build_called <- FALSE
    testthat::local_mocked_bindings(
      .build_wqx_dictionary = function() {
        build_called <<- TRUE
        mock_wqx
      },
      .package = "chemreg"
    )

    result <- load_wqx_dictionary(cache_dir = ".")

    expect_equal(result, mock_wqx)
    expect_false(build_called, info = ".build_wqx_dictionary should NOT be called when cache exists")
  })
})

test_that("load_wqx_dictionary calls build when cache is absent", {
  withr::with_tempdir({
    # No RDS exists
    expect_false(file.exists("wqx_dictionary.rds"))

    testthat::local_mocked_bindings(
      .build_wqx_dictionary = function() mock_wqx,
      .package = "chemreg"
    )

    result <- load_wqx_dictionary(cache_dir = ".")

    # RDS should now exist
    expect_true(file.exists("wqx_dictionary.rds"))

    # Result matches mock tibble
    expect_equal(result, mock_wqx)

    # Read back the saved RDS to confirm contents were persisted
    cached <- readRDS("wqx_dictionary.rds")
    expect_equal(cached, mock_wqx)
  })
})

test_that("refresh_wqx_cache overwrites existing RDS", {
  withr::with_tempdir({
    # Pre-create old RDS
    old_rds <- tibble::tibble(name = "old")
    saveRDS(old_rds, "wqx_dictionary.rds", compress = FALSE)

    new_mock <- mock_wqx

    testthat::local_mocked_bindings(
      .build_wqx_dictionary = function() new_mock,
      .package = "chemreg"
    )

    result <- refresh_wqx_cache(cache_dir = ".")

    # RDS on disk should now be the new mock
    on_disk <- readRDS("wqx_dictionary.rds")
    expect_equal(on_disk, new_mock)

    # Old data is gone
    expect_false("name" %in% names(on_disk) && nrow(on_disk) == 1 && on_disk$name == "old")

    # Return value (invisible) matches new mock
    expect_equal(result, new_mock)
  })
})

test_that("pre-built wqx_dictionary.rds has correct structure", {
  # Two-candidate probe: package root (devtools::test()) vs tests/testthat/ (test_file())
  candidates <- c(
    file.path(getwd(), "inst", "extdata", "reference_cache"),
    file.path(getwd(), "..", "..", "inst", "extdata", "reference_cache")
  )
  cache_dir <- candidates[sapply(candidates, function(d) file.exists(file.path(d, "wqx_dictionary.rds")))][1]
  if (is.na(cache_dir)) {
    skip("wqx_dictionary.rds not found — run scripts/build_wqx_dictionary.R first")
  }

  result <- readRDS(file.path(cache_dir, "wqx_dictionary.rds"))

  expect_s3_class(result, "tbl_df")
  expect_named(result, c("name", "canonical_name", "type", "cas_number", "group_name", "description"))

  # Type values must be the 4 defined values only
  expect_true(all(result$type %in% c("canonical", "synonym", "standardize", "retired")))

  # name must never be NA
  expect_true(all(!is.na(result$name)))

  # Canonical rows: name == canonical_name
  canonicals <- result[result$type == "canonical", ]
  expect_true(all(canonicals$name == canonicals$canonical_name))

  # Alias rows: cas_number must be NA
  aliases <- result[result$type != "canonical", ]
  expect_true(all(is.na(aliases$cas_number)))

  # Row count: expected ~124K (canonical 23,304 + alias 100,766)
  expect_gte(nrow(result), 120000)
})
