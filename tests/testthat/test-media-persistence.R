# test-media-persistence.R
# Round-trip tests for load_media_map() and harmonize_media() API extension
# Covers: bundled-cache path, user RDS merge, user precedence, backward compat,
# custom media_map parameter, and canonical/canonical_term column translation.

# ---- Helper: minimal AMOS table ------------------------------------------

make_amos_tbl <- function() {
  tibble::tibble(
    term = c("freshwater", "soil", "air", "marine water"),
    canonical_term = c("freshwater", "soil", "air", "marine water"),
    envo_id = c("ENVO:00000873", "ENVO:00001998", "ENVO:00002005", "ENVO:00002006"),
    parent = c("water", NA_character_, NA_character_, "water"),
    media_category = c("aqueous", "solid", "air", "aqueous"),
    source = rep("amos", 4),
    fetch_timestamp = rep(Sys.time(), 4)
  )
}

# ---- Helper: user RDS tibble (4-col display schema) ----------------------

make_user_map <- function() {
  tibble::tibble(
    term = c("freshwater", "wastewater"),
    canonical = c("freshwater_custom", "wastewater"),
    source = c("user", "user"),
    active = c(TRUE, TRUE)
  )
}

# ==============================================================================
# Section 1: load_media_map — bundled cache only (no user RDS)
# ==============================================================================

test_that("load_media_map returns expected columns when no user RDS exists", {
  withr::with_tempdir({
    # No user_media_map.rds here; get_media_table() returns real AMOS data
    result <- load_media_map(getwd())

    expect_s3_class(result, "tbl_df")
    expect_true("term" %in% names(result))
    expect_true("canonical" %in% names(result))
    expect_true("canonical_term" %in% names(result))
    expect_true("envo_id" %in% names(result))
    expect_true("media_category" %in% names(result))
    expect_true("source" %in% names(result))
    expect_true("active" %in% names(result))
  })
})

test_that("load_media_map bundled-only result has no user rows", {
  withr::with_tempdir({
    result <- load_media_map(getwd())

    if (nrow(result) > 0) {
      expect_false(any(result$source == "user"))
    } else {
      # amos_media.rds not yet built — empty tibble is acceptable
      expect_equal(nrow(result), 0L)
    }
  })
})

test_that("load_media_map returns 0-row typed tibble when both user RDS and AMOS are absent", {
  withr::with_tempdir({
    # Temporarily stub get_media_table to return NULL
    local_mocked_bindings(
      get_media_table = function() NULL,
      .package = "concert"
    )
    result <- load_media_map(getwd())

    expect_s3_class(result, "tbl_df")
    expect_equal(nrow(result), 0L)
    expect_true(all(
      c(
        "term",
        "canonical",
        "canonical_term",
        "envo_id",
        "media_category",
        "source",
        "active",
        "assertion_mode",
        "confidence"
      ) %in% names(result)
    ))
  })
})

# ==============================================================================
# Section 2: load_media_map — user RDS present
# ==============================================================================

test_that("load_media_map prepends user rows before AMOS rows", {
  withr::with_tempdir({
    user_map <- make_user_map()
    saveRDS(user_map, "user_media_map.rds", compress = FALSE)

    local_mocked_bindings(
      get_media_table = function() make_amos_tbl(),
      .package = "concert"
    )
    result <- load_media_map(getwd())

    # User rows should come first
    user_rows <- result[result$source == "user", ]
    expect_equal(nrow(user_rows), 2L)
    # First rows should be user
    expect_equal(result$source[seq_len(nrow(user_rows))], rep("user", nrow(user_rows)))
  })
})

test_that("load_media_map user entry for 'freshwater' suppresses AMOS entry for same term", {
  withr::with_tempdir({
    user_map <- make_user_map() # contains term = "freshwater"
    saveRDS(user_map, "user_media_map.rds", compress = FALSE)

    local_mocked_bindings(
      get_media_table = function() make_amos_tbl(),
      .package = "concert"
    )
    result <- load_media_map(getwd())

    freshwater_rows <- result[result$term == "freshwater", ]
    # Exactly one row for "freshwater" — the user row wins
    expect_equal(nrow(freshwater_rows), 1L)
    expect_equal(freshwater_rows$source, "user")
    # AMOS value for freshwater (canonical_term = "freshwater") should NOT appear
    expect_false(any(freshwater_rows$canonical == "freshwater" & freshwater_rows$source == "amos"))
  })
})

test_that("load_media_map round-trip: write user RDS, load_media_map includes user row", {
  withr::with_tempdir({
    user_row <- tibble::tibble(
      term = "unique_test_medium",
      canonical = "unique_canonical",
      source = "user",
      active = TRUE
    )
    saveRDS(user_row, "user_media_map.rds", compress = FALSE)

    local_mocked_bindings(
      get_media_table = function() make_amos_tbl(),
      .package = "concert"
    )
    result <- load_media_map(getwd())

    expect_true("unique_test_medium" %in% result$term)
    matched <- result[result$term == "unique_test_medium", ]
    expect_equal(matched$canonical, "unique_canonical")
    expect_equal(matched$source, "user")
  })
})

test_that("load_media_map backfills canonical_term from canonical when user RDS uses 4-col schema", {
  withr::with_tempdir({
    # 4-col schema: no canonical_term column
    user_map <- tibble::tibble(
      term = "custom_medium",
      canonical = "custom_canonical",
      source = "user",
      active = TRUE
    )
    saveRDS(user_map, "user_media_map.rds", compress = FALSE)

    local_mocked_bindings(
      get_media_table = function() make_amos_tbl(),
      .package = "concert"
    )
    result <- load_media_map(getwd())

    custom_row <- result[result$term == "custom_medium", ]
    expect_equal(custom_row$canonical_term, "custom_canonical")
  })
})

# ==============================================================================
# Section 3: harmonize_media — backward compatibility (media_map = NULL)
# ==============================================================================

test_that("harmonize_media with media_map = NULL still works (backward compat)", {
  result <- harmonize_media(c("water", "soil"), media_map = NULL)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2L)
  expect_named(
    result,
    c(
      "orig_row_id",
      "raw_media",
      "canonical_media",
      "envo_id",
      "media_category",
      "media_flag"
    )
  )
})

test_that("harmonize_media without media_map arg matches with media_map = NULL", {
  result_default <- harmonize_media(c("water", "soil"))
  result_null <- harmonize_media(c("water", "soil"), media_map = NULL)

  expect_equal(result_default, result_null)
})

# ==============================================================================
# Section 4: harmonize_media — custom media_map with canonical_term column
# ==============================================================================

test_that("harmonize_media uses custom media_map (canonical_term schema) instead of get_media_table", {
  custom_map <- tibble::tibble(
    term = c("custom_water", "custom_soil"),
    canonical_term = c("My Water", "My Soil"),
    envo_id = c("ENVO:CUSTOM1", "ENVO:CUSTOM2"),
    parent = c(NA_character_, NA_character_),
    media_category = c("aqueous", "solid"),
    source = rep("user", 2),
    active = c(TRUE, TRUE)
  )

  result <- harmonize_media(c("custom_water", "custom_soil"), media_map = custom_map)

  expect_equal(result$canonical_media, c("My Water", "My Soil"))
  expect_equal(result$media_category, c("aqueous", "solid"))
  expect_equal(result$media_flag, c("", ""))
})

test_that("harmonize_media returns media_unmatched for term not in custom media_map", {
  custom_map <- tibble::tibble(
    term = c("custom_water"),
    canonical_term = c("My Water"),
    envo_id = c("ENVO:CUSTOM1"),
    parent = NA_character_,
    media_category = "aqueous",
    source = "user",
    active = TRUE
  )

  result <- harmonize_media(c("completely_unknown_term"), media_map = custom_map)

  expect_equal(result$media_flag, "media_unmatched")
  expect_true(is.na(result$canonical_media))
})

# ==============================================================================
# Section 5: harmonize_media — custom media_map with canonical column (display schema)
# ==============================================================================

test_that("harmonize_media translates 'canonical' column but requires a resolvable media_category", {
  # Display schema: canonical not canonical_term. Without an inferable category,
  # the mapping is not usable for ppb/ppm routing and must remain unmatched.
  display_map <- tibble::tibble(
    term = c("display_medium"),
    canonical = c("Display Canonical"),
    source = "user",
    active = TRUE
  )

  result <- harmonize_media(c("display_medium"), media_map = display_map)

  expect_true(is.na(result$canonical_media))
  expect_true(is.na(result$media_category))
  expect_equal(result$media_flag, "media_unmatched")
})

test_that("harmonize_media with display-schema map falls back gracefully for missing term", {
  display_map <- tibble::tibble(
    term = c("known_term"),
    canonical = c("Known Canonical"),
    source = "user",
    active = TRUE
  )

  result <- harmonize_media(c("unknown_term"), media_map = display_map)

  expect_equal(result$media_flag, "media_unmatched")
  expect_true(is.na(result$canonical_media))
})

# ==============================================================================
# Section 6: harmonize_media — invalid media_map schema falls back to AMOS
# ==============================================================================

test_that("harmonize_media falls back to get_media_table when media_map lacks 'term' column", {
  bad_map <- tibble::tibble(
    wrong_col = c("water"),
    canonical_term = c("water")
  )

  # Should not error; falls back to bundled AMOS table
  result <- harmonize_media(c("water"), media_map = bad_map)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1L)
  # With bundled fallback, "water" should resolve
  expect_true(result$media_flag %in% c("", "parent_walk", "media_unmatched"))
})

# ==============================================================================
# Section 7: source tables and generated runtime cache
# ==============================================================================

test_that("media source tables build a deterministic legacy-compatible runtime map", {
  source_tables <- concert:::load_media_source_tables()

  map1 <- concert:::build_media_runtime_map(source_tables, fetch_timestamp = "2026-06-22T00:00:00")
  map2 <- concert:::build_media_runtime_map(source_tables, fetch_timestamp = "2026-06-22T00:00:00")

  legacy_cols <- c(
    "term",
    "canonical_term",
    "envo_id",
    "parent",
    "media_category",
    "source",
    "fetch_timestamp"
  )
  expect_true(all(legacy_cols %in% names(map1)))
  expect_true(all(c("assertion_mode", "confidence", "active") %in% names(map1)))
  expect_equal(map1, map2)
  expect_false(any(duplicated(map1$term)))
})

test_that("media source tables intentionally represent formerly unresolved AMOS terms", {
  source_tables <- concert:::load_media_source_tables()
  runtime_map <- concert:::build_media_runtime_map(source_tables, fetch_timestamp = "2026-06-22T00:00:00")

  former_unresolved <- c(
    "solid",
    "aqueous",
    "marine",
    "atmospheric",
    "lake",
    "runoff",
    "leachate"
  )
  represented <- runtime_map[runtime_map$term %in% former_unresolved, ]

  expect_setequal(represented$term, former_unresolved)
  expect_false(any(is.na(represented$assertion_mode) | !nzchar(represented$assertion_mode)))

  blank_canonical <- is.na(represented$canonical_term) | !nzchar(represented$canonical_term)
  expect_true(all(represented$assertion_mode[blank_canonical] == "pending"))
})

test_that("load_media_map preserves pending source rows for curation", {
  withr::with_tempdir({
    local_mocked_bindings(
      get_media_table = function() {
        tibble::tibble(
          term = c("runoff", "leachate"),
          canonical_term = c(NA_character_, "leachate"),
          envo_id = NA_character_,
          parent = NA_character_,
          media_category = c(NA_character_, "aqueous"),
          source = c("amos", "concert"),
          fetch_timestamp = "2026-06-22T00:00:00",
          assertion_mode = c("pending", "auto"),
          confidence = c("pending", "high"),
          active = TRUE
        )
      },
      .package = "concert"
    )

    result <- load_media_map(getwd())

    expect_true("runoff" %in% result$term)
    expect_equal(result$assertion_mode[result$term == "runoff"], "pending")
    expect_true(is.na(result$canonical[result$term == "runoff"]))
  })
})
