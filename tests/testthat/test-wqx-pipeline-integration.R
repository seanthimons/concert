# Test file for WQX pipeline integration (Phase 45)
# Tests INTG-02, INTG-03, INTG-04

# ============================================================================
# Group 1: compute_qc_tier handles wqx status
# ============================================================================

test_that("compute_qc_tier returns n_total for wqx status", {
  # WQX gets same tier as "single" (resolved but no multi-source agreement)
  expect_equal(compute_qc_tier("wqx", 0L, 1L), 1L)
  expect_equal(compute_qc_tier("wqx", 0L, 2L), 2L)
  expect_equal(compute_qc_tier("wqx", 0L, 3L), 3L)
})

# ============================================================================
# Group 2: classify_consensus assigns wqx for WQX-resolved rows
# ============================================================================

test_that("classify_consensus assigns wqx status for wqx_exact source tier", {
  df <- data.frame(
    Chemical = "Arsenic",
    dtxsid_Chemical = NA_character_,
    preferredName_Chemical = "Arsenic",
    source_tier_Chemical = "wqx_exact",
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- "dtxsid_Chemical"
  result <- classify_consensus(df, dtxsid_cols)

  expect_equal(result$consensus_status[1], "wqx")
  expect_true(is.na(result$consensus_dtxsid[1]))
})

test_that("classify_consensus assigns wqx status for wqx_alias source tier", {
  df <- data.frame(
    Chemical = "Arsenic",
    dtxsid_Chemical = NA_character_,
    preferredName_Chemical = "Arsenic",
    source_tier_Chemical = "wqx_alias",
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- "dtxsid_Chemical"
  result <- classify_consensus(df, dtxsid_cols)

  expect_equal(result$consensus_status[1], "wqx")
})

test_that("classify_consensus assigns wqx status for wqx_fuzzy source tier", {
  df <- data.frame(
    Chemical = "Arsenic",
    dtxsid_Chemical = NA_character_,
    preferredName_Chemical = "Arsenic",
    source_tier_Chemical = "wqx_fuzzy",
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- "dtxsid_Chemical"
  result <- classify_consensus(df, dtxsid_cols)

  expect_equal(result$consensus_status[1], "wqx")
})

test_that("classify_consensus promotes preferredName to consensus_name for wqx rows", {
  # Alias case: raw input differs from the resolved WQX canonical name.
  df <- data.frame(
    Chemical = "DO",
    dtxsid_Chemical = NA_character_,
    preferredName_Chemical = "Dissolved oxygen",
    source_tier_Chemical = "wqx_alias",
    stringsAsFactors = FALSE
  )
  result <- classify_consensus(df, "dtxsid_Chemical")

  expect_equal(result$consensus_status[1], "wqx")
  expect_equal(result$consensus_name[1], "Dissolved oxygen")
})

test_that("classify_consensus leaves consensus_name NA for non-wqx rows", {
  df <- data.frame(
    Chemical = "Unknown",
    dtxsid_Chemical = NA_character_,
    preferredName_Chemical = NA_character_,
    source_tier_Chemical = "miss",
    stringsAsFactors = FALSE
  )
  result <- classify_consensus(df, "dtxsid_Chemical")

  expect_true(is.na(result$consensus_name[1]))
})

test_that("classify_consensus still assigns error for non-wqx NA-DTXSID rows", {
  df <- data.frame(
    Chemical = "Unknown",
    dtxsid_Chemical = NA_character_,
    source_tier_Chemical = "miss",
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- "dtxsid_Chemical"
  result <- classify_consensus(df, dtxsid_cols)

  expect_equal(result$consensus_status[1], "error")
})

test_that("classify_consensus assigns single (not wqx) when DTXSID is present alongside wqx", {
  # One col: NA dtxsid + wqx_exact tier; Other col: real DTXSID + exact tier
  # n_present > 0, so WQX guard should NOT fire
  df <- data.frame(
    Chemical = "Arsenic",
    dtxsid_Chemical = NA_character_,
    source_tier_Chemical = "wqx_exact",
    dtxsid_Other = "DTXSID123",
    source_tier_Other = "exact",
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_Other")
  result <- classify_consensus(df, dtxsid_cols)

  # n_present == 1 (only dtxsid_Other has a real DTXSID), so "single"
  expect_equal(result$consensus_status[1], "single")
})

# --- Group 3: WQX result tibble schema ---

test_that("wqx_rows tibble conforms to combined_results schema", {
  mock_dict <- tibble::tibble(
    name = c("Arsenic", "Dissolved oxygen", "DO", "Arsenic, Total"),
    canonical_name = c("Arsenic", "Dissolved oxygen", "Dissolved oxygen", "Arsenic"),
    type = c("canonical", "canonical", "synonym", "standardize"),
    cas_number = c("7440-38-2", "7782-44-7", NA_character_, NA_character_),
    group_name = c("Metals", "Inorganics", NA_character_, NA_character_),
    description = rep(NA_character_, 4)
  )

  wqx_raw <- match_wqx(c("Arsenic", "NonExistentChemical"), mock_dict)
  wqx_resolved <- wqx_raw[wqx_raw$match_tier != "none", ]

  wqx_rows <- tibble::tibble(
    searchValue = wqx_resolved$input_name,
    dtxsid = NA_character_,
    preferredName = wqx_resolved$wqx_name,
    searchName = NA_character_,
    rank = NA_integer_,
    source_tier = paste0("wqx_", wqx_resolved$match_tier)
  )

  expect_named(wqx_rows, c("searchValue", "dtxsid", "preferredName", "searchName", "rank", "source_tier"))
  expect_true(all(is.na(wqx_rows$dtxsid)))
  expect_true(all(grepl("^wqx_", wqx_rows$source_tier)))
  expect_equal(wqx_rows$preferredName[1], "Arsenic")
})

# --- Group 4: WQX tier final_missed narrowing ---

test_that("WQX matching narrows vocabulary misses without resolving identifiers", {
  mock_dict <- tibble::tibble(
    name = c("Arsenic", "Dissolved oxygen", "DO"),
    canonical_name = c("Arsenic", "Dissolved oxygen", "Dissolved oxygen"),
    type = c("canonical", "canonical", "synonym"),
    cas_number = c("7440-38-2", "7782-44-7", NA_character_),
    group_name = c("Metals", "Inorganics", NA_character_),
    description = rep(NA_character_, 3)
  )

  final_missed <- c("Arsenic", "DO", "TotallyFakeChemical")
  wqx_raw <- match_wqx(final_missed, mock_dict)
  wqx_resolved <- wqx_raw[wqx_raw$match_tier != "none", ]
  wqx_matched_names <- wqx_resolved$input_name
  remaining <- setdiff(final_missed, wqx_matched_names)

  expect_equal(length(remaining), 1)
  expect_equal(remaining, "TotallyFakeChemical")
  expect_true("Arsenic" %in% wqx_matched_names)
  expect_true("DO" %in% wqx_matched_names)
})

# --- Group 5: Source tier values per D-05 ---

test_that("WQX source_tier values follow wqx_ prefix convention", {
  mock_dict <- tibble::tibble(
    name = c("Arsenic", "DO"),
    canonical_name = c("Arsenic", "Dissolved oxygen"),
    type = c("canonical", "synonym"),
    cas_number = c("7440-38-2", NA_character_),
    group_name = c("Metals", NA_character_),
    description = rep(NA_character_, 2)
  )

  wqx_raw <- match_wqx(c("Arsenic", "DO"), mock_dict)
  source_tiers <- paste0("wqx_", wqx_raw$match_tier[wqx_raw$match_tier != "none"])

  expect_true(all(source_tiers %in% c("wqx_exact", "wqx_alias", "wqx_fuzzy")))
  expect_equal(source_tiers[1], "wqx_exact") # Arsenic is exact canonical match
  expect_equal(source_tiers[2], "wqx_alias") # DO is alias for Dissolved oxygen
})

# --- Group 6: Full pipeline integration (requires API key) ---

test_that("full pipeline produces WQX matches for unresolved names", {
  skip_if_not(nzchar(Sys.getenv("ctx_api_key")), "CompTox API key not set")

  # Minimal dataset with one name CompTox won't resolve but WQX will
  clean_data <- data.frame(
    Chemical = c("PFBS", "Arsenic"),
    stringsAsFactors = FALSE
  )
  column_tags <- c(Chemical = "Chemical Name")

  result <- run_curation_pipeline(clean_data, column_tags)

  # search_summary should include n_wqx
  expect_true("n_wqx" %in% names(result$search_summary))

  # At least the results df should exist
  expect_true(nrow(result$results) > 0)
})

wqx_pipeline_dictionary <- function() {
  tibble::tibble(name = c("Arsenic", "Arsenic alias", "Class without CAS"),
    canonical_name = c("Arsenic", "Arsenic", "Class without CAS"),
    type = c("canonical", "synonym", "canonical"),
    cas_number = c("7440-38-2", NA_character_, NA_character_),
    group_name = NA_character_, description = NA_character_)
}

wqx_pipeline_mocks <- function(env = parent.frame()) {
  testthat::local_mocked_bindings(
    search_exact = function(names) tibble::tibble(searchValue = names, dtxsid = NA_character_,
      preferredName = NA_character_, searchName = NA_character_, rank = NA_integer_),
    load_wqx_dictionary = function(...) wqx_pipeline_dictionary(),
    add_resolver_candidates = function(df, ...) df,
    .env = env
  )
}

test_that("dictionary CAS continuation deduplicates queries and retains all provisional hits", {
  wqx_pipeline_mocks()
  queries <- character()
  df <- tibble::tibble(Chemical = c("Arsenic", "Arsenic alias", "Class without CAS"))
  result <- run_curation_pipeline(df, list(Chemical = "Name"), pubchem = FALSE,
    wqx_cas_lookup_fn = function(cas) {
      queries <<- cas
      tibble::tibble(original_cas = rep(cas, each = 3),
        dtxsid = c("DTXSID123", "DTXSID456", "DTXSID123"),
        preferredName = c("Different identity", "Another identity", "Different identity"))
    })$results
  expect_identical(queries, "7440-38-2")
  expect_identical(result$wqx_input_name, df$Chemical)
  expect_identical(result$wqx_name, c("Arsenic", "Arsenic", "Class without CAS"))
  expect_identical(result$wqx_match_tier, c("exact", "alias", "exact"))
  expect_identical(result$wqx_cas_dtxsid_candidates,
    c("DTXSID123|DTXSID456", "DTXSID123|DTXSID456", NA_character_))
  expect_identical(result$wqx_cas_lookup_status, c("candidate", "candidate", "missing"))
  expect_true(all(is.na(result$dtxsid)))
  expect_true(all(is.na(result$consensus_dtxsid)))
  expect_true(all(result$consensus_status == "wqx"))
  expect_identical(result$Chemical, df$Chemical)
})

test_that("WQX candidate lookup distinguishes missing, invalid, ambiguous, no-hit and outage", {
  matches <- tibble::tibble(input_name = letters[1:5], wqx_name = LETTERS[1:5],
    match_tier = "fuzzy", match_distance = .1, alias_type = NA_character_,
    wqx_cas = c(NA, NA, NA, "7440-38-2", "7782-44-7"),
    wqx_cas_status = c("missing", "invalid", "ambiguous", "valid", "valid"))
  observed <- NULL
  result <- wqx_dictionary_candidates(matches, function(cas) {
    observed <<- cas
    tibble::tibble(original_cas = cas, dtxsid = NA_character_, lookup_status = c("not_found", "unavailable"))
  })
  expect_identical(observed, c("7440-38-2", "7782-44-7"))
  expect_identical(result$wqx_cas_lookup_status, c("missing", "invalid", "ambiguous", "not_found", "unavailable"))
  failed <- wqx_dictionary_candidates(matches, function(...) stop("mock outage"))
  expect_identical(failed$wqx_cas_lookup_status, c("missing", "invalid", "ambiguous", "unavailable", "unavailable"))
  empty <- wqx_dictionary_candidates(matches, function(...) tibble::tibble(
    original_cas = character(), dtxsid = character()))
  expect_identical(empty$wqx_cas_lookup_status, c("missing", "invalid", "ambiguous", "not_found", "not_found"))
})

test_that("mapping preserves per-column WQX attribution and protects raw evidence columns", {
  wqx_pipeline_mocks()
  df <- tibble::tibble(A = c("Arsenic", "Class without CAS"), B = c("Arsenic alias", "Arsenic"),
    dtxsid_A = "raw unvalidated ID", wqx_name_B = "raw vocabulary metadata")
  expect_warning(result <- run_curation_pipeline(df, list(A = "Name", B = "Name"),
    wqx_cas_lookup_fn = function(cas) tibble::tibble(original_cas = cas, dtxsid = "DTXSID123",
      preferredName = "Candidate"))$results, "Unused source identifier")
  expect_identical(result$dtxsid_A, df$dtxsid_A)
  expect_identical(result$wqx_name_B, df$wqx_name_B)
  expect_identical(result$wqx_name_lookup_A, c("Arsenic", "Class without CAS"))
  expect_identical(result$wqx_name_lookup_B, c("Arsenic", "Arsenic"))
  expect_identical(result$wqx_match_tier_lookup_B, c("alias", "exact"))
  expect_true(all(is.na(result$dtxsid_lookup_A)))
  expect_true(all(is.na(result$dtxsid_lookup_B)))
  expect_true(all(is.na(result$consensus_dtxsid)))
})

test_that("default WQX CAS service preserves ties and marks lookup outages", {
  local_mocked_bindings(ct_chemical_search_equal_bulk = function(cas) {
    tibble::tibble(searchValue = rep(cas, 2), dtxsid = c("DTXSID456", "DTXSID123"),
      preferredName = c("Second", "First"), rank = c(2L, 1L))
  }, .package = "ComptoxR")
  lookup <- validate_and_lookup_cas("7440-38-2", preserve_candidates = TRUE)
  expect_setequal(lookup$dtxsid, c("DTXSID123", "DTXSID456"))
  expect_true(all(lookup$lookup_status == "candidate"))
  primary <- validate_and_lookup_cas("7440-38-2")
  expect_identical(primary$dtxsid, "DTXSID123")
  local_mocked_bindings(ct_chemical_search_equal_bulk = function(...) stop("mock service outage"),
    .package = "ComptoxR")
  failed <- validate_and_lookup_cas("7440-38-2", preserve_candidates = TRUE)
  expect_identical(failed$lookup_status, "unavailable")
  local_mocked_bindings(ct_chemical_search_equal_bulk = function(...) tibble::tibble(),
    .package = "ComptoxR")
  expect_identical(validate_and_lookup_cas("7440-38-2", preserve_candidates = TRUE)$lookup_status, "unavailable")
  local_mocked_bindings(ct_chemical_search_equal_bulk = function(...) tibble::tibble(
    searchValue = character(), dtxsid = character()), .package = "ComptoxR")
  expect_identical(validate_and_lookup_cas("7440-38-2", preserve_candidates = TRUE)$lookup_status, "not_found")
})


test_that("fuzzy dictionary classes remain name-only despite a CAS candidate", {
  wqx_pipeline_mocks()
  result <- run_curation_pipeline(tibble::tibble(Chemical = "Arseni"), list(Chemical = "Name"),
    wqx_cas_lookup_fn = function(cas) tibble::tibble(original_cas = cas, dtxsid = "DTXSID123",
      preferredName = "A different chemical"))$results
  expect_identical(result$wqx_match_tier, "fuzzy")
  expect_identical(result$wqx_input_name, "Arseni")
  expect_identical(result$wqx_name, "Arsenic")
  expect_identical(result$wqx_cas_lookup_status, "candidate")
  expect_true(is.na(result$dtxsid))
  expect_true(is.na(result$consensus_dtxsid))
  expect_identical(result$consensus_status, "wqx")
})

test_that("empty and malformed WQX service output retains stable attribution", {
  matches <- match_wqx("Arsenic", wqx_pipeline_dictionary())
  malformed <- wqx_dictionary_candidates(matches, function(cas) tibble::tibble(unexpected = cas))
  expect_identical(malformed$wqx_cas_lookup_status, "unavailable")
  malformed_empty <- wqx_dictionary_candidates(matches, function(...) tibble::tibble())
  expect_identical(malformed_empty$wqx_cas_lookup_status, "unavailable")
  invalid <- wqx_dictionary_candidates(matches, function(cas) tibble::tibble(original_cas = cas,
    dtxsid = "malformed-ID"))
  expect_identical(invalid$wqx_cas_lookup_status, "unavailable")
  expect_true(is.na(invalid$wqx_cas_dtxsid_candidates))
  empty <- wqx_dictionary_candidates(matches[FALSE, ], function(...) stop("must not query"))
  expect_equal(nrow(empty), 0L)
  expect_named(empty, wqx_candidate_fields())
})


test_that("mapped WQX distances retain exact values as portable decimal text", {
  distance <- c(1 / 11, 0, NA_real_)
  matches <- tibble::tibble(input_name = letters[1:3], wqx_name = LETTERS[1:3],
    match_tier = "fuzzy", match_distance = distance)
  evidence <- wqx_dictionary_candidates(matches, function(...) stop("no CAS queries"))
  expect_type(evidence$wqx_match_distance, "character")
  expect_identical(as.numeric(evidence$wqx_match_distance), distance)
  expect_true(is.na(evidence$wqx_match_distance[3]))
  path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(path), add = TRUE)
  writexl::write_xlsx(evidence, path)
  imported <- readxl::read_xlsx(path)
  expect_identical(imported$wqx_match_distance, evidence$wqx_match_distance)
  expect_identical(matches$match_distance, distance)
})


test_that("no-hit mapping cannot adopt raw WQX evidence through an owned lookup suffix", {
  df <- tibble::tibble(Name = "No dictionary match", wqx_name = "Spoofed canonical",
    wqx_cas = "50-00-0", wqx_cas_dtxsid_candidates = "DTXSID777",
    wqx_name_lookup_Name = "Second spoofed canonical")
  keys <- tibble::tibble(row_idx = 1L, column_name = "Name", dedup_key = df$Name)
  lookup <- tibble::tibble(searchValue = df$Name, dtxsid = NA_character_,
    preferredName = NA_character_, searchName = NA_character_, rank = NA_integer_, source_tier = "miss")
  result <- map_results_to_rows(df, keys, lookup)
  expect_identical(result$lookup_evidence_columns, "dtxsid_lookup_Name_lookup")
  expect_identical(result[names(df)], df)
  expect_length(wqx_review_columns(result), 0L)
  expect_equal(nrow(normalize_review_candidates(result)), 0L)
  result <- classify_consensus(result, find_dtxsid_cols(result))
  queries <- unresolved_name_queries(result, "Name")
  expect_identical(queries$names, df$Name)
  expect_identical(queries$role, "original")
  expect_true(is.na(result$consensus_dtxsid))
})
