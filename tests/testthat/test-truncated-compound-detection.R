test_that("detect_truncated_compound_names flags unbalanced delimiters", {
  df <- tibble::tibble(
    chemical_name = c(
      "Bisphenol A (BPA",
      "compound [mixture",
      "compound)",
      "compound]",
      "Chromium (III)",
      "A [B]",
      "nested (A [B]) text"
    )
  )

  result <- detect_truncated_compound_names(df, "chemical_name")

  expect_equal(result$cleaned_data$chemical_name, df$chemical_name)
  expect_true(all(grepl(
    "BLOCK: truncated compound \\[unbalanced delimiter\\]",
    result$cleaned_data$cleaning_flag[1:4]
  )))
  expect_true(all(is.na(result$cleaned_data$cleaning_flag[5:7])))
  expect_equal(nrow(result$audit_trail), 4)
  expect_true(all(result$audit_trail$step == "detect_truncated_compound"))
})

test_that("detect_truncated_compound_names flags ellipsis markers", {
  df <- tibble::tibble(
    chemical_name = c(
      "1-Octanesulfonamide, N-ethyl- ... ammonium salt",
      "compound ....",
      "compound \u2026",
      "compound ..",
      "acetone"
    )
  )

  result <- detect_truncated_compound_names(df, "chemical_name")

  expect_equal(result$cleaned_data$chemical_name, df$chemical_name)
  expect_true(all(grepl(
    "BLOCK: truncated compound \\[ellipsis\\]",
    result$cleaned_data$cleaning_flag[1:3]
  )))
  expect_true(all(is.na(result$cleaned_data$cleaning_flag[4:5])))
  expect_equal(nrow(result$audit_trail), 3)
})

test_that("detect_truncated_compound_names handles NA empty and multiple Name columns", {
  df <- tibble::tibble(
    chemical_name = c(NA_character_, "", "acetone", "ok"),
    product_name = c("acetone", "product", "other ...", "compound [mix")
  )

  result <- detect_truncated_compound_names(df, c("chemical_name", "product_name"))

  expect_true(is.na(result$cleaned_data$cleaning_flag[1]))
  expect_true(is.na(result$cleaned_data$cleaning_flag[2]))
  expect_true(grepl(
    "BLOCK: truncated compound \\[ellipsis\\]",
    result$cleaned_data$cleaning_flag[3]
  ))
  expect_true(grepl(
    "BLOCK: truncated compound \\[unbalanced delimiter\\]",
    result$cleaned_data$cleaning_flag[4]
  ))
  expect_equal(result$audit_trail$field, c("product_name", "product_name"))
})

test_that("detect_truncated_compound_names appends to existing flags", {
  df <- tibble::tibble(
    chemical_name = c("compound ...", "compound [mix ..."),
    cleaning_flag = c("WARNING: existing", "WARNING: existing")
  )

  result <- detect_truncated_compound_names(df, "chemical_name")

  expect_equal(
    result$cleaned_data$cleaning_flag[1],
    "WARNING: existing; BLOCK: truncated compound [ellipsis]"
  )
  expect_true(grepl(
    "WARNING: existing; BLOCK: truncated compound \\[unbalanced delimiter\\]; BLOCK: truncated compound \\[ellipsis\\]",
    result$cleaned_data$cleaning_flag[2]
  ))
})

test_that("run_cleaning_pipeline flags truncated compound names", {
  df <- tibble::tibble(
    cas_number = c("80-05-7", "67-64-1"),
    chemical_name = c("Bisphenol A (BPA", "acetone")
  )
  tag_map <- list(cas_number = "CASRN", chemical_name = "Name")

  result <- run_cleaning_pipeline(df, tag_map)

  expect_equal(result$cleaned_data$chemical_name[1], "Bisphenol A (BPA")
  expect_true(grepl(
    "BLOCK: truncated compound \\[unbalanced delimiter\\]",
    result$cleaned_data$cleaning_flag[1]
  ))
  expect_true(is.na(result$cleaned_data$cleaning_flag[2]))
  expect_true("detect_truncated_compound" %in% result$audit_trail$step)
})
