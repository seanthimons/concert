test_that("apply_value_corrections rewrites by regex, literal_exact, and literal_word", {
  df <- tibble::tibble(
    chemical = c("Total Lead", "Lead", "Leaded gas", "Zinc"),
    cas = c("7439-92-1", "bad", "bad", "7440-66-6")
  )
  corrections <- tibble::tibble(
    column = c("chemical", "cas", "chemical"),
    pattern = c("^Total ", "bad", "Lead"),
    replacement = c("", "0000-00-0", "Pb"),
    match_mode = c("regex", "literal_exact", "literal_word")
  )

  result <- apply_value_corrections(df, corrections)

  expect_equal(result$cleaned_data$chemical, c("Pb", "Pb", "Leaded gas", "Zinc"))
  expect_equal(result$cleaned_data$cas, c("7439-92-1", "0000-00-0", "0000-00-0", "7440-66-6"))
  expect_true(all(result$audit_trail$step == "value_correction"))
  expect_equal(nrow(result$audit_trail), 4)
})

test_that("apply_value_corrections validates columns and match_mode", {
  df <- tibble::tibble(chemical = "x")
  expect_error(
    apply_value_corrections(df, tibble::tibble(column = "nope", pattern = "x", replacement = "y")),
    "not in the data"
  )
  expect_error(
    apply_value_corrections(
      df,
      tibble::tibble(column = "chemical", pattern = "x", replacement = "y", match_mode = "fuzzy")
    ),
    "match_mode"
  )
  expect_identical(apply_value_corrections(df, NULL)$cleaned_data, df)
})

test_that("stage_clean applies value_corrections before cleaning and honours cleaning_steps", {
  input_path <- tempfile(fileext = ".csv")
  readr::write_csv(tibble::tibble(chemical = "Total  Lead ", cas = "7439921"), input_path)
  withr::defer(unlink(input_path))

  state <- stage_ingest(input_path, tag_map = list(chemical = "Name", cas = "CASRN"))
  cleaned <- suppressMessages(stage_clean(
    state,
    value_corrections = tibble::tibble(column = "chemical", pattern = "^Total\\s+", replacement = ""),
    cleaning_steps = list(cas = FALSE)
  ))

  expect_equal(cleaned$cleaning_result$cleaned_data$chemical, "Lead")
  expect_equal(cleaned$cleaning_result$cleaned_data$cas, "7439921")
  expect_true("value_correction" %in% cleaned$cleaning_result$audit_trail$step)
})

test_that("generate_concert_script embeds value_corrections, cleaning_steps, and multi_analyte_resolutions", {
  script <- generate_concert_script(
    input_path = "in.csv",
    output_path = "out.xlsx",
    tag_map = list(chemical = "Name"),
    header_row = NULL,
    value_corrections = tibble::tibble(column = "chemical", pattern = "^Total ", replacement = ""),
    cleaning_steps = list(chiral = FALSE),
    multi_analyte_resolutions = tibble::tibble(row_index = 3L, action = "split")
  )

  expect_match(script, "value_corrections <- ", fixed = TRUE)
  expect_match(script, "value_corrections = value_corrections", fixed = TRUE)
  expect_match(script, "cleaning_steps <- list(chiral = FALSE)", fixed = TRUE)
  expect_match(script, "cleaning_steps = cleaning_steps", fixed = TRUE)
  expect_match(script, "multi_analyte_resolutions = multi_analyte_resolutions", fixed = TRUE)

  env <- new.env()
  eval(parse(text = sub("curate_headless\\([\\s\\S]*$", "", script, perl = TRUE)), envir = env)
  expect_equal(env$value_corrections$pattern, "^Total ")
  expect_false(env$cleaning_steps$chiral)
})

test_that("generate_concert_script omits empty wild-type objects", {
  script <- generate_concert_script(
    input_path = "in.csv",
    output_path = "out.xlsx",
    tag_map = list(chemical = "Name"),
    header_row = NULL,
    value_corrections = tibble::tibble(column = character(), pattern = character(), replacement = character()),
    cleaning_steps = list()
  )
  expect_no_match(script, "value_corrections", fixed = TRUE)
  expect_no_match(script, "cleaning_steps", fixed = TRUE)
})
