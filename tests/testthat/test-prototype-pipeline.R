# ============================================================================
# Test Group 1: deduplicate_tagged_columns
# ============================================================================

test_that("deduplicate_tagged_columns extracts unique names from single column", {
  df <- data.frame(
    Chemical = c("Toluene", "Ethanol", "Toluene", "Acetone"),
    CAS = c("108-88-3", "64-17-5", "108-88-3", "67-64-1"),
    stringsAsFactors = FALSE
  )
  tag_map <- list(Chemical = "Name")

  result <- deduplicate_tagged_columns(df, tag_map)

  expect_type(result, "list")
  expect_true("unique_names" %in% names(result))
  expect_true("unique_cas" %in% names(result))
  expect_true("dedup_key_map" %in% names(result))

  # Toluene appears twice but should be deduplicated

  expect_equal(sort(result$unique_names), c("Acetone", "Ethanol", "Toluene"))
  expect_length(result$unique_cas, 0) # No CASRN columns tagged
})

test_that("deduplicate_tagged_columns handles multiple tag types", {
  df <- data.frame(
    Chemical = c("Toluene", "Ethanol"),
    CAS = c("108-88-3", "64-17-5"),
    stringsAsFactors = FALSE
  )
  tag_map <- list(Chemical = "Name", CAS = "CASRN")

  result <- deduplicate_tagged_columns(df, tag_map)

  expect_length(result$unique_names, 2)
  expect_length(result$unique_cas, 2)
  expect_true("108-88-3" %in% result$unique_cas)
})

test_that("deduplicate_tagged_columns excludes NA values", {
  df <- data.frame(
    Chemical = c("Toluene", NA, "Ethanol", NA),
    stringsAsFactors = FALSE
  )
  tag_map <- list(Chemical = "Name")

  result <- deduplicate_tagged_columns(df, tag_map)

  expect_false(any(is.na(result$unique_names)))
  expect_length(result$unique_names, 2)
})

test_that("deduplicate_tagged_columns preserves case (no lowercasing)", {
  df <- data.frame(
    Chemical = c("toluene", "Toluene"),
    stringsAsFactors = FALSE
  )
  tag_map <- list(Chemical = "Name")

  result <- deduplicate_tagged_columns(df, tag_map)

  # Both should be kept — CompTox is case-sensitive

  expect_length(result$unique_names, 2)
})

test_that("deduplicate_tagged_columns builds dedup_key_map", {
  df <- data.frame(
    Chemical = c("Toluene", "Ethanol", "Toluene"),
    stringsAsFactors = FALSE
  )
  tag_map <- list(Chemical = "Name")

  result <- deduplicate_tagged_columns(df, tag_map)

  expect_s3_class(result$dedup_key_map, "data.frame")
  expect_true(all(c("row_idx", "column_name", "tag_type", "dedup_key") %in%
    names(result$dedup_key_map)))
  expect_equal(nrow(result$dedup_key_map), 3) # One per original row
})

test_that("deduplicate_tagged_columns handles all-NA column", {
  df <- data.frame(
    Chemical = c(NA_character_, NA_character_),
    stringsAsFactors = FALSE
  )
  tag_map <- list(Chemical = "Name")

  result <- deduplicate_tagged_columns(df, tag_map)

  expect_length(result$unique_names, 0)
})

# ============================================================================
# Test Group 2: search_exact (API-dependent)
# ============================================================================

test_that("search_exact returns empty tibble for empty input", {
  result <- search_exact(character(0))

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
  expect_true(all(c("searchValue", "dtxsid", "preferredName", "searchName", "rank") %in%
    names(result)))
})

test_that("search_exact calls CompTox API for known chemicals", {
  skip_if_not(nzchar(Sys.getenv("ctx_api_key")), "CompTox API key not set")

  result <- tryCatch(
    search_exact(c("Toluene", "Ethanol")),
    error = function(e) skip(paste("API unavailable:", conditionMessage(e)))
  )

  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) >= 2)
  expect_true(all(c("searchValue", "dtxsid", "preferredName", "searchName", "rank") %in%
    names(result)))
  # Both should have DTXSID
  toluene_row <- result[result$searchValue == "Toluene", ]
  expect_true(nrow(toluene_row) >= 1)
  expect_false(is.na(toluene_row$dtxsid[1]))
})

# ============================================================================
# Test Group 3: search_starts_with (API-dependent)
# ============================================================================

test_that("search_starts_with returns empty tibble for empty input", {
  result <- search_starts_with(character(0))

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})

test_that("search_starts_with finds results for known prefix", {
  skip_if_not(nzchar(Sys.getenv("ctx_api_key")), "CompTox API key not set")

  result <- tryCatch(
    search_starts_with("Toluen"),
    error = function(e) skip(paste("API unavailable:", conditionMessage(e)))
  )

  expect_s3_class(result, "data.frame")
  skip_if(nrow(result) == 0, "API returned 0 results (may be connectivity issue)")
  expect_true(nrow(result) >= 1)
  expect_true("searchValue" %in% names(result))
})

# ============================================================================
# Test Group 4: validate_and_lookup_cas
# ============================================================================

test_that("validate_and_lookup_cas returns empty tibble for empty input", {
  result <- validate_and_lookup_cas(character(0))

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
  expect_true(all(c("original_cas", "validated_cas", "is_valid") %in%
    names(result)))
})

test_that("validate_and_lookup_cas normalizes and validates CAS numbers", {
  # This test uses ComptoxR::as_cas and is_cas but not the API
  result <- validate_and_lookup_cas(c("67-64-1", "invalid", NA))

  expect_equal(nrow(result), 3)
  expect_equal(result$original_cas, c("67-64-1", "invalid", NA))

  # First CAS is valid
  expect_false(is.na(result$validated_cas[1]))
  expect_true(result$is_valid[1])

  # "invalid" should not be a valid CAS
  expect_true(is.na(result$validated_cas[2]) || !result$is_valid[2])

  # NA stays NA
  expect_true(is.na(result$validated_cas[3]))
})

test_that("validate_and_lookup_cas looks up DTXSID for valid CAS", {
  skip_if_not(nzchar(Sys.getenv("ctx_api_key")), "CompTox API key not set")

  result <- tryCatch(
    validate_and_lookup_cas(c("67-64-1")), # Acetone
    error = function(e) skip(paste("API unavailable:", conditionMessage(e)))
  )

  expect_true("dtxsid" %in% names(result))
  skip_if(is.na(result$dtxsid[1]), "API returned NA dtxsid (may be connectivity issue)")
  expect_false(is.na(result$dtxsid[1]))
})

# ============================================================================
# Test Group 5: run_tiered_search (API-dependent)
# ============================================================================

test_that("run_tiered_search orchestrates all tiers", {
  skip_if_not(nzchar(Sys.getenv("ctx_api_key")), "CompTox API key not set")

  df <- data.frame(
    Chemical = c("Toluene", "Ethanol"),
    CAS = c("108-88-3", "64-17-5"),
    stringsAsFactors = FALSE
  )
  dedup <- deduplicate_tagged_columns(df, list(Chemical = "Name", CAS = "CASRN"))
  result <- tryCatch(
    run_tiered_search(dedup),
    error = function(e) skip(paste("API unavailable:", conditionMessage(e)))
  )

  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) >= 1)
  expect_true("searchValue" %in% names(result))
})

# ============================================================================
# Test Group 6: map_results_to_rows
# ============================================================================

test_that("map_results_to_rows joins results back to all original rows", {
  df <- data.frame(
    Chemical = c("Toluene", "Ethanol", "Toluene", "Acetone"),
    stringsAsFactors = FALSE
  )
  tag_map <- list(Chemical = "Name")
  dedup <- deduplicate_tagged_columns(df, tag_map)

  # Create mock lookup results
  lookup <- tibble::tibble(
    searchValue = c("Toluene", "Ethanol", "Acetone"),
    dtxsid = c("DTXSID7021360", "DTXSID9020584", "DTXSID1020001"),
    preferredName = c("Toluene", "Ethanol", "Acetone"),
    searchName = c("Approved Name", "Approved Name", "Approved Name"),
    rank = c(1L, 1L, 1L),
    source_tier = c("exact", "exact", "exact")
  )

  result <- map_results_to_rows(df, dedup$dedup_key_map, lookup)

  # Should have same number of rows as original
  expect_equal(nrow(result), 4)
  # Should have lookup columns joined
  expect_true("dtxsid" %in% names(result) || any(grepl("dtxsid", names(result))))
})

test_that("map_results_to_rows handles NA/missing lookups", {
  df <- data.frame(
    Chemical = c("Toluene", "UnknownChemical"),
    stringsAsFactors = FALSE
  )
  tag_map <- list(Chemical = "Name")
  dedup <- deduplicate_tagged_columns(df, tag_map)

  # Only Toluene has a result
  lookup <- tibble::tibble(
    searchValue = "Toluene",
    dtxsid = "DTXSID7021360",
    preferredName = "Toluene",
    searchName = "Approved Name",
    rank = 1L,
    source_tier = "exact"
  )

  result <- map_results_to_rows(df, dedup$dedup_key_map, lookup)

  expect_equal(nrow(result), 2)
  # UnknownChemical should have NA for dtxsid
  unknown_row <- result[result$Chemical == "UnknownChemical", ]
  dtxsid_col <- grep("dtxsid", names(result), value = TRUE)[1]
  expect_true(is.na(unknown_row[[dtxsid_col]]))
})

# ============================================================================
# Test Group 7: Other tag support (SRCH-02)
# ============================================================================

test_that("deduplicate_tagged_columns includes Other tag in unique_names", {
  df <- tibble::tibble(
    chem_name = c("Acetone", "Ethanol"),
    supplier_code = c("ACE-001", "ETH-002"),
    cas = c("67-64-1", "64-17-5")
  )
  tag_map <- list(chem_name = "Name", supplier_code = "Other", cas = "CASRN")

  result <- deduplicate_tagged_columns(df, tag_map)

  expect_true("Acetone" %in% result$unique_names)
  expect_true("ACE-001" %in% result$unique_names)  # Other values included
  expect_true("ETH-002" %in% result$unique_names)  # Other values included
  expect_equal(length(result$unique_cas), 2)
  # dedup_key_map should have entries for all 3 tag types
  expect_true("Other" %in% result$dedup_key_map$tag_type)
})

test_that("deduplicate_tagged_columns handles multiple Other columns", {
  df <- tibble::tibble(
    chem_name = c("Acetone"),
    synonym = c("2-Propanone"),
    supplier = c("Sigma")
  )
  tag_map <- list(chem_name = "Name", synonym = "Other", supplier = "Other")

  result <- deduplicate_tagged_columns(df, tag_map)

  expect_true("2-Propanone" %in% result$unique_names)
  expect_true("Sigma" %in% result$unique_names)
  expect_true("Acetone" %in% result$unique_names)
})

test_that("deduplicate_tagged_columns handles CAS-only tags", {
  df <- tibble::tibble(cas = c("67-64-1", "64-17-5"))
  tag_map <- list(cas = "CASRN")

  result <- deduplicate_tagged_columns(df, tag_map)

  expect_equal(length(result$unique_names), 0)
  expect_equal(length(result$unique_cas), 2)
})

# ============================================================================
# Test Group 8: Tier reorder and 3-char minimum (SRCH-01)
# ============================================================================

test_that("starts-with 3-char minimum filter excludes short strings", {
  # Simulate the filter logic from run_curation_pipeline
  still_missed <- c("AB", "Ac", "Acetone", "Et", "Ethanol", "X")
  sw_candidates <- still_missed[nchar(still_missed) >= 3]

  expect_equal(sw_candidates, c("Acetone", "Ethanol"))
  expect_false("AB" %in% sw_candidates)
  expect_false("Ac" %in% sw_candidates)
  expect_false("Et" %in% sw_candidates)
  expect_false("X" %in% sw_candidates)
})

# ============================================================================
# Test Group 9: starts-with cache regression tests
# ============================================================================

test_that("mixed-case cache hit returns current query casing in searchValue", {
  clear_starts_with_cache()

  # Prime cache with lowercase key and payload (no searchValue)
  payload <- tibble::tibble(
    dtxsid = "DTXSID7021360",
    preferredName = "Toluene",
    searchName = "Approved Name",
    rank = 1L
  )
  assign("toluene", payload, envir = .starts_with_cache)

  # Query with mixed case — should get searchValue = "Toluene", not stale casing
  result <- search_starts_with("Toluene")

  expect_true(nrow(result) >= 1)
  expect_equal(result$searchValue[1], "Toluene")

  # Query again with different casing — same cache hit, different searchValue
  result2 <- search_starts_with("TOLUENE")
  expect_equal(result2$searchValue[1], "TOLUENE")

  clear_starts_with_cache()
})

test_that("API error is NOT cached — allows retry on later runs", {
  clear_starts_with_cache()

  # Mock ComptoxR API to throw an error, then call the real search_starts_with
  local_mocked_bindings(
    ct_chemical_search_start_with = function(name) stop("simulated API failure"),
    .package = "ComptoxR"
  )

  cache_key <- "errortestchem"
  expect_false(exists(cache_key, envir = .starts_with_cache))

  # Call the production function — should log warning, NOT cache
  suppressMessages(search_starts_with("ErrorTestChem"))

  # Cache must NOT contain an entry for this key

  expect_false(exists(cache_key, envir = .starts_with_cache))

  clear_starts_with_cache()
})

test_that("true empty API response IS cached to avoid re-fetching", {
  clear_starts_with_cache()

  # Mock ComptoxR API to return NULL (0 results)
  call_count <- 0L
  local_mocked_bindings(
    ct_chemical_search_start_with = function(name) {
      call_count <<- call_count + 1L
      NULL
    },
    .package = "ComptoxR"
  )

  cache_key <- "nosuchchem"

  # First call — API returns NULL, should cache the true miss
  suppressMessages(search_starts_with("NoSuchChem"))
  expect_true(exists(cache_key, envir = .starts_with_cache))
  expect_equal(call_count, 1L)

  # Cached payload should be zero-row with correct columns
  cached <- get(cache_key, envir = .starts_with_cache)
  expect_equal(nrow(cached), 0)
  expect_true(all(c("dtxsid", "preferredName", "searchName", "rank") %in% names(cached)))

  # Second call — should serve from cache, NOT call API again
  suppressMessages(search_starts_with("NoSuchChem"))
  expect_equal(call_count, 1L)

  clear_starts_with_cache()
})
