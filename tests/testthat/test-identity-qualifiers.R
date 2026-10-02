test_that("13C6 identity enclosures survive cleaning without extraction or audit changes", {
  input <- tibble::tibble(
    name = c(
      "Dibenz(ah)anthracene (13C6)",
      "Dibenz(ah)anthracene [13C6]",
      "Acetone (ACS reagent)",
      "Compound (X13C6)",
      "Compound [13C6note]",
      NA_character_
    )
  )

  result <- strip_terminal_enclosures(input, "name")

  expect_identical(
    result$cleaned_data$name,
    c(
      input$name[1:2],
      "Acetone",
      "Compound",
      "Compound",
      NA_character_
    )
  )
  expect_identical(
    result$cleaned_data$formula_extract_name,
    c(
      NA_character_,
      NA_character_,
      "ACS reagent",
      "X13C6",
      "13C6note",
      NA_character_
    )
  )
  expect_identical(result$audit_trail$row_id, 3:5)
  expect_identical(result$audit_trail$original_value, input$name[3:5])
  expect_identical(result$audit_trail$new_value, c("Acetone", "Compound", "Compound"))
})
