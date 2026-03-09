# cleaning_reference.R
# Reference list loaders with local disk caching
#
# Functions for loading stop words, block patterns, and functional categories.
# Uses local RDS cache to avoid repeated API calls or slow initialization.
# ComptoxR is used for functional categories when available.

library(fs)
library(tibble)
library(dplyr)

#' Generic cache-or-fetch function
#'
#' Checks if cache file exists. If yes, reads from disk. If no, calls fetch_fn,
#' creates directory structure, saves result to disk, and returns result.
#'
#' @param cache_path Full path to cache file (e.g., "data/reference_cache/stop_words.rds")
#' @param fetch_fn Function that fetches/generates the data when cache missing
#' @param name Human-readable name for logging
#' @return Data returned by fetch_fn (or read from cache)
#'
#' @examples
#' load_or_fetch_reference("cache/data.rds", function() c("a", "b"), "test_data")
load_or_fetch_reference <- function(cache_path, fetch_fn, name) {
  if (file.exists(cache_path)) {
    message(sprintf("Loading %s from cache: %s", name, cache_path))
    return(readRDS(cache_path))
  }

  message(sprintf("Fetching %s (cache not found)...", name))
  result <- fetch_fn()

  # Create directory if it doesn't exist
  fs::dir_create(dirname(cache_path), recurse = TRUE)

  # Save to cache
  saveRDS(result, cache_path, compress = FALSE)
  message(sprintf("Cached %s to: %s", name, cache_path))

  return(result)
}

#' Load stop words list
#'
#' Returns a tibble of chemistry-specific stop words with provenance tracking.
#' These are domain knowledge defaults, not ComptoxR-seeded.
#'
#' Stop words are terms that indicate placeholder/test entries:
#' - test, sample, unknown, blank, standard, control, reference
#' - placeholder, tbd, tba
#' - na, n/a, none, not available, not applicable
#'
#' NOTE: Cache format changed in Phase 13 - delete existing cache files if needed.
#'
#' @param cache_dir Directory for cache files (e.g., "data/reference_cache")
#' @return Tibble with columns: term, source, active
load_stop_words <- function(cache_dir) {
  cache_path <- file.path(cache_dir, "stop_words.rds")

  fetch_fn <- function() {
    tibble::tibble(
      term = c(
        "test", "sample", "unknown", "blank", "standard", "control",
        "reference", "placeholder", "tbd", "tba", "na", "n/a",
        "none", "not available", "not applicable"
      ),
      source = "app_default",
      active = TRUE
    )
  }

  load_or_fetch_reference(cache_path, fetch_fn, "stop words")
}

#' Load block patterns list
#'
#' Returns a tibble of regex patterns for substances that should
#' be blocked from curation with provenance tracking.
#' These match empty/redacted/proprietary entries.
#'
#' Patterns:
#' - Empty strings, dashes, dots
#' - Proprietary/confidential/trade secret indicators
#' - "Not disclosed" phrases
#'
#' NOTE: Cache format changed in Phase 13 - delete existing cache files if needed.
#'
#' @param cache_dir Directory for cache files (e.g., "data/reference_cache")
#' @return Tibble with columns: term, source, active
load_block_patterns <- function(cache_dir) {
  cache_path <- file.path(cache_dir, "block_patterns.rds")

  fetch_fn <- function() {
    tibble::tibble(
      term = c(
        "^\\s*$",             # Empty or whitespace-only
        "^-+$",               # Only dashes
        "^[.]+$",             # Only dots
        "^proprietary",       # Proprietary (case-insensitive via grep flags)
        "^confidential",      # Confidential
        "^trade\\s*secret",   # Trade secret
        "^not\\s+disclosed"   # Not disclosed
      ),
      source = "app_default",
      active = TRUE
    )
  }

  load_or_fetch_reference(cache_path, fetch_fn, "block patterns")
}

#' Load functional use categories
#'
#' Returns a tibble of functional use categories from ComptoxR with provenance tracking.
#' Falls back gracefully if ComptoxR is unavailable or API fails.
#'
#' NOTE: Cache format changed in Phase 13 - delete existing cache files if needed.
#'
#' @param cache_dir Directory for cache files (e.g., "data/reference_cache")
#' @return Tibble with columns: term, source, active
load_functional_categories <- function(cache_dir) {
  cache_path <- file.path(cache_dir, "functional_categories.rds")

  fetch_fn <- function() {
    tryCatch(
      {
        # TODO: ComptoxR package API has drifted — ct_functional_use() no longer
        # accepts empty string queries. Need to identify the correct ComptoxR
        # function/endpoint for fetching functional use category lists.
        # See TODO.md for tracking. For now, returns empty tibble.
        if (requireNamespace("ComptoxR", quietly = TRUE)) {
          message("ComptoxR available but functional use API needs updating — returning empty list")
          tibble::tibble(term = character(), source = character(), active = logical())
        } else {
          message("ComptoxR package not available, using empty functional categories")
          tibble::tibble(term = character(), source = character(), active = logical())
        }
      },
      error = function(e) {
        message(sprintf("ComptoxR unavailable (%s), using empty functional categories", e$message))
        tibble::tibble(term = character(), source = character(), active = logical())
      }
    )
  }

  load_or_fetch_reference(cache_path, fetch_fn, "functional categories")
}

#' Load all reference lists
#'
#' Convenience wrapper that loads stop words, block patterns, and functional
#' categories in one call. Returns a named list.
#'
#' @param cache_dir Directory for cache files (e.g., "data/reference_cache")
#' @return List with keys: stop_words, block_patterns, functional_categories
#'
#' @examples
#' refs <- load_all_reference_lists("data/reference_cache")
#' refs$stop_words
#' refs$block_patterns
#' refs$functional_categories
load_all_reference_lists <- function(cache_dir) {
  list(
    stop_words = load_stop_words(cache_dir),
    block_patterns = load_block_patterns(cache_dir),
    functional_categories = load_functional_categories(cache_dir)
  )
}
