test_that("tagged_row_summary formats tagged source strings for modal context", {
  df <- data.frame(
    Chemical = c("Dissolved oxygen", NA_character_),
    CASRN = c("7782-44-7", NA_character_),
    Notes = c("not tagged", "ignored"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  column_tags <- c("Chemical" = "Name", "CASRN" = "CASRN", "Missing" = "Name")

  values <- format_tagged_row_values(df, 1L, column_tags)
  expect_equal(unname(values), c("Chemical = 'Dissolved oxygen'", "CASRN = '7782-44-7'"))
  expect_false(any(grepl("Missing", values, fixed = TRUE)))
  expect_false(any(grepl("Notes", values, fixed = TRUE)))

  summary <- as.character(tagged_row_summary(df, 1L, column_tags))
  expect_match(summary, "Chemical = 'Dissolved oxygen'", fixed = TRUE)
  expect_match(summary, "CASRN = '7782-44-7'", fixed = TRUE)

  expect_equal(format_tagged_row_values(df, 2L, column_tags), character(0))
  expect_equal(format_tagged_row_values(df, 0L, column_tags), character(0))
  expect_null(tagged_row_summary(df, 2L, column_tags))
})

test_that("tagged_row_summary escapes source strings before rendering", {
  df <- data.frame(
    Chemical = "<script>alert('x')</script>",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  summary <- as.character(tagged_row_summary(df, 1L, c("Chemical" = "Name")))

  expect_match(summary, "&lt;script&gt;alert", fixed = TRUE)
  expect_no_match(summary, "<script>alert", fixed = TRUE)
})
