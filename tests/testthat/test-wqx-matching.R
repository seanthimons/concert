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
  expect_named(result, c(
    "input_name", "wqx_name", "match_tier", "match_distance", "alias_type",
    "wqx_cas", "wqx_cas_status", "wqx_cas_raw", "wqx_cas_provenance"
  ))
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

# Test 10: Return tibble has the stable additive evidence schema
test_that("match_wqx return tibble has the stable additive evidence columns", {
  result <- match_wqx("Arsenic", mock_dict)

  expect_s3_class(result, "tbl_df")
  expect_named(result, c(
    "input_name", "wqx_name", "match_tier", "match_distance", "alias_type",
    "wqx_cas", "wqx_cas_status", "wqx_cas_raw", "wqx_cas_provenance"
  ))
  expect_equal(ncol(result), 9L)
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

test_that("match_wqx fuzzy tier never bridges isotope labels or congener codes", {
  dict <- tibble::tibble(
    name = c("Prochloraz", "PCB 138", "Diazepam-D5", "Progesterone-2,3,4-13C3"),
    canonical_name = c("Prochloraz", "PCB 138", "Diazepam-D5", "Progesterone-2,3,4-13C3"),
    type = "canonical"
  )
  inputs <- c("Prochloraz-d4", "PCB 153", "Diazepam d5", "Testosterone-2,3,4-13C3", "Diazepm-D5", "Prochloraze")
  result <- match_wqx(inputs, dict)

  expect_equal(result$match_tier, c("none", "none", "fuzzy", "none", "none", "fuzzy"))
  expect_equal(result$wqx_name, c(NA, NA, "Diazepam-D5", NA, NA, "Prochloraz"))
})


test_that("WQX CAS evidence comes from canonical rows across match tiers", {
  dict <- mock_dict
  # A populated, conflicting alias CAS must never replace canonical evidence.
  dict$cas_number[dict$name == "DO"] <- "50-00-0"
  result <- match_wqx(c("Arsenic", "DO", "Arsenick"), dict)

  expect_equal(result$wqx_cas, c("7440-38-2", "7782-44-7", "7440-38-2"))
  expect_equal(result$wqx_cas_status, rep("valid", 3))
  expect_equal(result$wqx_cas_raw, result$wqx_cas)
  expect_equal(result$wqx_cas_provenance,
    c("canonical:arsenic", "canonical:dissolved oxygen", "canonical:arsenic"))
})

test_that("aliases resolve CAS using normalized canonical keys and priority", {
  alias <- mock_dict[mock_dict$name == "DO", ]
  alias$canonical_name <- "  DISSOLVED OXYGEN "
  retired <- alias
  retired$type <- "retired"
  retired$canonical_name <- "Mercury"
  retired$cas_number <- "7439-97-6"
  dict <- dplyr::bind_rows(retired, mock_dict[mock_dict$type == "canonical", ], alias)

  result <- match_wqx("DO", dict)
  expect_equal(result$alias_type, "synonym")
  expect_equal(result$wqx_cas, "7782-44-7")
  expect_equal(result$wqx_cas_provenance, "canonical:dissolved oxygen")
})

test_that("missing and malformed canonical CAS remain distinct evidence", {
  dict <- mock_dict
  dict$cas_number[1:4] <- c(NA, "", "50-00-1", "NOCAS_1355346")
  result <- match_wqx(c("Arsenic", "DO", "Lead", "Mercury", "XYZZY_NONEXISTENT_CHEMICAL"), dict)

  expect_true(all(is.na(result$wqx_cas)))
  expect_equal(result$wqx_cas_status, c("missing", "missing", "invalid", "invalid", "missing"))
  expect_equal(result$wqx_cas_raw, c(NA, NA, "50-00-1", "NOCAS_1355346", NA))
  expect_true(is.na(result$wqx_cas_provenance[5]))

  dict$cas_number <- NULL
  expect_equal(match_wqx(c("Arsenic", "DO"), dict)$wqx_cas_status, rep("missing", 2))
})

test_that("duplicate canonical entries never choose conflicting CAS values", {
  duplicate <- mock_dict[1, ]
  same <- match_wqx("Arsenic", dplyr::bind_rows(mock_dict, duplicate))
  expect_equal(same$wqx_cas, "7440-38-2")
  expect_equal(same$wqx_cas_status, "valid")

  duplicate$name <- " ARSENIC "
  duplicate$cas_number <- "50-00-0"
  conflicting <- dplyr::bind_rows(mock_dict, duplicate)
  result <- match_wqx(c("Arsenic", "Arsenic, Total", "Arsenick"), conflicting)
  expect_true(all(is.na(result$wqx_cas)))
  expect_equal(result$wqx_cas_status, rep("ambiguous", 3))
  expect_equal(result$wqx_cas_raw, rep("50-00-0 | 7440-38-2", 3))
  reversed <- match_wqx("Arsenic", conflicting[nrow(conflicting):1, ])
  expect_equal(reversed$wqx_cas_status, "ambiguous")
  expect_equal(reversed$wqx_cas_raw, result$wqx_cas_raw[1])
})

test_that("empty dictionaries and dangling aliases preserve stable CAS evidence", {
  empty <- mock_dict[FALSE, ]
  result <- match_wqx(c("Arsenic", NA, ""), empty)
  expect_equal(result$match_tier, rep("none", 3))
  expect_equal(result$wqx_cas_status, rep("missing", 3))
  expect_true(all(is.na(result$wqx_cas)))
  expect_true(all(is.na(result$wqx_cas_provenance)))
  expect_identical(names(result), names(match_wqx(character(), mock_dict)))

  dangling <- mock_dict[mock_dict$name == "DO", ]
  dangling$cas_number <- "50-00-0"
  alias_result <- match_wqx("DO", dangling)
  expect_equal(alias_result$match_tier, "alias")
  expect_equal(alias_result$wqx_cas_status, "missing")
  expect_true(is.na(alias_result$wqx_cas))
})


test_that("fuzzy distance ties do not arbitrarily select canonical CAS evidence", {
  dict <- tibble::tibble(
    name = c("ABCD", "ABCE"),
    canonical_name = c("ABCD", "ABCE"),
    type = "canonical",
    cas_number = c("50-00-0", "7732-18-5")
  )
  result <- match_wqx("ABCF", dict, threshold = 0.8)
  reversed <- match_wqx("ABCF", dict[2:1, ], threshold = 0.8)
  expect_equal(result$match_tier, "none")
  expect_true(is.na(result$wqx_name))
  expect_true(is.na(result$wqx_cas))
  expect_identical(result, reversed)
})


test_that("equal-priority conflicting aliases never choose a canonical identity", {
  dict <- tibble::tibble(
    name = c("Arsenic", "Water", "Arsenick", " ARSENICK "),
    canonical_name = c("Arsenic", "Water", "Arsenic", "Water"),
    type = c("canonical", "canonical", "synonym", "synonym"),
    cas_number = c("7440-38-2", "7732-18-5", NA, NA)
  )
  # Arsenick would ordinarily fuzzy-match Arsenic. That must not conceal its
  # explicit equal-priority alias conflict.
  forward <- match_wqx("Arsenick", dict)
  reversed <- match_wqx("Arsenick", dict[nrow(dict):1, ])
  expect_identical(forward, reversed)
  expect_equal(forward$match_tier, "none")
  expect_true(is.na(forward$wqx_name))
  expect_true(is.na(forward$wqx_cas))
  expect_true(is.na(forward$wqx_cas_provenance))
  expect_true(is.na(forward$match_distance))
})

test_that("alias precedence and duplicate normalized targets remain usable", {
  dict <- tibble::tibble(
    name = c("Arsenic", "Water", "Alias X", "Alias X", "Alias X", "Alias X"),
    canonical_name = c("Arsenic", "Water", "Arsenic", "Water", "Water", " WATER "),
    type = c("canonical", "canonical", "retired", "synonym", "standardize", "standardize"),
    cas_number = c("7440-38-2", "7732-18-5", NA, NA, NA, NA)
  )
  for (rows in list(seq_len(nrow(dict)), nrow(dict):1)) {
    result <- match_wqx("Alias X", dict[rows, ])
    expect_equal(result$match_tier, "alias")
    expect_equal(normalize_wqx_key(result$wqx_name), "water")
    expect_equal(result$alias_type, "standardize")
    expect_equal(result$wqx_cas, "7732-18-5")
    expect_equal(result$wqx_cas_status, "valid")
  }
})
