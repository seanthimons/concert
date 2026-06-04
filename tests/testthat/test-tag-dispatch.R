# Test tag dispatch helpers
# Phase 33: Extended Column Tagging

test_that("classify_tags partitions chemical tags correctly", {
  tags <- list(col1 = "Name", col2 = "CASRN", col3 = "Other")
  result <- classify_tags(tags)

  expect_type(result, "list")
  expect_named(result, c("chemical_tags", "numeric_tags", "metadata_tags", "study_type_tags"))
  expect_equal(result$chemical_tags, list(col1 = "Name", col2 = "CASRN", col3 = "Other"))
  expect_equal(result$numeric_tags, list())
  expect_equal(result$metadata_tags, list())
})

test_that("classify_tags partitions numeric tags correctly", {
  tags <- list(
    col1 = "Result",
    col2 = "Numeric",
    col3 = "Unit",
    col4 = "Qualifier",
    col5 = "Duration",
    col6 = "DurationUnit"
  )

  result <- classify_tags(tags)

  expect_equal(result$chemical_tags, list())
  expect_equal(result$numeric_tags, tags)
  expect_equal(result$metadata_tags, list())
})

test_that("classify_tags partitions metadata tags correctly", {
  tags <- list(col1 = "Species", col2 = "ExposureRoute")
  result <- classify_tags(tags)

  expect_equal(result$chemical_tags, list())
  expect_equal(result$numeric_tags, list())
  expect_equal(result$metadata_tags, tags)
})

test_that("classify_tags handles mixed tag types", {
  tags <- list(col1 = "Name", col2 = "Result", col3 = "Species")
  result <- classify_tags(tags)

  expect_equal(result$chemical_tags, list(col1 = "Name"))
  expect_equal(result$numeric_tags, list(col2 = "Result"))
  expect_equal(result$metadata_tags, list(col3 = "Species"))
})

test_that("classify_tags handles empty input", {
  result <- classify_tags(list())

  expect_type(result, "list")
  expect_named(result, c("chemical_tags", "numeric_tags", "metadata_tags", "study_type_tags"))
  expect_equal(result$chemical_tags, list())
  expect_equal(result$numeric_tags, list())
  expect_equal(result$metadata_tags, list())
})

test_that("validate_tag_pairing warns on Result without Unit", {
  tags <- list(col1 = "Result")
  result <- validate_tag_pairing(tags)

  expect_type(result, "character")
  expect_match(result, "Result.*Unit", ignore.case = TRUE)
})

test_that("validate_tag_pairing warns on Unit without Result", {
  tags <- list(col1 = "Unit")
  result <- validate_tag_pairing(tags)

  expect_type(result, "character")
  expect_match(result, "Unit.*Result", ignore.case = TRUE)
})

test_that("validate_tag_pairing returns NULL for paired Result/Unit", {
  tags <- list(col1 = "Result", col2 = "Unit")
  result <- validate_tag_pairing(tags)

  expect_null(result)
})

test_that("validate_tag_pairing treats Unit paired with Numeric as valid", {
  tags <- list(col1 = "Numeric", col2 = "Unit")
  result <- validate_tag_pairing(tags)

  expect_null(result)
})

test_that("validate_tag_pairing returns NULL for non-numeric tags", {
  tags <- list(col1 = "Name", col2 = "CASRN")
  result <- validate_tag_pairing(tags)

  expect_null(result)
})

test_that("validate_tag_pairing returns NULL for empty tags", {
  result <- validate_tag_pairing(list())
  expect_null(result)
})

test_that("detect_tag_changes returns TRUE when tags differ", {
  old_tags <- list(col1 = "Name")
  new_tags <- list(col1 = "Name", col2 = "CASRN")

  expect_true(detect_tag_changes(old_tags, new_tags))
})

test_that("detect_tag_changes returns FALSE when tags identical", {
  tags <- list(col1 = "Name", col2 = "CASRN")

  expect_false(detect_tag_changes(tags, tags))
})

test_that("detect_tag_changes returns TRUE for NULL old_tags (first apply)", {
  new_tags <- list(col1 = "Name")

  expect_true(detect_tag_changes(NULL, new_tags))
})

test_that("detect_tag_changes returns TRUE when values change", {
  old_tags <- list(col1 = "Name")
  new_tags <- list(col1 = "CASRN")

  expect_true(detect_tag_changes(old_tags, new_tags))
})

test_that("detect_tag_changes returns FALSE for two empty lists", {
  expect_false(detect_tag_changes(list(), list()))
})

test_that("detect_tag_changes returns TRUE when column removed", {
  old_tags <- list(col1 = "Name", col2 = "CASRN")
  new_tags <- list(col1 = "Name")

  expect_true(detect_tag_changes(old_tags, new_tags))
})

test_that("classify_tags handles all tag types correctly", {
  # Test all tag types per D-06, D-07, D-08
  all_tags <- list(
    c1 = "Name",
    c2 = "CASRN",
    c3 = "Other",
    n1 = "Result",
    n2 = "Numeric",
    n3 = "Unit",
    n4 = "Qualifier",
    n5 = "Duration",
    n6 = "DurationUnit",
    m1 = "Species",
    m2 = "ExposureRoute"
  )

  result <- classify_tags(all_tags)

  # Chemical: 3 types

  expect_equal(length(result$chemical_tags), 3)
  expect_equal(unlist(result$chemical_tags, use.names = FALSE), c("Name", "CASRN", "Other"))


  # Numeric: 5 types
  expect_equal(length(result$numeric_tags), 6)
  expect_equal(
    unlist(result$numeric_tags, use.names = FALSE),
    c("Result", "Numeric", "Unit", "Qualifier", "Duration", "DurationUnit")
  )

  # Metadata: 2 types
  expect_equal(length(result$metadata_tags), 2)
  expect_equal(unlist(result$metadata_tags, use.names = FALSE), c("Species", "ExposureRoute"))
})

test_that("classify_tags partitions study_type tags correctly", {
  tags <- list(col1 = "StudyDate")
  result <- classify_tags(tags)
  expect_named(result, c("chemical_tags", "numeric_tags", "metadata_tags", "study_type_tags"))
  expect_equal(result$study_type_tags, list(col1 = "StudyDate"))
  expect_equal(result$chemical_tags, list())
  expect_equal(result$numeric_tags, list())
  expect_equal(result$metadata_tags, list())
})

test_that("classify_tags handles mixed tags including StudyDate", {
  tags <- list(col1 = "Name", col2 = "Result", col3 = "StudyDate", col4 = "Species")
  result <- classify_tags(tags)
  expect_equal(result$chemical_tags, list(col1 = "Name"))
  expect_equal(result$numeric_tags, list(col2 = "Result"))
  expect_equal(result$study_type_tags, list(col3 = "StudyDate"))
  expect_equal(result$metadata_tags, list(col4 = "Species"))
})
