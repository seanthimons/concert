# Tests for Phase 47: pipeline reorder, threshold passthrough, starts-with toggle
# Covers ORD-01, ORD-02, CONF-02, TOG-02

# Helper: build minimal test data for run_curation_pipeline()
make_test_data <- function(names_vec) {
  df <- data.frame(Chemical = names_vec, stringsAsFactors = FALSE)
  tags <- c(Chemical = "Chemical Name")
  list(df = df, tags = tags)
}

# Helper: build a mock WQX dictionary with known names
mock_wqx_dict <- tibble::tibble(
  name = c("Arsenic", "Dissolved oxygen", "DO", "Phosphorus"),
  canonical_name = c("Arsenic", "Dissolved oxygen", "Dissolved oxygen", "Phosphorus"),
  type = c("canonical", "canonical", "synonym", "canonical"),
  cas_number = c("7440-38-2", "7782-44-7", NA_character_, "7723-14-0"),
  group_name = c("Metals", "Inorganics", NA_character_, "Nutrients"),
  description = rep(NA_character_, 4)
)

test_that("WQX tier resolves names before starts-with (ORD-01)", {
  td <- make_test_data(c("Arsenic", "UnknownChemXYZ"))

  local_mocked_bindings(
    search_exact = function(...) {
      tibble::tibble(
        searchValue = character(0),
        dtxsid = character(0),
        preferredName = character(0),
        searchName = character(0),
        rank = integer(0)
      )
    },
    validate_and_lookup_cas = function(...) {
      tibble::tibble(
        original_cas = character(0),
        dtxsid = character(0),
        preferredName = character(0)
      )
    },
    search_starts_with = function(names_vec, ...) {
      tibble::tibble(
        searchValue = character(0),
        dtxsid = character(0),
        preferredName = character(0),
        searchName = character(0),
        rank = integer(0)
      )
    },
    load_wqx_dictionary = function(...) mock_wqx_dict,
    match_wqx = function(names_vec, dict, threshold = 0.85, ...) {
      tibble::tibble(
        input_name = names_vec,
        wqx_name = ifelse(names_vec == "Arsenic", "Arsenic", NA_character_),
        match_tier = ifelse(names_vec == "Arsenic", "exact", "none"),
        match_distance = ifelse(names_vec == "Arsenic", 0, NA_real_),
        alias_type = NA_character_
      )
    }
  )

  result <- run_curation_pipeline(td$df, td$tags, starts_with = TRUE)
  tiers <- result$results$source_tier_Chemical

  expect_true("wqx_exact" %in% tiers)
  arsenic_tier <- tiers[result$results$Chemical == "Arsenic"]
  expect_equal(arsenic_tier, "wqx_exact")
})

test_that("Names resolved by WQX never reach starts-with (ORD-02)", {
  td <- make_test_data(c("Arsenic", "UnknownChemXYZ"))
  sw_received <- character(0)

  local_mocked_bindings(
    search_exact = function(...) {
      tibble::tibble(
        searchValue = character(0),
        dtxsid = character(0),
        preferredName = character(0),
        searchName = character(0),
        rank = integer(0)
      )
    },
    validate_and_lookup_cas = function(...) {
      tibble::tibble(
        original_cas = character(0),
        dtxsid = character(0),
        preferredName = character(0)
      )
    },
    search_starts_with = function(names_vec, ...) {
      sw_received <<- names_vec
      tibble::tibble(
        searchValue = character(0),
        dtxsid = character(0),
        preferredName = character(0),
        searchName = character(0),
        rank = integer(0)
      )
    },
    load_wqx_dictionary = function(...) mock_wqx_dict,
    match_wqx = function(names_vec, dict, threshold = 0.85, ...) {
      tibble::tibble(
        input_name = names_vec,
        wqx_name = ifelse(names_vec == "Arsenic", "Arsenic", NA_character_),
        match_tier = ifelse(names_vec == "Arsenic", "exact", "none"),
        match_distance = ifelse(names_vec == "Arsenic", 0, NA_real_),
        alias_type = NA_character_
      )
    }
  )

  result <- run_curation_pipeline(td$df, td$tags, starts_with = TRUE)
  expect_false("Arsenic" %in% sw_received)
})

test_that("wqx_threshold parameter passes through to match_wqx (CONF-02)", {
  td <- make_test_data(c("Arsenic"))
  captured_threshold <- NULL

  local_mocked_bindings(
    search_exact = function(...) {
      tibble::tibble(
        searchValue = character(0),
        dtxsid = character(0),
        preferredName = character(0),
        searchName = character(0),
        rank = integer(0)
      )
    },
    validate_and_lookup_cas = function(...) {
      tibble::tibble(
        original_cas = character(0),
        dtxsid = character(0),
        preferredName = character(0)
      )
    },
    load_wqx_dictionary = function(...) mock_wqx_dict,
    match_wqx = function(names_vec, dict, threshold = 0.85, ...) {
      captured_threshold <<- threshold
      tibble::tibble(
        input_name = names_vec,
        wqx_name = NA_character_,
        match_tier = "none",
        match_distance = NA_real_,
        alias_type = NA_character_
      )
    }
  )

  run_curation_pipeline(td$df, td$tags, wqx_threshold = 0.60)
  expect_equal(captured_threshold, 0.60)
})

test_that("starts_with=FALSE skips starts-with entirely (TOG-02)", {
  td <- make_test_data(c("Arsenic", "UnknownChemXYZ"))
  sw_called <- FALSE

  local_mocked_bindings(
    search_exact = function(...) {
      tibble::tibble(
        searchValue = character(0),
        dtxsid = character(0),
        preferredName = character(0),
        searchName = character(0),
        rank = integer(0)
      )
    },
    validate_and_lookup_cas = function(...) {
      tibble::tibble(
        original_cas = character(0),
        dtxsid = character(0),
        preferredName = character(0)
      )
    },
    search_starts_with = function(names_vec, ...) {
      sw_called <<- TRUE
      tibble::tibble(
        searchValue = character(0),
        dtxsid = character(0),
        preferredName = character(0),
        searchName = character(0),
        rank = integer(0)
      )
    },
    load_wqx_dictionary = function(...) mock_wqx_dict,
    match_wqx = function(names_vec, dict, threshold = 0.85, ...) {
      tibble::tibble(
        input_name = names_vec,
        wqx_name = NA_character_,
        match_tier = "none",
        match_distance = NA_real_,
        alias_type = NA_character_
      )
    }
  )

  result <- run_curation_pipeline(td$df, td$tags, starts_with = FALSE)
  expect_false(sw_called)
  expect_false("starts_with" %in% result$results$source_tier_Chemical)
})

test_that("starts_with=TRUE allows starts-with on post-WQX misses (TOG-02)", {
  td <- make_test_data(c("Arsenic", "UnknownChemXYZ"))
  sw_called <- FALSE

  local_mocked_bindings(
    search_exact = function(...) {
      tibble::tibble(
        searchValue = character(0),
        dtxsid = character(0),
        preferredName = character(0),
        searchName = character(0),
        rank = integer(0)
      )
    },
    validate_and_lookup_cas = function(...) {
      tibble::tibble(
        original_cas = character(0),
        dtxsid = character(0),
        preferredName = character(0)
      )
    },
    search_starts_with = function(names_vec, ...) {
      sw_called <<- TRUE
      tibble::tibble(
        searchValue = character(0),
        dtxsid = character(0),
        preferredName = character(0),
        searchName = character(0),
        rank = integer(0)
      )
    },
    load_wqx_dictionary = function(...) mock_wqx_dict,
    match_wqx = function(names_vec, dict, threshold = 0.85, ...) {
      tibble::tibble(
        input_name = names_vec,
        wqx_name = NA_character_,
        match_tier = "none",
        match_distance = NA_real_,
        alias_type = NA_character_
      )
    }
  )

  result <- run_curation_pipeline(td$df, td$tags, starts_with = TRUE)
  expect_true(sw_called)
})
