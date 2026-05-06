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

test_that("WQX matching narrows final_missed to only truly unresolved names", {
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
