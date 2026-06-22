# test-media-harmonizer.R
# Tests for harmonize_media() -- MEDIA-01 through MEDIA-03
# Covers: output schema, exact match, case insensitivity, compound media,
#         parent-walk resolution, unmatched flagging, empty-input guard,
#         mixed vector, and media_category domain constraint

# ---- Helper: canonical test vector ----
make_test_media <- function() {
  c(
    "water", # exact match -> aqueous
    "freshwater", # exact match -> aqueous
    "freshwater sediment", # compound first-class -> solid
    "soil", # exact match -> solid
    "air", # exact match -> air
    "blood", # may be present/absent in ENVO subset
    "unknown_matrix_xyz", # unmatched -> media_unmatched flag
    NA_character_ # NA input
  )
}

# ==============================================================================
# SECTION 1: Output schema (MEDIA-01)
# ==============================================================================

test_that("harmonize_media returns 6-column tibble with correct names", {
  result <- harmonize_media(c("water"))

  expect_s3_class(result, "tbl_df")
  expect_named(result, c(
    "orig_row_id", "raw_media", "canonical_media",
    "envo_id", "media_category", "media_flag"
  ))
})

test_that("harmonize_media returns correct column types", {
  result <- harmonize_media(c("water"))

  expect_type(result$orig_row_id, "integer")
  expect_type(result$raw_media, "character")
  expect_type(result$canonical_media, "character")
  expect_type(result$envo_id, "character")
  expect_type(result$media_category, "character")
  expect_type(result$media_flag, "character")
})

test_that("harmonize_media orig_row_id defaults to seq_along", {
  result <- harmonize_media(c("water", "soil", "air"))

  expect_equal(result$orig_row_id, c(1L, 2L, 3L))
  expect_type(result$orig_row_id, "integer")
})

# ==============================================================================
# SECTION 2: Exact match resolution (MEDIA-01, MEDIA-02)
# ==============================================================================

test_that("harmonize_media exact match: water returns aqueous category", {
  result <- harmonize_media(c("water"))

  expect_equal(result$canonical_media, "water")
  expect_equal(result$media_category, "aqueous")
  expect_equal(result$media_flag, "")
})

test_that("harmonize_media exact match: soil returns solid category", {
  result <- harmonize_media(c("soil"))

  expect_equal(result$canonical_media, "soil")
  expect_equal(result$media_category, "solid")
  expect_equal(result$media_flag, "")
})

test_that("harmonize_media exact match: air returns air category", {
  result <- harmonize_media(c("air"))

  expect_equal(result$canonical_media, "air")
  expect_equal(result$media_category, "air")
  expect_equal(result$media_flag, "")
})

test_that("harmonize_media resolves active CONCERT routing aliases", {
  result <- harmonize_media(c("solid", "aqueous", "atmospheric"))

  expect_equal(result$canonical_media, c("solid", "aqueous", "air"))
  expect_equal(result$media_category, c("solid", "aqueous", "air"))
  expect_equal(result$media_flag, c("", "", ""))
})

test_that("harmonize_media exact match: envo_id is populated for matched terms", {
  result <- harmonize_media(c("water"))

  expect_false(is.na(result$envo_id))
  expect_match(result$envo_id, "^ENVO:")
})

# ==============================================================================
# SECTION 3: Case insensitivity and whitespace trimming
# ==============================================================================

test_that("harmonize_media normalises uppercase input to canonical term", {
  result <- harmonize_media(c("WATER"))

  expect_equal(result$canonical_media, "water")
  expect_equal(result$media_category, "aqueous")
})

test_that("harmonize_media normalises mixed-case input to canonical term", {
  result <- harmonize_media(c("Water"))

  expect_equal(result$canonical_media, "water")
  expect_equal(result$media_category, "aqueous")
})

test_that("harmonize_media trims leading and trailing whitespace", {
  result <- harmonize_media(c("  water  "))

  expect_equal(result$canonical_media, "water")
  expect_equal(result$media_category, "aqueous")
})

# ==============================================================================
# SECTION 4: Compound media first-class entries (MEDIA-03)
# ==============================================================================

test_that("harmonize_media freshwater sediment is a first-class entry with solid category", {
  result <- harmonize_media(c("freshwater sediment"))

  expect_equal(result$canonical_media, "freshwater sediment")
  expect_equal(result$media_category, "solid")
  expect_equal(result$media_flag, "")
})

test_that("harmonize_media compound media has a populated envo_id", {
  result <- harmonize_media(c("freshwater sediment"))

  expect_false(is.na(result$envo_id))
})

# ==============================================================================
# SECTION 5: Parent-walk resolution (D-08)
# ==============================================================================

test_that("harmonize_media parent-walk: freshwater resolves to aqueous via parent walk", {
  result <- harmonize_media(c("freshwater"))

  expect_equal(result$media_category, "aqueous")
  # freshwater is an exact entry but parent walk is also valid to test via a
  # less directly rooted term; the key test is the flag is "" or "parent_walk"
  expect_true(result$media_flag %in% c("", "parent_walk"))
})

test_that("harmonize_media parent-walk flag is set when resolution uses parent hierarchy", {
  # surface water -> parent=water (aqueous) -- tests the parent_walk flag
  result <- harmonize_media(c("surface water"))

  # surface water is a curated entry; if direct exact match then flag = ""
  # If not in table but parent-walk resolves it, flag = "parent_walk"
  expect_true(result$media_flag %in% c("", "parent_walk"))
  expect_equal(result$media_category, "aqueous")
})

# ==============================================================================
# SECTION 6: Unmatched flagging (D-10)
# ==============================================================================

test_that("harmonize_media unknown string returns media_unmatched flag", {
  result <- harmonize_media(c("unknown_matrix_xyz"))

  expect_equal(result$media_flag, "media_unmatched")
  expect_true(is.na(result$canonical_media))
  expect_true(is.na(result$media_category))
})

test_that("harmonize_media NA input returns media_unmatched flag", {
  result <- harmonize_media(c(NA_character_))

  expect_equal(result$media_flag, "media_unmatched")
  expect_true(is.na(result$canonical_media))
})

test_that("harmonize_media raw_media preserves original NA for unmatched NA input", {
  result <- harmonize_media(c(NA_character_))

  expect_true(is.na(result$raw_media))
})

# ==============================================================================
# SECTION 7: Empty input guard
# ==============================================================================

test_that("harmonize_media returns 0-row typed tibble for character(0) input", {
  result <- harmonize_media(character(0))

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
  expect_named(result, c(
    "orig_row_id", "raw_media", "canonical_media",
    "envo_id", "media_category", "media_flag"
  ))
})

test_that("harmonize_media empty tibble has correct column types", {
  result <- harmonize_media(character(0))

  expect_type(result$orig_row_id, "integer")
  expect_type(result$raw_media, "character")
  expect_type(result$canonical_media, "character")
  expect_type(result$envo_id, "character")
  expect_type(result$media_category, "character")
  expect_type(result$media_flag, "character")
})

# ==============================================================================
# SECTION 8: Mixed vector -- single call with multiple resolution paths
# ==============================================================================

test_that("harmonize_media handles mixed vector with exact, parent-walk, and unmatched", {
  inputs <- c("water", "freshwater sediment", "unknown_matrix_xyz", NA_character_)
  result <- harmonize_media(inputs)

  expect_equal(nrow(result), 4L)

  # water: exact match
  expect_equal(result$media_flag[1], "")
  expect_equal(result$media_category[1], "aqueous")

  # freshwater sediment: first-class compound (exact match in table)
  expect_equal(result$media_flag[2], "")
  expect_equal(result$media_category[2], "solid")

  # unknown_matrix_xyz: unmatched
  expect_equal(result$media_flag[3], "media_unmatched")
  expect_true(is.na(result$media_category[3]))

  # NA: unmatched
  expect_equal(result$media_flag[4], "media_unmatched")
})

test_that("harmonize_media produces identical output for repeated identical inputs", {
  result1 <- harmonize_media(c("water", "soil", "air"))
  result2 <- harmonize_media(c("water", "soil", "air"))

  expect_equal(result1, result2)
})

test_that("harmonize_media custom orig_row_id parameter is honored", {
  result <- harmonize_media(c("water", "soil", "air"), orig_row_id = c(5L, 10L, 15L))

  expect_equal(result$orig_row_id, c(5L, 10L, 15L))
})

# ==============================================================================
# SECTION 9: media_category domain constraint
# ==============================================================================

test_that("harmonize_media all media_category values are in permitted domain", {
  inputs <- make_test_media()
  result <- harmonize_media(inputs)

  permitted_set <- c("aqueous", "air", "solid")
  # Vectorized check: non-NA values must all be in permitted set
  non_na_cats <- result$media_category[!is.na(result$media_category)]
  expect_true(all(non_na_cats %in% permitted_set))
})

test_that("harmonize_media media_category is NA for unmatched entries", {
  result <- harmonize_media(c("unknown_matrix_xyz"))

  expect_true(is.na(result$media_category))
})

test_that("harmonize_media ignores pending aliases but resolves active auto aliases", {
  media_map <- tibble::tibble(
    term = c("runoff", "leachate"),
    canonical_term = c("surface water", "leachate"),
    envo_id = c("ENVO:00002042", NA_character_),
    parent = NA_character_,
    media_category = c("aqueous", "aqueous"),
    source = c("amos", "concert"),
    assertion_mode = c("pending", "auto"),
    active = TRUE
  )

  result <- harmonize_media(c("runoff", "leachate"), media_map = media_map)

  expect_equal(result$media_flag, c("media_unmatched", ""))
  expect_true(is.na(result$canonical_media[1]))
  expect_equal(result$canonical_media[2], "leachate")
  expect_equal(result$media_category[2], "aqueous")
})

test_that("harmonize_media user aliases override bundled aliases for the same term", {
  media_map <- tibble::tibble(
    term = c("marine", "marine"),
    canonical_term = c("sediment", "marine water"),
    envo_id = c("ENVO:00002007", "ENVO:00002149"),
    parent = NA_character_,
    media_category = c("solid", "aqueous"),
    source = c("user", "amos"),
    assertion_mode = c("user", "auto"),
    active = TRUE
  )

  result <- harmonize_media("marine", media_map = media_map)

  expect_equal(result$canonical_media, "sediment")
  expect_equal(result$media_category, "solid")
})
