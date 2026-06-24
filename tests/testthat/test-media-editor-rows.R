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

test_that("build_media_editor_rows includes CONCERT rows and only unresolved AMOS rows", {
  rows <- concert:::build_media_editor_rows(make_editor_media_map(), NULL)

  water <- rows[rows$term == "water", ]
  expect_equal(nrow(water), 1L)
  expect_equal(water$source, "concert")

  expect_true("runoff" %in% rows$term)
  expect_false("marine" %in% rows$term)
})

test_that("build_media_editor_rows counts raw media hits separately from unmatched hits", {
  media_results <- tibble::tibble(
    raw_media = c("Marine", "marine", "runoff", "water", "mystery matrix"),
    media_flag = c("", "", "media_unmatched", "", "media_unmatched")
  )

  rows <- concert:::build_media_editor_rows(make_editor_media_map(), media_results)

  runoff <- rows[rows$term == "runoff", ]
  expect_equal(runoff$hit_count, 1L)
  expect_equal(runoff$unmatched_count, 1L)

  mystery <- rows[rows$term == "mystery matrix", ]
  expect_equal(mystery$hit_count, 1L)
  expect_equal(mystery$unmatched_count, 1L)

  water <- rows[rows$term == "water", ]
  expect_equal(water$hit_count, 1L)
  expect_equal(water$unmatched_count, 0L)

  expect_false("marine" %in% rows$term)
})

test_that("build_media_editor_rows sorts uploaded rows first by hit count", {
  media_results <- tibble::tibble(
    raw_media = c(
      "low matrix",
      "high matrix", "high matrix", "high matrix",
      "medium matrix", "medium matrix",
      "runoff",
      "water"
    ),
    media_flag = c(
      "media_unmatched",
      "media_unmatched", "media_unmatched", "media_unmatched",
      "media_unmatched", "media_unmatched",
      "media_unmatched",
      ""
    )
  )

  rows <- concert:::build_media_editor_rows(make_editor_media_map(), media_results)

  expect_equal(rows$source[1:3], rep("uploaded", 3))
  expect_equal(rows$term[1:3], c("high matrix", "medium matrix", "low matrix"))
  expect_equal(rows$hit_count[1:3], c(3L, 2L, 1L))
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

test_that("build_media_editor_rows sorts bundled media by ontology path", {
  media_map <- tibble::tibble(
    term = c("soil", "water", "air"),
    canonical = c("soil", "water", "air"),
    canonical_term = c("soil", "water", "air"),
    envo_id = c("ENVO:00001998", "ENVO:00002006", "ENVO:00002005"),
    media_category = c("solid", "aqueous", "air"),
    ontology_node_id = c("media.solid.soil", "media.liquid.aqueous.water", "media.gas.air"),
    ontology_path = c(
      "media > solid > soil",
      "media > liquid > aqueous > water",
      "media > gas > air"
    ),
    physical_state = c("solid", "liquid", "gas"),
    source = "concert",
    assertion_mode = "auto",
    confidence = "high",
    active = TRUE
  )

  rows <- concert:::build_media_editor_rows(media_map, NULL)

  expect_equal(rows$term, c("air", "water", "soil"))
})

test_that("build_media_editor_rows counts delimiter-coded UAT media under canonical terms", {
  media_map <- tibble::tibble(
    term = c("surface water", "tissue"),
    canonical = c("surface water", "tissue"),
    canonical_term = c("surface water", "tissue"),
    envo_id = c("ENVO:00002042", "ENVO:01001434"),
    media_category = c("aqueous", "solid"),
    source = "concert",
    assertion_mode = "auto",
    confidence = "high",
    active = TRUE
  )
  media_results <- harmonize_media(
    c("surface_water", "surface_water", "fish_tissue"),
    media_map = media_map
  )

  rows <- concert:::build_media_editor_rows(media_map, media_results)

  surface <- rows[rows$term == "surface water", ]
  tissue <- rows[rows$term == "tissue", ]
  expect_equal(surface$source, "concert")
  expect_equal(surface$hit_count, 2L)
  expect_equal(surface$unmatched_count, 0L)
  expect_equal(tissue$source, "concert")
  expect_equal(tissue$hit_count, 1L)
  expect_equal(tissue$unmatched_count, 0L)
})
