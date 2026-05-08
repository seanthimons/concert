# ============================================================================
# Test Group 1: enrich_candidates - basic functionality
# ============================================================================

test_that("enrich_candidates returns structured cache tibble for valid DTXSIDs", {
  # Mock ComptoxR::ct_chemical_detail_search_bulk() to return synthetic data
  mock_response <- tibble::tibble(
    dtxsid = c("DTXSID7021360", "DTXSID9020584"),
    casrn = c("108-88-3", "64-17-5"),
    molFormula = c("C7H8", "C2H6O"),
    molecularWeight = c(92.14, 46.07)
  )

  testthat::local_mocked_bindings(
    ct_chemical_detail_search_bulk = function(...) mock_response,
    .package = "ComptoxR"
  )

  result <- enrich_candidates(
    dtxsids = c("DTXSID7021360", "DTXSID9020584")
  )

  expect_type(result, "list")
  expect_true("cache" %in% names(result))
  expect_true("failed_dtxsids" %in% names(result))

  cache <- result$cache
  expect_s3_class(cache, "tbl_df")
  expect_true(all(c("dtxsid", "casrn", "molecular_formula", "molecular_weight") %in% names(cache)))
  expect_equal(nrow(cache), 2)
  expect_equal(cache$dtxsid[1], "DTXSID7021360")
  expect_equal(cache$casrn[1], "108-88-3")
  expect_equal(cache$molecular_formula[1], "C7H8")
  expect_equal(cache$molecular_weight[1], 92.14)
  expect_length(result$failed_dtxsids, 0)
})

# ============================================================================
# Test Group 2: enrich_candidates - incremental caching
# ============================================================================

test_that("enrich_candidates skips already-cached DTXSIDs", {
  call_count <- 0
  testthat::local_mocked_bindings(
    ct_chemical_detail_search_bulk = function(dtxsids, ...) {
      call_count <<- call_count + 1
      tibble::tibble(
        dtxsid = dtxsids,
        casrn = rep("999-99-9", length(dtxsids)),
        molFormula = rep("H2O", length(dtxsids)),
        molecularWeight = rep(18.02, length(dtxsids))
      )
    },
    .package = "ComptoxR"
  )

  existing_cache <- tibble::tibble(
    dtxsid = "DTXSID7021360",
    casrn = "108-88-3",
    molecular_formula = "C7H8",
    molecular_weight = 92.14
  )

  result <- enrich_candidates(
    dtxsids = c("DTXSID7021360", "DTXSID9020584"),
    existing_cache = existing_cache
  )

  # Should only fetch DTXSID9020584 (DTXSID7021360 already cached)
  cache <- result$cache
  expect_equal(nrow(cache), 2) # Both in final cache
  expect_true("DTXSID7021360" %in% cache$dtxsid)
  expect_true("DTXSID9020584" %in% cache$dtxsid)

  # The cached entry should retain original values
  cached_row <- cache[cache$dtxsid == "DTXSID7021360", ]
  expect_equal(cached_row$casrn, "108-88-3")
})

test_that("enrich_candidates returns existing_cache when all DTXSIDs already cached", {
  # Mock should NOT be called
  testthat::local_mocked_bindings(
    ct_chemical_detail_search_bulk = function(...) {
      stop("Should not be called when all DTXSIDs are cached")
    },
    .package = "ComptoxR"
  )

  existing_cache <- tibble::tibble(
    dtxsid = c("DTXSID7021360", "DTXSID9020584"),
    casrn = c("108-88-3", "64-17-5"),
    molecular_formula = c("C7H8", "C2H6O"),
    molecular_weight = c(92.14, 46.07)
  )

  result <- enrich_candidates(
    dtxsids = c("DTXSID7021360", "DTXSID9020584"),
    existing_cache = existing_cache
  )

  expect_equal(nrow(result$cache), 2)
  expect_length(result$failed_dtxsids, 0)
})

# ============================================================================
# Test Group 3: enrich_candidates - empty/no DTXSIDs
# ============================================================================

test_that("enrich_candidates with empty DTXSIDs returns empty cache", {
  result <- enrich_candidates(dtxsids = character(0))

  expect_type(result, "list")
  expect_s3_class(result$cache, "tbl_df")
  expect_equal(nrow(result$cache), 0)
  expect_true(all(c("dtxsid", "casrn", "molecular_formula", "molecular_weight") %in% names(result$cache)))
  expect_length(result$failed_dtxsids, 0)
})

# ============================================================================
# Test Group 4: enrich_candidates - API failure handling
# ============================================================================

test_that("enrich_candidates handles total API failure gracefully", {
  testthat::local_mocked_bindings(
    ct_chemical_detail_search_bulk = function(...) stop("API connection refused"),
    .package = "ComptoxR"
  )

  result <- enrich_candidates(
    dtxsids = c("DTXSID7021360", "DTXSID9020584")
  )

  # Should not crash, returns empty cache + failed list
  expect_type(result, "list")
  expect_s3_class(result$cache, "tbl_df")
  expect_equal(nrow(result$cache), 0)
  expect_true("DTXSID7021360" %in% result$failed_dtxsids)
  expect_true("DTXSID9020584" %in% result$failed_dtxsids)
})

test_that("enrich_candidates handles API failure with existing_cache", {
  testthat::local_mocked_bindings(
    ct_chemical_detail_search_bulk = function(...) stop("API timeout"),
    .package = "ComptoxR"
  )

  existing_cache <- tibble::tibble(
    dtxsid = "DTXSID7021360",
    casrn = "108-88-3",
    molecular_formula = "C7H8",
    molecular_weight = 92.14
  )

  result <- enrich_candidates(
    dtxsids = c("DTXSID7021360", "DTXSID9020584"),
    existing_cache = existing_cache
  )

  # Should preserve existing cache, only new DTXSID in failed list
  expect_equal(nrow(result$cache), 1) # existing cache preserved
  expect_equal(result$cache$dtxsid[1], "DTXSID7021360")
  expect_true("DTXSID9020584" %in% result$failed_dtxsids)
})

# ============================================================================
# Test Group 5: enrich_candidates - partial API response
# ============================================================================

test_that("enrich_candidates handles partial API response (some DTXSIDs missing)", {
  testthat::local_mocked_bindings(
    ct_chemical_detail_search_bulk = function(dtxsids, ...) {
      # Only return data for first DTXSID
      tibble::tibble(
        dtxsid = dtxsids[1],
        casrn = "108-88-3",
        molFormula = "C7H8",
        molecularWeight = 92.14
      )
    },
    .package = "ComptoxR"
  )

  result <- enrich_candidates(
    dtxsids = c("DTXSID7021360", "DTXSID9020584")
  )

  cache <- result$cache
  expect_equal(nrow(cache), 2) # Both present
  expect_equal(cache$dtxsid[cache$dtxsid == "DTXSID7021360"][[1]], "DTXSID7021360")

  # Missing DTXSID should have NA values
  missing_row <- cache[cache$dtxsid == "DTXSID9020584", ]
  expect_true(is.na(missing_row$casrn))
  expect_true(is.na(missing_row$molecular_formula))
  expect_true(is.na(missing_row$molecular_weight))
})

# ============================================================================
# Test Group 6: get_resolution_options - enrichment_cache integration
# ============================================================================

test_that("get_resolution_options with enrichment_cache returns enrichment metadata", {
  df <- data.frame(
    Chemical = c("Toluene"),
    CAS = c("67-64-1"),
    dtxsid_Chemical = c("DTXSID7021360"),
    dtxsid_CAS = c("DTXSID1020001"),
    preferredName_Chemical = c("Toluene"),
    preferredName_CAS = c("Acetone"),
    rank_Chemical = c(1L),
    rank_CAS = c(2L),
    source_tier_Chemical = c("exact"),
    source_tier_CAS = c("cas"),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")
  df <- classify_consensus(df, dtxsid_cols)

  enrichment_cache <- tibble::tibble(
    dtxsid = c("DTXSID7021360", "DTXSID1020001"),
    casrn = c("108-88-3", "67-64-1"),
    molecular_formula = c("C7H8", "C3H6O"),
    molecular_weight = c(92.14, 58.08)
  )

  options <- get_resolution_options(df, 1, dtxsid_cols, enrichment_cache = enrichment_cache)

  expect_length(options, 2)

  # Check that enrichment metadata is present
  chem_opt <- options[["dtxsid_Chemical"]]
  expect_equal(chem_opt$source_column, "Chemical")
  expect_equal(chem_opt$source_tier, "Exact match")
  expect_equal(chem_opt$casrn, "108-88-3")
  expect_equal(chem_opt$molecular_formula, "C7H8")
  expect_equal(chem_opt$molecular_weight, 92.14)

  cas_opt <- options[["dtxsid_CAS"]]
  expect_equal(cas_opt$source_column, "CAS")
  expect_equal(cas_opt$source_tier, "CAS lookup")
  expect_equal(cas_opt$casrn, "67-64-1")
  expect_equal(cas_opt$molecular_formula, "C3H6O")
  expect_equal(cas_opt$molecular_weight, 58.08)
})

test_that("get_resolution_options without enrichment_cache is backward compatible", {
  df <- data.frame(
    Chemical = c("Toluene"),
    CAS = c("67-64-1"),
    dtxsid_Chemical = c("DTXSID7021360"),
    dtxsid_CAS = c("DTXSID1020001"),
    preferredName_Chemical = c("Toluene"),
    preferredName_CAS = c("Acetone"),
    rank_Chemical = c(1L),
    rank_CAS = c(2L),
    source_tier_Chemical = c("exact"),
    source_tier_CAS = c("cas"),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")
  df <- classify_consensus(df, dtxsid_cols)

  # No enrichment_cache — backward compatible call
  options <- get_resolution_options(df, 1, dtxsid_cols)

  expect_length(options, 2)

  # Enrichment fields should be NA
  chem_opt <- options[["dtxsid_Chemical"]]
  expect_equal(chem_opt$source_column, "Chemical")
  expect_equal(chem_opt$source_tier, "Exact match")
  expect_true(is.na(chem_opt$casrn))
  expect_true(is.na(chem_opt$molecular_formula))
  expect_true(is.na(chem_opt$molecular_weight))
})

test_that("get_resolution_options source_tier labels map correctly", {
  df <- data.frame(
    dtxsid_A = c("DTXSID1"),
    dtxsid_B = c("DTXSID2"),
    dtxsid_C = c("DTXSID3"),
    dtxsid_D = c("DTXSID4"),
    preferredName_A = c("A"),
    preferredName_B = c("B"),
    preferredName_C = c("C"),
    preferredName_D = c("D"),
    rank_A = c(1L),
    rank_B = c(2L),
    rank_C = c(3L),
    rank_D = c(4L),
    source_tier_A = c("exact"),
    source_tier_B = c("cas"),
    source_tier_C = c("starts_with"),
    source_tier_D = c("miss"),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_A", "dtxsid_B", "dtxsid_C", "dtxsid_D")
  df <- classify_consensus(df, dtxsid_cols)

  options <- get_resolution_options(df, 1, dtxsid_cols)

  expect_equal(options[["dtxsid_A"]]$source_tier, "Exact match")
  expect_equal(options[["dtxsid_B"]]$source_tier, "CAS lookup")
  expect_equal(options[["dtxsid_C"]]$source_tier, "Starts-with")
  expect_equal(options[["dtxsid_D"]]$source_tier, "No match")
})

test_that("get_resolution_options handles NA source_tier", {
  df <- data.frame(
    dtxsid_Chemical = c("DTXSID7021360"),
    dtxsid_CAS = c("DTXSID1020001"),
    preferredName_Chemical = c("Toluene"),
    preferredName_CAS = c("Acetone"),
    rank_Chemical = c(1L),
    rank_CAS = c(2L),
    # No source_tier columns at all
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")
  df <- classify_consensus(df, dtxsid_cols)

  options <- get_resolution_options(df, 1, dtxsid_cols)

  expect_length(options, 2)
  expect_equal(options[["dtxsid_Chemical"]]$source_tier, "Unknown")
  expect_equal(options[["dtxsid_CAS"]]$source_tier, "Unknown")
})

# ============================================================================
# Test Group 7: enrich_synonyms - synonym fetching and caching
# ============================================================================

test_that("enrich_synonyms returns cache with synonyms column", {
  mock_response <- tibble::tibble(
    dtxsid = "DTXSID5000001",
    valid = list(c("Silica gel", "Quartz")),
    good = list(c("Silicon dioxide")),
    other = list(NULL),
    deleted = list(NULL),
    beilstein = list(NULL),
    alternate = list(NULL),
    pcCode = list(NULL)
  )

  testthat::local_mocked_bindings(
    ct_chemical_synonym_search_bulk = function(...) mock_response,
    .package = "ComptoxR"
  )

  result <- enrich_synonyms(dtxsids = "DTXSID5000001")

  expect_type(result, "list")
  expect_true("cache" %in% names(result))
  expect_true("failed_dtxsids" %in% names(result))

  cache <- result$cache
  expect_true("dtxsid" %in% names(cache))
  expect_true("synonyms" %in% names(cache))
  expect_equal(nrow(cache), 1)
  expect_equal(cache$dtxsid[1], "DTXSID5000001")

  # Synonyms should be pipe-joined; all three names should be present
  syns <- strsplit(cache$synonyms[1], "|", fixed = TRUE)[[1]]
  expect_true("Silica gel" %in% syns)
  expect_true("Quartz" %in% syns)
  expect_true("Silicon dioxide" %in% syns)
})

test_that("enrich_synonyms stores NA when API returns 0 rows", {
  mock_response <- tibble::tibble(
    dtxsid = character(0),
    valid = list(),
    good = list()
  )

  testthat::local_mocked_bindings(
    ct_chemical_synonym_search_bulk = function(...) mock_response,
    .package = "ComptoxR"
  )

  result <- enrich_synonyms(dtxsids = "DTXSID5000002")

  cache <- result$cache
  expect_equal(nrow(cache), 1)
  expect_equal(cache$dtxsid[1], "DTXSID5000002")
  expect_true(is.na(cache$synonyms[1]))
})

test_that("enrich_synonyms merges into existing cache preserving other columns", {
  existing_cache <- tibble::tibble(
    dtxsid = "DTXSID5000003",
    casrn = "7631-86-9",
    molecular_formula = "O2Si",
    molecular_weight = 60.08
  )

  mock_response <- tibble::tibble(
    dtxsid = "DTXSID5000003",
    valid = list(c("Silica")),
    good = list(NULL),
    other = list(NULL),
    deleted = list(NULL),
    beilstein = list(NULL),
    alternate = list(NULL),
    pcCode = list(NULL)
  )

  testthat::local_mocked_bindings(
    ct_chemical_synonym_search_bulk = function(...) mock_response,
    .package = "ComptoxR"
  )

  result <- enrich_synonyms(dtxsids = "DTXSID5000003", existing_cache = existing_cache)

  cache <- result$cache
  # All original columns preserved
  expect_true("casrn" %in% names(cache))
  expect_true("molecular_formula" %in% names(cache))
  expect_true("molecular_weight" %in% names(cache))
  # Plus the new synonyms column
  expect_true("synonyms" %in% names(cache))
  expect_equal(cache$casrn[cache$dtxsid == "DTXSID5000003"], "7631-86-9")
  expect_false(is.na(cache$synonyms[cache$dtxsid == "DTXSID5000003"]))
})

test_that("enrich_synonyms skips already-cached DTXSIDs with synonyms", {
  call_args <- NULL
  testthat::local_mocked_bindings(
    ct_chemical_synonym_search_bulk = function(dtxsids, ...) {
      call_args <<- dtxsids
      tibble::tibble(
        dtxsid = dtxsids,
        valid = lapply(dtxsids, function(x) "Some synonym"),
        good = lapply(dtxsids, function(x) NULL),
        other = lapply(dtxsids, function(x) NULL),
        deleted = lapply(dtxsids, function(x) NULL),
        beilstein = lapply(dtxsids, function(x) NULL),
        alternate = lapply(dtxsids, function(x) NULL),
        pcCode = lapply(dtxsids, function(x) NULL)
      )
    },
    .package = "ComptoxR"
  )

  # Cache with synonyms already for DTXSID5000004
  existing_cache <- tibble::tibble(
    dtxsid = "DTXSID5000004",
    synonyms = "Cached synonym"
  )

  result <- enrich_synonyms(
    dtxsids = c("DTXSID5000004", "DTXSID5000005"),
    existing_cache = existing_cache
  )

  # API should only have been called for DTXSID5000005
  expect_false(is.null(call_args))
  expect_false("DTXSID5000004" %in% call_args)
  expect_true("DTXSID5000005" %in% call_args)

  # Both DTXSIDs should be in the result
  cache <- result$cache
  expect_true("DTXSID5000004" %in% cache$dtxsid)
  expect_true("DTXSID5000005" %in% cache$dtxsid)
})

test_that("enrich_synonyms handles API failure gracefully", {
  testthat::local_mocked_bindings(
    ct_chemical_synonym_search_bulk = function(...) stop("API connection refused"),
    .package = "ComptoxR"
  )

  existing_cache <- tibble::tibble(
    dtxsid = "DTXSID5000006",
    casrn = "108-88-3",
    molecular_formula = "C7H8",
    molecular_weight = 92.14
  )

  result <- enrich_synonyms(
    dtxsids = c("DTXSID5000006", "DTXSID5000007"),
    existing_cache = existing_cache
  )

  # Should not crash
  expect_type(result, "list")
  # Existing cache preserved (with synonyms column added)
  cache <- result$cache
  expect_true("DTXSID5000006" %in% cache$dtxsid)
  # Failed DTXSIDs reported (only new ones, since 5000006 was already cached)
  expect_true("DTXSID5000007" %in% result$failed_dtxsids)
})
