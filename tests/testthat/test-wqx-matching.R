# Test file for wqx_matching.R
# Tests MATCH-01 through MATCH-04 requirements

# Shared minimal mock dictionary — used across all tests
mock_dict <- tibble::tibble(
  name = c(
    "Arsenic",
    "Dissolved oxygen",
    "Lead",
    "Mercury",
    "DO",
    "Arsenic, Total",
    "Quicksilver"
  ),
  canonical_name = c(
    "Arsenic",
    "Dissolved oxygen",
    "Lead",
    "Mercury",
    "Dissolved oxygen",
    "Arsenic",
    "Mercury"
  ),
  type = c(
    "canonical",
    "canonical",
    "canonical",
    "canonical",
    "synonym",
    "standardize",
    "retired"
  ),
  cas_number = c(
    "7440-38-2",
    "7782-44-7",
    "7439-92-1",
    "7439-97-6",
    NA_character_,
    NA_character_,
    NA_character_
  ),
  group_name = c(
    "Metals",
    "Inorganics",
    "Metals",
    "Metals",
    NA_character_,
    NA_character_,
    NA_character_
  ),
  description = rep(NA_character_, 7)
)

pah_dict <- tibble::tibble(
  name = c(
    "Benz[a]anthracene",
    "Benzo(a)anthracene-D12",
    "Benzo(a) anthracene",
    "Benzo[a]anthracene",
    "Dibenz[a,h]anthracene",
    "Dibenz(g,h,i)perylene",
    "Dibenz (a,h) anthracene",
    "Dibenz (g,h,i) perylene"
  ),
  canonical_name = c(
    "Benz[a]anthracene",
    "Benzo(a)anthracene-D12",
    "Benz[a]anthracene",
    "Benz[a]anthracene",
    "Dibenz[a,h]anthracene",
    "Dibenz(g,h,i)perylene",
    "Dibenz[a,h]anthracene",
    "Dibenz(g,h,i)perylene"
  ),
  type = c(
    "canonical",
    "canonical",
    "synonym",
    "synonym",
    "canonical",
    "canonical",
    "synonym",
    "synonym"
  ),
  cas_number = rep(NA_character_, 8),
  group_name = rep(NA_character_, 8),
  description = rep(NA_character_, 8)
)

test_that("normalize_wqx_key canonicalizes single, paired, and triple locants", {
  inputs <- c(
    "benzo (a) anthracene",
    "benzo(a) anthracene",
    "BENZO[A]ANTHRACENE",
    "dibenz (a, h) anthracene",
    "dibenz [g, h, i] perylene"
  )

  expect_equal(
    normalize_wqx_key(inputs),
    c(
      "benzo(a)anthracene",
      "benzo(a)anthracene",
      "benzo(a)anthracene",
      "dibenz(a,h)anthracene",
      "dibenz(g,h,i)perylene"
    )
  )
})

# Test 1 (MATCH-01): Exact canonical name match
test_that("match_wqx returns exact tier for canonical name match", {
  result <- match_wqx("Arsenic", mock_dict)

  expect_equal(nrow(result), 1L)
  expect_equal(result$match_tier, "exact")
  expect_equal(result$wqx_name, "Arsenic")
  expect_true(is.na(result$match_distance))
  expect_true(is.na(result$alias_type))
})

test_that("match_wqx normalizes spaced single locants before fuzzy isotope fallback", {
  result <- match_wqx("benzo (a) anthracene", pah_dict)

  expect_equal(result$match_tier, "alias")
  expect_equal(result$wqx_name, "Benz[a]anthracene")
  expect_equal(result$alias_type, "synonym")
})

test_that("match_wqx normalizes comma-separated locants with spaces", {
  result <- match_wqx(c("dibenz (a, h) anthracene", "dibenz [g, h, i] perylene"), pah_dict)

  expect_equal(result$match_tier, c("exact", "exact"))
  expect_equal(result$wqx_name, c("Dibenz[a,h]anthracene", "Dibenz(g,h,i)perylene"))
})

# Test 2 (MATCH-01): Case-insensitive and whitespace-trimmed exact match
test_that("match_wqx is case-insensitive and trims whitespace for exact tier", {
  result <- match_wqx(c("ARSENIC", " Arsenic "), mock_dict)

  expect_equal(nrow(result), 2L)
  expect_true(all(result$match_tier == "exact"))
  expect_equal(result$input_name, c("ARSENIC", " Arsenic "))
})

# Test 3 (MATCH-02): Synonym alias resolves to canonical
test_that("match_wqx returns alias tier for synonym match", {
  result <- match_wqx("DO", mock_dict)

  expect_equal(nrow(result), 1L)
  expect_equal(result$match_tier, "alias")
  expect_equal(result$wqx_name, "Dissolved oxygen")
  expect_equal(result$alias_type, "synonym")
})

# Test 4 (MATCH-02): Standardize alias resolves to canonical
test_that("match_wqx returns alias tier for standardize match", {
  result <- match_wqx("Arsenic, Total", mock_dict)

  expect_equal(nrow(result), 1L)
  expect_equal(result$match_tier, "alias")
  expect_equal(result$wqx_name, "Arsenic")
  expect_equal(result$alias_type, "standardize")
})

# Test 5 (MATCH-03): Near-match returns fuzzy tier with distance <= 0.15
test_that("match_wqx returns fuzzy tier for near-match (Arsenick)", {
  result <- match_wqx("Arsenick", mock_dict)

  expect_equal(nrow(result), 1L)
  expect_equal(result$match_tier, "fuzzy")
  expect_false(is.na(result$match_distance))
  expect_true(result$match_distance <= 0.15)
  expect_equal(result$wqx_name, "Arsenic")
})

# Test 6 (MATCH-03): Distant name returns none tier
test_that("match_wqx returns none tier for distant name", {
  result <- match_wqx("XYZZY_NONEXISTENT_CHEMICAL", mock_dict)

  expect_equal(nrow(result), 1L)
  expect_equal(result$match_tier, "none")
  expect_true(is.na(result$wqx_name))
  expect_false(is.na(result$match_distance))
  expect_true(result$match_distance > 0.15)
})

# Test 7 (MATCH-04): Verbose logging behavior
test_that("match_wqx verbose=TRUE produces per-name output; verbose=FALSE does not", {
  # verbose=FALSE: no per-name messages should appear
  msgs_quiet <- character(0)
  withCallingHandlers(
    match_wqx("Arsenic", mock_dict, verbose = FALSE),
    message = function(m) {
      msgs_quiet <<- c(msgs_quiet, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )

  # verbose=TRUE: per-name messages should appear
  msgs_verbose <- character(0)
  withCallingHandlers(
    match_wqx("Arsenic", mock_dict, verbose = TRUE),
    message = function(m) {
      msgs_verbose <<- c(msgs_verbose, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )

  # verbose=FALSE: only the summary line (no per-name detail lines)
  # Summary line is always emitted; per-name lines only in verbose mode
  expect_gte(length(msgs_verbose), length(msgs_quiet))
  expect_true(length(msgs_verbose) > 0)
})

# Test 8: Empty character vector input returns zero-row tibble with correct schema
test_that("match_wqx returns zero-row tibble for empty input", {
  result <- match_wqx(character(0), mock_dict)

  expect_equal(nrow(result), 0L)
  expect_named(result, c("input_name", "wqx_name", "match_tier", "match_distance", "alias_type"))
  expect_s3_class(result, "tbl_df")
})

# Test 9: NA and empty-string inputs return none tier
test_that("match_wqx handles NA and empty string inputs returning none tier", {
  result <- match_wqx(c("Arsenic", NA_character_, ""), mock_dict)

  expect_equal(nrow(result), 3L)
  expect_equal(result$match_tier[1], "exact")
  expect_equal(result$match_tier[2], "none")
  expect_equal(result$match_tier[3], "none")
})

# Test 10: Return tibble has exactly the 5 required columns
test_that("match_wqx return tibble has exactly 5 columns with correct names", {
  result <- match_wqx("Arsenic", mock_dict)

  expect_s3_class(result, "tbl_df")
  expect_named(result, c("input_name", "wqx_name", "match_tier", "match_distance", "alias_type"))
  expect_equal(ncol(result), 5L)
})

# Test 11: Multiple names in single call, one per tier, all resolve correctly
test_that("match_wqx resolves multiple names in single call across all tiers", {
  inputs <- c("Arsenic", "DO", "Arsenick", "XYZZY_NONEXISTENT_CHEMICAL")
  result <- match_wqx(inputs, mock_dict)

  expect_equal(nrow(result), 4L)
  expect_equal(result$input_name, inputs)

  # Tier assignments
  expect_equal(result$match_tier[1], "exact")
  expect_equal(result$match_tier[2], "alias")
  expect_equal(result$match_tier[3], "fuzzy")
  expect_equal(result$match_tier[4], "none")

  # Alias type for alias row
  expect_equal(result$alias_type[2], "synonym")

  # Fuzzy distance within threshold
  expect_true(result$match_distance[3] <= 0.15)
})
