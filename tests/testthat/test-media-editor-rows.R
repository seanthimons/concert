# test-media-editor-rows.R
# Tests for the Media Classification editor row model.

make_editor_media_map <- function() {
  tibble::tibble(
    term = c("water", "runoff", "soil", "marine"),
    canonical = c("water", NA_character_, "soil", "marine water"),
    canonical_term = c("water", NA_character_, "soil", "marine water"),
    envo_id = c("ENVO:00002006", NA_character_, "ENVO:00001998", "ENVO:00002149"),
    media_category = c("aqueous", NA_character_, "solid", "aqueous"),
    source = c("concert", "amos", "user", "amos"),
    assertion_mode = c("auto", "pending", "user", "auto"),
    confidence = c("high", "pending", "user", "medium"),
    active = TRUE
  )
}

test_that("build_media_editor_rows includes raw unmatched terms absent from media map", {
  media_results <- tibble::tibble(
    raw_media = c("mystery matrix", "water"),
    media_flag = c("media_unmatched", "")
  )

  rows <- concert:::build_media_editor_rows(make_editor_media_map(), media_results)

  mystery <- rows[rows$term == "mystery matrix", ]
  expect_equal(nrow(mystery), 1L)
  expect_true(mystery$is_raw_unmatched)
  expect_equal(mystery$hit_count, 1L)
  expect_equal(mystery$unmatched_count, 1L)
})

test_that("build_media_editor_rows collapses duplicate raw unmatched rows with a count", {
  media_results <- tibble::tibble(
    raw_media = c("Mystery Matrix", " mystery matrix ", "MYSTERY MATRIX"),
    media_flag = rep("media_unmatched", 3)
  )

  rows <- concert:::build_media_editor_rows(make_editor_media_map(), media_results)

  mystery <- rows[rows$term == "mystery matrix", ]
  expect_equal(nrow(mystery), 1L)
  expect_equal(mystery$hit_count, 3L)
  expect_equal(mystery$unmatched_count, 3L)
})

test_that("build_media_editor_rows hides CONCERT source rows from AMOS review model", {
  rows <- concert:::build_media_editor_rows(make_editor_media_map(), NULL)

  expect_false("concert" %in% rows$source)
  expect_false("water" %in% rows$term)
})

test_that("build_media_editor_rows counts raw media hits separately from unmatched hits", {
  media_results <- tibble::tibble(
    raw_media = c("Marine", "marine", "runoff", "water", "mystery matrix"),
    media_flag = c("", "", "media_unmatched", "", "media_unmatched")
  )

  rows <- concert:::build_media_editor_rows(make_editor_media_map(), media_results)

  marine <- rows[rows$term == "marine", ]
  expect_equal(marine$hit_count, 2L)
  expect_equal(marine$unmatched_count, 0L)

  runoff <- rows[rows$term == "runoff", ]
  expect_equal(runoff$hit_count, 1L)
  expect_equal(runoff$unmatched_count, 1L)

  mystery <- rows[rows$term == "mystery matrix", ]
  expect_equal(mystery$hit_count, 1L)
  expect_equal(mystery$unmatched_count, 1L)

  expect_false("water" %in% rows$term)
})

test_that("build_media_editor_rows includes pending aliases with no upload results", {
  rows <- concert:::build_media_editor_rows(make_editor_media_map(), NULL)

  runoff <- rows[rows$term == "runoff", ]
  expect_equal(nrow(runoff), 1L)
  expect_equal(runoff$assertion_mode, "pending")
  expect_true(is.na(runoff$canonical))
  expect_equal(runoff$hit_count, 0L)
  expect_equal(runoff$unmatched_count, 0L)
})
